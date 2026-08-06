import Foundation
import SwiftUI

// MARK: - Embarcação

/// Embarcação / modalidade de remo (água ou ergométrico).
enum RowingBoatType: String, CaseIterable, Identifiable, Codable, Hashable {
    case singleSkiff = "Single Skiff"
    case double = "Double"
    case four = "Four"
    case erg = "Ergométrico"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .singleSkiff:
            return "Skiff individual — equilíbrio e simetria críticos"
        case .double:
            return "Double — coordenação de par e estabilidade lateral"
        case .four:
            return "Four — ritmo de equipe e balanço do barco"
        case .erg:
            return "Remo ergométrico indoor — SPM, split e eficiência"
        }
    }

    var icon: String {
        switch self {
        case .singleSkiff: return "person.fill"
        case .double: return "person.2.fill"
        case .four: return "person.3.fill"
        case .erg: return "figure.rower"
        }
    }

    /// Barcos na água: GPS + sensores de equilíbrio.
    var isOnWater: Bool {
        self != .erg
    }

    /// Equilíbrio lateral é especialmente relevante nestes barcos.
    var emphasizesBalance: Bool {
        switch self {
        case .singleSkiff, .double, .four: return true
        case .erg: return false
        }
    }
}

// MARK: - Faixas de SPM (Stroke Rate)

/// Faixas comuns de ritmo de remada (strokes per minute).
enum RowingSPMZone: String, CaseIterable, Identifiable, Codable, Hashable {
    case recovery = "Recuperação"
    case endurance = "Endurance"
    case technical = "Treino técnico"
    case race = "Prova"
    case sprint = "Sprint"
    case transition = "Transição"
    case unknown = "—"

    var id: String { rawValue }

    /// Intervalo inclusivo típico da faixa.
    var spmRange: ClosedRange<Double>? {
        switch self {
        case .recovery: return 18...20
        case .endurance: return 20...24
        case .technical: return 24...28
        case .race: return 30...34
        case .sprint: return 36...42
        case .transition, .unknown: return nil
        }
    }

    var rangeLabel: String {
        switch self {
        case .recovery: return "18–20"
        case .endurance: return "20–24"
        case .technical: return "24–28"
        case .race: return "30–34"
        case .sprint: return "36–42"
        case .transition: return "—"
        case .unknown: return "—"
        }
    }

    var color: Color {
        switch self {
        case .recovery: return .green
        case .endurance: return .cyan
        case .technical: return .blue
        case .race: return AppTheme.accentSecondary
        case .sprint: return .red
        case .transition: return .orange
        case .unknown: return AppTheme.textSecondary
        }
    }

    var tip: String {
        switch self {
        case .recovery: return "Recuperação ativa — low rate, técnica limpa"
        case .endurance: return "Base aeróbica e volume"
        case .technical: return "Foco em técnica e eficiência"
        case .race: return "Ritmo de prova"
        case .sprint: return "Alta cadência — sprints curtos"
        case .transition: return "Entre faixas — estabilize o ritmo"
        case .unknown: return "Aguardando remadas suficientes"
        }
    }

    static func classify(spm: Double) -> RowingSPMZone {
        guard spm > 0 else { return .unknown }
        switch spm {
        case 18..<20.5: return .recovery
        case 20.5..<24.5: return .endurance
        case 24.5..<28.5: return .technical
        case 28.5..<30: return .transition
        case 30..<34.5: return .race
        case 34.5..<36: return .transition
        case 36...42: return .sprint
        case 15..<18: return .recovery
        case ..<15: return .unknown
        default:
            if spm > 42 { return .sprint }
            return .transition
        }
    }
}

// MARK: - Setup / snapshot

struct RowingSetup: Hashable, Codable {
    var boatType: RowingBoatType

    static let `default` = RowingSetup(boatType: .singleSkiff)

    func snapshot() -> RowingSessionSnapshot {
        RowingSessionSnapshot(boatType: boatType)
    }
}

/// Resumo persistido da sessão de remo.
struct RowingSessionSnapshot: Codable, Hashable {
    var boatType: RowingBoatType
    var totalStrokes: Int
    var averageSPM: Double
    var peakSPM: Double
    var averageSplitSecondsPer500m: Double?
    var bestSplitSecondsPer500m: Double?
    var metersPerStroke: Double
    var efficiencyScore: Double
    var stabilityScore: Double
    var balanceScore: Double
    var leftSideShare: Double
    var rightSideShare: Double
    var asymmetryPercent: Double
    var peakSpeedMps: Double
    var averageAcceleration: Double
    var averageDeceleration: Double
    var distanceMeters: Double

