import CoreLocation
import Foundation

// MARK: - Equipamento Kite

enum KiteEquipmentType: String, CaseIterable, Identifiable, Codable, Hashable {
    case tubeKite = "Tube Kite"
    case foilKite = "Foil Kite"
    case hybrid = "Hybrid"
    case trainer = "Trainer / 2-linhas"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tubeKite: return "wind"
        case .foilKite: return "sailboat.fill"
        case .hybrid: return "arrow.triangle.branch"
        case .trainer: return "flag.2.crossed"
        }
    }

    var detail: String {
        switch self {
        case .tubeKite: return "Clássica com infláveis — freeride e Big Air"
        case .foilKite: return "Leve, bom em vento fraco e foiling"
        case .hybrid: return "Compromisso tube + foil"
        case .trainer: return "Aprendizado e treino em terra / água controlada"
        }
    }
}

// MARK: - Pranchas

enum WaterBoardCatalog: String, CaseIterable, Identifiable, Codable, Hashable {
    // Surf
    case shortboard = "Shortboard"
    case longboard = "Longboard"
    case fish = "Fish"
    case funboard = "Funboard"
    case softTop = "Soft top / escola"
    // Kite
    case twinTip = "Twin Tip"
    case directionalSurf = "Directional / Surfboard"
    case foilBoard = "Foil Board"
    case strapless = "Strapless"

    var id: String { rawValue }

    static var surfBoards: [WaterBoardCatalog] {
        [.shortboard, .longboard, .fish, .funboard, .softTop]
    }

    static var kiteBoards: [WaterBoardCatalog] {
        [.twinTip, .directionalSurf, .foilBoard, .strapless]
    }

    var isKiteBoard: Bool { Self.kiteBoards.contains(self) }
    var isSurfBoard: Bool { Self.surfBoards.contains(self) }

    var icon: String {
        switch self {
        case .shortboard, .longboard, .fish, .funboard, .softTop, .directionalSurf, .strapless:
            return "figure.surfing"
        case .twinTip: return "rectangle.split.2x1"
        case .foilBoard: return "water.waves.and.arrow.up"
        }
    }

    var detail: String {
        switch self {
        case .shortboard: return "Performance e manobras"
        case .longboard: return "Estabilidade e nose riders"
        case .fish: return "Ondas pequenas e velocidade"
        case .funboard: return "Transição intermediária"
        case .softTop: return "Iniciante e segurança"
        case .twinTip: return "Freeride e saltos simétricos"
        case .directionalSurf: return "Ondas e rides direcionais"
        case .foilBoard: return "Voo acima da água (hydrofoil)"
        case .strapless: return "Surf kite sem straps"
        }
    }
}

// MARK: - Modos de velejo (Kite)

enum KiteRidingMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case bigAir = "Big Air"
    case speed = "Speed"
    case coaching = "Coaching"
    case downwind = "Downwind"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bigAir: return "arrow.up.to.line"
        case .speed: return "gauge.with.dots.needle.67percent"
        case .coaching: return "person.badge.clock"
        case .downwind: return "wind"
        }
    }

    var detail: String {
        switch self {
        case .bigAir: return "Altitude e tempo de ar — foco em saltos"
        case .speed: return "Velocidade máxima e percursos longos"
        case .coaching: return "Sessão instructiva, ritmo controlado"
        case .downwind: return "Saída longe do ponto, percurso a favor do vento"
        }
    }
}

// MARK: - Spot e condições

struct WaterSpotInfo: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?

    init(id: UUID = UUID(), name: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasCoordinates: Bool { latitude != nil && longitude != nil }
}

struct WindTideConditions: Codable, Hashable {
    /// km/h
    var windSpeedKmh: Double
    /// Graus 0–360 (N=0)
    var windDirectionDegrees: Double
    var windLabel: String
    /// Descrição da maré (enchente, vazante, preamar…)
    var tideLabel: String
    /// Altura aproximada da maré (m), se conhecida
    var tideHeightMeters: Double?

    static let empty = WindTideConditions(
        windSpeedKmh: 0,
        windDirectionDegrees: 0,
        windLabel: "Não informado",
        tideLabel: "Não informado",
        tideHeightMeters: nil
    )

    var windSummary: String {
        if windSpeedKmh <= 0 { return windLabel }
        return String(format: "%.0f km/h · %@", windSpeedKmh, windLabel)
    }

    var tideSummary: String {
        if let h = tideHeightMeters {
            return String(format: "%@ (%.2f m)", tideLabel, h)
        }
        return tideLabel
    }
}

// MARK: - Saltos e aceleração

