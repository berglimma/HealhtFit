import CoreLocation
import Foundation
import SwiftUI

/// Modalidade de tracking outdoor (classificação de movimento e calorias).
enum OutdoorCardioModality: String, Codable, CaseIterable {
    case running
    case walking
    case cycling
    case surfing
    case kitesurfing

    /// Corrida e caminhada usam pedômetro e estados Parado / Caminhando / Correndo.
    var usesFootTracking: Bool {
        switch self {
        case .running, .walking: return true
        case .cycling, .surfing, .kitesurfing: return false
        }
    }

    var isWaterSport: Bool {
        switch self {
        case .surfing, .kitesurfing: return true
        default: return false
        }
    }
}

/// Estado de atividade durante cardio outdoor (corrida, caminhada ou bike).
enum RunningActivityState: String, Codable, CaseIterable, Identifiable {
    case stationary = "Parado"
    case walking = "Caminhando"
    case running = "Correndo"
    case lightCycling = "Pedalando leve"
    case hardCycling = "Pedalando forte"
    case moving = "Em movimento"
    case unknown = "Detectando"

    var id: String { rawValue }

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .stationary: return "pause.circle.fill"
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .lightCycling, .hardCycling, .moving: return "bicycle"
        case .unknown: return "location.slash"
        }
    }
}

/// Ponto GPS persistível da rota outdoor.
struct RouteCoordinate: Identifiable, Codable, Hashable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var timestamp: Date
    var speedMetersPerSecond: Double?
    /// Gravado durante pausa do treino (segmento azul no mapa).
    var isPaused: Bool

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date = .now,
        speedMetersPerSecond: Double? = nil,
        isPaused: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speedMetersPerSecond = speedMetersPerSecond
        self.isPaused = isPaused
    }

    init(location: CLLocation, isPaused: Bool = false) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            speedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
            isPaused: isPaused
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? .now
        speedMetersPerSecond = try container.decodeIfPresent(Double.self, forKey: .speedMetersPerSecond)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(speedMetersPerSecond, forKey: .speedMetersPerSecond)
        if isPaused {
            try container.encode(isPaused, forKey: .isPaused)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, altitude, timestamp, speedMetersPerSecond, isPaused
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: 1,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}

enum RunTrackingMath {
    /// Passos médios por km (passada ~0,76 m) quando o pedômetro não está disponível.
    static let estimatedStepsPerKm = 1_312.0

    /// Classifica velocidade GPS (m/s) para corrida: parado / caminhada / corrida.
    static func activityState(fromSpeedMetersPerSecond speed: Double) -> RunningActivityState {
        activityState(fromSpeedMetersPerSecond: speed, modality: .running)
    }

    /// Classifica velocidade GPS conforme a modalidade.
    static func activityState(
        fromSpeedMetersPerSecond speed: Double,
        modality: OutdoorCardioModality
    ) -> RunningActivityState {
        switch modality {
        case .running, .walking:
            // Corrida e caminhada: Parado / Caminhando / Correndo.
            if speed < 0.5 { return .stationary }
            if speed < 2.0 { return .walking }
            return .running
        case .cycling:
            if speed < 0.8 { return .stationary }
            if speed < 4.5 { return .lightCycling } // ~16 km/h
            return .hardCycling
        case .surfing, .kitesurfing:
            if speed < 0.6 { return .stationary }
            if speed < 3.0 { return .moving }
            return .hardCycling // reusa ícone alto movimento
        }
    }

    /// Estimativa de calorias: MET × peso (kg) × horas.
    static func estimatedCalories(
        weightKg: Double,
        elapsedSeconds: Int,
        activityState: RunningActivityState,
        speedMetersPerSecond: Double?,
        modality: OutdoorCardioModality = .running
    ) -> Double {
        let hours = Double(max(elapsedSeconds, 0)) / 3_600.0
        let weight = max(weightKg, 40)
        let met = metValue(
            activityState: activityState,
            speedMetersPerSecond: speedMetersPerSecond,
            modality: modality
        )
        return met * weight * hours
    }

