import Foundation

@MainActor
final class DailyEveningCheckInService: ObservableObject {
    static let shared = DailyEveningCheckInService()

    @Published private(set) var state: DailyEveningCheckInState?

    private let storageKey = "healthfit_daily_evening_checkin"

    private init() {
        state = load()
        refreshForToday()
    }

    func refreshForToday() {
        let today = DailyEveningCheckInEngine.todayKey()
        if state?.dateKey != today {
            state = DailyEveningCheckInState(dateKey: today, phase: .pending)
            save(state)
        }
    }

    var isDue: Bool {
        refreshForToday()
        guard let state, state.phase != .completed else { return false }
        return DailyEveningCheckInEngine.isCheckInWindowOpen() || isAwaitingReply
    }

    var isAwaitingReply: Bool {
        state?.phase == .askedDayReflection || state?.phase == .askedRestReadiness
    }

    var needsAttention: Bool {
        isDue
    }

    func markAskedDayReflection() {
        refreshForToday()
        guard var current = state else { return }
        current.phase = .askedDayReflection
        state = current
        save(current)
        notifyIfNeeded()
    }

    func markAskedRestReadiness() {
        refreshForToday()
        guard var current = state else { return }
        current.phase = .askedRestReadiness
        state = current
        save(current)
    }

    func markCompleted() {
        refreshForToday()
        guard var current = state else { return }
        current.phase = .completed
        state = current
        save(current)
        PostWorkoutCheckInService.shared.refreshAssistantBadge()
    }

    private func notifyIfNeeded() {
        if !PostWorkoutCheckInService.shared.isAssistantTabActive {
            PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
        }
    }

    private func save(_ state: DailyEveningCheckInState?) {
        guard let state else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() -> DailyEveningCheckInState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(DailyEveningCheckInState.self, from: data) else {
            return nil
        }
        return state
    }
}
