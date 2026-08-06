import SwiftUI
import UserNotifications

@main
struct HealthFitApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var mealPlanService = MealPlanService()
    @StateObject private var timerService = RestTimerService()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var weeklyReportService = WeeklyReportService.shared
    @StateObject private var monthlyReportService = MonthlyReportService.shared
    @StateObject private var wellnessService = DailyWellnessService.shared
    @StateObject private var shareCardStore = WorkoutShareCardStore.shared
    @StateObject private var exerciseVideoRepository = ExerciseVideoRepository.shared
    @ObservedObject private var languageStore = AppLanguageStore.shared

    init() {
        // BGTask registration must stay early; notifications / Watch activate after first frame.
        AppIconInactivityService.shared.registerBackgroundTasks()
        // Garante persistência do padrão pt-BR antes da primeira renderização.
        _ = AppLanguageStore.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(healthKitManager)
                .environmentObject(workoutStore)
                .environmentObject(mealPlanService)
                .environmentObject(timerService)
                .environmentObject(watchConnectivity)
                .environmentObject(weeklyReportService)
                .environmentObject(monthlyReportService)
                .environmentObject(wellnessService)
                .environmentObject(shareCardStore)
                .environmentObject(exerciseVideoRepository)
                .environmentObject(TrainingNutritionSyncService.shared)
                .environmentObject(BodyEvolutionService.shared)
                .environmentObject(languageStore)
                .environmentObject(SubscriptionService.shared)
                .environment(\.locale, languageStore.locale)
                // Avoid `.id(language)` — full view remount freezes tab navigation on language bind.
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    _ = SocialSignInService.handleIncomingURL(url)
                }
                .onAppear {
                    watchConnectivity.bind(workoutStore: workoutStore)
                }
                .task(priority: .utility) {
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    NotificationService.shared.requestAuthorization()
                    watchConnectivity.ensureSessionActivated()
                    watchConnectivity.bind(workoutStore: workoutStore)
                    // StoreKit products only after first UI frames — not during install/login paint.
                    await SubscriptionService.shared.refreshIfNeeded()
                }
        }
    }
}
