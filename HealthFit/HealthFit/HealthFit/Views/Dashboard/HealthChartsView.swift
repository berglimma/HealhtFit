import SwiftUI
import Charts

struct HealthChartsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedMetric: ChartMetric = .steps

    enum ChartMetric: String, CaseIterable {
        case steps = "Passos"
        case calories = "Calorias"
        case heartRate = "FC Repouso"
        case workout = "Treino (min)"
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

            Chart(healthKitManager.dailyMetrics) { metric in
                BarMark(
                    x: .value("Dia", metric.date, unit: .day),
                    y: .value("Valor", valueForMetric(metric))
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

            summaryRow
        }
        .cardStyle()
    }

    private var summaryRow: some View {
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

    private func valueForMetric(_ metric: DailyHealthMetric) -> Double {
        switch selectedMetric {
        case .steps: return Double(metric.steps)
        case .calories: return metric.activeCalories
        case .heartRate: return metric.restingHeartRate
        case .workout: return Double(metric.workoutMinutes)
        }
    }

    private var chartColor: Color {
        switch selectedMetric {
        case .steps: return AppTheme.accent
        case .calories: return AppTheme.accentSecondary
        case .heartRate: return .red
        case .workout: return .purple
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