struct SurfJumpEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var timestamp: Date
    /// Altura estimada do salto (metros), giroscópio/altímetro Watch + iPhone
    var heightMeters: Double
    /// Aceleração de pico no salto (g)
    var peakAccelerationG: Double
    var airtimeSeconds: Double?
    var latitude: Double?
    var longitude: Double?
    var source: JumpEventSource

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        heightMeters: Double,
        peakAccelerationG: Double = 0,
        airtimeSeconds: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        source: JumpEventSource = .iphone
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heightMeters = heightMeters
        self.peakAccelerationG = peakAccelerationG
        self.airtimeSeconds = airtimeSeconds
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum JumpEventSource: String, Codable, Hashable {
    case iphone
    case appleWatch
    case manual
}

struct SurfAccelSample: Identifiable, Codable, Hashable {
    var id: UUID
    var timestamp: Date
    /// Magnitude da aceleração em g (inclui ou não gravidade conforme captura)
    var accelerationG: Double
    var source: JumpEventSource

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        accelerationG: Double,
        source: JumpEventSource = .iphone
    ) {
        self.id = id
        self.timestamp = timestamp
        self.accelerationG = accelerationG
        self.source = source
    }
}

// MARK: - Snapshot da sessão (persistido)

struct WaterSportSessionSnapshot: Codable, Hashable {
    var isKitesurf: Bool
    var kiteEquipmentRaw: String?
    var boardTypeRaw: String?
    var ridingModeRaw: String?
    var spot: WaterSpotInfo?
    var conditions: WindTideConditions?
    var jumps: [SurfJumpEvent]
    var accelerationSamples: [SurfAccelSample]

    init(
        isKitesurf: Bool,
        kiteEquipmentRaw: String? = nil,
        boardTypeRaw: String? = nil,
        ridingModeRaw: String? = nil,
        spot: WaterSpotInfo? = nil,
        conditions: WindTideConditions? = nil,
        jumps: [SurfJumpEvent] = [],
        accelerationSamples: [SurfAccelSample] = []
    ) {
        self.isKitesurf = isKitesurf
        self.kiteEquipmentRaw = kiteEquipmentRaw
        self.boardTypeRaw = boardTypeRaw
        self.ridingModeRaw = ridingModeRaw
        self.spot = spot
        self.conditions = conditions
        self.jumps = jumps
        self.accelerationSamples = accelerationSamples
    }

    var jumpCount: Int { jumps.count }

    var maxJumpHeightMeters: Double {
        jumps.map(\.heightMeters).max() ?? 0
    }

    var averageJumpHeightMeters: Double {
        guard !jumps.isEmpty else { return 0 }
        return jumps.map(\.heightMeters).reduce(0, +) / Double(jumps.count)
    }

    var maxAccelerationG: Double {
        let fromJumps = jumps.map(\.peakAccelerationG).max() ?? 0
        let fromSamples = accelerationSamples.map(\.accelerationG).max() ?? 0
        return max(fromJumps, fromSamples)
    }

    var kiteEquipment: KiteEquipmentType? {
        kiteEquipmentRaw.flatMap(KiteEquipmentType.init(rawValue:))
    }

    var boardType: WaterBoardCatalog? {
        boardTypeRaw.flatMap(WaterBoardCatalog.init(rawValue:))
    }

    var ridingMode: KiteRidingMode? {
        ridingModeRaw.flatMap(KiteRidingMode.init(rawValue:))
    }
}

// MARK: - Setup pre-treino

struct WaterSportSetup: Hashable, Codable {
    var kiteEquipment: KiteEquipmentType?
    var boardType: WaterBoardCatalog?
    var ridingMode: KiteRidingMode?
    var spot: WaterSpotInfo
    var conditions: WindTideConditions

    static func defaultSurf() -> WaterSportSetup {
        WaterSportSetup(
            kiteEquipment: nil,
            boardType: .shortboard,
            ridingMode: nil,
            spot: WaterSpotInfo(name: ""),
            conditions: .empty
        )
    }

    static func defaultKite() -> WaterSportSetup {
        WaterSportSetup(
            kiteEquipment: .tubeKite,
            boardType: .twinTip,
            ridingMode: .bigAir,
            spot: WaterSpotInfo(name: ""),
            conditions: .empty
        )
    }

    func snapshot(isKitesurf: Bool) -> WaterSportSessionSnapshot {
        WaterSportSessionSnapshot(
            isKitesurf: isKitesurf,
            kiteEquipmentRaw: kiteEquipment?.rawValue,
            boardTypeRaw: boardType?.rawValue,
            ridingModeRaw: ridingMode?.rawValue,
            spot: spot.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : spot,
            conditions: conditions.windSpeedKmh > 0 || conditions.tideLabel != "Não informado"
                ? conditions
                : conditions,
            jumps: [],
            accelerationSamples: []
        )
    }
}

// MARK: - Direção do vento (rótulos)

enum WindDirectionLabels {
    static func label(degrees: Double) -> String {
        let dirs = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
        let idx = Int(((degrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360) / 45.0 + 0.5) % 8
        return dirs[idx]
    }

    static let tidePresets = [
        "Enchente", "Vazante", "Preamar", "Baixamar", "Maré morta", "Maré viva", "Não informado"
    ]
}
