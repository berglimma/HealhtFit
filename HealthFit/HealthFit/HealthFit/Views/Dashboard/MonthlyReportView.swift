import SwiftUI
import Charts

struct MonthlyReportView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var monthlyReportService: MonthlyReportService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    private var report: MonthlyProgressReport {
        monthlyReportService.buildReport(
            sessions: workoutStore.sessionHistory,
            wellnessEntries: monthlyReportService.recentWellnessEntries,
            profile: authService.currentUser,
            weeklyPlan: mealPlanService.weeklyPlan,
            goal: authService.currentUser?.goal ?? .maintenance
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Relatório Mensal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .overlay {
                if monthlyReportService.isLoadingWellness {
                    ProgressView("Carregando histórico…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await monthlyReportService.loadWellnessHistory(
                    userId: authService.currentUser?.id,
                    todayEntry: wellnessService.todayEntry
                )
                monthlyReportService.markReportViewed()
            }
        }
        .requiresSubscription(.monthlyReport)
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: Double(report.overallScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(report.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("pontos")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Text(report.periodLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)

            Text("Resumo dos últimos \(MonthlyProgressAnalyzer.reportDays) dias")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var scoreColor: Color {
        switch report.overallScore {
        case 80...: return AppTheme.accent
        case 50..<80: return AppTheme.accentSecondary
        default: return .orange
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MonthlyStatCard(
                icon: "dumbbell.fill",
                value: "\(report.currentMonth.workoutCount)",
                label: "Treinos",
                color: AppTheme.accent
            )
            MonthlyStatCard(
                icon: "clock.fill",
                value: "\(report.currentMonth.totalMinutes)",
                label: "Minutos",
                color: AppTheme.accentSecondary
            )
            MonthlyStatCard(
                icon: "moon.zzz.fill",
                value: report.sleepSummary.daysLogged > 0
                    ? String(format: "%.1fh", report.sleepSummary.averageHours)
                    : "—",
                label: "Sono médio",
                color: .indigo
            )
            MonthlyStatCard(
                icon: "pills.fill",
                value: "\(report.supplementSummary.totalIntakes)",
                label: "Suplementos",
                color: .teal
            )
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sono", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if report.sleepSummary.daysLogged == 0 {
                Text("Nenhum registro de sono neste período. Registre em Sono e Hidratação.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                HStack {
                    Text("\(report.sleepSummary.daysLogged) noite(s)")
                    Spacer()
                    Text("\(report.sleepSummary.idealNights) no ideal (7–9 h)")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                Chart(report.sleepSummary.dailyHours.filter { $0.hours > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Horas", day.hours)
                    )
                    .foregroundStyle(Color.indigo.gradient)
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...12)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(height: 180)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
    }

    // MARK: - Supplements

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suplementos", systemImage: "pills.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if report.supplementSummary.totalIntakes == 0 {
                Text("Nenhum suplemento registrado. Use Nutrição → Suplementos.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                Text("\(report.supplementSummary.totalIntakes) registro(s) em \(report.supplementSummary.daysLogged) dia(s)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Chart(report.dailySupplementActivity.filter { $0.intakeCount > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Registros", day.intakeCount)
                    )
                    .foregroundStyle(Color.teal.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 140)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                if !report.supplementSummary.topSupplements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mais registrados")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        ForEach(report.supplementSummary.topSupplements) { item in
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text("\(item.count)×")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                let recent = Array(report.supplementSummary.entries.prefix(8))
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Histórico recente")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        ForEach(recent) { intake in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(intake.name)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(intake.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text(intake.quantityDisplay)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
        }
    }

    // MARK: - Body measurements

    private var bodyMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Medidas corporais", systemImage: "ruler.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if !report.bodyMeasurements.hasData {
                Text("Nenhuma medida cadastrada. Atualize em Perfil → Medidas / Evolução Corporal.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                if let current = report.bodyMeasurements.current, current.hasAnyValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Atual")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let measuredAt = current.measuredAt {
                            Text(measuredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        ForEach(current.labeledValues.filter { $0.value != nil }, id: \.label) { row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(BodyMeasurements.formatCm(row.value!))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                if let comparison = report.bodyMeasurements.comparison {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comparativo (\(comparison.periodDays) dia(s))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if comparison.changes.isEmpty {
                            Text("Nenhuma medida variou no período.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Chart(comparison.changes) { change in
                                BarMark(
                                    x: .value("Delta", change.delta),
                                    y: .value("Medida", change.label)
                                )
                                .foregroundStyle(change.delta >= 0 ? AppTheme.accent.gradient : Color.orange.gradient)
                            }
                            .frame(height: CGFloat(max(120, comparison.changes.count * 28)))
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
        }
    }

    // MARK: - Meal plan

    private var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plano de refeições", systemImage: "fork.knife")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if !report.mealPlanSummary.hasPlan {
                Text("Nenhum cardápio ativo. Gere seu plano em Nutrição.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                let pct = Int((report.mealPlanSummary.completionRate * 100).rounded())
                Text("\(report.mealPlanSummary.completedMeals)/\(report.mealPlanSummary.totalMeals) refeições concluídas (\(pct)%)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Chart(report.mealPlanSummary.daySummaries) { day in
                    BarMark(
                        x: .value("Dia", shortDay(day.dayOfWeek)),
                        y: .value("Concluídas", day.completed)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.mealPlanSummary.daySummaries) { day in
                        HStack {
                            Text(day.dayOfWeek)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(day.completed)/\(day.total)")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
    }

    // MARK: - Workouts chart

    private var workoutChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atividade (minutos)")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if report.dailyWorkoutMinutes.allSatisfy({ $0.minutes == 0 }) {
                Text("Nenhuma atividade registrada neste período.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                Chart(report.dailyWorkoutMinutes.filter { $0.minutes > 0 }) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Minutos", day.minutes)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Destaques do mês", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)

            ForEach(report.highlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text(highlight)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func shortDay(_ dayOfWeek: String) -> String {
        let parts = dayOfWeek.split(separator: "-").map(String.init)
        if let first = parts.first, first.count >= 3 {
            return String(first.prefix(3))
        }
        return String(dayOfWeek.prefix(3))
    }
}

private struct MonthlyStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
