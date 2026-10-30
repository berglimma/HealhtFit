import Combine
import Foundation

/// Abre a aba IAssistente e inicia o fluxo de montar treino (ex.: CTA “Montar treino pelo IA”).
@MainActor
final class AssistantNavigationRouter: ObservableObject {
    static let shared = AssistantNavigationRouter()

    struct PendingStart {
        let preferredGender: Gender?
    }

    @Published private(set) var focusAssistantTabTick: Int = 0
    @Published private(set) var pendingStartWorkoutBuilderTick: Int = 0
    private var pendingPreferredGender: Gender?
    private var hasPendingStart = false

    private init() {}

    func startWorkoutBuilder(preferredGender: Gender? = nil) {
        pendingPreferredGender = preferredGender
        hasPendingStart = true
        focusAssistantTabTick &+= 1
        pendingStartWorkoutBuilderTick &+= 1
    }

    /// Consome o pedido pendente. Retorna `nil` se não houver CTA aguardando.
    func consumePendingStart() -> PendingStart? {
        guard hasPendingStart else { return nil }
        hasPendingStart = false
        let gender = pendingPreferredGender
        pendingPreferredGender = nil
        return PendingStart(preferredGender: gender)
    }
}
