import Foundation

@MainActor
final class DailyMorningCheckInService: ObservableObject {
    static let shared = DailyMorningCheckInService()

    @Published private(set) var state: DailyMorningCheckInState?

    private let storageKey = "healthfit_daily_morning_checkin"

    private init() {
        state = load()
        refreshForToday()
    }

    func refreshForToday() {
        let today = DailyMorningCheckInEngine.todayKey()
        if state?.dateKey != today {
            state = DailyMorningCheckInState(dateKey: today, phase: .pending)
            save(state)
        }
    }

    var isDue: Bool {
        refreshForToday()
        guard let state, state.phase != .completed else { return false }
        return DailyMorningCheckInEngine.isCheckInWindowOpen() || state.phase == .askedFeeling
    }

    var isAwaitingFeelingReply: Bool {
        state?.phase == .askedFeeling
    }

    var needsAttention: Bool {
        isDue
    }

    func markAskedFeeling() {
        refreshForToday()
        guard var current = state else { return }
        current.phase = .askedFeeling
        state = current
        save(current)
        if !PostWorkoutCheckInService.shared.isAssistantTabActive {
            PostWorkoutCheckInService.shared.notifyAssistantMessagePending()
        }
    }

    func markCompleted() {
        refreshForToday()
        guard var current = state else { return }
        current.phase = .completed
        state = current
        save(current)
        PostWorkoutCheckInService.shared.refreshAssistantBadge()
    }

    private func save(_ state: DailyMorningCheckInState?) {
        guard let state else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() -> DailyMorningCheckInState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(DailyMorningCheckInState.self, from: data) else {
            return nil
        }
        return state
    }
}
