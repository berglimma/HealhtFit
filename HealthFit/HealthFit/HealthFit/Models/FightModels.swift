import Foundation
import SwiftUI

/// Modalidades de luta cronometradas pelo card "Luta" da aba Cardio.
enum FightModality: String, Codable, CaseIterable, Identifiable, Hashable {
    case boxe = "Boxe"
    case muayThai = "Muay Thai"
    case kickboxing = "Kickboxing"
    case mma = "MMA"
    case jiuJitsu = "Jiu-Jitsu"
    case judo = "Judô"
    case wrestling = "Wrestling"
    case lutaLivre = "Luta Livre"
    case karate = "Karatê"
    case taekwondo = "Taekwondo"
    case kravMaga = "Krav Magá"
    case capoeira = "Capoeira"

    var id: String { rawValue }

    var name: String { rawValue }

    var icon: String {
        switch self {
        case .boxe: return "figure.boxing"
        case .muayThai, .kickboxing: return "figure.kickboxing"
        case .mma, .karate, .taekwondo, .kravMaga: return "figure.martial.arts"
        case .jiuJitsu, .wrestling, .lutaLivre, .judo: return "figure.wrestling"
        case .capoeira: return "figure.dance"
        }
    }

    var summary: String {
        switch self {
        case .boxe: return "Trocação de mãos com esquiva e trabalho de pernas"
        case .muayThai: return "Oito armas: punhos, cotovelos, joelhos e canelas"
        case .kickboxing: return "Punhos e chutes em ritmo contínuo"
        case .mma: return "Trocação, quedas e chão no mesmo combate"
        case .jiuJitsu: return "Solo, raspagens e finalizações"
        case .judo: return "Pegada, desequilíbrio e projeções"
        case .wrestling: return "Quedas, controle e domínio no solo"
        case .lutaLivre: return "Submissão sem kimono, foco em pegadas"
        case .karate: return "Golpes lineares com entrada e recuo explosivos"
        case .taekwondo: return "Chutes altos, giros e mobilidade de quadril"
        case .kravMaga: return "Defesa pessoal com respostas curtas e diretas"
        case .capoeira: return "Ginga, esquiva e movimentos acrobáticos"
        }
    }

    /// Referência de tempo oficial da modalidade — mostrada antes de iniciar.
    var roundReference: String {
        switch self {
        case .boxe: return "Rounds de 3 min · 1 min de descanso"
        case .muayThai: return "5 rounds de 3 min · 2 min de descanso"
        case .kickboxing: return "3 rounds de 3 min · 1 min de descanso"
        case .mma: return "3 a 5 rounds de 5 min · 1 min de descanso"
        case .jiuJitsu: return "Luta única de 5 a 10 min"
        case .judo: return "Luta de 4 min · golden score se empatar"
        case .wrestling: return "2 rounds de 3 min · 30 s de descanso"
        case .lutaLivre: return "Luta única de 6 a 10 min"
        case .karate: return "Combate de 3 min"
        case .taekwondo: return "3 rounds de 2 min · 1 min de descanso"
        case .kravMaga: return "Blocos de 2 a 3 min por cenário"
        case .capoeira: return "Roda contínua, sem round fixo"
        }
    }

    /// Estimativa para atleta de ~70 kg em ritmo de treino/luta.
    var caloriesPerMinute: Double {
        switch self {
        case .mma: return 15
        case .muayThai: return 14
        case .boxe, .kickboxing, .wrestling: return 13
        case .judo, .lutaLivre, .kravMaga: return 12
        case .jiuJitsu, .taekwondo, .capoeira: return 11
        case .karate: return 10
        }
    }

    var coverColors: [Color] {
        switch self {
        case .boxe:
            return [Color(red: 0.82, green: 0.20, blue: 0.22), Color(red: 0.35, green: 0.06, blue: 0.10)]
        case .muayThai:
            return [Color(red: 0.90, green: 0.42, blue: 0.15), Color(red: 0.42, green: 0.14, blue: 0.06)]
        case .kickboxing:
            return [Color(red: 0.88, green: 0.32, blue: 0.35), Color(red: 0.38, green: 0.10, blue: 0.18)]
        case .mma:
            return [Color(red: 0.55, green: 0.16, blue: 0.28), Color(red: 0.20, green: 0.05, blue: 0.12)]
        case .jiuJitsu:
            return [Color(red: 0.22, green: 0.45, blue: 0.78), Color(red: 0.07, green: 0.16, blue: 0.38)]
        case .judo:
            return [Color(red: 0.30, green: 0.55, blue: 0.88), Color(red: 0.10, green: 0.20, blue: 0.42)]
        case .wrestling:
            return [Color(red: 0.42, green: 0.48, blue: 0.62), Color(red: 0.15, green: 0.18, blue: 0.28)]
        case .lutaLivre:
            return [Color(red: 0.38, green: 0.58, blue: 0.55), Color(red: 0.12, green: 0.24, blue: 0.24)]
        case .karate:
            return [Color(red: 0.72, green: 0.62, blue: 0.30), Color(red: 0.32, green: 0.26, blue: 0.10)]
        case .taekwondo:
            return [Color(red: 0.35, green: 0.62, blue: 0.42), Color(red: 0.10, green: 0.26, blue: 0.18)]
        case .kravMaga:
            return [Color(red: 0.45, green: 0.42, blue: 0.52), Color(red: 0.16, green: 0.15, blue: 0.22)]
        case .capoeira:
            return [Color(red: 0.85, green: 0.58, blue: 0.20), Color(red: 0.38, green: 0.22, blue: 0.06)]
        }
    }

    /// Asset de capa no mesmo padrão de `CardioCoverCorrida`.
    var coverImageName: String {
        switch self {
        case .boxe: return "FightCoverBoxe"
        case .muayThai: return "FightCoverMuayThai"
        case .kickboxing: return "FightCoverKickboxing"
        case .mma: return "FightCoverMMA"
        case .jiuJitsu: return "FightCoverJiuJitsu"
        case .judo: return "FightCoverJudo"
        case .wrestling: return "FightCoverWrestling"
        case .lutaLivre: return "FightCoverLutaLivre"
        case .karate: return "FightCoverKarate"
        case .taekwondo: return "FightCoverTaekwondo"
        case .kravMaga: return "FightCoverKravMaga"
        case .capoeira: return "FightCoverCapoeira"
        }
    }

    /// Exercício de cardio equivalente — a sessão de luta reaproveita o cronômetro do cardio.
    var cardioExercise: CardioExercise {
        CardioExercise(
            name: name,
            description: summary,
            icon: icon,
            caloriesPerMinute: caloriesPerMinute
        )
    }
}

extension CardioExercise {
    /// Modalidade de luta correspondente, quando o exercício for um combate.
    var fightModality: FightModality? { FightModality(rawValue: name) }

    /// Luta: cronômetro de tempo de combate, sem GPS nem metas de distância.
    var isFight: Bool { fightModality != nil }

    /// Fora de `catalog` de propósito — luta aparece no card "Luta", não na lista de cardio.
    static let fightCatalog: [CardioExercise] = FightModality.allCases.map(\.cardioExercise)

    /// Cardio somado às lutas — use ao reconstruir sessões salvas por nome.
    static var allKnown: [CardioExercise] { catalog + fightCatalog }
}
