import SwiftUI

/// Sobrevive a remount do `RootView` (comum no iPad após background / Stage Manager).
/// Sem isso, `@State didCompleteWelcomeForSession` volta a `false` e a UI trava em "Carregando…".
private enum WelcomeSessionGate {
    static var didCompleteWelcomeThisLaunch = false
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var exerciseVideoRepository: ExerciseVideoRepository
    @EnvironmentObject var timerService: RestTimerService
    @Environment(\.scenePhase) private var scenePhase

    @State private var showWelcomeMotivation = false
    @State private var welcomeContext: WelcomeMotivationContext?
    /// Evita flash do painel: só libera o MainTab depois que a transição for concluída (ou dispensada).
    @State private var didCompleteWelcomeForSession = false
    /// Só roda o pipeline pesado após `.background` real (evita lentidão no iPad/Stage Manager em `.inactive`→`.active`).
    @State private var didEnterBackground = false
    @State private var lastForegroundPipelineAt: Date?
    @State private var foregroundPipelineTask: Task<Void, Never>?
    private let foregroundPipelineMinInterval: TimeInterval = 120
    /// Trabalho muito pesado (HealthKit / catálogo / sync externo) no máximo a cada 5 min.
    private let heavyForegroundMinInterval: TimeInterval = 300
    @State private var lastHeavyForegroundAt: Date?

