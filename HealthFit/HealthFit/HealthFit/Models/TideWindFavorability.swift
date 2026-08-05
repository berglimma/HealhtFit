import Foundation

/// Avaliação simples de vento + maré para Surf / Kitesurf (heurística educativa, não alerta oficial).
enum TideWindFavorability: String, Equatable, Sendable {
    case favorable
    case moderate
    case unfavorable
    case unknown

    var badgeLabel: String {
        switch self {
        case .favorable: return "Maré favorável"
        case .moderate: return "Condições moderadas"
        case .unfavorable: return "Menos favorável"
        case .unknown: return "Sem leitura de maré"
        }
    }

    var shortReason: String? {
        switch self {
        case .favorable: return nil
        case .moderate: return "Leia o pico com atenção"
        case .unfavorable: return "Evite extremos de maré ou vento fraco/excessivo"
        case .unknown: return "Aguardando dados de maré da internet"
        }
    }

    var isFavorable: Bool { self == .favorable }
}
