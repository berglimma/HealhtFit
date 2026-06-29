import Foundation
import WatchConnectivity
import HealthKit
import Combine
import UserNotifications
import WatchKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var workoutName = ""
    @Published var isCardioWorkout = false
    @Published var workoutElapsedSeconds = 0
    @Published var exerciseElapsedSeconds = 0
    @Published var currentExerciseName = ""
    @Published var cardioTargetSeconds = 0
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var restRemainingSeconds = 0
    @Published var isResting = false
    @Published var isRestOvertime = false
    @Published var restExerciseName = ""
    @Published var restOvertimeSeconds = 0

    private var session: WCSession?
    private var heartRateTimer: Timer?
    private var workoutClockTimer: Timer?
    private var restTimer: Timer?
    private var configuredRestSeconds = 60
    private var restElapsedSeconds = 0
    private var secondsSincePhoneSync = 0
    private var hasSentRestOvertimeNotification = false
    private let healthStore = HKHealthStore()

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func startWorkout(name: String) {
        resetWorkoutState()
        workoutName = name
        isCardioWorkout = false
        isActive = true
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    func startCardio(name: String, targetSeconds: Int, exerciseName: String) {
        resetWorkoutState()
        workoutName = name
        isCardioWorkout = true
        cardioTargetSeconds = max(targetSeconds, 1)
        currentExerciseName = exerciseName
        isActive = true
        startHeartRateMonitoring()
        startWorkoutClock()
    }

    func stopWorkout() {
        isActive = false
        isCardioWorkout = false
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        workoutClockTimer?.invalidate()
        workoutClockTimer = nil
        stopRestCountdown()
        resetWorkoutState()
        sendMetricsToPhone()
    }

    private func resetWorkoutState() {
        workoutElapsedSeconds = 0
        exerciseElapsedSeconds = 0
        currentExerciseName = ""
        cardioTargetSeconds = 0
        calories = 0
        secondsSincePhoneSync = 0
    }

    private func startWorkoutClock() {
        workoutClockTimer?.invalidate()
        secondsSincePhoneSync = 0
        workoutClockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickWorkoutClock()
            }
        }
    }

    private func tickWorkoutClock() {
        guard isActive else { return }
        secondsSincePhoneSync += 1

        guard secondsSincePhoneSync > 2, !isResting else { return }
        workoutElapsedSeconds += 1
        if !isCardioWorkout {
            exerciseElapsedSeconds += 1
        }
    }

    private func applyPhoneSync(
        workoutElapsedSeconds: Int? = nil,
        exerciseElapsedSeconds: Int? = nil,
        exerciseName: String? = nil,
        targetSeconds: Int? = nil
    ) {
        secondsSincePhoneSync = 0
        if let workoutElapsedSeconds {
            self.workoutElapsedSeconds = workoutElapsedSeconds
        }
        if let exerciseElapsedSeconds {
            self.exerciseElapsedSeconds = exerciseElapsedSeconds
        }
        if let exerciseName, !exerciseName.isEmpty {
            currentExerciseName = exerciseName
        }
        if let targetSeconds, targetSeconds > 0 {
            cardioTargetSeconds = targetSeconds
        }
    }

    func startRestCountdown(seconds: Int, exerciseName: String) {
        stopRestCountdown()
        configuredRestSeconds = max(seconds, 1)
        restExerciseName = exerciseName
        restRemainingSeconds = configuredRestSeconds
        restElapsedSeconds = 0
        isResting = true
        isRestOvertime = false
        restOvertimeSeconds = 0
        hasSentRestOvertimeNotification = false

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickRest()
            }
        }
    }

    func stopRestCountdown() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        isRestOvertime = false
        restRemainingSeconds = 0
        restElapsedSeconds = 0
        restOvertimeSeconds = 0
        restExerciseName = ""
        hasSentRestOvertimeNotification = false
    }

    func notifyRestOvertime(exerciseName: String) {
        guard !hasSentRestOvertimeNotification else { return }
        hasSentRestOvertimeNotification = true
        isRestOvertime = true
        restExerciseName = exerciseName.isEmpty ? restExerciseName : exerciseName
        WKInterfaceDevice.current().play(.notification)
    }

    private func deliverSyncedNotification(title: String, body: String, category: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if !category.isEmpty {
            content.categoryIdentifier = category
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watch_\(identifier)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func syncDailyMotivationFromPhone(_ entries: [[String: Any]]) {
        cancelDailyMotivationOnWatch()

        let calendar = Calendar.current
        for entry in entries {
            guard let identifier = entry["identifier"] as? String,
                  let title = entry["title"] as? String,
                  let body = entry["body"] as? String,
                  let year = entry["year"] as? Int,
                  let month = entry["month"] as? Int,
                  let day = entry["day"] as? Int,
                  let hour = entry["hour"] as? Int,
                  let minute = entry["minute"] as? Int else { continue }

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute

            guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "DAILY_MOTIVATION"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "watch_\(identifier)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelDailyMotivationOnWatch() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("watch_daily_motivation") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleInactivityReminderOnWatch(
        title: String,
        body: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        identifier: String
    ) {
        cancelInactivityReminderOnWatch()

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        guard let scheduledDate = calendar.date(from: components), scheduledDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_INACTIVITY"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watch_\(identifier)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelInactivityReminderOnWatch() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("watch_workout_inactivity") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func tickRest() {
        restElapsedSeconds += 1

        if restRemainingSeconds > 0 {
            restRemainingSeconds -= 1
        }

        if restRemainingSeconds == 0 && restElapsedSeconds == configuredRestSeconds {
            WKInterfaceDevice.current().play(.retry)
        }

        if restElapsedSeconds > configuredRestSeconds {
            isRestOvertime = true
            restOvertimeSeconds = restElapsedSeconds - configuredRestSeconds
            notifyRestOvertime(exerciseName: restExerciseName)
        }
    }

    private func startHeartRateMonitoring() {
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchHeartRate()
                self?.calories += Double.random(in: 1...5)
                self?.sendMetricsToPhone()
            }
        }
    }

    private func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            heartRate = Double.random(in: 100...150)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            Task { @MainActor in
                if let sample = samples?.first as? HKQuantitySample {
                    self?.heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } else {
                    self?.heartRate = Double.random(in: 100...150)
                }
            }
        }
        healthStore.execute(query)
    }

    private func sendMetricsToPhone() {
        guard let session, session.isReachable else { return }
        session.sendMessage([
            "heartRate": heartRate,
            "calories": calories
        ], replyHandler: nil)
    }

    private func handlePhoneMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "startWorkout":
            let name = message["workoutName"] as? String ?? "Treino"
            startWorkout(name: name)
        case "startCardio":
            let name = message["workoutName"] as? String ?? "Cardio"
            let targetSeconds = message["targetSeconds"] as? Int ?? 0
            let exerciseName = message["exerciseName"] as? String ?? "Cardio"
            startCardio(name: name, targetSeconds: targetSeconds, exerciseName: exerciseName)
        case "syncWorkoutProgress":
            applyPhoneSync(
                workoutElapsedSeconds: message["workoutElapsedSeconds"] as? Int,
                exerciseElapsedSeconds: message["exerciseElapsedSeconds"] as? Int,
                exerciseName: message["exerciseName"] as? String
            )
        case "syncCardioProgress":
            applyPhoneSync(
                workoutElapsedSeconds: message["elapsedSeconds"] as? Int,
                targetSeconds: message["targetSeconds"] as? Int
            )
        case "stopWorkout":
            stopWorkout()
        case "restTimerStart":
            let seconds = message["seconds"] as? Int ?? 60
            let exerciseName = message["exerciseName"] as? String ?? "Exercício"
            startRestCountdown(seconds: seconds, exerciseName: exerciseName)
        case "restTimerStop":
            stopRestCountdown()
        case "restOvertime":
            let exerciseName = message["exerciseName"] as? String ?? restExerciseName
            notifyRestOvertime(exerciseName: exerciseName)
        case "deliverNotification":
            let title = message["title"] as? String ?? ""
            let body = message["body"] as? String ?? ""
            let category = message["category"] as? String ?? ""
            let identifier = message["identifier"] as? String ?? UUID().uuidString
            deliverSyncedNotification(title: title, body: body, category: category, identifier: identifier)
            if category == "REST_OVERTIME" {
                let exerciseName = message["exerciseName"] as? String ?? restExerciseName
                notifyRestOvertime(exerciseName: exerciseName)
            }
        case "syncDailyMotivation":
            if let payload = message["payload"] as? Data,
               let entries = try? JSONSerialization.jsonObject(with: payload) as? [[String: Any]] {
                syncDailyMotivationFromPhone(entries)
            }
        case "cancelDailyMotivation":
            cancelDailyMotivationOnWatch()
        case "scheduleInactivityReminder":
            let title = message["title"] as? String ?? "Hora de voltar a treinar!"
            let body = message["body"] as? String ?? ""
            scheduleInactivityReminderOnWatch(
                title: title,
                body: body,
                year: message["year"] as? Int ?? 0,
                month: message["month"] as? Int ?? 0,
                day: message["day"] as? Int ?? 0,
                hour: message["hour"] as? Int ?? 0,
                minute: message["minute"] as? Int ?? 0,
                identifier: message["identifier"] as? String ?? "workout_inactivity_48h"
            )
        case "cancelInactivityReminder":
            cancelInactivityReminderOnWatch()
        case "restTimer":
            let seconds = message["seconds"] as? Int ?? 60
            startRestCountdown(seconds: seconds, exerciseName: "Exercício")
        default:
            break
        }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handlePhoneMessage(userInfo)
        }
    }
}
