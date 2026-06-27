import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mealPlanService: MealPlanService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .task {
                        await healthKitManager.requestAuthorization()
                        mealPlanService.loadSavedData()
                        if mealPlanService.weeklyPlan.isEmpty, let user = authService.currentUser {
                            mealPlanService.generatePlan(for: user)
                        }
                        NotificationService.shared.scheduleDailyMotivationNotifications()
                    }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, authService.isAuthenticated {
                NotificationService.shared.scheduleDailyMotivationNotifications()
            }
        }
    }
}
