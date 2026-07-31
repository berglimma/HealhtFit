import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var weeklyReportService: WeeklyReportService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var shareCardStore: WorkoutShareCardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showWeeklyReport = false
    @State private var isSyncingWatch = false
    @State private var watchSyncResult: WatchSyncResult?
    @State private var showWatchSyncAlert = false

    private var healthStatus: WellnessHealthIconStatus {
        wellnessService.healthIconStatus()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    weeklyReportBanner
                    lastShareCardSection
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
            .task {
                await healthKitManager.refreshFromHealthKit()
            }
            .refreshable {
                await healthKitManager.refreshFromHealthKit()
            }
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
            }
            .alert(
                watchSyncResult?.title ?? "Apple Watch",
                isPresented: $showWatchSyncAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(watchSyncResult?.message ?? "")
            }
        }
    }

    private var weeklyReportBanner: some View {
        Button {
            showWeeklyReport = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Relatório Semanal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if weeklyReportService.isReportAvailable {
                            Text("NOVO")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentSecondary)
                                .clipShape(Capsule())
                        }
                    }

                    if weeklyReportService.isReportAvailable {
                        Text("Veja seu progresso e o que melhorar esta semana")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if weeklyReportService.daysUntilNextReport > 0 {
                        Text("Próximo relatório em \(weeklyReportService.daysUntilNextReport) dia(s)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text("Acompanhe treinos, calorias e sugestões de melhoria")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var lastShareCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Último card de postagem")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if let card = shareCardStore.lastCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.workoutTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(formattedShareCardDate(card.displayDate))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }

                    if let preview = shareCardStore.previewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                            .accessibilityLabel("Card de postagem de \(card.workoutTitle)")
                    } else {
                        WorkoutShareCardView(
                            session: card.makeSession(),
                            athleteName: card.athleteName,
                            motivationLine: card.motivationLine
                        )
                        .scaleEffect(0.72)
                        .frame(height: 324)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                Text("Nenhum card gerado ainda. Finalize um treino para criar o card de postagem.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .cardStyle()
            }
        }
    }

    private func formattedShareCardDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Olá, \(authService.currentUser?.greetingName ?? "Atleta")!")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(dashboardHealthSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            PulsingHeartIconView(
                size: DeviceLayout.isPad ? 52 : 44,
                glowColor: healthStatus.glowColor
            )
            .accessibilityLabel(healthStatus.title)
            .accessibilityValue(wellnessService.healthIconDetailMessage())
        }
    }

    private var dashboardHealthSubtitle: String {
        switch healthStatus {
        case .green:
            return "Pronto para treinar hoje?"
        case .yellow:
            return "Atualize água e sono para manter o ícone verde."
        case .red:
            return "Ícone vermelho — registre água e sono no Perfil."
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricBadge(
                icon: "figure.walk",
                value: "\(dashboardSteps)",
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
                value: String(format: "%.0f", dashboardHeartRate),
                label: "BPM",
                color: .red
            )
        }
    }

    private var dashboardSteps: Int {
        max(healthKitManager.todaySteps, watchConnectivity.watchSteps)
    }

    private var dashboardHeartRate: Double {
        if watchConnectivity.watchHeartRate > 0 {
            return watchConnectivity.watchHeartRate
        }
        return healthKitManager.displayedHeartRate
    }

    private var watchSection: some View {
        Button {
            Task { await syncAppleWatch() }
        } label: {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(watchConnectivity.isWatchConnected ? AppTheme.accent : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(watchStatusSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if isSyncingWatch {
                    ProgressView()
                } else {
                    Circle()
                        .fill(watchConnectivity.isWatchConnected ? AppTheme.accent : .gray)
                        .frame(width: 10, height: 10)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .disabled(isSyncingWatch)
        .accessibilityHint("Toca para sincronizar com o Apple Watch")
    }

    private var watchStatusSubtitle: String {
        if isSyncingWatch {
            return "Buscando sincronismo..."
        }
        if watchConnectivity.isWatchConnected {
            return "Conectado · Toque para sincronizar"
        }
        return "Desconectado · Toque para tentar sincronizar"
    }

    private func syncAppleWatch() async {
        guard !isSyncingWatch else { return }
        isSyncingWatch = true
        let result = await watchConnectivity.attemptSyncWithWatch()
        await healthKitManager.refreshFromHealthKit()
        isSyncingWatch = false
        watchSyncResult = result
        showWatchSyncAlert = true
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
