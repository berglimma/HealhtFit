import SwiftUI
import Charts

struct HealthChartsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService

    @State private var selectedMetric: ChartMetric = .workout
    /// Memoized by session count + goal so body/chart rebuilds don't re-scan history.
    @State private var cachedWeeklyReport: WeeklyProgressReport?
    @State private var weeklyReportCacheKey: String = ""

    enum ChartMetric: String, CaseIterable {
        case workout = "Treino (min)"
        case steps = "Passos"
        case calories = "Calorias"
        case heartRate = "FC Repouso"
        case meditation = "Meditação (min)"
    }

    private var weeklyReport: WeeklyProgressReport {
        if let cachedWeeklyReport { return cachedWeeklyReport }
        return WeeklyProgressAnalyzer.buildReport(
            sessions: workoutStore.sessionHistory,
            goal: authService.currentUser?.goal ?? .maintenance
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Desempenho Semanal")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Picker("Métrica", selection: $selectedMetric) {
                    ForEach(ChartMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.accent)
            }

            if selectedMetric == .meditation {
                meditationEvolutionBanner
            }

            Chart(chartDataPoints) { point in
                BarMark(
                    x: .value("Dia", point.date, unit: .day),
                    y: .value("Valor", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor, chartColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
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
            .frame(height: 200)
            .drawingGroup()

            summaryRow
        }
        .cardStyle()
        .onAppear(perform: refreshWeeklyReportIfNeeded)
        .onChange(of: workoutStore.sessionHistory.count) { _, _ in
            refreshWeeklyReportIfNeeded()
        }
        .onChange(of: authService.currentUser?.goal) { _, _ in
            refreshWeeklyReportIfNeeded()
        }
    }

    private func refreshWeeklyReportIfNeeded() {
        let goal = authService.currentUser?.goal ?? .maintenance
        let key = "\(workoutStore.sessionHistory.count)|\(goal.rawValue)|\(workoutStore.sessionHistory.first?.id.uuidString ?? "")"
        guard key != weeklyReportCacheKey else { return }
        weeklyReportCacheKey = key
        cachedWeeklyReport = WeeklyProgressAnalyzer.buildReport(
            sessions: workoutStore.sessionHistory,
            goal: goal
        )
    }

    private var meditationEvolutionBanner: some View {
        let summary = weeklyReport.meditationSummary
        let delta = summary.totalMinutes - summary.previousMinutes
        let direction: ProgressTrendDirection
        if delta > 0 { direction = .up }
        else if delta < 0 { direction = .down }
        else { direction = .stable }

        return HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Evolução da meditação")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(meditationEvolutionText(delta: delta, previous: summary.previousMinutes))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Label(evolutionLabel(delta: delta, direction: direction), systemImage: evolutionIcon(direction))
                .font(.caption.weight(.semibold))
                .foregroundStyle(evolutionColor(direction))
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var chartDataPoints: [WeeklyChartPoint] {
        switch selectedMetric {
        case .meditation:
            return weeklyReport.dailyMeditationMinutes.map {
                WeeklyChartPoint(date: $0.date, value: Double($0.minutes))
            }
        default:
            return healthKitManager.dailyMetrics.map {
                WeeklyChartPoint(date: $0.date, value: valueForMetric($0))
            }
        }
    }

    @ViewBuilder
    private var summaryRow: some View {
        switch selectedMetric {
        case .meditation:
            HStack(spacing: 16) {
                SummaryItem(
                    title: "Total semana",
                    value: "\(weeklyReport.meditationSummary.totalMinutes) min",
                    icon: "clock.fill"
                )
                SummaryItem(
                    title: "Sessões",
                    value: "\(weeklyReport.meditationSummary.sessionCount)",
                    icon: "leaf.fill"
                )
                SummaryItem(
                    title: "Semana anterior",
                    value: "\(weeklyReport.meditationSummary.previousMinutes) min",
                    icon: "calendar"
                )
            }
        default:
            HStack(spacing: 16) {
                SummaryItem(
                    title: "Média Passos",
                    value: "\(averageSteps)",
                    icon: "figure.walk"
                )
                SummaryItem(
                    title: "Total Calorias",
                    value: "\(Int(totalCalories))",
                    icon: "flame.fill"
                )
                SummaryItem(
                    title: "FC Média",
                    value: "\(Int(averageHR))",
                    icon: "heart.fill"
                )
            }
        }
    }

    private func valueForMetric(_ metric: DailyHealthMetric) -> Double {
        switch selectedMetric {
        case .steps: return Double(metric.steps)
        case .calories: return metric.activeCalories
        case .heartRate: return metric.restingHeartRate
        case .workout: return Double(metric.workoutMinutes)
        case .meditation: return 0
        }
    }

    private var chartColor: Color {
        switch selectedMetric {
        case .steps: return AppTheme.accent
        case .calories: return AppTheme.accentSecondary
        case .heartRate: return .red
        case .workout: return .purple
        case .meditation: return .purple
        }
    }

    private var averageSteps: Int {
        let total = healthKitManager.dailyMetrics.map(\.steps).reduce(0, +)
        return healthKitManager.dailyMetrics.isEmpty ? 0 : total / healthKitManager.dailyMetrics.count
    }

    private var totalCalories: Double {
        healthKitManager.dailyMetrics.map(\.activeCalories).reduce(0, +)
    }

    private var averageHR: Double {
        let values = healthKitManager.dailyMetrics.map(\.restingHeartRate).filter { $0 > 0 }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func meditationEvolutionText(delta: Int, previous: Int) -> String {
        if previous == 0 && weeklyReport.meditationSummary.totalMinutes == 0 {
            return "Nenhuma sessão registrada. Comece em Treinos → Meditação."
        }
        if previous == 0 {
            return "Primeira semana com meditação registrada no app."
        }
        if delta > 0 {
            return "+\(delta) min vs semana anterior (\(previous) min)"
        }
        if delta < 0 {
            return "\(delta) min vs semana anterior (\(previous) min)"
        }
        return "Mesmo tempo da semana anterior (\(previous) min)"
    }

    private func evolutionLabel(delta: Int, direction: ProgressTrendDirection) -> String {
        switch direction {
        case .up: return "+\(delta) min"
        case .down: return "\(delta) min"
        case .stable: return "Estável"
        }
    }

    private func evolutionIcon(_ direction: ProgressTrendDirection) -> String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }

    private func evolutionColor(_ direction: ProgressTrendDirection) -> Color {
        switch direction {
        case .up: return AppTheme.accent
        case .down: return .orange
        case .stable: return AppTheme.textSecondary
        }
    }
}

private struct WeeklyChartPoint: Identifiable {
    /// Stable identity — never use UUID() (forces Chart rewrite every body pass).
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    let date: Date
    let value: Double
}

struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
