import Combine
import CoreLocation
import Foundation
import SwiftUI

/// Gravidade das condições para escalada em rocha.
enum ClimbingWeatherAlertLevel: Int, Comparable {
    case safe = 0
    case caution = 1
    case danger = 2

    static func < (lhs: ClimbingWeatherAlertLevel, rhs: ClimbingWeatherAlertLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .safe: return "Condições favoráveis"
        case .caution: return "Atenção"
        case .danger: return "Risco alto"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: return Color(red: 0.20, green: 0.72, blue: 0.42)
        case .caution: return Color(red: 0.95, green: 0.72, blue: 0.18)
        case .danger: return Color(red: 0.90, green: 0.28, blue: 0.24)
        }
    }
}

/// Clima para escalada via Open-Meteo (HTTPS, sem API key): chuva, vento forte e raios.
@MainActor
final class ClimbingWeatherService: ObservableObject {
    static let shared = ClimbingWeatherService()

    struct Snapshot: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        let locationLabel: String
        let temperatureCelsius: Double?
        let humidityPercent: Double?
        let windSpeedKmh: Double
        let windGustsKmh: Double?
        let precipitationMm: Double?
        /// Maior probabilidade de chuva nas próximas horas.
        let rainChancePercent: Double?
        let uvIndex: Double?
        /// Código WMO da condição atual.
        let weatherCode: Int?
        let fetchedAt: Date

        /// Tempestade em curso: WMO 95 (trovoada), 96 e 99 (trovoada com granizo).
        var hasThunderstorm: Bool {
            guard let weatherCode else { return false }
            return weatherCode >= 95
        }

        var isRaining: Bool {
            if let precipitationMm, precipitationMm >= 0.2 { return true }
            guard let weatherCode else { return false }
            // 61–67 chuva, 80–82 pancadas.
            return (61...67).contains(weatherCode) || (80...82).contains(weatherCode)
        }

        var effectiveWindKmh: Double { windGustsKmh ?? windSpeedKmh }

        var alertLevel: ClimbingWeatherAlertLevel {
            if hasThunderstorm || effectiveWindKmh >= 55 { return .danger }
            if isRaining || effectiveWindKmh >= 35 { return .danger }
            if (rainChancePercent ?? 0) >= 60 || effectiveWindKmh >= 25 { return .caution }
            if let uvIndex, uvIndex >= 8 { return .caution }
            return .safe
        }

        /// Avisos acionáveis, do mais grave para o menos.
        var alerts: [String] {
            var list: [String] = []

            if hasThunderstorm {
                list.append("Risco de raios. Saia da parede e afaste-se de cumes, cadeias e árvores isoladas — o costão é o pior lugar numa tempestade.")
            }

            if isRaining {
                list.append("Chovendo. Rocha molhada perde atrito e o arenito fica frágil — escalar molhado quebra agarras.")
            } else if let chance = rainChancePercent, chance >= 60 {
                list.append(String(format: "%.0f%% de chance de chuva nas próximas horas. Leve capa para a mochila e planeje a retirada.", chance))
            }

            let wind = effectiveWindKmh
            if wind >= 55 {
                list.append(String(format: "Vento de %.0f km/h. Rapel e manejo de corda ficam perigosos nessa faixa.", wind))
            } else if wind >= 35 {
                list.append(String(format: "Vento forte de %.0f km/h. A corda embaraça e a comunicação com o segurança falha.", wind))
            } else if wind >= 25 {
                list.append(String(format: "Vento moderado de %.0f km/h. Prenda o cabelo e atenção ao rapel.", wind))
            }

            if let uvIndex, uvIndex >= 8 {
                list.append(String(format: "Índice UV %.0f. Protetor solar e camisa nas paradas expostas.", uvIndex))
            }

            if let temperatureCelsius, temperatureCelsius >= 30 {
                list.append(String(format: "%.0f °C. Calor derrete a aderência da borracha e sua pele sua — prefira o setor na sombra.", temperatureCelsius))
            }

            return list
        }

