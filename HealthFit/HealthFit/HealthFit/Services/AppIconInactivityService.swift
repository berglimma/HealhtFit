import BackgroundTasks
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppIconInactivityService {
    static let shared = AppIconInactivityService()

    /// Mantido para alerta de 48h sem abrir o app (welcome / notificação).
    static let yellowThreshold: TimeInterval = 24 * 60 * 60
    static let redThreshold: TimeInterval = 36 * 60 * 60
    static let brokenThreshold: TimeInterval = 48 * 60 * 60
    static let pulseInterval: TimeInterval = 0.65

    private static let backgroundTaskHealthSync = "luan.com.healthfit.appicon.healthsync"
    private static let backgroundTaskBroken = "luan.com.healthfit.appicon.broken"

    static let backgroundTaskIdentifiers = [
        backgroundTaskHealthSync,
        backgroundTaskBroken,
    ]

    enum IconState: Equatable {
        case normal
        case yellow
        case red
        case broken

        init(healthStatus: WellnessHealthIconStatus) {
            switch healthStatus {
            case .green: self = .normal
            case .yellow: self = .yellow
            case .red: self = .red
            }
        }

        var title: String {
            switch self {
            case .normal: WellnessHealthIconStatus.green.title
            case .yellow: WellnessHealthIconStatus.yellow.title
            case .red: WellnessHealthIconStatus.red.title
            case .broken: "Ícone quebrado — retome os treinos"
            }
        }

        var detail: String {
            switch self {
            case .normal: WellnessHealthIconStatus.green.message
            case .yellow: WellnessHealthIconStatus.yellow.message
            case .red: WellnessHealthIconStatus.red.message
            case .broken:
                "Após 48h sem abrir, o ícone quebra e você recebe um alerta para voltar a se movimentar."
            }
        }

        var glowColor: Color {
            switch self {
            case .normal: WellnessHealthIconStatus.green.glowColor
            case .yellow: WellnessHealthIconStatus.yellow.glowColor
            case .red: WellnessHealthIconStatus.red.glowColor
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
        registerBackgroundTask(identifier: Self.backgroundTaskHealthSync)
        registerBackgroundTask(identifier: Self.backgroundTaskBroken)
    }

    /// Sincroniza o ícone da tela inicial — sempre mantém o ícone padrão do app.
    func syncWithWellnessHealthIcon(
        status: WellnessHealthIconStatus? = nil,
        pulseFrame: Int? = nil
    ) {
        restoreDefaultAppIcon()
    }

    /// Ao abrir o app: restaura o ícone padrão e limpa lembretes de inatividade de abertura.
    func handleAppBecameActive() {
        stopIconPulse()
        pulseFrameIndex = 0
        restoreDefaultAppIcon()
        UserDefaults.standard.removeObject(forKey: lastSessionEndKey)
        UserDefaults.standard.removeObject(forKey: brokenAlertSentKey)
        NotificationService.shared.cancelAppUsageInactivityReminder()
        scheduleWellnessBackgroundUpdates()
    }

    func resetForAccountDeletion() {
        stopIconPulse()
        pulseFrameIndex = 0
        restoreDefaultAppIcon()
        UserDefaults.standard.removeObject(forKey: lastSessionEndKey)
        UserDefaults.standard.removeObject(forKey: brokenAlertSentKey)
    }

    /// Ao sair do app: agenda alertas de inatividade sem alterar o ícone da home.
    func handleAppEnteredBackground() {
        let now = Date.now
        UserDefaults.standard.set(now, forKey: lastSessionEndKey)
        scheduleWellnessBackgroundUpdates()
        scheduleBrokenAlertIfNeeded(from: now)
        NotificationService.shared.refreshAppUsageInactivityReminder(lastSessionEndAt: now)

        pulseFrameIndex = 0
        restoreDefaultAppIcon()
        stopIconPulse()
    }

    func refreshIconForCurrentInactivity() async {
        restoreDefaultAppIcon()

        if UIApplication.shared.applicationState != .active,
           let sessionEnd = lastSessionEndAt,
           Date.now.timeIntervalSince(sessionEnd) >= Self.brokenThreshold {
            await NotificationService.shared.deliverAppUsageInactivityAlertIfNeeded(
                referenceSessionEnd: sessionEnd
            )
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

    /// Estado projetado do ícone: prioriza saúde; quebrado só após 48h fechado.
    func projectedIconState(from referenceDate: Date = .now) -> IconState {
        if let sessionEnd = lastSessionEndAt,
           referenceDate.timeIntervalSince(sessionEnd) >= Self.brokenThreshold {
            return .broken
        }
        return IconState(healthStatus: DailyWellnessService.shared.healthIconStatus(referenceDate: referenceDate))
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
        scheduleWellnessBackgroundUpdates()
        if let sessionEnd = lastSessionEndAt {
            scheduleBrokenAlertIfNeeded(from: sessionEnd)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            await refreshIconForCurrentInactivity()
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleWellnessBackgroundUpdates() {
        let scheduler = BGTaskScheduler.shared
        scheduler.cancel(taskRequestWithIdentifier: Self.backgroundTaskHealthSync)

        let wellness = DailyWellnessService.shared
        let status = wellness.healthIconStatus()
        guard status != .red else { return }

        let anchor = wellness.lastWaterOrSleepUpdateAtForIconScheduling
            ?? wellness.trackingStartedAtForIconScheduling
            ?? Date.now
        let redFireDate = anchor.addingTimeInterval(DailyWellnessService.staleUpdateThreshold)
        guard redFireDate > .now else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskHealthSync)
        request.earliestBeginDate = redFireDate
        try? scheduler.submit(request)
    }

    private func scheduleBrokenAlertIfNeeded(from referenceDate: Date) {
        let scheduler = BGTaskScheduler.shared
        scheduler.cancel(taskRequestWithIdentifier: Self.backgroundTaskBroken)

        let fireDate = referenceDate.addingTimeInterval(Self.brokenThreshold)
        guard fireDate > .now else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskBroken)
        request.earliestBeginDate = fireDate
        try? scheduler.submit(request)
    }

    private func currentDisplayState() -> IconState {
        if UIApplication.shared.applicationState != .active,
           let sessionEnd = lastSessionEndAt,
           Date.now.timeIntervalSince(sessionEnd) >= Self.brokenThreshold {
            return .broken
        }
        return IconState(healthStatus: DailyWellnessService.shared.healthIconStatus())
    }

    private func startIconPulse() {
        // Pulsação de ícone desativada — o app mantém sempre o ícone padrão.
        stopIconPulse()
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
        // Sem troca de ícone; apenas alerta de inatividade após 48h, se aplicável.
        if currentDisplayState() == .broken, let sessionEnd = lastSessionEndAt {
            Task {
                await NotificationService.shared.deliverAppUsageInactivityAlertIfNeeded(
                    referenceSessionEnd: sessionEnd
                )
            }
        }
    }

    /// Garante o ícone padrão (primário) na tela inicial.
    private func restoreDefaultAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != nil else { return }
        setAlternateIconSilently(nil)
    }

    private func applyIcon(_ state: IconState, pulseFrame: Int) {
        restoreDefaultAppIcon()
    }

    /// Troca o ícone sem o alerta do sistema (“Você alterou o ícone…”).
    private func setAlternateIconSilently(_ iconName: String?) {
        let application = UIApplication.shared
        let selector = NSSelectorFromString("_setAlternateIconName:completionHandler:")

        guard let method = class_getInstanceMethod(UIApplication.self, selector) else {
            application.setAlternateIconName(iconName) { error in
                if let error {
                    print("AppIconInactivityService: failed to set icon \(iconName ?? "primary") - \(error.localizedDescription)")
                }
            }
            return
        }

        typealias IconSetter = @convention(c) (AnyObject, Selector, NSString?, @escaping (NSError?) -> Void) -> Void
        let implementation = method_getImplementation(method)
        let setIcon = unsafeBitCast(implementation, to: IconSetter.self)
        setIcon(application, selector, iconName as NSString?) { error in
            if let error {
                print("AppIconInactivityService: failed to set icon \(iconName ?? "primary") - \(error.localizedDescription)")
            }
        }
    }
}
