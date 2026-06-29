import SwiftUI
import Charts

struct WeeklyReportView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var weeklyReportService: WeeklyReportService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    private var report: WeeklyProgressReport {
        weeklyReportService.buildReport(
            sessions: workoutStore.sessionHistory,
            goal: authService.currentUser?.goal ?? .maintenance
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scoreSection
                    statsGrid
                    if !report.trends.isEmpty {
                        trendsSection
                    }
                    activityChart
                    if !report.highlights.isEmpty {
                        highlightsSection
                    }
                    improvementsSection
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Relatório Semanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .onAppear {
                weeklyReportService.markReportViewed()
            }
        }
    }

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

            Text(scoreMessage)
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

    private var scoreMessage: String {
        switch report.overallScore {
        case 80...: return "Semana excelente! Você está no caminho certo."
        case 50..<80: return "Bom progresso. Veja abaixo o que pode melhorar."
        case 1..<50: return "Há espaço para evoluir. Foque nas sugestões abaixo."
        default: return "Complete treinos para gerar seu relatório."
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            WeeklyStatCard(
                icon: "dumbbell.fill",
                value: "\(report.currentWeek.workoutCount)",
                label: "Treinos",
                color: AppTheme.accent
            )
            WeeklyStatCard(
                icon: "clock.fill",
                value: "\(report.currentWeek.totalMinutes)",
                label: "Minutos",
                color: AppTheme.accentSecondary
            )
            WeeklyStatCard(
                icon: "flame.fill",
                value: "\(Int(report.currentWeek.totalCalories))",
                label: "Calorias",
                color: .orange
            )
            WeeklyStatCard(
                icon: "calendar",
                value: "\(report.currentWeek.activeDays)/7",
                label: "Dias ativos",
                color: .blue
            )
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparado à semana anterior")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(report.trends) { trend in
                HStack(spacing: 12) {
                    Image(systemName: trend.icon)
                        .foregroundStyle(trendColor(trend.direction))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(trend.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Antes: \(trend.previousValue)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(trend.currentValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Label(trend.direction.rawValue, systemImage: trendIcon(trend.direction))
                            .font(.caption2)
                            .foregroundStyle(trendColor(trend.direction))
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atividade diária")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if report.dailyWorkoutMinutes.allSatisfy({ $0.minutes == 0 }) {
                Text("Nenhuma atividade registrada nesta semana.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .cardStyle()
            } else {
                Chart(report.dailyWorkoutMinutes) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Minutos", day.minutes)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(4)
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
                .frame(height: 160)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Destaques da semana", systemImage: "star.fill")
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
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("O que melhorar", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accentSecondary)

            ForEach(report.improvements) { suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .font(.title3)
                        .foregroundStyle(priorityColor(suggestion.priority))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(suggestion.detail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func trendColor(_ direction: ProgressTrendDirection) -> Color {
        switch direction {
        case .up: return AppTheme.accent
        case .down: return .orange
        case .stable: return AppTheme.textSecondary
        }
    }

    private func trendIcon(_ direction: ProgressTrendDirection) -> String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }

    private func priorityColor(_ priority: ImprovementPriority) -> Color {
        switch priority {
        case .high: return .orange
        case .medium: return AppTheme.accentSecondary
        case .low: return AppTheme.accent
        }
    }
}

private struct WeeklyStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
