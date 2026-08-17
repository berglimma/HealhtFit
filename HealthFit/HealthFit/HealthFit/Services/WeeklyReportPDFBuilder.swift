import Charts
import SwiftUI
import UIKit

/// PDF do relatório semanal com o mesmo layout/gráficos do app.
@MainActor
enum WeeklyReportPDFBuilder {
    static func makePDF(
        report: WeeklyProgressReport,
        athleteName: String
    ) -> URL? {
        let view = WeeklyReportPDFContentView(report: report, athleteName: athleteName)
        guard let image = HealthFitPDFSnapshot.render(view) else { return nil }
        return HealthFitPDFSnapshot.writePaginatedPDF(
            image: image,
            documentTitle: "Relatório Semanal",
            fileNamePrefix: "HealthFit-Semanal"
        )
    }
}

// MARK: - Layout impressão (espelha WeeklyReportView)

private struct WeeklyReportPDFContentView: View {
    let report: WeeklyProgressReport
    let athleteName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            scoreSection
            statsGrid
            if !report.trends.isEmpty {
                trendsSection
            }
            meditationSection
            preWorkoutSection
            activityChart
            if !report.highlights.isEmpty {
                highlightsSection
            }
            if !report.improvements.isEmpty {
                improvementsSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportPDFPrintTheme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Relatório Semanal")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
            Text("Atleta: \(athleteName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
            Text(report.periodLabel)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
        }
    }

