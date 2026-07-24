import Foundation
import Combine

@MainActor
final class ProfileDataReminderService: ObservableObject {
    static let shared = ProfileDataReminderService()
    static let refreshIntervalDays = 30

    enum PromptKind: Equatable {
        case firstFill
        case refreshDue

        var title: String {
            switch self {
            case .firstFill:
                return "Complete seus dados"
            case .refreshDue:
                return "Atualize seus dados"
            }
        }

        var message: String {
            switch self {
            case .firstFill:
                return "No primeiro acesso, preencha Perfil (peso, altura, idade e sexo) e Nutrição (biotipo e objetivo) para personalizar treinos e cardápio."
            case .refreshDue:
                return "Já se passaram 30 dias desde a última atualização. Revise Perfil e Nutrição para manter metas e calorias corretas."
            }
        }
    }

    @Published private(set) var activePrompt: PromptKind?

    private let defaults = UserDefaults.standard

    private init() {}

    func evaluate(for user: UserProfile?) {
        guard let user else {
            activePrompt = nil
            return
        }

        if lastUpdated(for: user.id) == nil {
            if looksLikeUnsetMetrics(user) {
                activePrompt = .firstFill
            } else {
                // Contas já em uso: não força o fluxo de primeiro preenchimento.
                seedLastUpdated(for: user.id)
                activePrompt = nil
            }
            return
        }

        guard let updated = lastUpdated(for: user.id) else {
            activePrompt = nil
            return
        }

        let days = Calendar.current.dateComponents([.day], from: updated, to: .now).day ?? 0
        if days >= Self.refreshIntervalDays {
            if shouldSuppressRefreshPrompt(for: user.id) {
                activePrompt = nil
            } else {
                activePrompt = .refreshDue
            }
        } else {
            activePrompt = nil
        }
    }

    func markBodyDataUpdated(for userId: String?) {
        guard let userId else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: updatedKey(userId))
        defaults.removeObject(forKey: dismissedRefreshDayKey(userId))
        activePrompt = nil
    }

    func dismissPrompt(for userId: String?) {
        guard let userId else {
            activePrompt = nil
            return
        }

        if activePrompt == .refreshDue {
            defaults.set(dayKey(for: .now), forKey: dismissedRefreshDayKey(userId))
        }

        activePrompt = nil
    }

    private func looksLikeUnsetMetrics(_ user: UserProfile) -> Bool {
        user.weight == 75 && user.height == 175 && user.age == 28
    }

    private func seedLastUpdated(for userId: String) {
        guard lastUpdated(for: userId) == nil else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: updatedKey(userId))
    }

    private func lastUpdated(for userId: String) -> Date? {
        let raw = defaults.double(forKey: updatedKey(userId))
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    private func shouldSuppressRefreshPrompt(for userId: String) -> Bool {
        defaults.string(forKey: dismissedRefreshDayKey(userId)) == dayKey(for: .now)
    }

    private func updatedKey(_ userId: String) -> String {
        "healthfit.profileBodyData.updatedAt.\(userId)"
    }

    private func dismissedRefreshDayKey(_ userId: String) -> String {
        "healthfit.profileBodyData.refreshDismissedDay.\(userId)"
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