        /// Resumo curto para o cabeçalho.
        var summaryLine: String {
            var parts: [String] = []
            if let temperatureCelsius {
                parts.append(String(format: "%.0f °C", temperatureCelsius))
            }
            if let humidityPercent {
                parts.append(String(format: "umidade %.0f%%", humidityPercent))
            }
            parts.append(String(format: "vento %.0f km/h", windSpeedKmh))
            if let rainChancePercent {
                parts.append(String(format: "chuva %.0f%%", rainChancePercent))
            }
            return parts.joined(separator: " · ")
        }

        /// Condição de atrito: frio e seco é o que a rocha pede.
        var frictionNote: String? {
            guard let temperatureCelsius, let humidityPercent else { return nil }
            if temperatureCelsius <= 18 && humidityPercent <= 55 {
                return "Atrito excelente — frio e seco é a janela que os graus difíceis pedem."
            }
            if temperatureCelsius >= 28 || humidityPercent >= 80 {
                return "Atrito ruim — calor e umidade alta tiram aderência da borracha e da pele."
            }
            return nil
        }

        var updatedAtText: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: fetchedAt)
        }
    }

    enum ServiceError: LocalizedError {
        case offline
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .offline: return "Sem conexão. Verifique a internet e tente novamente."
            case .invalidResponse: return "Não foi possível obter as condições do tempo."
            }
        }
    }

    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let cacheTTL: TimeInterval = 10 * 60
    private var cacheKey: String?

    private init() {}

    // MARK: - Fetch

    @discardableResult
    func refresh(
        coordinate: CLLocationCoordinate2D,
        locationLabel: String,
        forceRefresh: Bool = false
    ) async -> Snapshot? {
        let key = String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
        if !forceRefresh,
           cacheKey == key,
           let snapshot,
           Date().timeIntervalSince(snapshot.fetchedAt) < cacheTTL {
            return snapshot
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await fetch(coordinate: coordinate, locationLabel: locationLabel)
            cacheKey = key
            snapshot = fetched
            return fetched
        } catch {
            errorMessage = (error as? ServiceError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    private func fetch(
        coordinate: CLLocationCoordinate2D,
        locationLabel: String
    ) async throws -> Snapshot {
        guard let url = Self.forecastURL(coordinate: coordinate) else {
            throw ServiceError.invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ServiceError.offline
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServiceError.invalidResponse
        }

        let decoded: ClimbingForecastResponse
        do {
            decoded = try JSONDecoder().decode(ClimbingForecastResponse.self, from: data)
        } catch {
            throw ServiceError.invalidResponse
        }

        guard let current = decoded.current else {
            throw ServiceError.invalidResponse
        }

        return Snapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationLabel: locationLabel,
            temperatureCelsius: current.temperature_2m,
            humidityPercent: current.relative_humidity_2m,
            windSpeedKmh: current.wind_speed_10m ?? 0,
            windGustsKmh: current.wind_gusts_10m,
            precipitationMm: current.precipitation,
            rainChancePercent: Self.peakRainChance(decoded.hourly),
            uvIndex: current.uv_index,
            weatherCode: current.weather_code,
            fetchedAt: Date()
        )
    }

    // MARK: - Private

    private static func forecastURL(coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_gusts_10m,uv_index"
            ),
            URLQueryItem(name: "hourly", value: "precipitation_probability"),
            URLQueryItem(name: "forecast_hours", value: "6"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    /// Pior cenário nas próximas horas — o que interessa para decidir se sobe ou não.
    private static func peakRainChance(_ hourly: ClimbingForecastHourly?) -> Double? {
        guard let values = hourly?.precipitation_probability else { return nil }
        return values.compactMap { $0 }.max()
    }
}

// MARK: - JSON

private struct ClimbingForecastResponse: Decodable {
    let current: ClimbingForecastCurrent?
    let hourly: ClimbingForecastHourly?
}

private struct ClimbingForecastCurrent: Decodable {
    let temperature_2m: Double?
    let relative_humidity_2m: Double?
    let precipitation: Double?
    let weather_code: Int?
    let wind_speed_10m: Double?
    let wind_gusts_10m: Double?
    let uv_index: Double?
}

private struct ClimbingForecastHourly: Decodable {
    let precipitation_probability: [Double?]?
}
