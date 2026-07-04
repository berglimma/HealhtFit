import BackgroundTasks
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppIconInactivityService {
    static let shared = AppIconInactivityService()

    /// 24h sem abrir o app.
    static let yellowThreshold: TimeInterval = 24 * 60 * 60
    /// 36h sem abrir o app.
    static let redThreshold: TimeInterval = 36 * 60 * 60
    /// Após o vermelho: ícone quebrado + alerta.
    static let brokenThreshold: TimeInterval = 48 * 60 * 60
    static let pulseInterval: TimeInterval = 0.65

    private static let backgroundTaskYellow = "luan.com.healthfit.appicon.yellow"
    private static let backgroundTaskRed = "luan.com.healthfit.appicon.red"
    private static let backgroundTaskBroken = "luan.com.healthfit.appicon.broken"

    static let backgroundTaskIdentifiers = [
        backgroundTaskYellow,
        backgroundTaskRed,
        backgroundTaskBroken,
    ]

    enum IconState: Equatable {
        case normal
        case yellow
        case red
        case broken

        var title: String {
            switch self {
            case .normal: "Ícone saudável"
            case .yellow: "Ícone amarelo — 24h sem uso"
            case .red: "Ícone vermelho — 36h sem abrir"
            case .broken: "Ícone quebrado — retome os treinos"
            }
        }

        var detail: String {
            switch self {
            case .normal:
                "Ícone verde ao usar o app."
            case .yellow:
                "Após 24h sem abrir o app, o ícone fica amarelo."
            case .red:
                "Após 36h sem abrir o app, o ícone fica vermelho."
            case .broken:
                "Após 48h sem abrir, o ícone quebra e você recebe um alerta para voltar a se movimentar."
            }
        }

        var glowColor: Color {
            switch self {
            case .normal: AppTheme.accent
            case .yellow: .yellow
            case .red: .red
            case .broken: Color(red: 0.86, green: 0.18, blue: 0.16)
            }
        }

        func alternateIconName(pulseFrame: Int) -> String? {
            let frame = ((pulseFrame % 3) + 3) % 3

            switch self {
            case .normal:
                switch frame {
                case 0: return nil
                case 1: return "AppIconPulse1"
                default: return "AppIconPulse2"
                }
            case .yellow:
                switch frame {
                case 0: return "AppIconYellow"
                case 1: return "AppIconYellowPulse1"
                default: return "AppIconYellowPulse2"
                }
            case .red:
                switch frame {
                case 0: return "AppIconRed"
                case 1: return "AppIconRedPulse1"
                default: return "AppIconRedPulse2"
                }
            case .broken:
                switch frame {
                case 0: return "AppIconBroken"
                case 1: return "AppIconBrokenPulse1"
                default: return "AppIconBrokenPulse2"
                }
            }
        }
    }

    private let lastSessionEndKey = "healthfit_last_session_end_at"
    private let brokenAlertSentKey = "healthfit_broken_icon_alert_sent_for_session"

    private var pulseFrameIndex = 0
    private var pulseTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var isPulsing = false

    private init() {}

    func registerBackgroundTasks() {
        registerBackgroundTask(identifier: Self.backgroundTaskYellow)
        registerBackgroundTask(identifier: Self.backgroundTaskRed)
        registerBackgroundTask(identifier: Self.backgroundTaskBroken)
    }

    /// Ao abrir o app: ícone volta ao verde padrão.
    func handleAppBecameActive() {
        stopIconPulse()
        pulseFrameIndex = 0
        applyIcon(.normal, pulseFrame: 0)
        UserDefaults.standard.removeObject(forKey: lastSessionEndKey)
        UserDefaults.standard.removeObject(forKey: brokenAlertSentKey)
        NotificationService.shared.cancelAppUsageInactivityReminder()
    }

    /// Ao sair do app: inicia contagem e pulsação do ícone.
    func handleAppEnteredBackground() {
        let now = Date.now
        UserDefaults.standard.set(now, forKey: lastSessionEndKey)
        scheduleAllBackgroundUpdates(from: now)
        NotificationService.shared.refreshAppUsageInactivityReminder(lastSessionEndAt: now)

        pulseFrameIndex = 0
        applyIcon(.normal, pulseFrame: 0)
        startIconPulse()
    }

    func refreshIconForCurrentInactivity() async {
        guard UIApplication.shared.applicationState != .active else {
            applyIcon(.normal, pulseFrame: 0)
            return
        }

        guard let sessionEnd = lastSessionEndAt else { return }

        let elapsed = Date.now.timeIntervalSince(sessionEnd)
        let state = iconState(forElapsed: elapsed)
        applyIcon(state, pulseFrame: pulseFrameIndex)

        if state == .broken {
            await NotificationService.shared.deliverAppUsageInactivityAlertIfNeeded(
                referenceSessionEnd: sessionEnd
            )
        }

        if !isPulsing {
            startIconPulse()
        }
    }

    var lastSessionEndAt: Date? {
        UserDefaults.standard.object(forKey: lastSessionEndKey) as? Date
    }

    /// Horas desde a última sessão fechada (antes do reset ao abrir o app).
    func hoursSinceLastSessionEnd(referenceDate: Date = .now) -> Double? {
        guard let sessionEnd = lastSessionEndAt else { return nil }
        return referenceDate.timeIntervalSince(sessionEnd) / 3600
    }

    /// Estado que o ícone teria agora se o app estivesse fechado.
    func projectedIconState(from referenceDate: Date = .now) -> IconState {
        guard let sessionEnd = lastSessionEndAt else { return .normal }
        return iconState(forElapsed: referenceDate.timeIntervalSince(sessionEnd))
    }

    func iconState(forElapsed elapsed: TimeInterval) -> IconState {
        switch elapsed {
        case ..<Self.yellowThreshold:
            return .normal
        case ..<Self.redThreshold:
            return .yellow
        case ..<Self.brokenThreshold:
            return .red
        default:
            return .broken
        }
    }

    func formattedTimeUntilNextChange(from referenceDate: Date = .now) -> String? {
        guard let sessionEnd = lastSessionEndAt else { return nil }

        let elapsed = referenceDate.timeIntervalSince(sessionEnd)
        let nextThreshold: TimeInterval?

        switch iconState(forElapsed: elapsed) {
        case .normal:
            nextThreshold = Self.yellowThreshold
        case .yellow:
            nextThreshold = Self.redThreshold
        case .red:
            nextThreshold = Self.brokenThreshold
        case .broken:
            nextThreshold = nil
        }

        guard let nextThreshold else { return nil }
        let remaining = nextThreshold - elapsed
        guard remaining > 0 else { return nil }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Próxima mudança em \(hours)h \(minutes)min"
        }
        return "Próxima mudança em \(minutes) min"
    }

    private func registerBackgroundTask(identifier: String) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                self.handleBackgroundRefresh(task: refreshTask)
            }
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        if let sessionEnd = lastSessionEndAt {
            scheduleAllBackgroundUpdates(from: sessionEnd)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            await refreshIconForCurrentInactivity()
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleAllBackgroundUpdates(from referenceDate: Date) {
        let scheduler = BGTaskScheduler.shared

        for identifier in Self.backgroundTaskIdentifiers {
            scheduler.cancel(taskRequestWithIdentifier: identifier)
        }

        let milestones: [(String, TimeInterval)] = [
            (Self.backgroundTaskYellow, Self.yellowThreshold),
            (Self.backgroundTaskRed, Self.redThreshold),
            (Self.backgroundTaskBroken, Self.brokenThreshold),
        ]

        for (identifier, milestone) in milestones {
            let fireDate = referenceDate.addingTimeInterval(milestone)
            guard fireDate > .now else { continue }

            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = fireDate
            try? scheduler.submit(request)
        }
    }

    private func currentInactivityState() -> IconState {
        guard let sessionEnd = lastSessionEndAt else { return .normal }
        return iconState(forElapsed: Date.now.timeIntervalSince(sessionEnd))
    }

    private func startIconPulse() {
        guard !isPulsing else { return }
        isPulsing = true

        if backgroundTaskID == .invalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "HealthFitIconPulse") { [weak self] in
                self?.stopIconPulse()
            }
        }

        let timer = Timer(timeInterval: Self.pulseInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advancePulseFrame()
            }
        }
        pulseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopIconPulse() {
        isPulsing = false
        pulseTimer?.invalidate()
        pulseTimer = nil

        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func advancePulseFrame() {
        pulseFrameIndex = (pulseFrameIndex + 1) % 3
        let state = currentInactivityState()
        applyIcon(state, pulseFrame: pulseFrameIndex)

        if state == .broken, let sessionEnd = lastSessionEndAt {
            Task {
                await NotificationService.shared.deliverAppUsageInactivityAlertIfNeeded(
                    referenceSessionEnd: sessionEnd
                )
            }
        }
    }

    private func applyIcon(_ state: IconState, pulseFrame: Int) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let targetName = state.alternateIconName(pulseFrame: pulseFrame)
        guard UIApplication.shared.alternateIconName != targetName else { return }

        UIApplication.shared.setAlternateIconName(targetName) { error in
            if let error {
                print("AppIconInactivityService: failed to set icon \(targetName ?? "primary") - \(error.localizedDescription)")
            }
        }
    }
}
