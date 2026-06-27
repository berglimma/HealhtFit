import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    metricsRow
                    HealthChartsView()
                    watchSection
                    recentWorkoutsSection
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Dashboard")
            .refreshable {
                await healthKitManager.fetchWeeklyMetrics()
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Olá, \(authService.currentUser?.name.components(separatedBy: " ").first ?? "Atleta")!")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Pronto para treinar hoje?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(AppTheme.accentSecondary)
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(Circle())
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricBadge(
                icon: "figure.walk",
                value: "\(healthKitManager.todaySteps)",
                label: "Passos",
                color: AppTheme.accent
            )
            MetricBadge(
                icon: "flame.fill",
                value: String(format: "%.0f", healthKitManager.todayCalories),
                label: "Calorias",
                color: AppTheme.accentSecondary
            )
            MetricBadge(
                icon: "heart.fill",
                value: String(format: "%.0f", healthKitManager.currentHeartRate > 0 ? healthKitManager.currentHeartRate : healthKitManager.restingHeartRate),
                label: "BPM",
                color: .red
            )
        }
    }

    private var watchSection: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(watchConnectivity.isWatchConnected ? AppTheme.accent : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Watch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(watchConnectivity.isWatchConnected ? "Conectado" : "Sincronização automática ativa")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Circle()
                .fill(watchConnectivity.isWatchConnected ? AppTheme.accent : .orange)
                .frame(width: 10, height: 10)
        }
        .cardStyle()
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Treinos Recentes")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if workoutStore.sessionHistory.isEmpty {
                Text("Nenhum treino realizado ainda")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .cardStyle()
            } else {
                ForEach(workoutStore.sessionHistory.prefix(3)) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.workoutTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(session.duration / 60)) min")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.accent)
                            if session.caloriesBurned > 0 {
                                Text("\(Int(session.caloriesBurned)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
