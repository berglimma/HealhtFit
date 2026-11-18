import Foundation
import SwiftUI

/// Trilhas do hub CrossFit na aba Cardio (fora do catálogo genérico).
enum CrossFitTrack: String, Codable, CaseIterable, Identifiable, Hashable {
    case treinoCrossfit = "Treino Crossfit"
    case metodoHyrox = "Método Hyrox"

    var id: String { rawValue }
    var name: String { rawValue }

    var icon: String {
        switch self {
        case .treinoCrossfit: return "figure.cross.training"
        case .metodoHyrox: return "flag.checkered"
        }
    }

    var summary: String {
        switch self {
        case .treinoCrossfit:
            return "WODs com AMRAP, EMOM e For Time — força e condicionamento mistos"
        case .metodoHyrox:
            return "8 estações de corrida + funcional no formato de prova Hyrox"
        }
    }

    var eyebrow: String {
        switch self {
        case .treinoCrossfit: return "WOD · METCON"
        case .metodoHyrox: return "8 ESTAÇÕES · RACE"
        }
    }

    var caloriesPerMinute: Double {
        switch self {
        case .treinoCrossfit: return 14
        case .metodoHyrox: return 13
        }
    }

    var coverColors: [Color] {
        switch self {
        case .treinoCrossfit:
            return [
                Color(red: 0.92, green: 0.38, blue: 0.12),
                Color(red: 0.28, green: 0.08, blue: 0.04)
            ]
        case .metodoHyrox:
            return [
                Color(red: 0.12, green: 0.55, blue: 0.72),
                Color(red: 0.04, green: 0.18, blue: 0.32)
            ]
        }
    }

    var coverImageName: String {
        switch self {
        case .treinoCrossfit: return "CrossFitCoverWOD"
        case .metodoHyrox: return "CrossFitCoverHyrox"
        }
    }

    var formats: [CrossFitFormat] {
        switch self {
        case .treinoCrossfit: return CrossFitFormat.crossfitPresets
        case .metodoHyrox: return CrossFitFormat.hyroxPresets
        }
    }

    var defaultFormat: CrossFitFormat {
        formats.first ?? .open
    }

    var tips: [String] {
        switch self {
        case .treinoCrossfit:
            return [
                "Há 10 s de PREP antes do WOD — tempo para posicionar o celular.",
                "No AMRAP, use +1 round a cada volta completa; no EMOM o app sinaliza cada minuto.",
                "Use o Apple Watch para BPM e calorias; encerre no For Time ao completar."
            ]
        case .metodoHyrox:
            return [
                "Há 10 s de PREP; depois marque as estações conforme concluir.",
                "Simule a prova ou foque uma estação — o cronômetro é a referência.",
                "Após a sessão, compartilhe o resultado como nas outras modalidades."
            ]
        }
    }

    var stationsHint: String? {
        guard !stations.isEmpty else { return nil }
        return stations.joined(separator: " · ")
    }

    /// Estações individuais (checklist na sessão ao vivo).
    var stations: [String] {
        switch self {
        case .treinoCrossfit: return []
        case .metodoHyrox:
            return [
                "SkiErg",
                "Sled Push",
                "Sled Pull",
                "Burpee Broad Jump",
                "Row",
                "Farmers",
                "Sandbag Lunges",
                "Wall Balls"
            ]
        }
    }

    var cardioExercise: CardioExercise {
        CardioExercise(
            name: name,
            description: summary,
            icon: icon,
            caloriesPerMinute: caloriesPerMinute
        )
    }
}

/// Formato de sessão CrossFit / Hyrox (meta de tempo opcional).
struct CrossFitFormat: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    /// `nil` ou 0 = cronômetro livre (For Time / prova).
    let targetSeconds: Int?

    var hasTimedTarget: Bool {
        (targetSeconds ?? 0) > 0
    }

    static let open = CrossFitFormat(
        id: "open",
        title: "Livre",
        detail: "Cronômetro aberto — encerre quando quiser",
        targetSeconds: nil
    )

    static let crossfitPresets: [CrossFitFormat] = [
        CrossFitFormat(id: "amrap12", title: "AMRAP 12", detail: "Máximo de rounds em 12 min", targetSeconds: 12 * 60),
        CrossFitFormat(id: "amrap15", title: "AMRAP 15", detail: "Máximo de rounds em 15 min", targetSeconds: 15 * 60),
        CrossFitFormat(id: "amrap20", title: "AMRAP 20", detail: "Clássico de condicionamento", targetSeconds: 20 * 60),
        CrossFitFormat(id: "emom12", title: "EMOM 12", detail: "A cada minuto, um bloco de reps", targetSeconds: 12 * 60),
        CrossFitFormat(id: "emom16", title: "EMOM 16", detail: "Blocos longos com recuperação curta", targetSeconds: 16 * 60),
        CrossFitFormat(id: "fortime", title: "For Time", detail: "Complete o WOD no menor tempo", targetSeconds: nil),
        CrossFitFormat(id: "chipper", title: "Chipper", detail: "Lista longa, uma vez — cronômetro livre", targetSeconds: nil),
        open
    ]

    static let hyroxPresets: [CrossFitFormat] = [
        CrossFitFormat(id: "race", title: "Simulação de prova", detail: "8 estações + corridas entre elas", targetSeconds: nil),
        CrossFitFormat(id: "half", title: "Meia prova", detail: "4 estações + corridas · ~30–45 min", targetSeconds: 40 * 60),
        CrossFitFormat(id: "station", title: "Foco em estação", detail: "Repetições e técnica em uma estação", targetSeconds: 20 * 60),
        CrossFitFormat(id: "doubles", title: "Doubles", detail: "Treino em dupla — revezamento", targetSeconds: nil),
        open
    ]
}

extension CardioExercise {
    var crossFitTrack: CrossFitTrack? { CrossFitTrack(rawValue: name) }

    var isCrossFit: Bool { crossFitTrack != nil }

    /// Fora de `catalog` — aparece só no hub CrossFit.
    static let crossFitCatalog: [CardioExercise] = CrossFitTrack.allCases.map(\.cardioExercise)
}
