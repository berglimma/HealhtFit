import Foundation
import SwiftUI

// MARK: - Tipo de equipamento

/// Item do inventário de escalada, com limite de usos e tempo de serviço.
///
/// Os limites seguem a orientação usual dos fabricantes para uso recreativo. Uma
/// queda severa, corte ou exposição química condena o item antes de qualquer limite.
enum ClimbingGearType: String, Codable, CaseIterable, Identifiable, Hashable {
    case rope = "Corda"
    case quickdraw = "Costura"
    case harness = "Cadeirinha"
    case carabiner = "Mosquetão"
    case helmet = "Capacete"
    case belayDevice = "Freio / breque"
    case sling = "Fita / anel"
    case crashPad = "Crash pad"
    case shoes = "Sapatilha"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .rope: return "line.3.crossed.swirl.circle"
        case .quickdraw: return "link"
        case .harness: return "figure.climbing"
        case .carabiner: return "oval.portrait"
        case .helmet: return "hearingdevice.ear"
        case .belayDevice: return "hexagon"
        case .sling: return "infinity"
        case .crashPad: return "rectangle.fill"
        case .shoes: return "shoe.2"
        }
    }

    /// Usos até a inspeção detalhada recomendada.
    var inspectionUseLimit: Int {
        switch self {
        case .rope: return 200
        case .quickdraw: return 300
        case .harness: return 250
        case .carabiner: return 500
        case .helmet: return 200
        case .belayDevice: return 400
        case .sling: return 150
        case .crashPad: return 200
        case .shoes: return 120
        }
    }

    /// Tempo de serviço, em meses, até a inspeção detalhada recomendada.
    var serviceLifeMonths: Int {
        switch self {
        case .rope: return 60
        case .quickdraw: return 120
        case .harness: return 84
        case .carabiner: return 120
        case .helmet: return 60
        case .belayDevice: return 120
        case .sling: return 60
        case .crashPad: return 84
        case .shoes: return 36
        }
    }

    /// O que olhar na inspeção.
    var inspectionChecklist: String {
        switch self {
        case .rope:
            return "Passe a corda inteira pelas mãos procurando pontos moles, gordos ou achatados. Verifique a capa por desgaste, cortes e queimaduras."
        case .quickdraw:
            return "Fitas com corte, desfiamento ou desbotamento forte. Gatilhos travando e sulcos abertos pela corda no mosquetão inferior."
        case .harness:
            return "Fitas de cintura e perneiras, costuras de segurança e o loop de encordamento — o ponto que mais desgasta."
        case .carabiner:
            return "Gatilho e trava abrindo e fechando limpos, sem folga no rebite. Sulcos profundos ou trincas condenam a peça."
        case .helmet:
            return "Trincas na casca, espuma amassada e integridade da jugular. Um impacto forte condena o capacete."
        case .belayDevice:
            return "Sulcos abertos pela corda e bordas afiadas que possam serrar a capa."
        case .sling:
            return "Costuras íntegras e fita sem corte, rigidez ou desbotamento. Fita de Dyneema envelhece sem aviso visual."
        case .crashPad:
            return "Espuma sem afundamento permanente, costuras e alças de transporte."
        case .shoes:
            return "Sola furada no dedão e descolamento da rande — dá para resolar antes de perder o cabedal."
        }
    }
}

// MARK: - Item do inventário

struct ClimbingGearItem: Identifiable, Codable, Hashable {
    var id: UUID
    var type: ClimbingGearType
    var name: String
    /// Início da contagem de tempo de serviço.
    var acquiredAt: Date
    var useCount: Int
    var lastInspectedAt: Date?
    /// Retirado de uso — não gera mais lembrete.
    var isRetired: Bool
    var notes: String

    init(
        id: UUID = UUID(),
        type: ClimbingGearType,
        name: String = "",
        acquiredAt: Date = .now,
        useCount: Int = 0,
        lastInspectedAt: Date? = nil,
        isRetired: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.type = type
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed.isEmpty ? type.rawValue : trimmed
        self.acquiredAt = acquiredAt
        self.useCount = max(0, useCount)
        self.lastInspectedAt = lastInspectedAt
        self.isRetired = isRetired
        self.notes = notes
    }

    // MARK: Desgaste

