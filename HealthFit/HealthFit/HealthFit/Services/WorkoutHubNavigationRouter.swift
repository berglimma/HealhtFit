import Combine
import Foundation

/// Destino dentro do hub de musculação (Personalizados / Recomendados).
enum WorkoutHubSection: String, Equatable, Hashable {
    case personalizados
    case recommended
}

/// Navegação profunda para Treinos → programa por gênero (ex.: após o IAssistente criar/recomendar).
@MainActor
final class WorkoutHubNavigationRouter: ObservableObject {
    static let shared = WorkoutHubNavigationRouter()

    struct PendingOpen: Equatable {
        let gender: Gender
        let section: WorkoutHubSection
    }

    @Published private(set) var focusWorkoutsTabTick: Int = 0
    @Published private(set) var openHubTick: Int = 0
    private var pending: PendingOpen?

    private init() {}

    func openGenderHub(gender: Gender, section: WorkoutHubSection = .personalizados) {
        pending = PendingOpen(gender: gender, section: section)
        focusWorkoutsTabTick &+= 1
        openHubTick &+= 1
    }

    /// Consome o pedido de navegação até o hub (lista de treinos).
    func consumePendingOpen() -> PendingOpen? {
        let value = pending
        pending = nil
        return value
    }

    /// Peek sem consumir — usado pelo hub para rolar até a seção.
    var pendingGender: Gender? { pending?.gender }
    var pendingSection: WorkoutHubSection { pending?.section ?? .personalizados }

    /// Após a lista de treinos consumir o open, o hub ainda precisa do target de scroll.
    func keepSectionForScroll(gender: Gender, section: WorkoutHubSection) {
        pending = PendingOpen(gender: gender, section: section)
    }

    func consumePendingSectionIfMatching(gender: Gender) -> WorkoutHubSection? {
        guard let pending, pending.gender == gender else { return nil }
        let section = pending.section
        self.pending = nil
        return section
    }
}
