import Charts
import SwiftUI

/// Diário de bordo de natação: histórico, distância, ritmo e calorias.
struct SwimmingLogbookView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var entries: [SwimmingLogEntry] {
        SwimmingMetricsAnalyzer.entries(from: workoutStore.sessionHistory)
    }

    private var totalMeters: Double {
        SwimmingMetricsAnalyzer.totalDistanceMeters(entries: entries)
    }

    private var totalCalories: Double {
        SwimmingMetricsAnalyzer.totalCalories(entries: entries)
    }

    private var averagePace: Int? {
        SwimmingMetricsAnalyzer.averagePaceSecondsPer100m(entries: entries)
    }

    private var distancePoints: [(date: Date, meters: Double)] {
        SwimmingMetricsAnalyzer.distanceChartPoints(entries: entries)
    }

    private var pacePoints: [(date: Date, pace: Int)] {
        SwimmingMetricsAnalyzer.paceChartPoints(entries: entries)
    }

    private var caloriePoints: [(date: Date, kcal: Double)] {
        SwimmingMetricsAnalyzer.calorieChartPoints(entries: entries)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerBanner
                if entries.isEmpty {
                    emptyState
                } else {
                    summaryGrid
                    distanceChartCard
                    paceChartCard
                    caloriesChartCard
                    logbookList
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Diário de natação")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: "figure.pool.swim")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Diário de bordo")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Evolução de distância, ritmo (/100 m) e gasto calórico estimado.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nenhuma natação registrada")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Inicie um cardio de Natação, defina o tamanho da piscina e conte as voltas. O histórico aparece aqui.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile(
                title: "Sessões",
                value: "\(entries.count)",
                icon: "list.bullet",
                color: AppTheme.accent
            )
            metricTile(
                title: "Distância total",
                value: totalMeters >= 1000
                    ? String(format: "%.1f km", totalMeters / 1000)
                    : "\(Int(totalMeters.rounded())) m",
                icon: "ruler",
                color: AppTheme.accentSecondary
            )
            metricTile(
                title: "Ritmo médio",
                value: averagePace.map { PaceFormatting.formatSwimPace(secondsPer100m: $0) } ?? "—",
                icon: "speedometer",
                color: .cyan
            )
            metricTile(
                title: "kcal estimadas",
                value: "\(Int(totalCalories.rounded()))",
                icon: "flame.fill",
                color: .orange
            )
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var distanceChartCard: some View {
        chartCard(title: "Evolução de distância", subtitle: "Metros por sessão") {
            if distancePoints.isEmpty {
                chartPlaceholder
            } else {
                Chart {
                    ForEach(Array(distancePoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("m", point.meters)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Data", point.date),
                            y: .value("m", point.meters)
                        )
                        .foregroundStyle(AppTheme.accent.opacity(0.15))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("m", point.meters)
                        )
                        .foregroundStyle(AppTheme.accent)
                    }
                }
                .chartYAxisLabel("m")
                .frame(height: 180)
            }
        }
    }

    private var paceChartCard: some View {
        chartCard(title: "Evolução de ritmo", subtitle: "Segundos por 100 m (menor = mais rápido)") {
            if pacePoints.isEmpty {
                chartPlaceholder
            } else {
                Chart {
                    ForEach(Array(pacePoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("s/100m", point.pace)
                        )
                        .foregroundStyle(Color.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("s/100m", point.pace)
                        )
                        .foregroundStyle(Color.cyan)
                    }
                }
                .chartYAxisLabel("s/100m")
                .frame(height: 180)
            }
        }
    }

    private var caloriesChartCard: some View {
        chartCard(title: "Estimativa calórica", subtitle: "kcal por sessão") {
            if caloriePoints.isEmpty {
                chartPlaceholder
            } else {
                Chart {
                    ForEach(Array(caloriePoints.enumerated()), id: \.offset) { _, point in
                        BarMark(
                            x: .value("Data", point.date, unit: .day),
                            y: .value("kcal", point.kcal)
                        )
                        .foregroundStyle(AppTheme.accentSecondary.gradient)
                    }
                }
                .chartYAxisLabel("kcal")
                .frame(height: 180)
            }
        }
    }

    private var chartPlaceholder: some View {
        Text("Dados insuficientes para o gráfico")
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func chartCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var logbookList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Histórico")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVStack(spacing: 10) {
                ForEach(entries) { entry in
                    logEntryRow(entry)
                }
            }
        }
    }

    private func logEntryRow(_ entry: SwimmingLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate(entry.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let intensity = entry.intensityLabel {
                    Text(intensity)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                logStat(icon: "arrow.triangle.2.circlepath", text: "\(entry.laps) voltas")
                logStat(icon: "ruler", text: entry.formattedDistance)
                logStat(icon: "speedometer", text: entry.formattedPace)
            }

            HStack(spacing: 12) {
                logStat(icon: "clock", text: PaceFormatting.formatDuration(seconds: entry.durationSeconds))
                logStat(icon: "flame.fill", text: "~\(Int(entry.calories.rounded())) kcal")
                logStat(icon: "figure.pool.swim", text: "\(Int(entry.poolLengthMeters)) m")
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func logStat(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }
}

/// Rota de navegação para o diário (Hashable / NavigationLink).
struct SwimmingLogbookRoute: Hashable {}
