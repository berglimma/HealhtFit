import CoreLocation
import Foundation
import SwiftUI

// MARK: - Modalidade

/// Tipo de via — usado na taxa de sucesso por modalidade e no filtro do diário.
enum ClimbingDiscipline: String, Codable, CaseIterable, Identifiable, Hashable {
    case boulder = "Boulder"
    case sport = "Esportiva"
    case trad = "Tradicional"
    case gym = "Ginásio"
    case multipitch = "Via longa"
    case ice = "Gelo"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .boulder: return "square.stack.3d.up"
        case .sport: return "figure.climbing"
        case .trad: return "shippingbox"
        case .gym: return "building.2"
        case .multipitch: return "mountain.2"
        case .ice: return "snowflake"
        }
    }

    /// Ginásio é indoor — clima e GPS não se aplicam.
    var isOutdoor: Bool { self != .gym }

    /// Sistema de graduação natural da modalidade.
    var preferredGradeSystem: ClimbingGradeSystem {
        self == .boulder ? .vScale : .brazilian
    }

    var detail: String {
        switch self {
        case .boulder: return "Blocos baixos, sem corda, com crash pad"
        case .sport: return "Grampos fixos, mosquetão e corda"
        case .trad: return "Proteção móvel colocada pelo escalador"
        case .gym: return "Parede artificial indoor"
        case .multipitch: return "Vários enfiamentes com paradas"
        case .ice: return "Gelo ou misto, com piquetas e crampons"
        }
    }
}

// MARK: - Graduação

enum ClimbingGradeSystem: String, Codable, CaseIterable, Identifiable, Hashable {
    case brazilian = "Brasileiro"
    case french = "Francês"
    case vScale = "V (boulder)"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .brazilian: return "BR"
        case .french: return "FR"
        case .vScale: return "V"
        }
    }

    /// Escala ordenada, do mais fácil ao mais difícil.
    var ladder: [String] {
        switch self {
        case .brazilian:
            return ["I", "II", "III", "IV", "IVsup", "V", "Vsup", "VI", "VIsup",
                    "7a", "7b", "7c", "8a", "8b", "8c", "9a"]
        case .french:
            return ["4", "5a", "5b", "5c", "6a", "6a+", "6b", "6b+", "6c", "6c+",
                    "7a", "7a+", "7b", "7b+", "7c", "7c+", "8a", "8a+", "8b", "8b+", "8c", "9a"]
        case .vScale:
            return ["VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7",
                    "V8", "V9", "V10", "V11", "V12", "V13", "V14"]
        }
    }
}

/// Grau de uma via com pontuação normalizada, para comparar sistemas diferentes.
///
/// A conversão entre sistemas é aproximada — como toda tabela de equivalência de
/// escalada, serve para acompanhar tendência de evolução, não para cravar equivalência.
struct ClimbingGrade: Codable, Hashable, Identifiable {
    var system: ClimbingGradeSystem
    var label: String

    var id: String { "\(system.rawValue)#\(label)" }

    init(system: ClimbingGradeSystem, label: String) {
        self.system = system
        self.label = label
    }

    /// Pontuação 0–100 compartilhada entre sistemas.
    var difficultyPoints: Double {
        Self.pointsTable[system]?[label] ?? 0
    }

    /// "6º", "7º" — a linguagem que o escalador brasileiro usa para falar de progressão.
    var brazilianDegree: Int? {
        let p = difficultyPoints
        guard p > 0 else { return nil }
        switch p {
        case ..<20: return 3
        case ..<26: return 4
        case ..<33: return 5
        case ..<45: return 6
        case ..<62: return 7
        case ..<80: return 8
        default: return 9
        }
    }

    var degreeLabel: String {
        guard let degree = brazilianDegree else { return label }
        return "\(degree)º grau"
    }

    var displayLabel: String { "\(label) (\(system.shortLabel))" }

    static func defaultGrade(for discipline: ClimbingDiscipline) -> ClimbingGrade {
        let system = discipline.preferredGradeSystem
        let ladder = system.ladder
        // Meio da escala é um ponto de partida mais útil que o extremo fácil.
        let index = max(0, ladder.count / 2 - 1)
        return ClimbingGrade(system: system, label: ladder[index])
    }

