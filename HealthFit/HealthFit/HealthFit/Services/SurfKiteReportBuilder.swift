import Foundation
import UIKit

/// Extrai e compara sessões de Surf / Kitesurf.
enum SurfKiteMetricsAnalyzer {
    static func isWaterSportSession(_ session: WorkoutSession) -> Bool {
        if session.waterSport != nil { return true }
        let t = session.workoutTitle.lowercased()
        return t.contains("kitesurf") || t.contains("kite surf") || t.contains("surf")
    }

    static func isKitesurfSession(_ session: WorkoutSession) -> Bool {
        if let w = session.waterSport { return w.isKitesurf }
        let t = session.workoutTitle.lowercased()
        return t.contains("kitesurf") || t.contains("kite surf")
    }

    static func isSurfSession(_ session: WorkoutSession) -> Bool {
        isWaterSportSession(session) && !isKitesurfSession(session)
    }

    static func sessions(from history: [WorkoutSession], kitesurfOnly: Bool? = nil) -> [WorkoutSession] {
        history.filter { session in
            guard isWaterSportSession(session) else { return false }
            if let kitesurfOnly {
                return isKitesurfSession(session) == kitesurfOnly
            }
            return true
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    static func totalJumps(in sessions: [WorkoutSession]) -> Int {
        sessions.reduce(0) { $0 + ($1.waterSport?.jumpCount ?? 0) }
    }

    static func bestJumpMeters(in sessions: [WorkoutSession]) -> Double {
        sessions.compactMap { $0.waterSport?.maxJumpHeightMeters }.max() ?? 0
    }

    static func totalDistanceKm(in sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { $0 + $1.displayDistanceKm }
    }
}

struct SurfKiteComparisonReport {
    let session: WorkoutSession
    let jumpCount: Int
    let maxJumpMeters: Double
    let avgJumpMeters: Double
    let maxAccelerationG: Double
    let distanceKm: Double
    let durationSeconds: Int
    let previousBestJumpMeters: Double?
    let jumpDeltaVsBest: Double?
    let previousSessionJumpCount: Int?
    let sessionsCompared: Int
    let boardLabel: String?
    let equipmentLabel: String?
    let ridingModeLabel: String?
    let spotName: String?
    let windSummary: String?
    let tideSummary: String?

    var improvedJump: Bool {
        guard let delta = jumpDeltaVsBest else { return false }
        return delta > 0.05
    }
}

enum SurfKiteReportBuilder {
    static func build(
        session: WorkoutSession,
        allSessions: [WorkoutSession]
    ) -> SurfKiteComparisonReport? {
        guard SurfKiteMetricsAnalyzer.isWaterSportSession(session) else { return nil }
        let snapshot = session.waterSport
        let peers = SurfKiteMetricsAnalyzer.sessions(
            from: allSessions,
            kitesurfOnly: SurfKiteMetricsAnalyzer.isKitesurfSession(session)
        )
        .filter { $0.id != session.id }

        let maxJump = snapshot?.maxJumpHeightMeters ?? 0
        let jumpCount = snapshot?.jumpCount ?? 0
        let avgJump = snapshot?.averageJumpHeightMeters ?? 0
        let maxG = snapshot?.maxAccelerationG ?? 0

        let previousBest = peers
            .compactMap { $0.waterSport?.maxJumpHeightMeters }
            .filter { $0 > 0 }
            .max()

        let previousSession = peers.first
        let delta: Double? = {
            guard let previousBest, maxJump > 0 else { return nil }
            return maxJump - previousBest
        }()

        return SurfKiteComparisonReport(
            session: session,
            jumpCount: jumpCount,
            maxJumpMeters: maxJump,
            avgJumpMeters: avgJump,
            maxAccelerationG: maxG,
            distanceKm: session.displayDistanceKm,
            durationSeconds: session.activeDurationSeconds,
            previousBestJumpMeters: previousBest,
            jumpDeltaVsBest: delta,
            previousSessionJumpCount: previousSession?.waterSport?.jumpCount,
            sessionsCompared: peers.count + 1,
            boardLabel: snapshot?.boardTypeRaw,
            equipmentLabel: snapshot?.kiteEquipmentRaw,
            ridingModeLabel: snapshot?.ridingModeRaw,
            spotName: snapshot?.spot?.name,
            windSummary: snapshot?.conditions?.windSummary,
            tideSummary: snapshot?.conditions?.tideSummary
        )
    }

    static func emailLines(report: SurfKiteComparisonReport) -> [String] {
        var lines = [
            "",
            "—— Surf / Kitesurf ——",
            "Saltos: \(report.jumpCount)",
            String(format: "Maior salto: %.2f m", report.maxJumpMeters),
            String(format: "Salto médio: %.2f m", report.avgJumpMeters),
            String(format: "Pico de aceleração: %.2f g", report.maxAccelerationG),
            String(format: "Distância GPS: %.2f km", report.distanceKm),
            "Tempo ativo: \(DurationFormatting.format(seconds: report.durationSeconds))"
        ]
        if let board = report.boardLabel {
            lines.append("Prancha: \(board)")
        }
        if let eq = report.equipmentLabel {
            lines.append("Kite: \(eq)")
        }
        if let mode = report.ridingModeLabel {
            lines.append("Modo: \(mode)")
        }
        if let spot = report.spotName, !spot.isEmpty {
            lines.append("Spot: \(spot)")
        }
        if let wind = report.windSummary {
            lines.append("Vento: \(wind)")
        }
        if let tide = report.tideSummary {
            lines.append("Maré: \(tide)")
        }
        if let prev = report.previousBestJumpMeters, prev > 0 {
            lines.append(String(format: "Melhor salto anterior: %.2f m", prev))
            if let delta = report.jumpDeltaVsBest {
                if delta > 0 {
                    lines.append(String(format: "Evolução no salto: +%.2f m (recorde pessoal)", delta))
                } else if delta < 0 {
                    lines.append(String(format: "Diferença vs recorde: %.2f m", delta))
                } else {
                    lines.append("Empatou com o recorde pessoal de salto")
                }
            }
        }
        if let prevJumps = report.previousSessionJumpCount {
            lines.append("Saltos na sessão anterior: \(prevJumps)")
        }
        lines.append("Sessões comparadas na modalidade: \(report.sessionsCompared)")
        return lines
    }

    /// PDF simples (UIKit) com métricas e comparativo.
    @MainActor
    static func makePDF(
        report: SurfKiteComparisonReport,
        athleteName: String
    ) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-SurfKite-\(UUID().uuidString.prefix(8)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: UIColor.label
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                var y: CGFloat = 48
                let draw: (String, [NSAttributedString.Key: Any]) -> Void = { text, attrs in
                    (text as NSString).draw(at: CGPoint(x: 48, y: y), withAttributes: attrs)
                    y += 22
                }
                draw("HealthFit — Relatório Surf / Kitesurf", titleAttrs)
                y += 8
                draw("Atleta: \(athleteName)", bodyAttrs)
                draw(report.session.workoutTitle, bodyAttrs)
                let df = DateFormatter()
                df.locale = Locale(identifier: "pt_BR")
                df.dateStyle = .long
                df.timeStyle = .short
                draw("Data: \(df.string(from: report.session.startedAt))", bodyAttrs)
                y += 10
                draw(String(format: "Saltos: %d", report.jumpCount), bodyAttrs)
                draw(String(format: "Maior salto: %.2f m", report.maxJumpMeters), bodyAttrs)
                draw(String(format: "Salto médio: %.2f m", report.avgJumpMeters), bodyAttrs)
                draw(String(format: "Pico aceleração: %.2f g", report.maxAccelerationG), bodyAttrs)
                draw(String(format: "Distância: %.2f km", report.distanceKm), bodyAttrs)
                draw("Duração ativa: \(DurationFormatting.format(seconds: report.durationSeconds))", bodyAttrs)
                if let board = report.boardLabel { draw("Prancha: \(board)", bodyAttrs) }
                if let eq = report.equipmentLabel { draw("Kite: \(eq)", bodyAttrs) }
                if let mode = report.ridingModeLabel { draw("Modo: \(mode)", bodyAttrs) }
                if let spot = report.spotName { draw("Spot: \(spot)", bodyAttrs) }
                if let wind = report.windSummary { draw("Vento: \(wind)", bodyAttrs) }
                if let tide = report.tideSummary { draw("Maré: \(tide)", bodyAttrs) }
                y += 12
                draw("Comparativo", titleAttrs)
                if let prev = report.previousBestJumpMeters {
                    draw(String(format: "Recorde anterior: %.2f m", prev), bodyAttrs)
                } else {
                    draw("Primeira sessão com saltos registrados.", bodyAttrs)
                }
                if let delta = report.jumpDeltaVsBest {
                    draw(String(format: "Delta vs recorde: %+.2f m", delta), bodyAttrs)
                }
                draw("Sessões na modalidade: \(report.sessionsCompared)", bodyAttrs)
                y += 20
                draw("HealthFit · BERG / LUAN", bodyAttrs)
            }
            return url
        } catch {
            return nil
        }
    }
}
