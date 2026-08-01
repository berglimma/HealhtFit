import CoreLocation
import Foundation

/// Estado de atividade durante uma corrida ao ar livre.
enum RunningActivityState: String, Codable, CaseIterable, Identifiable {
    case stationary = "Parado"
    case walking = "Caminhando"
    case running = "Correndo"
    case unknown = "Detectando"

    var id: String { rawValue }

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .stationary: return "pause.circle.fill"
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .unknown: return "location.slash"
        }
    }
}

/// Ponto GPS persistível da rota de corrida.
struct RouteCoordinate: Identifiable, Codable, Hashable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var timestamp: Date
    var speedMetersPerSecond: Double?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date = .now,
        speedMetersPerSecond: Double? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speedMetersPerSecond = speedMetersPerSecond
    }

    init(location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            speedMetersPerSecond: location.speed >= 0 ? location.speed : nil
        )
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

    /// Classifica velocidade GPS (m/s): parado / caminhada / corrida.
    static func activityState(fromSpeedMetersPerSecond speed: Double) -> RunningActivityState {
        if speed < 0.5 { return .stationary }
        if speed < 2.0 { return .walking }
        return .running
    }

    /// Estimativa de calorias: MET × peso (kg) × horas.
    static func estimatedCalories(
        weightKg: Double,
        elapsedSeconds: Int,
        activityState: RunningActivityState,
        speedMetersPerSecond: Double?
    ) -> Double {
        let hours = Double(max(elapsedSeconds, 0)) / 3_600.0
        let weight = max(weightKg, 40)
        let met = metValue(activityState: activityState, speedMetersPerSecond: speedMetersPerSecond)
        return met * weight * hours
    }

    static func metValue(
        activityState: RunningActivityState,
        speedMetersPerSecond: Double?
    ) -> Double {
        if let speed = speedMetersPerSecond, speed > 0 {
            // Aproximação linear: caminhada ~3,5 MET a 1,4 m/s; corrida ~9,8 MET a 3,0 m/s.
            if speed < 0.5 { return 1.3 }
            if speed < 2.0 {
                return 2.5 + (speed / 2.0) * 1.5
            }
            return min(14.0, 6.0 + speed * 1.5)
        }
        switch activityState {
        case .stationary, .unknown: return 1.5
        case .walking: return 3.5
        case .running: return 9.8
        }
    }

    static func estimatedSteps(distanceKm: Double) -> Int {
        Int((max(distanceKm, 0) * estimatedStepsPerKm).rounded())
    }
}