    init(
        boatType: RowingBoatType = .singleSkiff,
        totalStrokes: Int = 0,
        averageSPM: Double = 0,
        peakSPM: Double = 0,
        averageSplitSecondsPer500m: Double? = nil,
        bestSplitSecondsPer500m: Double? = nil,
        metersPerStroke: Double = 0,
        efficiencyScore: Double = 0,
        stabilityScore: Double = 0,
        balanceScore: Double = 0,
        leftSideShare: Double = 0.5,
        rightSideShare: Double = 0.5,
        asymmetryPercent: Double = 0,
        peakSpeedMps: Double = 0,
        averageAcceleration: Double = 0,
        averageDeceleration: Double = 0,
        distanceMeters: Double = 0
    ) {
        self.boatType = boatType
        self.totalStrokes = totalStrokes
        self.averageSPM = averageSPM
        self.peakSPM = peakSPM
        self.averageSplitSecondsPer500m = averageSplitSecondsPer500m
        self.bestSplitSecondsPer500m = bestSplitSecondsPer500m
        self.metersPerStroke = metersPerStroke
        self.efficiencyScore = efficiencyScore
        self.stabilityScore = stabilityScore
        self.balanceScore = balanceScore
        self.leftSideShare = leftSideShare
        self.rightSideShare = rightSideShare
        self.asymmetryPercent = asymmetryPercent
        self.peakSpeedMps = peakSpeedMps
        self.averageAcceleration = averageAcceleration
        self.averageDeceleration = averageDeceleration
        self.distanceMeters = distanceMeters
    }

    var formattedAverageSplit: String {
        guard let s = averageSplitSecondsPer500m, s > 0 else { return "—" }
        return RowingMetricsMath.formatSplit(seconds: s)
    }

    var formattedBestSplit: String {
        guard let s = bestSplitSecondsPer500m, s > 0 else { return "—" }
        return RowingMetricsMath.formatSplit(seconds: s)
    }

    var symmetryInsight: String {
        if asymmetryPercent < 8 {
            return "Simetria boa — carga equilibrada entre lados."
        }
        if asymmetryPercent < 15 {
            return "Assimetria leve — revise a entrada da remada."
        }
        let dominant = leftSideShare >= rightSideShare ? "esquerdo" : "direito"
        return "Assimetria eleva (lado \(dominant) com mais carga) — risco de lesão e perda de eficiência."
    }
}

// MARK: - Cálculos puros

enum RowingMetricsMath {
    /// Split clássico: tempo para remar 500 m. Quanto menor, melhor.
    static func splitSecondsPer500m(speedMetersPerSecond: Double) -> Double? {
        guard speedMetersPerSecond > 0.15 else { return nil }
        return 500.0 / speedMetersPerSecond
    }

    static func splitSecondsPer500m(distanceMeters: Double, elapsedSeconds: Double) -> Double? {
        guard distanceMeters > 5, elapsedSeconds > 0 else { return nil }
        let speed = distanceMeters / elapsedSeconds
        return splitSecondsPer500m(speedMetersPerSecond: speed)
    }

    static func metersPerStroke(distanceMeters: Double, strokes: Int) -> Double {
        guard strokes > 0, distanceMeters > 0 else { return 0 }
        return distanceMeters / Double(strokes)
    }

    /// Eficiência 0–100: metros/remada + velocidade + estabilidade − assimetria.
    static func efficiencyScore(
        metersPerStroke: Double,
        speedMps: Double,
        stabilityScore: Double,
        balanceScore: Double,
        asymmetryPercent: Double
    ) -> Double {
        // ~8–12 m/remada é excelente em água; erg varia.
        let dpsComponent = min(max((metersPerStroke / 10.0) * 35.0, 0), 35)
        let speedComponent = min(max((speedMps / 4.5) * 25.0, 0), 25)
        let stabilityComponent = stabilityScore * 0.20
        let balanceComponent = balanceScore * 0.15
        let asymmetryPenalty = min(asymmetryPercent, 40) * 0.35
        return min(100, max(0, dpsComponent + speedComponent + stabilityComponent + balanceComponent - asymmetryPenalty))
    }

    static func formatSplit(seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func formatSPM(_ spm: Double) -> String {
        guard spm > 0 else { return "—" }
        return String(format: "%.0f", spm)
    }
}
