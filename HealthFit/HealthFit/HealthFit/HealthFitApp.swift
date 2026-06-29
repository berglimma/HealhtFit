import SwiftUI
import UserNotifications

@main
struct HealthFitApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var mealPlanService = MealPlanService()
    @StateObject private var timerService = RestTimerService()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var weeklyReportService = WeeklyReportService.shared

    init() {
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
                .preferredColorScheme(.dark)
        }
    }
}
