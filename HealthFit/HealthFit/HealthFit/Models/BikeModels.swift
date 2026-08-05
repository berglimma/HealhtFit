import CoreLocation
import Foundation

// MARK: - Manutenção / vida útil

enum BikeWearPart: String, CaseIterable, Identifiable, Codable {
    case chain
    case tires
    case brakePads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chain: return "Corrente"
        case .tires: return "Pneus"
        case .brakePads: return "Pastilhas de freio"
        }
    }

    var icon: String {
        switch self {
        case .chain: return "link"
        case .tires: return "circle.circle"
        case .brakePads: return "circle.hexagongrid.fill"
        }
    }

    /// Limiar de vida útil em km de pedais acumulados na peça.
    var lifeKm: Double {
        switch self {
        case .chain: return 2_500
        case .tires: return 4_000
        case .brakePads: return 1_500
        }
    }

    var warningRatio: Double { 0.85 }
}

enum BikeLogEntryKind: String, Codable {
    case ride
    case problem
    case maintenance
    case partReplace
}

struct BikeLogEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var kind: BikeLogEntryKind
    var title: String
    var detail: String
    var distanceKm: Double?
    var part: BikeWearPart?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        kind: BikeLogEntryKind,
        title: String,
        detail: String = "",
        distanceKm: Double? = nil,
        part: BikeWearPart? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.detail = detail
        self.distanceKm = distanceKm
        self.part = part
    }
}

struct BikeWearState: Codable, Hashable {
    var kmSinceReplace: Double
    var lastReplacedAt: Date?

    static var fresh: BikeWearState {
        BikeWearState(kmSinceReplace: 0, lastReplacedAt: .now)
    }

    func progress(for part: BikeWearPart) -> Double {
        min(kmSinceReplace / max(part.lifeKm, 1), 1.5)
    }

    func needsAttention(for part: BikeWearPart) -> Bool {
        progress(for: part) >= part.warningRatio
    }

    func isOverdue(for part: BikeWearPart) -> Bool {
        kmSinceReplace >= part.lifeKm
    }
}

// MARK: - Perigos na pista

enum RoadHazardType: String, CaseIterable, Identifiable, Codable {
    case pothole
    case debris
    case glass
    case construction
    case wetRoad
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pothole: return "Buraco"
        case .debris: return "Entulho / objeto"
        case .glass: return "Vidro"
        case .construction: return "Obra na via"
        case .wetRoad: return "Pista molhada / óleo"
        case .other: return "Outro perigo"
        }
    }

    var icon: String {
        switch self {
        case .pothole: return "circle.dotted"
        case .debris: return "trash"
        case .glass: return "diamond.fill"
        case .construction: return "cone.fill"
        case .wetRoad: return "drop.fill"
        case .other: return "exclamationmark.triangle"
        }
    }

    var alertTitle: String {
        switch self {
        case .pothole: return "Buraco à frente!"
        case .debris: return "Objeto na pista"
        case .glass: return "Vidro na pista"
        case .construction: return "Obra na via"
        case .wetRoad: return "Pista escorregadia"
        case .other: return "Perigo reportado"
        }
    }
}

struct RoadHazard: Identifiable, Codable, Hashable {
    var id: UUID
    var type: RoadHazardType
    var latitude: Double
    var longitude: Double
    var note: String
    var reportedAt: Date
    var isCommunitySeed: Bool

    init(
        id: UUID = UUID(),
        type: RoadHazardType,
        latitude: Double,
        longitude: Double,
        note: String = "",
        reportedAt: Date = .now,
        isCommunitySeed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.reportedAt = reportedAt
        self.isCommunitySeed = isCommunitySeed
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var alertSubtitle: String {
        let source = isCommunitySeed ? "reportado pela comunidade" : "reportado por usuários neste aparelho"
        if note.isEmpty {
            return "\(type.title) \(source). Reduza a velocidade."
        }
        return "\(note) · \(source)"
    }
}