    private var scoreSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 10)
                    .frame(width: 110, height: 110)
                Circle()
                    .trim(from: 0, to: Double(report.overallScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(report.overallScore)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                    Text("pontos")
                        .font(.caption2)
                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                }
            }
            Text(scoreMessage)
                .font(.subheadline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ReportPDFPrintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
    }

    private var scoreColor: Color {
        switch report.overallScore {
        case 80...: return ReportPDFPrintTheme.accent
        case 50..<80: return ReportPDFPrintTheme.accentSecondary
        default: return ReportPDFPrintTheme.orange
        }
    }

    private var scoreMessage: String {
        switch report.overallScore {
        case 80...: return "Semana excelente! Você está no caminho certo."
        case 50..<80: return "Bom progresso. Veja abaixo o que pode melhorar."
        case 1..<50: return "Há espaço para evoluir. Foque nas sugestões abaixo."
        default: return "Complete treinos para gerar seu relatório."
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            pdfStat("dumbbell.fill", "\(report.currentWeek.workoutCount)", "Treinos", ReportPDFPrintTheme.accent)
            pdfStat("clock.fill", "\(report.currentWeek.totalMinutes)", "Minutos", ReportPDFPrintTheme.accentSecondary)
            pdfStat("flame.fill", "\(Int(report.currentWeek.totalCalories))", "Calorias", ReportPDFPrintTheme.orange)
            pdfStat("calendar", "\(report.currentWeek.activeDays)/7", "Dias ativos", ReportPDFPrintTheme.blue)
            pdfStat("brain.head.profile", "\(report.meditationSummary.sessionCount)", "Meditação", ReportPDFPrintTheme.purple)
            pdfStat("leaf.fill", "\(report.meditationSummary.totalMinutes) min", "Min. meditação", ReportPDFPrintTheme.indigo)
        }
    }

    private func pdfStat(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ReportPDFPrintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparado à semana anterior")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            ForEach(report.trends) { trend in
                HStack(spacing: 10) {
                    Image(systemName: trend.icon)
                        .foregroundStyle(trendColor(trend.direction))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trend.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        Text("Antes: \(trend.previousValue)")
                            .font(.caption)
                            .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(trend.currentValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        Text(trend.direction.rawValue)
                            .font(.caption2)
                            .foregroundStyle(trendColor(trend.direction))
                    }
                }
                .padding(10)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var meditationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Meditação", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.purple)

            HStack(spacing: 10) {
                meditationTile("leaf.fill", "\(report.meditationSummary.sessionCount)", "Sessões", ReportPDFPrintTheme.purple)
                meditationTile("clock.fill", "\(report.meditationSummary.totalMinutes) min", "Tempo total", ReportPDFPrintTheme.indigo)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Evolução diária")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ReportPDFPrintTheme.textPrimary)

                if report.dailyMeditationMinutes.allSatisfy({ $0.minutes == 0 }) {
                    Text("Sem minutos de meditação registrados nesta semana.")
                        .font(.caption)
                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Chart(report.dailyMeditationMinutes) { day in
                        BarMark(
                            x: .value("Dia", day.date, unit: .day),
                            y: .value("Minutos", day.minutes)
                        )
                        .foregroundStyle(ReportPDFPrintTheme.purple.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                        .font(.caption2)
                                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Color.black.opacity(0.08))
                            AxisValueLabel()
                                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                        }
                    }
                    .frame(height: 140)
                }
            }
            .padding(12)
            .background(ReportPDFPrintTheme.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !report.meditationSummary.topics.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tópicos praticados")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                    ForEach(report.meditationSummary.topics, id: \.self) { topic in
                        Text("• \(topic)")
                            .font(.subheadline)
                            .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func meditationTile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ReportPDFPrintTheme.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var preWorkoutSection: some View {
        if report.preWorkoutSummary.totalAnswered > 0 || report.lifetimePreWorkoutSummary.totalAnswered > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Label("Pré-treino", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(ReportPDFPrintTheme.accentSecondary)

                HStack(spacing: 10) {
                    preTile("\(report.preWorkoutSummary.usedCount)x", "Com pré-treino (semana)")
                    preTile("\(report.preWorkoutSummary.notUsedCount)x", "Sem pré-treino (semana)")
                }

                HStack {
                    Text("Total histórico com pré-treino")
                        .font(.caption)
                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                    Spacer()
                    Text("\(report.lifetimePreWorkoutSummary.usedCount)x")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                }

                if !report.preWorkoutEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Respostas desta semana")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        ForEach(report.preWorkoutEntries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.workoutTitle)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                                    Text(entry.date, format: .dateTime.day().month().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                                }
                                Spacer()
                                Text(entry.tookPreWorkout ? "Sim" : "Não")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(entry.tookPreWorkout ? ReportPDFPrintTheme.accent : ReportPDFPrintTheme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func preTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ReportPDFPrintTheme.accentSecondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Atividade diária")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if report.dailyWorkoutMinutes.allSatisfy({ $0.minutes == 0 }) {
                Text("Nenhuma atividade registrada nesta semana.")
                    .font(.subheadline)
                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
            } else {
                Chart(report.dailyWorkoutMinutes) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Minutos", day.minutes)
                    )
                    .foregroundStyle(ReportPDFPrintTheme.accent.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.black.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                    }
                }
                .frame(height: 160)
                .padding(12)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
            }
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Destaques da semana", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.accent)
            ForEach(report.highlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ReportPDFPrintTheme.accent)
                    Text(highlight)
                        .font(.subheadline)
                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReportPDFPrintTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("O que melhorar", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.accentSecondary)
            ForEach(report.improvements) { suggestion in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: suggestion.icon)
                        .font(.title3)
                        .foregroundStyle(priorityColor(suggestion.priority))
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        Text(suggestion.detail)
                            .font(.caption)
                            .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func trendColor(_ direction: ProgressTrendDirection) -> Color {
        switch direction {
        case .up: return ReportPDFPrintTheme.accent
        case .down: return ReportPDFPrintTheme.orange
        case .stable: return ReportPDFPrintTheme.textSecondary
        }
    }

    private func priorityColor(_ priority: ImprovementPriority) -> Color {
        switch priority {
        case .high: return ReportPDFPrintTheme.orange
        case .medium: return ReportPDFPrintTheme.accentSecondary
        case .low: return ReportPDFPrintTheme.accent
        }
    }
}