    static func metValue(
        activityState: RunningActivityState,
        speedMetersPerSecond: Double?,
        modality: OutdoorCardioModality = .running
    ) -> Double {
        if let speed = speedMetersPerSecond, speed > 0 {
            switch modality {
            case .running:
                if speed < 0.5 { return 1.3 }
                if speed < 2.0 {
                    return 2.5 + (speed / 2.0) * 1.5
                }
                return min(14.0, 6.0 + speed * 1.5)
            case .walking:
                // Foco em caminhada: MET mais baixo que corrida no mesmo range.
                if speed < 0.5 { return 1.3 }
                if speed < 1.8 {
                    return 2.0 + (speed / 1.8) * 1.8
                }
                // Trote ocasional durante caminhada.
                return min(10.0, 4.5 + speed * 1.2)
            case .cycling:
                if speed < 0.8 { return 1.5 }
                // ~4 MET a 3 m/s (~11 km/h); ~10 MET a 8 m/s (~29 km/h)
                return min(12.0, 2.5 + speed * 0.95)
            case .surfing:
                if speed < 0.6 { return 2.0 }
                return min(11.0, 4.0 + speed * 1.1)
            case .kitesurfing:
                if speed < 0.8 { return 2.5 }
                return min(13.0, 5.0 + speed * 0.9)
            }
        }
        switch activityState {
        case .stationary, .unknown: return 1.5
        case .walking: return 3.5
        case .running: return 9.8
        case .lightCycling: return 5.5
        case .hardCycling: return 9.0
        case .moving: return 6.0
        }
    }

    static func estimatedSteps(distanceKm: Double) -> Int {
        Int((max(distanceKm, 0) * estimatedStepsPerKm).rounded())
    }

    /// Soma das distâncias entre pontos consecutivos da rota (km).
    static func distanceKm(from routePoints: [RouteCoordinate]) -> Double {
        guard routePoints.count >= 2 else { return 0 }
        var meters = 0.0
        for index in 1..<routePoints.count {
            meters += routePoints[index - 1].clLocation.distance(from: routePoints[index].clLocation)
        }
        return meters / 1_000.0
    }
}

// MARK: - Performance-colored route

/// Métrica relativa para colorir segmentos da rota (mais rápido = melhor = verde).
enum RoutePerformanceMetric: String, Codable, CaseIterable {
    /// Corrida: ritmo implícito via velocidade (mais rápido = verde).
    case pace
    /// Bike: velocidade (mais rápido = verde).
    case speed
}

/// Faixa discreta de rendimento relativo à mediana da sessão.
enum RoutePerformanceBand: String, Equatable, CaseIterable {
    /// Parado / quase parado — cinza (não conta como rendimento ruim).
    case stopped
    /// Trecho com pausa do treino ativa — azul.
    case paused
    /// Abaixo do rendimento (< ~90% da mediana).
    case below
    /// Rendimento intermediário (~90–110% da mediana).
    case intermediate
    /// Rendimento ótimo (≥ ~110% da mediana).
    case optimal

    /// Score canônico: pausa=-2, parado=-1, abaixo=0, meio=0.5, ótimo=1.
    var performanceScore: Double {
        switch self {
        case .paused: return -2
        case .stopped: return -1
        case .below: return 0
        case .intermediate: return 0.5
        case .optimal: return 1
        }
    }
}

/// Segmento colorido entre dois pontos GPS consecutivos.
struct RoutePerformanceSegment: Identifiable {
    let id: UUID
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    /// Faixa discreta: ótimo / intermediário / abaixo / parado.
    let band: RoutePerformanceBand
    /// -1 = parado, 0 = abaixo, 0.5 = intermediário, 1 = ótimo.
    let performanceScore: Double
    let color: Color

    init(
        id: UUID = UUID(),
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        band: RoutePerformanceBand,
        performanceScore: Double? = nil,
        color: Color? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.band = band
        self.performanceScore = performanceScore ?? band.performanceScore
        self.color = color ?? RoutePerformanceColoring.color(for: band)
    }

    var coordinates: [CLLocationCoordinate2D] { [start, end] }
}

enum RoutePerformanceColoring {
    /// Velocidade mínima considerada em movimento (m/s).
    static let movingSpeedFloor = 0.4
    /// Abaixo do rendimento: velocidade < 90% da mediana em movimento.
    static let belowRatio = 0.90
    /// Rendimento ótimo: velocidade ≥ 110% da mediana em movimento.
    static let optimalRatio = 1.10

