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
    @StateObject private var wellnessService = DailyWellnessService.shared
    @StateObject private var shareCardStore = WorkoutShareCardStore.shared
    @StateObject private var exerciseVideoRepository = ExerciseVideoRepository.shared

    init() {
        AppIconInactivityService.shared.registerBackgroundTasks()
        NotificationService.shared.requestAuthorization()
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
                .environmentObject(wellnessService)
                .environmentObject(shareCardStore)
                .environmentObject(exerciseVideoRepository)
                .environmentObject(TrainingNutritionSyncService.shared)
                .environmentObject(BodyEvolutionService.shared)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    _ = SocialSignInService.handleIncomingURL(url)
                }
        }
    }
}
