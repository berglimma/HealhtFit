import Charts
import SwiftUI
import UIKit

/// PDF do relatório mensal com o mesmo layout/gráficos do app.
@MainActor
enum MonthlyReportPDFBuilder {
    static func makePDF(
        report: MonthlyProgressReport,
        athleteName: String
    ) -> URL? {
        let view = MonthlyReportPDFContentView(report: report, athleteName: athleteName)
        guard let image = HealthFitPDFSnapshot.render(view) else { return nil }
        return HealthFitPDFSnapshot.writePaginatedPDF(
            image: image,
            documentTitle: "Relatório Mensal",
            fileNamePrefix: "HealthFit-Mensal"
        )
    }
}

// MARK: - Layout impressão (espelha MonthlyReportView)

private struct MonthlyReportPDFContentView: View {
    let report: MonthlyProgressReport
    let athleteName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            scoreSection
            statsGrid
            sleepSection
            supplementsSection
            bodyMeasurementsSection
            mealPlanSection
            workoutChartSection
            if !report.highlights.isEmpty {
                highlightsSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportPDFPrintTheme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Relatório Mensal")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
            Text("Atleta: \(athleteName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
            Text(report.periodLabel)
                .font(.system(size: 12))
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
            Text("Resumo dos últimos \(MonthlyProgressAnalyzer.reportDays) dias")
                .font(.system(size: 12))
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

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            pdfStat("dumbbell.fill", "\(report.currentMonth.workoutCount)", "Treinos", ReportPDFPrintTheme.accent)
            pdfStat("clock.fill", "\(report.currentMonth.totalMinutes)", "Minutos", ReportPDFPrintTheme.accentSecondary)
            pdfStat(
                "moon.zzz.fill",
                report.sleepSummary.daysLogged > 0
                    ? String(format: "%.1fh", report.sleepSummary.averageHours)
                    : "—",
                "Sono médio",
                ReportPDFPrintTheme.indigo
            )
            pdfStat("pills.fill", "\(report.supplementSummary.totalIntakes)", "Suplementos", ReportPDFPrintTheme.teal)
        }
    }

