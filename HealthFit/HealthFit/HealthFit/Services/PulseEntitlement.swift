import Foundation

/// Acesso ao HealthFit Pulse: 15 dias grátis, depois plano Básico (R$ 9,90).
@MainActor
enum PulseEntitlement {
    static let trialDurationDays = 15
    private static let trialStartedKey = "pulse.entitlement.trialStartedAt"

    /// Kill-switch remoto ainda pode esconder o produto; Labs libera em DEBUG.
    static var isPulseVisible: Bool {
        _ = AppUpdateService.shared.pulseFlagsEpoch
        #if DEBUG
        if PulseExperimental.isLabEnabled { return true }
        #endif
        return PulseExperimental.isUIEnabled
    }

    static var trialStartedAt: Date? {
        let raw = UserDefaults.standard.double(forKey: trialStartedKey)
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Inicia o trial na primeira vez que o usuário abre o Pulse.
    static func markTrialStartedIfNeeded() {
        guard UserDefaults.standard.object(forKey: trialStartedKey) == nil else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: trialStartedKey)
    }

    static var isTrialActive: Bool {
        guard let start = trialStartedAt else {
            // Ainda não começou — libera até a primeira abertura.
            return true
        }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed < Double(trialDurationDays) * 86_400
    }

    static var trialDaysRemaining: Int {
        guard let start = trialStartedAt else { return trialDurationDays }
        let remaining = Double(trialDurationDays) * 86_400 - Date().timeIntervalSince(start)
        return max(0, Int(ceil(remaining / 86_400)))
    }

    static var hasPaidAccess: Bool {
        FeatureGate.canAccess(
            .healthFitPulse,
            tier: SubscriptionService.shared.currentTier
        )
    }

    /// Pode usar o feed/publicar: assinatura Básico+ ou trial de 15 dias.
    static var canUsePulse: Bool {
        guard isPulseVisible else { return false }
        if hasPaidAccess { return true }
        markTrialStartedIfNeeded()
        return isTrialActive
    }

    static var needsSubscriptionPrompt: Bool {
        isPulseVisible && !hasPaidAccess && !isTrialActive
    }
}
