import SwiftUI

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
                        showWelcomeMotivation = false
                        didCompleteWelcomeForSession = true
                    }
                } else {
                    loadingScreen(message: nil)
                        .onAppear {
                            presentWelcome()
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
                    }
            }
        }
        // No implicit .animation on auth/welcome flags — they animate layout of heavy MainTab
        // and make the first tab switch feel frozen on device.
        .onAppear {
            prepareWelcomeIfAuthenticated(trigger: .coldStart)
            // Icon sync is cheap but not needed before first paint.
            Task { @MainActor in
                await Task.yield()
                AppIconInactivityService.shared.handleAppBecameActive()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Clear any residual keyboard avoidance that can leave bottom chrome mid-screen.
                KeyboardDismiss.hide()
                if authService.isAuthenticated {
                    prepareWelcomeIfAuthenticated(trigger: .returnFromBackground)
                    Task { await runForegroundRefreshPipeline() }
                } else {
                    WorkoutLiveActivitySync.end()
                }
            case .inactive, .background:
                KeyboardDismiss.hide()
                if phase == .background {
                    workoutStore.handleAppEnteredBackground()
                    timerService.handleAppEnteredBackground()
                    authService.flushProfileToCloudIfNeeded()
                    AppIconInactivityService.shared.handleAppEnteredBackground()
                }
            default:
                break
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
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
                didCompleteWelcomeForSession = false
                showWelcomeMotivation = false
                welcomeContext = nil
                workoutStore.configureCloudSync(userId: nil)
                wellnessService.configureCloudSync(userId: nil)
                mealPlanService.bind(userId: nil)
                MealPhotoAnalysisService.shared.bind(userId: nil)
                ClimbingGearService.shared.bind(userId: nil)
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
        mealPlanService.loadSavedData()
        if mealPlanService.weeklyPlan.isEmpty, let user = authService.currentUser {
            mealPlanService.generatePlan(for: user)
        }
        if let userId = authService.currentUser?.id {
            await MealPhotoAnalysisService.shared.loadIfNeeded(userId: userId)
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
        NotificationService.shared.refreshRecurringNotifications()
        // Espelha treinos de hoje no Calendário (uma vez por sessão; pede permissão se necessário).
        WorkoutCalendarService.syncTodaysCompletedSessions(workoutStore.sessionHistory)
        ExternalWorkoutSyncService.shared.bind(
            workoutStore: workoutStore,
            athleteName: authService.currentUser?.greetingName
        )
        await ExternalWorkoutSyncService.shared.syncRecentExternalWorkouts(reason: .startup)

        try? await Task.sleep(nanoseconds: 700_000_000)

        // Phase 5 — exercise video/GIF Firebase catalog last
        await exerciseVideoRepository.bootstrapRemoteCatalog()
    }

    /// Foreground return: stagger the same heavy work that used to run synchronously in onChange.
    private func runForegroundRefreshPipeline() async {
        wellnessService.configure(for: authService.currentUser)
        wellnessService.checkInOnAppOpen()
        _ = workoutStore.autoEndStaleActiveSessionIfNeeded(
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )
        workoutStore.handleAppBecameActive()
        timerService.handleAppBecameActive()
        WorkoutLiveActivitySync.reconcile(
            workoutStore: workoutStore,
            timerService: timerService
        )
        if let session = workoutStore.activeSession {
            NotificationService.shared.cancelActiveWorkoutBackgroundReminder(sessionId: session.id)
        }
        AppIconInactivityService.shared.handleAppBecameActive()

        await Task.yield()

        mealPlanService.bind(userId: authService.currentUser?.id)
        ClimbingGearService.shared.bind(userId: authService.currentUser?.id)
        mealPlanService.loadSavedData()
        refreshInactivityReminder()
        EveningTrainingNudgeService.refresh(workoutStore: workoutStore)
        syncWellnessCloudHistory()

        try? await Task.sleep(nanoseconds: 250_000_000)
        NotificationService.shared.refreshRecurringNotifications()

        try? await Task.sleep(nanoseconds: 400_000_000)
        await exerciseVideoRepository.bootstrapRemoteCatalog()
        await healthKitManager.refreshFromHealthKit()
        ExternalWorkoutSyncService.shared.bind(
            workoutStore: workoutStore,
            athleteName: authService.currentUser?.greetingName
        )
        await ExternalWorkoutSyncService.shared.syncRecentExternalWorkouts(reason: .foreground)
    }

    private func syncWorkoutCloudHistory() {
        guard let userId = authService.currentUser?.id else {
            workoutStore.configureCloudSync(userId: nil)
            return
        }

        workoutStore.configureCloudSync(userId: userId)
        Task {
            await workoutStore.loadCloudHistory(userId: userId)
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
        case .login, .coldStart:
            didCompleteWelcomeForSession = false
            presentWelcome()
        case .returnFromBackground:
            if let hours = AppIconInactivityService.shared.hoursSinceLastSessionEnd(), hours >= 24 {
                didCompleteWelcomeForSession = false
                presentWelcome()
            }
        }
    }

    private func presentWelcome() {
        guard !showWelcomeMotivation else { return }

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
        didCompleteWelcomeForSession = false
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
