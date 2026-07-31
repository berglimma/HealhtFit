import Foundation

enum SupplementUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case grams = "g"
    case milliliters = "ml"
    case capsules = "cápsulas"
    case scoop = "scoop"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grams: return "g"
        case .milliliters: return "ml"
        case .capsules: return "cápsulas"
        case .scoop: return "scoop"
        }
    }

    /// Forma singular para quantidades iguais a 1.
    var singularLabel: String {
        switch self {
        case .grams: return "g"
        case .milliliters: return "ml"
        case .capsules: return "cápsula"
        case .scoop: return "scoop"
        }
    }
}

struct SupplementCatalogItem: Identifiable, Hashable {
    let id: String
    let name: String
    let defaultQuantity: Double
    let defaultUnit: SupplementUnit
    var isCustom: Bool = false
}

enum SupplementCatalog {
    static let customId = "outro"

    static let items: [SupplementCatalogItem] = [
        SupplementCatalogItem(id: "whey", name: "Whey Protein", defaultQuantity: 30, defaultUnit: .grams),
        SupplementCatalogItem(id: "creatina", name: "Creatina", defaultQuantity: 5, defaultUnit: .grams),
        SupplementCatalogItem(id: "bcaa", name: "BCAA", defaultQuantity: 10, defaultUnit: .grams),
        SupplementCatalogItem(id: "multivitaminico", name: "Multivitamínico", defaultQuantity: 1, defaultUnit: .capsules),
        SupplementCatalogItem(id: "omega3", name: "Ômega-3", defaultQuantity: 1, defaultUnit: .capsules),
        SupplementCatalogItem(id: "vitamina_d", name: "Vitamina D", defaultQuantity: 1, defaultUnit: .capsules),
        SupplementCatalogItem(id: "cafeina", name: "Cafeína", defaultQuantity: 1, defaultUnit: .capsules),
        SupplementCatalogItem(id: "pre_treino", name: "Pré-treino", defaultQuantity: 1, defaultUnit: .scoop),
        SupplementCatalogItem(id: "glutamina", name: "Glutamina", defaultQuantity: 5, defaultUnit: .grams),
        SupplementCatalogItem(id: "colageno", name: "Colágeno", defaultQuantity: 10, defaultUnit: .grams),
        SupplementCatalogItem(id: customId, name: "Outro", defaultQuantity: 1, defaultUnit: .capsules, isCustom: true),
    ]

    static func item(id: String) -> SupplementCatalogItem? {
        items.first { $0.id == id }
    }
}

struct SupplementIntakeEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var catalogId: String
    var name: String
    var quantity: Double
    var unit: SupplementUnit
    var loggedAt: Date

    init(
        id: UUID = UUID(),
        catalogId: String,
        name: String,
        quantity: Double,
        unit: SupplementUnit,
        loggedAt: Date = .now
    ) {
        self.id = id
        self.catalogId = catalogId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0, quantity)
        self.unit = unit
        self.loggedAt = loggedAt
    }

    var quantityDisplay: String {
        let formatted: String
        if quantity == floor(quantity) {
            formatted = String(Int(quantity))
        } else {
            formatted = String(format: "%g", quantity)
        }
        let unitLabel = (quantity == 1) ? unit.singularLabel : unit.label
        return "\(formatted) \(unitLabel)"
    }
}
