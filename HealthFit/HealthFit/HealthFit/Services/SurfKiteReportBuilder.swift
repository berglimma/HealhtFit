import Foundation
import UIKit

/// Extrai e compara sessões de Surf / Kitesurf.
enum SurfKiteMetricsAnalyzer {
    static func isWaterSportSession(_ session: WorkoutSession) -> Bool {
        isKitesurfSession(session) || isSurfSession(session)
    }

    static func isKitesurfSession(_ session: WorkoutSession) -> Bool {
        if let w = session.waterSport { return w.isKitesurf }
        if exerciseRecordsIndicateKitesurf(session) { return true }
        return titleIndicatesKitesurf(session.workoutTitle)
    }

    static func isSurfSession(_ session: WorkoutSession) -> Bool {
        if let w = session.waterSport { return !w.isKitesurf }
        if isKitesurfSession(session) { return false }
        if exerciseRecordsIndicateSurf(session) { return true }
        return titleIndicatesSurf(session.workoutTitle)
    }

    /// Histórico do diário: só sessões concluídas da modalidade (Surf e/ou Kitesurf).
    static func sessions(from history: [WorkoutSession], kitesurfOnly: Bool? = nil) -> [WorkoutSession] {
        history.filter { session in
            guard session.endedAt != nil else { return false }
            guard isWaterSportSession(session) else { return false }
            if let kitesurfOnly {
                return isKitesurfSession(session) == kitesurfOnly
            }
            return true
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    private static func titleIndicatesKitesurf(_ title: String) -> Bool {
        let t = title.lowercased()
        return t.contains("kitesurf") || t.contains("kite surf")
    }

    private static func titleIndicatesSurf(_ title: String) -> Bool {
        if titleIndicatesKitesurf(title) { return false }
        let t = title.lowercased()
        // Títulos típicos: "Cardio — Surf", "Cardio — Surf · Shortboard · Spot"
        if t.contains("— surf") || t.contains("- surf") { return true }
        let tokens = t.split { !$0.isLetter && $0 != "'" }.map(String.init)
        return tokens.contains("surf") || tokens.contains("surfing")
    }

    private static func exerciseRecordsIndicateKitesurf(_ session: WorkoutSession) -> Bool {
        session.exerciseRecords.contains { record in
            let n = record.exerciseName.lowercased()
            return n.contains("kitesurf") || n.contains("kite surf")
        }
    }

    private static func exerciseRecordsIndicateSurf(_ session: WorkoutSession) -> Bool {
        session.exerciseRecords.contains { record in
            let n = record.exerciseName.lowercased()
            if n.contains("kitesurf") || n.contains("kite surf") { return false }
            let tokens = n.split { !$0.isLetter }.map(String.init)
            return tokens.contains("surf") || tokens.contains("surfing")
        }
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

    /// PDF com identidade HealthFit (logo, marca d'água, cabeçalho/rodapé).
    @MainActor
    static func makePDF(
        report: SurfKiteComparisonReport,
        athleteName: String
    ) -> URL? {
        let page = HealthFitPDFChrome.pageRect
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-SurfKite-\(UUID().uuidString.prefix(8)).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                let layout = HealthFitPDFPageLayout(
                    context: context,
                    documentTitle: "Relatório Surf / Kitesurf"
                )
                layout.beginPage()

                let body = HealthFitPDFChrome.bodyAttributes(size: 12)
                let title = HealthFitPDFChrome.titleAttributes()
                let accent = HealthFitPDFChrome.accentHeadingAttributes()

                layout.draw("Surf / Kitesurf", attrs: title)
                layout.draw("Atleta: \(athleteName)", attrs: body)
                layout.draw(report.session.workoutTitle, attrs: HealthFitPDFChrome.headingAttributes())

                let df = DateFormatter()
                df.locale = Locale(identifier: "pt_BR")
                df.dateStyle = .long
                df.timeStyle = .short
                layout.draw(
                    "Data: \(df.string(from: report.session.startedAt))",
                    attrs: HealthFitPDFChrome.metaAttributes(),
                    spacingAfter: 12
                )

                layout.draw("Métricas da sessão", attrs: accent)
                layout.draw(String(format: "Saltos: %d", report.jumpCount), attrs: body)
                layout.draw(String(format: "Maior salto: %.2f m", report.maxJumpMeters), attrs: body)
                layout.draw(String(format: "Salto médio: %.2f m", report.avgJumpMeters), attrs: body)
                layout.draw(String(format: "Pico aceleração: %.2f g", report.maxAccelerationG), attrs: body)
                layout.draw(String(format: "Distância: %.2f km", report.distanceKm), attrs: body)
                layout.draw(
                    "Duração ativa: \(DurationFormatting.format(seconds: report.durationSeconds))",
                    attrs: body
                )
                if let board = report.boardLabel { layout.draw("Prancha: \(board)", attrs: body) }
                if let eq = report.equipmentLabel { layout.draw("Kite: \(eq)", attrs: body) }
                if let mode = report.ridingModeLabel { layout.draw("Modo: \(mode)", attrs: body) }
                if let spot = report.spotName { layout.draw("Spot: \(spot)", attrs: body) }
                if let wind = report.windSummary { layout.draw("Vento: \(wind)", attrs: body) }
                if let tide = report.tideSummary { layout.draw("Maré: \(tide)", attrs: body) }

                layout.addVerticalSpace(10)
                layout.draw("Comparativo", attrs: accent)
                if let prev = report.previousBestJumpMeters {
                    layout.draw(String(format: "Recorde anterior: %.2f m", prev), attrs: body)
                } else {
                    layout.draw("Primeira sessão com saltos registrados.", attrs: body)
                }
                if let delta = report.jumpDeltaVsBest {
                    layout.draw(String(format: "Delta vs recorde: %+.2f m", delta), attrs: body)
                }
                layout.draw("Sessões na modalidade: \(report.sessionsCompared)", attrs: body)
            }
            return url
        } catch {
            return nil
        }
    }
}