    static let legendText = "Verde ótimo · Amarelo intermediário · Vermelho abaixo · Azul pausa"

    /// Gera segmentos coloridos por faixa relativa à mediana de velocidades em movimento.
    /// Verde = ótimo, amarelo = intermediário, vermelho = abaixo; parado = cinza; pausa = azul.
    static func segments(
        from routePoints: [RouteCoordinate],
        metric: RoutePerformanceMetric = .pace
    ) -> [RoutePerformanceSegment] {
        guard routePoints.count >= 2 else { return [] }

        // metric reserved for future pace-specific weighting; faster = better for both.
        _ = metric

        var rawSpeeds: [Double] = []
        rawSpeeds.reserveCapacity(routePoints.count - 1)
        var isPausedSegment: [Bool] = []
        isPausedSegment.reserveCapacity(routePoints.count - 1)

        for index in 1..<routePoints.count {
            let a = routePoints[index - 1]
            let b = routePoints[index]
            // Segmento em pausa se qualquer extremo foi gravado durante pausa.
            isPausedSegment.append(a.isPaused || b.isPaused)
            rawSpeeds.append(segmentSpeed(from: a, to: b))
        }

        // Pausa não entra na mediana (evita puxar faixas de desempenho).
        let movingSpeeds = zip(rawSpeeds, isPausedSegment)
            .compactMap { speed, paused -> Double? in
                guard !paused, speed >= movingSpeedFloor else { return nil }
                return speed
            }
        let medianSpeed = median(of: movingSpeeds) ?? movingSpeedFloor

        var result: [RoutePerformanceSegment] = []
        result.reserveCapacity(rawSpeeds.count)

        for index in 0..<rawSpeeds.count {
            let performanceBand: RoutePerformanceBand
            if isPausedSegment[index] {
                performanceBand = .paused
            } else {
                performanceBand = band(forSpeed: rawSpeeds[index], medianMovingSpeed: medianSpeed)
            }
            let a = routePoints[index]
            let b = routePoints[index + 1]
            result.append(
                RoutePerformanceSegment(
                    start: a.coordinate,
                    end: b.coordinate,
                    band: performanceBand
                )
            )
        }
        return result
    }

    /// Classifica velocidade relativa à mediana da sessão.
    static func band(forSpeed speed: Double, medianMovingSpeed: Double) -> RoutePerformanceBand {
        guard speed >= movingSpeedFloor else { return .stopped }
        let baseline = max(medianMovingSpeed, movingSpeedFloor)
        let ratio = speed / baseline
        if ratio >= optimalRatio { return .optimal }
        if ratio < belowRatio { return .below }
        return .intermediate
    }

    static func color(for band: RoutePerformanceBand) -> Color {
        switch band {
        case .paused:
            return Color(red: 0.20, green: 0.48, blue: 0.96)
        case .stopped:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .below:
            return Color(red: 0.90, green: 0.22, blue: 0.21)
        case .intermediate:
            return Color(red: 0.95, green: 0.78, blue: 0.18)
        case .optimal:
            return Color(red: 0.22, green: 0.78, blue: 0.40)
        }
    }

    /// Mapeia score canônico para cor discreta das faixas (+ cinza parado, azul pausa).
    static func color(forScore score: Double) -> Color {
        if score <= -1.5 { return color(for: .paused) }
        if score < 0 { return color(for: .stopped) }
        if score < 0.25 { return color(for: .below) }
        if score < 0.75 { return color(for: .intermediate) }
        return color(for: .optimal)
    }

    static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func segmentSpeed(from a: RouteCoordinate, to b: RouteCoordinate) -> Double {
        if let s = b.speedMetersPerSecond, s >= 0 {
            return s
        }
        if let s = a.speedMetersPerSecond, s >= 0 {
            return s
        }
        let meters = a.clLocation.distance(from: b.clLocation)
        let dt = b.timestamp.timeIntervalSince(a.timestamp)
        guard dt > 0.05 else { return 0 }
        return meters / dt
    }
}
