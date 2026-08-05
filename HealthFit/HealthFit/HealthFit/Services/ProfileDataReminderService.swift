import Foundation
import Combine

@MainActor
final class ProfileDataReminderService: ObservableObject {
    static let shared = ProfileDataReminderService()
    static let refreshIntervalDays = 30

    enum PromptKind: Equatable, Identifiable {
        case firstFill
        case refreshDue

        var id: String {
            switch self {
            case .firstFill: return "firstFill"
            case .refreshDue: return "refreshDue"
            }
        }

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
                return "No primeiro acesso, preencha data de nascimento, peso, altura e sexo no Perfil (e Nutrição) para personalizar treinos e cardápio."
            case .refreshDue:
                return "Já se passaram 30 dias desde a última atualização. Revise data de nascimento, medidas e Nutrição para manter metas e calorias corretas."
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

        // Mantém o prompt de primeiro acesso até o usuário escolher uma ação no pop-up.
        if activePrompt == .firstFill {
            return
        }

        if lastUpdated(for: user.id) == nil {
            if looksLikeUnsetMetrics(user) {
                if shouldSuppressFirstFillPrompt(for: user.id) {
                    activePrompt = nil
                } else {
                    activePrompt = .firstFill
                }
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
        defaults.removeObject(forKey: dismissedFirstFillDayKey(userId))
        activePrompt = nil
    }

    /// Só deve ser chamado pelos botões do pop-up (não no dismiss automático do SwiftUI).
    func dismissPrompt(for userId: String?) {
        guard let userId else {
            activePrompt = nil
            return
        }

        if activePrompt == .refreshDue {
            defaults.set(dayKey(for: .now), forKey: dismissedRefreshDayKey(userId))
        }

        if activePrompt == .firstFill {
            defaults.set(dayKey(for: .now), forKey: dismissedFirstFillDayKey(userId))
        }

        activePrompt = nil
    }

    private func looksLikeUnsetMetrics(_ user: UserProfile) -> Bool {
        !user.hasValidDateOfBirth || (user.weight == 75 && user.height == 175 && user.age == 28)
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

    private func shouldSuppressFirstFillPrompt(for userId: String) -> Bool {
        defaults.string(forKey: dismissedFirstFillDayKey(userId)) == dayKey(for: .now)
    }

    private func updatedKey(_ userId: String) -> String {
        "healthfit.profileBodyData.updatedAt.\(userId)"
    }

    private func dismissedRefreshDayKey(_ userId: String) -> String {
        "healthfit.profileBodyData.refreshDismissedDay.\(userId)"
    }

    private func dismissedFirstFillDayKey(_ userId: String) -> String {
        "healthfit.profileBodyData.firstFillDismissedDay.\(userId)"
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
