import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .task {
                        wellnessService.configure(for: authService.currentUser)
                        await healthKitManager.requestAuthorization()
                        mealPlanService.loadSavedData()
                        if mealPlanService.weeklyPlan.isEmpty, let user = authService.currentUser {
                            mealPlanService.generatePlan(for: user)
                        }
                        NotificationService.shared.scheduleDailyMotivationNotifications()
                        refreshInactivityReminder()
                    }
                    .sheet(isPresented: $wellnessService.showSleepCheckIn) {
                        DailyWellnessCheckInView()
                    }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, authService.isAuthenticated {
                wellnessService.configure(for: authService.currentUser)
                wellnessService.checkInOnAppOpen()
                NotificationService.shared.scheduleDailyMotivationNotifications()
                refreshInactivityReminder()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                wellnessService.configure(for: authService.currentUser)
            }
        }
    }

    private func refreshInactivityReminder() {
        NotificationService.shared.refreshWorkoutInactivityReminder(
            lastWorkoutAt: workoutStore.lastCompletedWorkoutAt,
            accountCreatedAt: authService.currentUser?.createdAt
        )
    }
}