    static func all(for system: ClimbingGradeSystem) -> [ClimbingGrade] {
        system.ladder.map { ClimbingGrade(system: system, label: $0) }
    }

    // Âncoras aproximadas em uma régua 0–100 comum aos três sistemas.
    private static let pointsTable: [ClimbingGradeSystem: [String: Double]] = [
        .french: [
            "4": 20, "5a": 24, "5b": 27, "5c": 30,
            "6a": 34, "6a+": 37, "6b": 40, "6b+": 43, "6c": 46, "6c+": 49,
            "7a": 53, "7a+": 56, "7b": 59, "7b+": 62, "7c": 65, "7c+": 68,
            "8a": 72, "8a+": 75, "8b": 78, "8b+": 81, "8c": 84, "9a": 90
        ],
        .brazilian: [
            "I": 8, "II": 12, "III": 16, "IV": 20, "IVsup": 23,
            "V": 26, "Vsup": 29, "VI": 33, "VIsup": 37,
            "7a": 45, "7b": 52, "7c": 60, "8a": 68, "8b": 76, "8c": 83, "9a": 90
        ],
        .vScale: [
            "VB": 28, "V0": 34, "V1": 40, "V2": 45, "V3": 50, "V4": 55,
            "V5": 60, "V6": 65, "V7": 69, "V8": 73, "V9": 77, "V10": 81,
            "V11": 84, "V12": 87, "V13": 90, "V14": 93
        ]
    ]
}

// MARK: - Estilo de ascensão

enum ClimbingAscentStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Encadenou de primeira, sem informação prévia.
    case onsight = "Onsight"
    /// Encadenou de primeira, com beta.
    case flash = "Flash"
    /// Encadenou após trabalhar a via.
    case redpoint = "Redpoint"
    /// Subiu com corda por cima.
    case topRope = "Top rope"
    /// Não completou.
    case failed = "Não completou"

    var id: String { rawValue }

    var isSuccess: Bool { self != .failed }

    var icon: String {
        switch self {
        case .onsight: return "eye.fill"
        case .flash: return "bolt.fill"
        case .redpoint: return "checkmark.seal.fill"
        case .topRope: return "arrow.up.circle"
        case .failed: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .onsight: return Color(red: 0.20, green: 0.72, blue: 0.42)
        case .flash: return Color(red: 0.95, green: 0.72, blue: 0.18)
        case .redpoint: return Color(red: 0.90, green: 0.32, blue: 0.28)
        case .topRope: return Color(red: 0.30, green: 0.58, blue: 0.90)
        case .failed: return Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    /// Peso da qualidade da ascensão — onsight vale mais que top rope na média ponderada.
    var qualityWeight: Double {
        switch self {
        case .onsight: return 1.0
        case .flash: return 0.9
        case .redpoint: return 0.8
        case .topRope: return 0.5
        case .failed: return 0
        }
    }
}

// MARK: - Tentativa

/// Uma tentativa registrada em uma via durante a sessão.
struct ClimbingAttempt: Codable, Hashable, Identifiable {
    var id: UUID
    var routeName: String
    var discipline: ClimbingDiscipline
    var grade: ClimbingGrade
    var style: ClimbingAscentStyle
    /// Quedas na tentativa (0 em onsight/flash).
    var falls: Int
    var notes: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        routeName: String,
        discipline: ClimbingDiscipline,
        grade: ClimbingGrade,
        style: ClimbingAscentStyle,
        falls: Int = 0,
        notes: String = "",
        recordedAt: Date = .now
    ) {
        self.id = id
        self.routeName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.discipline = discipline
        self.grade = grade
        self.style = style
        self.falls = max(0, falls)
        self.notes = notes
        self.recordedAt = recordedAt
    }

    var isSuccess: Bool { style.isSuccess }

    var displayName: String {
        routeName.isEmpty ? "Via sem nome" : routeName
    }
}

// MARK: - Setup da sessão