    private func pdfStat(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ReportPDFPrintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sono", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if report.sleepSummary.daysLogged == 0 {
                emptyCard("Nenhum registro de sono neste período.")
            } else {
                HStack {
                    Text("\(report.sleepSummary.daysLogged) noite(s)")
                    Spacer()
                    Text("\(report.sleepSummary.idealNights) no ideal (7–9 h)")
                }
                .font(.caption)
                .foregroundStyle(ReportPDFPrintTheme.textSecondary)

                Chart(report.sleepSummary.dailyHours.filter { $0.hours > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Horas", day.hours)
                    )
                    .foregroundStyle(ReportPDFPrintTheme.indigo.gradient)
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...12)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
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
                .frame(height: 180)
                .padding(12)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
            }
        }
    }

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suplementos", systemImage: "pills.fill")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if report.supplementSummary.totalIntakes == 0 {
                emptyCard("Nenhum suplemento registrado neste período.")
            } else {
                Text("\(report.supplementSummary.totalIntakes) registro(s) em \(report.supplementSummary.daysLogged) dia(s)")
                    .font(.caption)
                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)

                Chart(report.dailySupplementActivity.filter { $0.intakeCount > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Registros", day.intakeCount)
                    )
                    .foregroundStyle(ReportPDFPrintTheme.teal.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 140)
                .padding(12)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))

                if !report.supplementSummary.topSupplements.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mais registrados")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        ForEach(report.supplementSummary.topSupplements) { item in
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                                Spacer()
                                Text("\(item.count)×")
                                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(12)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
                }

                let recent = Array(report.supplementSummary.entries.prefix(8))
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Histórico recente")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        ForEach(recent) { intake in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(intake.name)
                                        .font(.subheadline)
                                        .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                                    Text(intake.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                                }
                                Spacer()
                                Text(intake.quantityDisplay)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ReportPDFPrintTheme.accent)
                            }
                        }
                    }
                    .padding(12)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
                }
            }
        }
    }

    private var bodyMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Medidas corporais", systemImage: "ruler.fill")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if !report.bodyMeasurements.hasData {
                emptyCard("Nenhuma medida cadastrada neste período.")
            } else {
                if let current = report.bodyMeasurements.current, current.hasAnyValue {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Atual")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        if let measuredAt = current.measuredAt {
                            Text(measuredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                        }
                        ForEach(current.labeledValues.filter { $0.value != nil }, id: \.label) { row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(BodyMeasurements.formatCm(row.value!))
                                    .foregroundStyle(ReportPDFPrintTheme.accent)
                            }
                            .font(.subheadline)
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                        }
                    }
                    .padding(12)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
                }

                if let comparison = report.bodyMeasurements.comparison {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comparativo (\(comparison.periodDays) dia(s))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReportPDFPrintTheme.textPrimary)

                        if comparison.changes.isEmpty {
                            Text("Nenhuma medida variou no período.")
                                .font(.subheadline)
                                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                        } else {
                            Chart(comparison.changes) { change in
                                BarMark(
                                    x: .value("Delta", change.delta),
                                    y: .value("Medida", change.label)
                                )
                                .foregroundStyle(
                                    change.delta >= 0
                                        ? ReportPDFPrintTheme.accent.gradient
                                        : ReportPDFPrintTheme.orange.gradient
                                )
                            }
                            .frame(height: CGFloat(max(120, comparison.changes.count * 28)))
                        }
                    }
                    .padding(12)
                    .background(ReportPDFPrintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
                }
            }
        }
    }

    private var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Plano de refeições", systemImage: "fork.knife")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if !report.mealPlanSummary.hasPlan {
                emptyCard("Nenhum cardápio ativo neste período.")
            } else {
                let pct = Int((report.mealPlanSummary.completionRate * 100).rounded())
                Text("\(report.mealPlanSummary.completedMeals)/\(report.mealPlanSummary.totalMeals) refeições concluídas (\(pct)%)")
                    .font(.caption)
                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)

                Chart(report.mealPlanSummary.daySummaries) { day in
                    BarMark(
                        x: .value("Dia", shortDay(day.dayOfWeek)),
                        y: .value("Concluídas", day.completed)
                    )
                    .foregroundStyle(ReportPDFPrintTheme.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .padding(12)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.mealPlanSummary.daySummaries) { day in
                        HStack {
                            Text(day.dayOfWeek)
                                .foregroundStyle(ReportPDFPrintTheme.textPrimary)
                            Spacer()
                            Text("\(day.completed)/\(day.total)")
                                .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(12)
                .background(ReportPDFPrintTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
            }
        }
    }

    private var workoutChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Atividade (minutos)")
                .font(.headline)
                .foregroundStyle(ReportPDFPrintTheme.textPrimary)

            if report.dailyWorkoutMinutes.allSatisfy({ $0.minutes == 0 }) {
                emptyCard("Nenhuma atividade registrada neste período.")
            } else {
                Chart(report.dailyWorkoutMinutes.filter { $0.minutes > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Minutos", day.minutes)
                    )
                    .foregroundStyle(ReportPDFPrintTheme.accent.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(ReportPDFPrintTheme.textSecondary)
                            }
                        }
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
            Label("Destaques do mês", systemImage: "star.fill")
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
            }
        }
        .padding(12)
        .background(ReportPDFPrintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(ReportPDFPrintTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(ReportPDFPrintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: ReportPDFPrintTheme.corner))
    }

    private func shortDay(_ dayOfWeek: String) -> String {
        let parts = dayOfWeek.split(separator: "-").map(String.init)
        if let first = parts.first, first.count >= 3 {
            return String(first.prefix(3))
        }
        return String(dayOfWeek.prefix(3))
    }
}
