import SwiftUI
import Charts
import Photos
import UIKit

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var weeklyReportService: WeeklyReportService
    @EnvironmentObject var monthlyReportService: MonthlyReportService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var shareCardStore: WorkoutShareCardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showWeeklyReport = false
    @State private var showMonthlyReport = false
    @State private var isSyncingWatch = false
    @State private var watchSyncResult: WatchSyncResult?
    @State private var showWatchSyncAlert = false
    @State private var isShareCardExpanded = false
    @State private var showFullscreenShareCard = false
    @State private var suppressShareCardTapAfterLongPress = false
    @State private var isSavingShareCard = false
    @State private var shareCardSaveAlertTitle = ""
    @State private var shareCardSaveAlertMessage = ""
    @State private var showShareCardSaveAlert = false

    /// Live `WorkoutShareCardView` is fixed ~360×464–568; this scale fits dashboard width when expanded.
    private let shareCardExpandedScale: CGFloat = 0.72
    private var shareCardPreviewHeight: CGFloat {
        WorkoutShareCardView.maxPreviewCardHeight * shareCardExpandedScale
    }

    private var healthStatus: WellnessHealthIconStatus {
        wellnessService.healthIconStatus()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    weeklyReportBanner
                    monthlyReportBanner
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
            .sheet(isPresented: $showMonthlyReport) {
                MonthlyReportView()
            }
            .alert(
                watchSyncResult?.title ?? "Apple Watch",
                isPresented: $showWatchSyncAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(watchSyncResult?.message ?? "")
            }
            .fullScreenCover(isPresented: $showFullscreenShareCard) {
                shareCardFullscreenCover
                    .alert(shareCardSaveAlertTitle, isPresented: $showShareCardSaveAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(shareCardSaveAlertMessage)
                    }
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

    private var monthlyReportBanner: some View {
        Button {
            showMonthlyReport = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSecondary.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Relatório Mensal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if monthlyReportService.isReportAvailable {
                            Text("NOVO")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                        }
                    }

                    if monthlyReportService.isReportAvailable {
                        Text("Sono, suplementos, medidas e plano de refeições")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if monthlyReportService.daysUntilNextReport > 0 {
                        Text("Próximo relatório em \(monthlyReportService.daysUntilNextReport) dia(s)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text("Histórico de 30 dias com gráficos de sono e suplementos")
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
        Group {
            if let card = shareCardStore.lastCard {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if suppressShareCardTapAfterLongPress {
                            suppressShareCardTapAfterLongPress = false
                            return
                        }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                            isShareCardExpanded.toggle()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: isShareCardExpanded ? 16 : 0) {
                            // Same rectangular language as `weeklyReportBanner` when collapsed.
                            HStack(spacing: 14) {
                                let modalityIcon = WorkoutShareCardView.modalitySystemImage(for: card.makeSession())
                                ZStack {
                                    // Foto do atleta (mantém) + badge com ícone da modalidade.
                                    if let profileImage = authService.profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 48, height: 48)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(AppTheme.accent.opacity(0.85), lineWidth: 1.5)
                                            )

                                        Image(systemName: modalityIcon)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(AppTheme.accent)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(AppTheme.cardBackground))
                                            .overlay(Circle().strokeBorder(AppTheme.accent.opacity(0.5), lineWidth: 1))
                                            .offset(x: 16, y: 16)
                                    } else {
                                        Circle()
                                            .fill(AppTheme.accent.opacity(0.2))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: modalityIcon)
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Último card de postagem")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)

                                    Text("\(card.workoutTitle) · \(formattedShareCardDate(card.displayDate))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: isShareCardExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            if isShareCardExpanded {
                                shareCardPreview(for: card)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                    .buttonStyle(.plain)
                    // simultaneousGesture keeps short-tap snappy; onLongPressGesture alone would delay taps by 1s.
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1)
                            .onEnded { _ in
                                suppressShareCardTapAfterLongPress = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showFullscreenShareCard = true
                            }
                    )
                    .accessibilityLabel("Card de postagem de \(card.workoutTitle)")
                    .accessibilityHint(
                        isShareCardExpanded
                            ? "Toque para recolher o card. Mantenha pressionado por 1 segundo para tela cheia e salvar em Fotos."
                            : "Toque para expandir o card. Mantenha pressionado por 1 segundo para tela cheia e salvar em Fotos."
                    )
                    .accessibilityAction(named: "Abrir em tela cheia") {
                        showFullscreenShareCard = true
                    }
                    .onChange(of: card.sessionId) { _, _ in
                        isShareCardExpanded = false
                        showFullscreenShareCard = false
                    }

                    Text("Pressione firmemente por 1s para salvar o card em Fotos")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Último card de postagem")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Nenhum card gerado ainda. Finalize um treino para criar o card de postagem.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
    }

    private var shareCardFullscreenCover: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    showFullscreenShareCard = false
                }

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Fechar") {
                        showFullscreenShareCard = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 0)

                Group {
                    if let image = shareCardStore.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                            .padding(.horizontal, 24)
                            .onTapGesture {
                                showFullscreenShareCard = false
                            }
                    } else if let card = shareCardStore.lastCard {
                        WorkoutShareCardView(
                            session: card.makeSession(),
                            athleteName: card.athleteName,
                            motivationLine: card.motivationLine,
                            profileImage: authService.profileImage
                        )
                        .scaleEffect(shareCardExpandedScale)
                        .frame(height: shareCardPreviewHeight)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 24)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await saveShareCardToPhotos() }
                } label: {
                    HStack(spacing: 10) {
                        if isSavingShareCard {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("Salvar em Fotos")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isSavingShareCard || (shareCardStore.previewImage == nil && shareCardStore.lastCard == nil))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .accessibilityLabel("Card de postagem em tela cheia")
        .task {
            await ensureShareCardPreviewImage()
        }
    }

    @ViewBuilder
    private func shareCardPreview(for card: LastWorkoutShareCard) -> some View {
        if let preview = shareCardStore.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        } else {
            WorkoutShareCardView(
                session: card.makeSession(),
                athleteName: card.athleteName,
                motivationLine: card.motivationLine,
                profileImage: authService.profileImage
            )
            .scaleEffect(shareCardExpandedScale)
            .frame(height: shareCardPreviewHeight)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
    }

    @MainActor
    private func ensureShareCardPreviewImage() async {
        guard shareCardStore.previewImage == nil,
              let card = shareCardStore.lastCard else { return }
        if let image = WorkoutShareCardRenderer.renderImage(
            session: card.makeSession(),
            athleteName: card.athleteName,
            motivationLine: card.motivationLine,
            profileImage: authService.profileImage
        ) {
            shareCardStore.updatePreviewImage(image)
        }
    }

    @MainActor
    private func saveShareCardToPhotos() async {
        await ensureShareCardPreviewImage()
        guard let image = shareCardStore.previewImage else {
            presentShareCardSaveAlert(
                title: "Não foi possível salvar",
                message: "A imagem do card não está disponível."
            )
            return
        }

        isSavingShareCard = true
        defer { isSavingShareCard = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            presentShareCardSaveAlert(
                title: "Permissão necessária",
                message: "Permissão negada para salvar em Fotos. Ative em Ajustes → HealthFit → Fotos."
            )
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            presentShareCardSaveAlert(
                title: "Salvo em Fotos",
                message: "O card de postagem foi salvo na sua galeria."
            )
        } catch {
            presentShareCardSaveAlert(
                title: "Não foi possível salvar",
                message: error.localizedDescription
            )
        }
    }

    private func presentShareCardSaveAlert(title: String, message: String) {
        shareCardSaveAlertTitle = title
        shareCardSaveAlertMessage = message
        showShareCardSaveAlert = true
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
                Text(MotivationMessages.namedGreeting(name: authService.currentUser?.greetingName ?? "Atleta"))
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
        let restWindow = MotivationMessages.isRestWindow()
        switch healthStatus {
        case .green:
            return restWindow
                ? "Hora de desacelerar e preparar um bom descanso."
                : "Pronto para treinar hoje?"
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