/// Configuração escolhida antes de iniciar a escalada.
struct ClimbingSetup: Hashable, Codable {
    var discipline: ClimbingDiscipline
    var gradeSystem: ClimbingGradeSystem
    /// Meta de grau para a sessão (opcional).
    var targetGrade: ClimbingGrade?
    /// Setor / área escolhida no mapa.
    var areaName: String
    var areaLatitude: Double?
    var areaLongitude: Double?
    /// Ligar detecção de tentativas por acelerômetro + giroscópio.
    var usesMotionDetection: Bool

    init(
        discipline: ClimbingDiscipline = .sport,
        gradeSystem: ClimbingGradeSystem? = nil,
        targetGrade: ClimbingGrade? = nil,
        areaName: String = "",
        areaLatitude: Double? = nil,
        areaLongitude: Double? = nil,
        usesMotionDetection: Bool = true
    ) {
        self.discipline = discipline
        self.gradeSystem = gradeSystem ?? discipline.preferredGradeSystem
        self.targetGrade = targetGrade
        self.areaName = areaName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.areaLatitude = areaLatitude
        self.areaLongitude = areaLongitude
        self.usesMotionDetection = usesMotionDetection
    }

    static let `default` = ClimbingSetup()

    var coordinate: CLLocationCoordinate2D? {
        guard let areaLatitude, let areaLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: areaLatitude, longitude: areaLongitude)
    }

    func snapshot() -> ClimbingSessionSnapshot {
        ClimbingSessionSnapshot(
            discipline: discipline,
            gradeSystem: gradeSystem,
            targetGradeLabel: targetGrade?.label,
            areaName: areaName.isEmpty ? nil : areaName,
            areaLatitude: areaLatitude,
            areaLongitude: areaLongitude
        )
    }
}

// MARK: - Snapshot persistido

/// Resumo da sessão de escalada gravado junto ao `WorkoutSession`.
struct ClimbingSessionSnapshot: Codable, Hashable {
    var discipline: ClimbingDiscipline
    var gradeSystem: ClimbingGradeSystem
    var targetGradeLabel: String?
    var areaName: String?
    var areaLatitude: Double?
    var areaLongitude: Double?
    var attempts: [ClimbingAttempt]
    /// Tempo em parede detectado pelos sensores (segundos).
    var activeClimbingSeconds: Int
    /// Tempo de descanso entre tentativas detectado pelos sensores (segundos).
    var detectedRestSeconds: Int
    /// Tentativas identificadas automaticamente pelo acelerômetro/giroscópio.
    var autoDetectedAttemptCount: Int
    /// Sessão aberta automaticamente pela detecção do Apple Watch.
    var startedAutomatically: Bool
    // Contexto de saúde e clima, para o IAssistente cruzar desempenho com recuperação.
    var heartRateAverage: Double?
    var caloriesBurned: Double?
    var sleepHoursBefore: Double?
    var hrvMsBefore: Double?
    var temperatureCelsius: Double?
    var humidityPercent: Double?

    init(
        discipline: ClimbingDiscipline = .sport,
        gradeSystem: ClimbingGradeSystem = .brazilian,
        targetGradeLabel: String? = nil,
        areaName: String? = nil,
        areaLatitude: Double? = nil,
        areaLongitude: Double? = nil,
        attempts: [ClimbingAttempt] = [],
        activeClimbingSeconds: Int = 0,
        detectedRestSeconds: Int = 0,
        autoDetectedAttemptCount: Int = 0,
        startedAutomatically: Bool = false,
        heartRateAverage: Double? = nil,
        caloriesBurned: Double? = nil,
        sleepHoursBefore: Double? = nil,
        hrvMsBefore: Double? = nil,
        temperatureCelsius: Double? = nil,
        humidityPercent: Double? = nil
    ) {
        self.discipline = discipline
        self.gradeSystem = gradeSystem
        self.targetGradeLabel = targetGradeLabel
        self.areaName = areaName
        self.areaLatitude = areaLatitude
        self.areaLongitude = areaLongitude
        self.attempts = attempts
        self.activeClimbingSeconds = max(0, activeClimbingSeconds)
        self.detectedRestSeconds = max(0, detectedRestSeconds)
        self.autoDetectedAttemptCount = max(0, autoDetectedAttemptCount)
        self.startedAutomatically = startedAutomatically
        self.heartRateAverage = heartRateAverage
        self.caloriesBurned = caloriesBurned
        self.sleepHoursBefore = sleepHoursBefore
        self.hrvMsBefore = hrvMsBefore
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = humidityPercent
    }

