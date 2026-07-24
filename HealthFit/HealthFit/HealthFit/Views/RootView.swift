import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var exerciseVideoRepository: ExerciseVideoRepository
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
                        wellnessService.configure(for: authService.currentUser)
                        syncWellnessCloudHistory()
                        await healthKitManager.requestAuthorization()
                        mealPlanService.loadSavedData()
                        if mealPlanService.weeklyPlan.isEmpty, let user = authService.currentUser {
                            mealPlanService.generatePlan(for: user)
                        }
                        syncWorkoutCloudHistory()
                        await exerciseVideoRepository.bootstrapRemoteCatalog()
                        NotificationService.shared.refreshRecurringNotifications()
                        refreshInactivityReminder()
                    }
                    .sheet(isPresented: $wellnessService.showSleepCheckIn) {
                        DailyWellnessCheckInView()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isRestoringSession)
        .animation(.easeInOut(duration: 0.25), value: showWelcomeMotivation)
        .animation(.easeInOut(duration: 0.25), value: didCompleteWelcomeForSession)
        .onAppear {
            prepareWelcomeIfAuthenticated(trigger: .coldStart)
            AppIconInactivityService.shared.handleAppBecameActive()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if authService.isAuthenticated {
                    prepareWelcomeIfAuthenticated(trigger: .returnFromBackground)
                    wellnessService.configure(for: authService.currentUser)
                    syncWellnessCloudHistory()
                    wellnessService.checkInOnAppOpen()
                    NotificationService.shared.refreshRecurringNotifications()
                    refreshInactivityReminder()
                    Task { await exerciseVideoRepository.bootstrapRemoteCatalog() }
                }
                AppIconInactivityService.shared.handleAppBecameActive()
            case .background:
                AppIconInactivityService.shared.handleAppEnteredBackground()
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
                syncWellnessCloudHistory()
                syncWorkoutCloudHistory()
                Task { await exerciseVideoRepository.bootstrapRemoteCatalog() }
            } else {
                didCompleteWelcomeForSession = false
                showWelcomeMotivation = false
                welcomeContext = nil
                workoutStore.configureCloudSync(userId: nil)
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

    private func syncWorkoutCloudHistory() {
        guard let userId = authService.currentUser?.id else {
            workoutStore.configureCloudSync(userId: nil)
            return
        }

        workoutStore.configureCloudSync(userId: userId)
        Task {
            await workoutStore.loadCloudHistory(userId: userId)
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
        NotificationService.shared.refreshWorkoutInactivityReminder(
            lastWorkoutAt: workoutStore.lastCompletedWorkoutAt,
            accountCreatedAt: authService.currentUser?.createdAt
        )
    }
}
