import SwiftUI
import WatchConnectivity
import UserNotifications
import WatchKit
import HealthKit

@main
struct HealthFitWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var workoutManager = WatchWorkoutManager.shared

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

/// Recebe o launch do iPhone via `HKHealthStore.startWatchApp` e abre a UI de treino.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            WatchWorkoutManager.shared.handleHealthKitLaunch(configuration: workoutConfiguration)
        }
    }

    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            WatchWorkoutManager.shared.handleActiveWorkoutRecovery()
        }
    }
}