    // Decodificação tolerante: sessões antigas não têm estes campos.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        discipline = try c.decodeIfPresent(ClimbingDiscipline.self, forKey: .discipline) ?? .sport
        gradeSystem = try c.decodeIfPresent(ClimbingGradeSystem.self, forKey: .gradeSystem) ?? .brazilian
        targetGradeLabel = try c.decodeIfPresent(String.self, forKey: .targetGradeLabel)
        areaName = try c.decodeIfPresent(String.self, forKey: .areaName)
        areaLatitude = try c.decodeIfPresent(Double.self, forKey: .areaLatitude)
        areaLongitude = try c.decodeIfPresent(Double.self, forKey: .areaLongitude)
        attempts = try c.decodeIfPresent([ClimbingAttempt].self, forKey: .attempts) ?? []
        activeClimbingSeconds = max(0, try c.decodeIfPresent(Int.self, forKey: .activeClimbingSeconds) ?? 0)
        detectedRestSeconds = max(0, try c.decodeIfPresent(Int.self, forKey: .detectedRestSeconds) ?? 0)
        autoDetectedAttemptCount = max(0, try c.decodeIfPresent(Int.self, forKey: .autoDetectedAttemptCount) ?? 0)
        startedAutomatically = try c.decodeIfPresent(Bool.self, forKey: .startedAutomatically) ?? false
        heartRateAverage = try c.decodeIfPresent(Double.self, forKey: .heartRateAverage)
        caloriesBurned = try c.decodeIfPresent(Double.self, forKey: .caloriesBurned)
        sleepHoursBefore = try c.decodeIfPresent(Double.self, forKey: .sleepHoursBefore)
        hrvMsBefore = try c.decodeIfPresent(Double.self, forKey: .hrvMsBefore)
        temperatureCelsius = try c.decodeIfPresent(Double.self, forKey: .temperatureCelsius)
        humidityPercent = try c.decodeIfPresent(Double.self, forKey: .humidityPercent)
    }

    private enum CodingKeys: String, CodingKey {
        case discipline, gradeSystem, targetGradeLabel
        case areaName, areaLatitude, areaLongitude
        case attempts, activeClimbingSeconds, detectedRestSeconds, autoDetectedAttemptCount
        case startedAutomatically
        case heartRateAverage, caloriesBurned, sleepHoursBefore, hrvMsBefore
        case temperatureCelsius, humidityPercent
    }

    // MARK: Derivados

    var successCount: Int { attempts.filter(\.isSuccess).count }

    var successRate: Double {
        guard !attempts.isEmpty else { return 0 }
        return Double(successCount) / Double(attempts.count)
    }

    var hardestSend: ClimbingAttempt? {
        attempts
            .filter(\.isSuccess)
            .max { $0.grade.difficultyPoints < $1.grade.difficultyPoints }
    }

    var totalFalls: Int { attempts.reduce(0) { $0 + $1.falls } }

    var coordinate: CLLocationCoordinate2D? {
        guard let areaLatitude, let areaLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: areaLatitude, longitude: areaLongitude)
    }

    /// Proporção do tempo de sessão realmente em parede.
    func effortRatio(totalSeconds: Int) -> Double? {
        guard totalSeconds > 0, activeClimbingSeconds > 0 else { return nil }
        return min(1, Double(activeClimbingSeconds) / Double(totalSeconds))
    }
}

// MARK: - Área de escalada (mapa)

/// Setor de escalada exibido no mapa.
struct ClimbingArea: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double
    var disciplines: [ClimbingDiscipline]
    var routeCount: Int
    var gradeRange: String
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        region: String,
        latitude: Double,
        longitude: Double,
        disciplines: [ClimbingDiscipline],
        routeCount: Int,
        gradeRange: String,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.disciplines = disciplines
        self.routeCount = routeCount
        self.gradeRange = gradeRange
        self.notes = notes
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var disciplineSummary: String {
        disciplines.map(\.rawValue).joined(separator: " · ")
    }

    func distanceKm(from coordinate: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return a.distance(from: b) / 1000.0
    }
}
