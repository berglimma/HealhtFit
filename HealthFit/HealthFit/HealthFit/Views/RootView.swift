import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mealPlanService: MealPlanService

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
                    }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}