    /// Usos desde a última inspeção (ou desde a aquisição, se nunca inspecionado).
    var usageRatio: Double {
        let limit = Double(type.inspectionUseLimit)
        guard limit > 0 else { return 0 }
        return Double(useCount) / limit
    }

    var monthsInService: Int {
        let reference = lastInspectedAt ?? acquiredAt
        let components = Calendar.current.dateComponents([.month], from: reference, to: .now)
        return max(0, components.month ?? 0)
    }

    var ageRatio: Double {
        let limit = Double(type.serviceLifeMonths)
        guard limit > 0 else { return 0 }
        return Double(monthsInService) / limit
    }

    /// O que estiver mais adiantado — usos ou tempo — define o status.
    var wearRatio: Double { max(usageRatio, ageRatio) }

    var status: ClimbingGearStatus {
        if isRetired { return .retired }
        if wearRatio >= 1 { return .overdue }
        if wearRatio >= 0.8 { return .dueSoon }
        return .ok
    }

    /// Motivo dominante do alerta, para redigir o aviso.
    var limitingFactor: ClimbingGearLimitingFactor {
        usageRatio >= ageRatio ? .uses : .age
    }

    var usesRemaining: Int {
        max(0, type.inspectionUseLimit - useCount)
    }

    var monthsRemaining: Int {
        max(0, type.serviceLifeMonths - monthsInService)
    }

    /// Frase pronta para a UI e para o IAssistente.
    var alertMessage: String {
        switch status {
        case .ok:
            return "\(name): \(usesRemaining) usos ou \(monthsRemaining) meses até a próxima inspeção."
        case .dueSoon:
            switch limitingFactor {
            case .uses:
                return "\(name): faltam \(usesRemaining) usos para o limite de inspeção (\(useCount)/\(type.inspectionUseLimit))."
            case .age:
                return "\(name): faltam \(monthsRemaining) meses para o limite de serviço (\(monthsInService)/\(type.serviceLifeMonths) meses)."
            }
        case .overdue:
            switch limitingFactor {
            case .uses:
                return "\(name): \(useCount) usos, acima do limite de \(type.inspectionUseLimit). Inspecione antes da próxima escalada."
            case .age:
                return "\(name): \(monthsInService) meses de serviço, acima do limite de \(type.serviceLifeMonths). Inspecione antes da próxima escalada."
            }
        case .retired:
            return "\(name): aposentado."
        }
    }
}

// MARK: - Status

enum ClimbingGearStatus: String, Codable, Hashable {
    case ok
    case dueSoon
    case overdue
    case retired

    var label: String {
        switch self {
        case .ok: return "Em dia"
        case .dueSoon: return "Inspeção próxima"
        case .overdue: return "Inspeção vencida"
        case .retired: return "Aposentado"
        }
    }

    var icon: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .dueSoon: return "exclamationmark.triangle.fill"
        case .overdue: return "xmark.octagon.fill"
        case .retired: return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return Color(red: 0.20, green: 0.72, blue: 0.42)
        case .dueSoon: return Color(red: 0.95, green: 0.72, blue: 0.18)
        case .overdue: return Color(red: 0.90, green: 0.28, blue: 0.24)
        case .retired: return Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    /// Ordena o inventário pelo que precisa de atenção primeiro.
    var sortPriority: Int {
        switch self {
        case .overdue: return 0
        case .dueSoon: return 1
        case .ok: return 2
        case .retired: return 3
        }
    }
}

enum ClimbingGearLimitingFactor: String, Codable, Hashable {
    case uses
    case age
}

// MARK: - Equipamento por modalidade

extension ClimbingDiscipline {
    /// Itens que contam uso quando a sessão é desta modalidade.
    var gearTypesInUse: [ClimbingGearType] {
        switch self {
        case .boulder:
            return [.crashPad, .shoes]
        case .sport:
            return [.rope, .quickdraw, .harness, .carabiner, .belayDevice, .helmet, .shoes]
        case .trad:
            return [.rope, .harness, .carabiner, .belayDevice, .helmet, .sling, .shoes]
        case .gym:
            return [.rope, .harness, .belayDevice, .shoes]
        case .multipitch:
            return ClimbingGearType.allCases
        case .ice:
            return [.rope, .harness, .helmet, .carabiner, .belayDevice, .sling]
        }
    }

    /// Kit sugerido ao montar o inventário pela primeira vez.
    var suggestedStarterKit: [ClimbingGearType] { gearTypesInUse }
}
