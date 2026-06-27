import SwiftUI
import WatchConnectivity
import UserNotifications

@main
struct HealthFitWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(workoutManager)
        }
    }
}