    var body: some View {
        Group {
            if authService.isRestoringSession {
                loadingScreen(message: "Carregando...")
            } else if !authService.isAuthenticated {
                LoginView()
            } else if !didCompleteWelcomeForSession {
                // Após login/sessão, a transição tem prioridade — nunca renderiza o painel antes.
                if showWelcomeMotivation, let welcomeContext {
                    WelcomeMotivationView(context: welcomeContext) {
                        completeWelcomeAndShowMainTab()
                    }
                } else {
                    loadingScreen(message: nil)
                        .onAppear {
                            presentWelcome(preserveMainTab: false)
                            // Failsafe: se o Task do welcome travar (iPad remount), libera o MainTab.
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                guard authService.isAuthenticated else { return }
                                guard !didCompleteWelcomeForSession else { return }
                                completeWelcomeAndShowMainTab()
                            }
                        }
                }
            } else {
                MainTabView()
                    .task {
                        await runPostLoginStartupPipeline()
                    }
                    .sheet(isPresented: $wellnessService.showSleepCheckIn) {
                        DailyWellnessCheckInView()
                            .environmentObject(authService)
                            .environmentObject(wellnessService)
                            .environmentObject(healthKitManager)
                    }
                    // Welcome após 24h em overlay — não desmonta o MainTab (evita cold start no iPad).
                    .fullScreenCover(isPresented: $showWelcomeMotivation) {
                        if let welcomeContext {
                            WelcomeMotivationView(context: welcomeContext) {
                                showWelcomeMotivation = false
                            }
                        } else {
                            // Evita fullScreenCover vazio (não dismissível) se o contexto falhar.
                            Color.clear
                                .onAppear { showWelcomeMotivation = false }
                        }
                    }
            }
        }
        // No implicit .animation on auth/welcome flags — they animate layout of heavy MainTab
        // and make the first tab switch feel frozen on device.
        .onAppear {
            // Remount após background (iPad): restaura o gate — NÃO reinicia cold start.
            if WelcomeSessionGate.didCompleteWelcomeThisLaunch {
                didCompleteWelcomeForSession = true
                showWelcomeMotivation = false
            } else {
                prepareWelcomeIfAuthenticated(trigger: .coldStart)
            }
            // Icon sync is cheap but not needed before first paint.
            Task { @MainActor in
                await Task.yield()
                AppIconInactivityService.shared.handleAppBecameActive()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Não chamar KeyboardDismiss aqui — ao voltar de inactive (ficha/sheet/teclado)
                // o endEditing global cancela a digitação em TextFields.
                if authService.isAuthenticated {
                    // iPad remount: @State zera, mas o processo ainda está vivo — restaura o MainTab.
                    if WelcomeSessionGate.didCompleteWelcomeThisLaunch {
                        didCompleteWelcomeForSession = true
                        showWelcomeMotivation = false
                    }
                    let returningFromBackground = didEnterBackground
                    didEnterBackground = false
                    if returningFromBackground {
                        // Só após background real: catch-up + pipeline (evita lag no Control Center / Stage Manager).
                        runLightweightForegroundCatchUp()
                        prepareWelcomeIfAuthenticated(trigger: .returnFromBackground)
                        scheduleForegroundRefreshPipeline()
                    } else if workoutStore.activeSession != nil || timerService.isRunning {
                        // Multitarefa breve: só relógio, sem JSON/cloud/HealthKit.
                        runActiveSessionClockCatchUpOnly()
                    }
                } else {
                    WorkoutLiveActivitySync.end()
                }
            case .background:
                didEnterBackground = true
                KeyboardDismiss.hide()
                workoutStore.handleAppEnteredBackground()
                timerService.handleAppEnteredBackground()
                DuoTeamService.shared.handleAppEnteredBackground()
                BluetoothHeartRateService.shared.stopScanning()
                authService.flushProfileToCloudIfNeeded()
                AppIconInactivityService.shared.handleAppEnteredBackground()
            case .inactive:
                break
            default:
                break
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                WelcomeSessionGate.didCompleteWelcomeThisLaunch = false
                didCompleteWelcomeForSession = false
                showWelcomeMotivation = false
                welcomeContext = nil
                prepareWelcomeIfAuthenticated(trigger: .login)
                wellnessService.configure(for: authService.currentUser)
                // Cloud + GIF catalog after UI settles (MainTab `.task` also covers post-welcome).
                Task {
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    syncWellnessCloudHistory()
                    syncWorkoutCloudHistory()
                }
            } else {
                WelcomeSessionGate.didCompleteWelcomeThisLaunch = false
                didCompleteWelcomeForSession = false
                showWelcomeMotivation = false
                welcomeContext = nil
                workoutStore.configureCloudSync(userId: nil)
                wellnessService.configureCloudSync(userId: nil)
                mealPlanService.bind(userId: nil)
                MealPhotoAnalysisService.shared.bind(userId: nil)
                ClimbingGearService.shared.bind(userId: nil)
                DuoTeamService.shared.bind(userId: nil, userName: nil)
                CoachService.shared.stop()
                WorkoutLiveActivitySync.end()
                EveningTrainingNudgeService.cancelAll()
            }
        }
    }

    @ViewBuilder
    private func loadingScreen(message: String?) -> some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if let message {
                ProgressView(message)
                    .tint(AppTheme.accent)
            } else {
                ProgressView()
                    .tint(AppTheme.accent)
            }
        }
    }

    /// Phased startup: keep first tab interactive, then local data, then cloud / GIF / notifications.
    private func runPostLoginStartupPipeline() async {
        // Phase 1 — local UI state only (MainTab can paint)
        wellnessService.configure(for: authService.currentUser)
        if let user = authService.currentUser {
            AssistantBirthdayCongratsEngine.queueIfNeeded(
                athleteName: user.greetingName,
                dateOfBirth: user.dateOfBirth
            )
        }
        _ = workoutStore.autoEndStaleActiveSessionIfNeeded(
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )
        WorkoutLiveActivitySync.reconcile(
            workoutStore: workoutStore,
            timerService: timerService
        )

        await Task.yield()
        try? await Task.sleep(nanoseconds: 450_000_000)

        // Phase 2 — meal plan + light reminders (decode can hitch main; after first interaction window)
        mealPlanService.bind(userId: authService.currentUser?.id)
        MealPhotoAnalysisService.shared.bind(userId: authService.currentUser?.id)
        ClimbingGearService.shared.bind(userId: authService.currentUser?.id)
        DuoTeamService.shared.bind(
            userId: authService.currentUser?.id,
            userName: authService.currentUser?.greetingName,
            countryCode: authService.currentUser?.countryCode
        )
        CoachService.shared.bind(
            authService: authService,
            workoutStore: workoutStore,
            mealPlanService: mealPlanService
        )
        mealPlanService.loadSavedData()
        if let userId = authService.currentUser?.id {
            Task { await MealPhotoAnalysisService.shared.loadIfNeeded(userId: userId) }
            Task {
                await authService.syncProfileFromCloudIfNeeded()
                await authService.syncProfilePhotoFromCloud(userId: userId)
            }
            Task { await DuoTeamService.shared.loadIfNeeded() }
            CoachService.shared.start()
            Task { await CoachService.shared.refreshLinkStatusesForPlan() }
        }
        refreshInactivityReminder()
        EveningTrainingNudgeService.refresh(workoutStore: workoutStore)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Phase 3 — cloud history (does not block UI)
        syncWellnessCloudHistory()
        syncWorkoutCloudHistory()

        try? await Task.sleep(nanoseconds: 400_000_000)

        // Phase 4 — HealthKit + notifications (after tabs are interactive)
        await healthKitManager.requestAuthorization()
        NotificationService.shared.refreshRecurringNotifications(force: true)
        // Espelha treinos de hoje no Calendário só se a permissão já existir (não pede no launch).
        WorkoutCalendarService.syncTodaysCompletedSessions(workoutStore.sessionHistory)
        ExternalWorkoutSyncService.shared.bind(
            workoutStore: workoutStore,
            athleteName: authService.currentUser?.greetingName
        )
        Task { await ExternalWorkoutSyncService.shared.syncRecentExternalWorkouts(reason: .startup) }
        bindAppleSleepSync()
        Task { await wellnessService.syncSleepFromAppleHealth() }

        try? await Task.sleep(nanoseconds: 700_000_000)

        // Phase 5 — exercise video/GIF Firebase catalog last
        Task { await exerciseVideoRepository.bootstrapRemoteCatalog() }
    }

    /// Só o essencial para o relógio do treino/timer não “pular” ao voltar do background.
    private func runLightweightForegroundCatchUp() {
        workoutStore.handleAppBecameActive()
        _ = workoutStore.autoEndStaleActiveSessionIfNeeded(
            athleteName: authService.currentUser?.greetingName ?? "Atleta",
            restoreIfNeeded: false
        )
        timerService.handleAppBecameActive()
        WorkoutLiveActivitySync.reconcile(
            workoutStore: workoutStore,
            timerService: timerService
        )
        if let session = workoutStore.activeSession {
            NotificationService.shared.cancelActiveWorkoutBackgroundReminder(sessionId: session.id)
        }
    }

    /// Multitarefa (Control Center / ficheiro): atualiza só o wall-clock, sem persistência.
    private func runActiveSessionClockCatchUpOnly() {
        workoutStore.catchUpActiveSessionClockFromForeground()
        timerService.handleAppBecameActive()
        WorkoutLiveActivitySync.reconcile(
            workoutStore: workoutStore,
            timerService: timerService
        )
    }

    private func scheduleForegroundRefreshPipeline() {
        if let last = lastForegroundPipelineAt,
           Date().timeIntervalSince(last) < foregroundPipelineMinInterval {
            return
        }
        foregroundPipelineTask?.cancel()
        // Não forçar MainActor no Task inteiro — trabalho de rede/HK fica em Tasks filhas.
        foregroundPipelineTask = Task {
            await runForegroundRefreshPipeline()
        }
    }

    /// Retorno de background real: sync em fases longas — UI volta a responder antes do trabalho pesado.
    @MainActor
    private func runForegroundRefreshPipeline() async {
        lastForegroundPipelineAt = Date()

        wellnessService.configure(for: authService.currentUser)
        wellnessService.checkInOnAppOpen()
        if let user = authService.currentUser {
            AssistantBirthdayCongratsEngine.queueIfNeeded(
                athleteName: user.greetingName,
                dateOfBirth: user.dateOfBirth
            )
        }
        // Ícone: barato, mas depois do 1º frame.
        Task { @MainActor in
            await Task.yield()
            AppIconInactivityService.shared.handleAppBecameActive()
        }

        #if targetEnvironment(simulator)
        // Simulador: resume só com catch-up leve (já feito) — sem Duo/HK/notificações/cloud.
        await Task.yield()
        #else
        let outdoorCardioRunning =
            workoutStore.activeSession != nil
            && (workoutStore.resolvedActiveCardioConfig()?.isOutdoorGPSCardio == true)

        // Deixa a UI pintar antes de qualquer rebind/cloud.
        if outdoorCardioRunning {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        } else {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        guard !Task.isCancelled else { return }

        mealPlanService.bind(userId: authService.currentUser?.id)
        ClimbingGearService.shared.bind(userId: authService.currentUser?.id)
        // Duo/reminders — ainda depois; não competem com o 1º segundo de interação.
        try? await Task.sleep(nanoseconds: outdoorCardioRunning ? 1_200_000_000 : 800_000_000)
        guard !Task.isCancelled else { return }

        DuoTeamService.shared.handleAppBecameActive()
        EveningTrainingNudgeService.refresh(workoutStore: workoutStore)

        try? await Task.sleep(nanoseconds: outdoorCardioRunning ? 1_000_000_000 : 700_000_000)
        guard !Task.isCancelled else { return }
        NotificationService.shared.refreshRecurringNotifications()
        refreshInactivityReminder()

        let shouldRunHeavy: Bool = {
            guard let last = lastHeavyForegroundAt else { return true }
            return Date().timeIntervalSince(last) >= heavyForegroundMinInterval
        }()
        guard shouldRunHeavy else { return }

        try? await Task.sleep(nanoseconds: outdoorCardioRunning ? 2_000_000_000 : 1_500_000_000)
        guard !Task.isCancelled else { return }
        lastHeavyForegroundAt = Date()

        if authService.currentUser?.id != nil {
            Task {
                await authService.syncProfileFromCloudIfNeeded()
            }
            // loadIfNeeded Duo só se ainda não carregou — evita prefetch duplo com handleAppBecameActive.
            Task { await CoachService.shared.refreshLinkStatusesForPlan() }
        }

        Task { await healthKitManager.refreshFromHealthKit() }
        ExternalWorkoutSyncService.shared.bind(
            workoutStore: workoutStore,
            athleteName: authService.currentUser?.greetingName
        )
        Task { await ExternalWorkoutSyncService.shared.syncRecentExternalWorkouts(reason: .foreground) }
        bindAppleSleepSync()
        Task { await wellnessService.syncSleepFromAppleHealth() }
        #endif
    }

    private func bindAppleSleepSync() {
        healthKitManager.onSleepAnalysisChanged = {
            Task { @MainActor in
                _ = await DailyWellnessService.shared.syncSleepFromAppleHealth()
            }
        }
    }

    private func syncWorkoutCloudHistory() {
        guard let userId = authService.currentUser?.id else {
            workoutStore.configureCloudSync(userId: nil)
            return
        }

        workoutStore.configureCloudSync(userId: userId)
        Task {
            await workoutStore.loadCloudHistory(userId: userId)
            await workoutStore.loadCloudSheets(userId: userId)
            await CrossDeviceSyncCoordinator.syncAll(
                userId: userId,
                workoutStore: workoutStore,
                timerService: timerService
            )
            await authService.syncProfileBackgroundFromCloud(userId: userId)
            await authService.syncProfilePhotoFromCloud(userId: userId)
            await authService.syncProfileFromCloudIfNeeded()
            EveningTrainingNudgeService.refresh(workoutStore: workoutStore)
        }
    }

    private func syncWellnessCloudHistory() {
        guard let userId = authService.currentUser?.id else {
            wellnessService.configureCloudSync(userId: nil)
            return
        }

        wellnessService.configureCloudSync(userId: userId)
        Task {
            await wellnessService.syncFromCloudIfNeeded()
        }
    }

    private enum WelcomeTrigger {
        case coldStart
        case login
        case returnFromBackground
    }

    private func prepareWelcomeIfAuthenticated(trigger: WelcomeTrigger) {
        guard authService.isAuthenticated else { return }

        switch trigger {
        case .login:
            WelcomeSessionGate.didCompleteWelcomeThisLaunch = false
            didCompleteWelcomeForSession = false
            presentWelcome(preserveMainTab: false)
        case .coldStart:
            // Remount do RootView no iPad NÃO deve reiniciar o welcome.
            if WelcomeSessionGate.didCompleteWelcomeThisLaunch {
                didCompleteWelcomeForSession = true
                showWelcomeMotivation = false
                return
            }
            didCompleteWelcomeForSession = false
            presentWelcome(preserveMainTab: false)
        case .returnFromBackground:
            if let hours = AppIconInactivityService.shared.hoursSinceLastSessionEnd(), hours >= 24 {
                // Mantém MainTab montado; só mostra overlay.
                presentWelcome(preserveMainTab: true)
            }
        }
    }

    private func completeWelcomeAndShowMainTab() {
        WelcomeSessionGate.didCompleteWelcomeThisLaunch = true
        showWelcomeMotivation = false
        didCompleteWelcomeForSession = true
    }

    private func presentWelcome(preserveMainTab: Bool) {
        guard !showWelcomeMotivation else { return }

        // Relatório/contexto — não bloqueia o handler de scenePhase.
        Task { @MainActor in
            await Task.yield()
            guard !showWelcomeMotivation else { return }
            // Se o failsafe / remount já liberou o MainTab, não força welcome de novo.
            if preserveMainTab == false, WelcomeSessionGate.didCompleteWelcomeThisLaunch {
                didCompleteWelcomeForSession = true
                return
            }

            let user = authService.currentUser
            let weeklyReport = WeeklyProgressAnalyzer.buildReport(
                sessions: workoutStore.sessionHistory,
                goal: user?.goal ?? .maintenance
            )
            let hoursSinceLastWorkout = workoutStore.lastCompletedWorkoutAt.map {
                Date().timeIntervalSince($0) / 3600
            }

            welcomeContext = WelcomeMotivationEngine.makeContext(
                athleteName: user?.greetingName ?? "Atleta",
                hoursSinceLastOpen: AppIconInactivityService.shared.hoursSinceLastSessionEnd(),
                hoursSinceLastWorkout: hoursSinceLastWorkout,
                weeklyWorkoutCount: weeklyReport.currentWeek.workoutCount
            )
            showWelcomeMotivation = true
            if !preserveMainTab {
                didCompleteWelcomeForSession = false
            }
        }
    }

    private func refreshInactivityReminder() {
        let accountCreatedAt = authService.currentUser?.createdAt
        NotificationService.shared.refreshWorkoutInactivityReminder(
            lastWorkoutAt: workoutStore.lastCompletedWorkoutAt,
            accountCreatedAt: accountCreatedAt
        )
        NotificationService.shared.refreshCardioInactivityReminder(
            lastCardioAt: workoutStore.lastCompletedCardioAt,
            accountCreatedAt: accountCreatedAt
        )
        NotificationService.shared.refreshMeditationInactivityReminder(
            lastMeditationAt: workoutStore.lastCompletedMeditationAt,
            accountCreatedAt: accountCreatedAt
        )
        wellnessService.refreshHealthIconNotifications()
    }
}
