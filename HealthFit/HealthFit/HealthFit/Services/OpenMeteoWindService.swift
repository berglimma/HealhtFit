import CoreLocation
import Foundation

/// Condições de vento e mar (ondas + nível do mar) via Open-Meteo — HTTPS, sem API key.
@MainActor
final class OpenMeteoWindService {
    static let shared = OpenMeteoWindService()

    /// Ponto horário de nível do mar / ondas (Open-Meteo Marine).
    struct MarineHourPoint: Equatable, Sendable, Identifiable {
        let id: String
        let time: Date
        let seaLevelMeters: Double?
        let waveHeightMeters: Double?
        let wavePeriodSeconds: Double?

        var hourLabel: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: time)
        }
    }

    /// Extremo estimado a partir da série de `sea_level_height_msl` (não é tábua oficial).
    struct TideExtremum: Equatable, Sendable, Identifiable {
        enum Kind: String, Sendable {
            case high
            case low
        }

        let id: String
        let kind: Kind
        let time: Date
        let heightMeters: Double

        var kindLabel: String {
            switch kind {
            case .high: return "Preamar (est.)"
            case .low: return "Baixamar (est.)"
            }
        }
    }

    struct Snapshot: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        let locationLabel: String
        let windSpeedKmh: Double
        let windDirectionDegrees: Double
        let windGustsKmh: Double?
        let waveHeightMeters: Double?
        let wavePeriodSeconds: Double?
        /// Nível do mar atual vs. MSL global (`sea_level_height_msl`) — estimado, não tábua de porto.
        let seaLevelHeightMeters: Double?
        /// Próximas horas de maré/ondas.
        let marineHours: [MarineHourPoint]
        /// Extremos locais estimados da série de nível do mar.
        let tideExtrema: [TideExtremum]
        let fetchedAt: Date

        var windLabel: String {
            WindDirectionLabels.label(degrees: windDirectionDegrees)
        }

        var updatedAtText: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: fetchedAt)
        }

        /// Rótulo honesto da “maré” a gravar no setup da sessão.
        var estimatedTideLabel: String {
            if let next = tideExtrema.first {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "pt_BR")
                formatter.dateFormat = "HH:mm"
                return "\(next.kindLabel) ~\(formatter.string(from: next.time))"
            }
            if seaLevelHeightMeters != nil || !marineHours.isEmpty {
                if let phase = estimatedPhaseLabel {
                    return "\(phase) · Nível do mar (estimado)"
                }
                return "Nível do mar (estimado)"
            }
            return "Não informado"
        }

        /// Enchente/Vazante a partir da tendência entre as próximas horas de `sea_level_height_msl`.
        var estimatedPhaseLabel: String? {
            let levels = marineHours.compactMap { point -> (Date, Double)? in
                guard let h = point.seaLevelMeters else { return nil }
                return (point.time, h)
            }
            guard levels.count >= 2 else { return nil }
            let delta = levels[1].1 - levels[0].1
            if abs(delta) < 0.01 { return nil }
            return delta > 0 ? "Enchente (est.)" : "Vazante (est.)"
        }

        var hasMarineData: Bool {
            waveHeightMeters != nil
                || wavePeriodSeconds != nil
                || seaLevelHeightMeters != nil
                || !marineHours.isEmpty
        }

        /// Altura “de maré” para gravação da sessão (m) — nível do mar atual ou próximo extremo.
        var displayTideHeightMeters: Double? {
            if let sea = seaLevelHeightMeters {
                return abs(sea)
            }
            return tideExtrema.first.map(\.heightMeters)
        }

        // MARK: Favorabilidade (heurística simples)

        /// Surf: preferimos maré intermediária (não extremos de preamar/baixamar) e ondas ~0,5–2,8 m quando há dado.
        /// Kite: vento 15–42 km/h, rajadas controladas, e maré não em baixamar extrema.
        func favorability(isKitesurf: Bool) -> TideWindFavorability {
            if isKitesurf {
                return kiteFavorability
            }
            return surfFavorability
        }

        private var surfFavorability: TideWindFavorability {
            guard hasMarineData || seaLevelHeightMeters != nil || !tideExtrema.isEmpty else {
                return .unknown
            }

            var score = 0
            var votes = 0

            if let wave = waveHeightMeters {
                votes += 1
                if wave >= 0.5 && wave <= 2.8 {
                    score += 2
                } else if wave > 0.25 && wave < 3.5 {
                    score += 1
                }
            }

            let tideScore = midTideScore
            if let tideScore {
                votes += 1
                score += tideScore
            }

            if let phase = estimatedPhaseLabel {
                votes += 1
                // Enchente/Vazante costuma ser janela útil em muitos picos.
                if phase.contains("Enchente") || phase.contains("Vazante") {
                    score += 2
                } else {
                    score += 1
                }
            }

            guard votes > 0 else { return .unknown }
            let avg = Double(score) / Double(votes)
            if avg >= 1.6 { return .favorable }
            if avg >= 0.9 { return .moderate }
            return .unfavorable
        }

        private var kiteFavorability: TideWindFavorability {
            var score = 0
            var votes = 0

            votes += 1
            if windSpeedKmh >= 15 && windSpeedKmh <= 42 {
                score += 2
            } else if windSpeedKmh >= 12 && windSpeedKmh <= 50 {
                score += 1
            }

            if let gusts = windGustsKmh {
                votes += 1
                let spread = gusts - windSpeedKmh
                if spread <= 12 {
                    score += 2
                } else if spread <= 20 {
                    score += 1
                }
            }

            if let tideScore = midTideScore {
                votes += 1
                score += tideScore
            } else if hasMarineData {
                votes += 1
                score += 1
            }

            guard votes > 0 else { return .unknown }
            let avg = Double(score) / Double(votes)
            if avg >= 1.6 { return .favorable }
            if avg >= 0.9 { return .moderate }
            return .unfavorable
        }

        /// 0–2: 2 = maré intermediária entre extremos, 1 = razoável, 0 = extremo.
        private var midTideScore: Int? {
            let levels = marineHours.compactMap(\.seaLevelMeters)
            let current = seaLevelHeightMeters
                ?? marineHours.first(where: { $0.seaLevelMeters != nil })?.seaLevelMeters
            guard let current, !levels.isEmpty else {
                // Sem série: evita baixamar “agora” se o próximo extremo for baixa em <1 h
                if let next = tideExtrema.first {
                    if next.kind == .low, next.time.timeIntervalSinceNow < 3600 {
                        return 0
                    }
                    return 1
                }
                return nil
            }
            let minL = levels.min() ?? current
            let maxL = levels.max() ?? current
            let span = maxL - minL
            guard span > 0.05 else { return 1 }
            let ratio = (current - minL) / span
            // Faixa intermediária 0,25–0,75
            if ratio >= 0.25 && ratio <= 0.75 { return 2 }
            if ratio >= 0.15 && ratio <= 0.85 { return 1 }
            return 0
        }

        /// Frases de praia para o card (condição + modalidade).
        func beachSportMessage(isKitesurf: Bool) -> String {
            let fav = favorability(isKitesurf: isKitesurf)
            if isKitesurf {
                switch fav {
                case .favorable:
                    return Self.pickRotating([
                        "Vento no ponto — hora de soltar o kite!",
                        "Condições no sweet spot. Bora voar com segurança!",
                        "Maré ok e vento bacana. Aproveita a sessão!"
                    ], salt: fetchedAt)
                case .moderate:
                    return Self.pickRotating([
                        "Dá pra andar — leia o vento e respeite o pico.",
                        "Janela razoável de kite. Confira rajadas e maré.",
                        "Condições medianas: escolha o horário com calma."
                    ], salt: fetchedAt)
                case .unfavorable:
                    return Self.pickRotating([
                        "Vento ou maré menos ideais agora — planeje outra janela.",
                        "Hoje pede cautela no kite. Spot conhecido e limite seguro.",
                        "Nem todo dia é sessão. Revise a maré e volta mais forte."
                    ], salt: fetchedAt)
                case .unknown:
                    return "Liga o GPS e atualiza — a gente busca maré e vento pra você."
                }
            }
            switch fav {
            case .favorable:
                return Self.pickRotating([
                    "Hora de pegar onda — maré no caminho certo!",
                    "Pico convidando. Respeito ao mar e boa sessão!",
                    "Maré favorável. Escolhe o pico e parte!"
                ], salt: fetchedAt)
            case .moderate:
                return Self.pickRotating([
                    "Maré ok — leia o banco e o horário do pico.",
                    "Condições razoáveis de surf. Calma na entrada.",
                    "Dá pra treinar com atenção à maré e ao local."
                ], salt: fetchedAt)
            case .unfavorable:
                return Self.pickRotating([
                    "Maré ou mar menos ideais. Se for, spot seguro.",
                    "Hoje a maré pede paciência — planeje a próxima janela.",
                    "Nem toda sessão precisa forçar. Observa e volta melhor."
                ], salt: fetchedAt)
            case .unknown:
                return "Buscando maré real com sua localização… atualize quando o GPS travar."
            }
        }

        private static func pickRotating(_ options: [String], salt: Date) -> String {
            guard !options.isEmpty else { return "" }
            let idx = Int(salt.timeIntervalSince1970 / 600) % options.count
            return options[idx]
        }
    }

    enum ServiceError: LocalizedError {
        case offline
        case invalidResponse
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .offline:
                return "Sem conexão. Verifique a internet e tente novamente."
            case .invalidResponse:
                return "Não foi possível obter condições de vento."
            case .decodeFailed:
                return "Resposta do clima inválida."
            }
        }
    }

    /// Florianópolis / costa sul — fallback quando não há GPS.
    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: -27.5954, longitude: -48.5480)
    static let fallbackLocationLabel = "Florianópolis (fallback)"

    private let cacheTTL: TimeInterval = 8 * 60
    private var cacheKey: String?
    private var cacheSnapshot: Snapshot?
    private let lastKnownDefaultsKey = "openMeteo.lastKnownLocation"
    /// Último snapshot bem-sucedido (para IAssistente / alertas de maré).
    private(set) var lastSuccessfulSnapshot: Snapshot?

    private init() {}

    // MARK: - Last known location

    func saveLastKnown(coordinate: CLLocationCoordinate2D, label: String? = nil) {
        let payload: [String: Any] = [
            "lat": coordinate.latitude,
            "lon": coordinate.longitude,
            "label": label ?? "Última localização",
            "at": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(payload, forKey: lastKnownDefaultsKey)
    }

    func lastKnownCoordinate() -> (CLLocationCoordinate2D, String)? {
        guard let dict = UserDefaults.standard.dictionary(forKey: lastKnownDefaultsKey),
              let lat = dict["lat"] as? Double,
              let lon = dict["lon"] as? Double else { return nil }
        let label = dict["label"] as? String ?? "Última localização"
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), label)
    }

    // MARK: - Fetch

    func fetch(
        latitude: Double,
        longitude: Double,
        locationLabel: String,
        forceRefresh: Bool = false
    ) async throws -> Snapshot {
        let key = String(format: "%.3f,%.3f", latitude, longitude)
        if !forceRefresh,
           let cacheKey,
           cacheKey == key,
           let cacheSnapshot,
           Date().timeIntervalSince(cacheSnapshot.fetchedAt) < cacheTTL {
            lastSuccessfulSnapshot = cacheSnapshot
            return cacheSnapshot
        }

        guard let url = Self.forecastURL(latitude: latitude, longitude: longitude) else {
            throw ServiceError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                throw ServiceError.offline
            }
            throw ServiceError.offline
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServiceError.invalidResponse
        }

        let forecast: ForecastResponse
        do {
            forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        } catch {
            throw ServiceError.decodeFailed
        }

        guard let current = forecast.current else {
            throw ServiceError.invalidResponse
        }

        let marine = await fetchMarineOptional(latitude: latitude, longitude: longitude)

        let snapshot = Snapshot(
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
            windSpeedKmh: current.wind_speed_10m ?? 0,
            windDirectionDegrees: current.wind_direction_10m ?? 0,
            windGustsKmh: current.wind_gusts_10m,
            waveHeightMeters: marine?.waveHeightMeters,
            wavePeriodSeconds: marine?.wavePeriodSeconds,
            seaLevelHeightMeters: marine?.seaLevelHeightMeters,
            marineHours: marine?.hours ?? [],
            tideExtrema: marine?.extrema ?? [],
            fetchedAt: Date()
        )

        cacheKey = key
        cacheSnapshot = snapshot
        lastSuccessfulSnapshot = snapshot
        saveLastKnown(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            label: locationLabel
        )
        return snapshot
    }

    /// Resolve coordenadas: GPS → última conhecida → cidade fallback.
    func resolveLocation(
        preferred: CLLocationCoordinate2D?,
        preferredLabel: String?
    ) -> (CLLocationCoordinate2D, String) {
        if let preferred {
            let label: String = {
                if let preferredLabel, !preferredLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return preferredLabel
                }
                return String(format: "GPS %.4f, %.4f", preferred.latitude, preferred.longitude)
            }()
            return (preferred, label)
        }
        if let last = lastKnownCoordinate() {
            return last
        }
        return (Self.fallbackCoordinate, Self.fallbackLocationLabel)
    }

    // MARK: - Private

    private static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "current",
                value: "wind_speed_10m,wind_direction_10m,wind_gusts_10m"
            ),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    private static func marineURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "current",
                value: "wave_height,wave_period,sea_level_height_msl"
            ),
            URLQueryItem(
                name: "hourly",
                value: "sea_level_height_msl,wave_height,wave_period"
            ),
            URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "cell_selection", value: "sea")
        ]
        return components?.url
    }

    private struct MarineParsed {
        let waveHeightMeters: Double?
        let wavePeriodSeconds: Double?
        let seaLevelHeightMeters: Double?
        let hours: [MarineHourPoint]
        let extrema: [TideExtremum]
    }

    private func fetchMarineOptional(latitude: Double, longitude: Double) async -> MarineParsed? {
        guard let url = Self.marineURL(latitude: latitude, longitude: longitude) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(MarineResponse.self, from: data)
            return Self.parseMarine(decoded)
        } catch {
            return nil
        }
    }

    private static func parseMarine(_ decoded: MarineResponse) -> MarineParsed {
        let current = decoded.current
        let hours = buildHourSeries(from: decoded.hourly)
        let seaLevels = hours.compactMap { p -> (Date, Double)? in
            guard let h = p.seaLevelMeters else { return nil }
            return (p.time, h)
        }
        let extrema = computeTideExtrema(from: seaLevels)
        return MarineParsed(
            waveHeightMeters: current?.wave_height,
            wavePeriodSeconds: current?.wave_period,
            seaLevelHeightMeters: current?.sea_level_height_msl,
            hours: hours,
            extrema: extrema
        )
    }

    private static func buildHourSeries(from hourly: MarineHourly?) -> [MarineHourPoint] {
        guard let hourly, let times = hourly.time, !times.isEmpty else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        // Open-Meteo local times often look like "2026-08-05T17:00" without Z
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let now = Date()
        var points: [MarineHourPoint] = []
        for (index, timeString) in times.enumerated() {
            let date = formatter.date(from: timeString)
                ?? localFormatter.date(from: timeString)
            guard let date else { continue }
            // Inclui a hora atual e as próximas (~12 h na UI).
            if date < now.addingTimeInterval(-3600) { continue }
            let sea = hourly.sea_level_height_msl.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            let wave = hourly.wave_height.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            let period = hourly.wave_period.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            if sea == nil && wave == nil && period == nil { continue }
            points.append(
                MarineHourPoint(
                    id: timeString,
                    time: date,
                    seaLevelMeters: sea,
                    waveHeightMeters: wave,
                    wavePeriodSeconds: period
                )
            )
            if points.count >= 12 { break }
        }
        return points
    }

    /// Extremos locais (máx/mín) na série de nível do mar — estimativa, não tábua oficial.
    private static func computeTideExtrema(from series: [(Date, Double)]) -> [TideExtremum] {
        guard series.count >= 3 else { return [] }
        var result: [TideExtremum] = []
        for i in 1..<(series.count - 1) {
            let prev = series[i - 1].1
            let cur = series[i].1
            let next = series[i + 1].1
            let kind: TideExtremum.Kind?
            if cur >= prev && cur > next {
                kind = .high
            } else if cur <= prev && cur < next {
                kind = .low
            } else {
                kind = nil
            }
            guard let kind else { continue }
            let time = series[i].0
            result.append(
                TideExtremum(
                    id: "\(kind.rawValue)-\(time.timeIntervalSince1970)",
                    kind: kind,
                    time: time,
                    heightMeters: cur
                )
            )
        }
        return Array(result.prefix(4))
    }
}

// MARK: - JSON

private struct ForecastResponse: Decodable {
    let current: ForecastCurrent?
}

private struct ForecastCurrent: Decodable {
    let wind_speed_10m: Double?
    let wind_direction_10m: Double?
    let wind_gusts_10m: Double?
}

private struct MarineResponse: Decodable {
    let current: MarineCurrent?
    let hourly: MarineHourly?
}

private struct MarineCurrent: Decodable {
    let wave_height: Double?
    let wave_period: Double?
    let sea_level_height_msl: Double?
}

private struct MarineHourly: Decodable {
    let time: [String]?
    let sea_level_height_msl: [Double?]?
    let wave_height: [Double?]?
    let wave_period: [Double?]?
}
