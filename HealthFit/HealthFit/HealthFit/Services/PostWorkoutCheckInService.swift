import Foundation

@MainActor
final class PostWorkoutCheckInService: ObservableObject {
    static let shared = PostWorkoutCheckInService()

    @Published private(set) var pendingCheckIn: PendingPostWorkoutCheckIn?

    private let storageKey = "healthfit_post_workout_checkin"

    private init() {
        pendingCheckIn = load()
    }

    func scheduleCheckIn(for session: WorkoutSession) {
        guard session.endedAt != nil else { return }

        if let previous = pendingCheckIn, previous.phase != .completed {
            NotificationService.shared.cancelPostWorkoutCheckIn(sessionId: previous.sessionId)
        }

        let checkIn = PendingPostWorkoutCheckIn(session: session)
        pendingCheckIn = checkIn
        save(checkIn)

        NotificationService.shared.schedulePostWorkoutCheckIn(
            sessionId: session.id,
            workoutTitle: session.workoutTitle,
            fireDate: checkIn.endedAt.addingTimeInterval(PostWorkoutCheckInEngine.delaySeconds)
        )
        refreshAssistantBadge()
    }

    var dueCheckIn: PendingPostWorkoutCheckIn? {
        guard let checkIn = pendingCheckIn,
              checkIn.phase != .completed,
              PostWorkoutCheckInEngine.isDue(checkIn) else {
            return nil
        }
        return checkIn
    }

    var isAwaitingFeelingReply: Bool {
        pendingCheckIn?.phase == .askedFeeling
    }

    private(set) var isAssistantTabActive = false

    var assistantTabBadgeCount: Int {
        guard !isAssistantTabActive else { return 0 }
        if dueCheckIn != nil || isAwaitingFeelingReply || DailyMorningCheckInService.shared.needsAttention {
            return 1
        }
        return hasUnreadAssistantMessage ? 1 : 0
    }

    private var hasUnreadAssistantMessage: Bool {
        UserDefaults.standard.bool(forKey: unreadAssistantKey)
    }

    private let unreadAssistantKey = "healthfit_assistant_unread"

    func setAssistantTabActive(_ active: Bool) {
        isAssistantTabActive = active
        if active {
            clearUnreadAssistantMessage()
        } else {
            syncAppIconBadge()
        }
    }

    func notifyAssistantMessagePending() {
        UserDefaults.standard.set(true, forKey: unreadAssistantKey)
        syncAppIconBadge()
        objectWillChange.send()
    }

    func clearUnreadAssistantMessage() {
        UserDefaults.standard.set(false, forKey: unreadAssistantKey)
        syncAppIconBadge()
        objectWillChange.send()
    }

    func syncAppIconBadge() {
        let count: Int
        if isAssistantTabActive {
            count = 0
        } else if dueCheckIn != nil || isAwaitingFeelingReply || DailyMorningCheckInService.shared.needsAttention || hasUnreadAssistantMessage {
            count = 1
        } else {
            count = 0
        }
        NotificationService.shared.setAppIconBadgeCount(count)
    }

    func refreshAssistantBadge() {
        DailyMorningCheckInService.shared.refreshForToday()
        if !isAssistantTabActive,
           dueCheckIn != nil || isAwaitingFeelingReply || DailyMorningCheckInService.shared.needsAttention {
            notifyAssistantMessagePending()
        } else {
            syncAppIconBadge()
        }
        objectWillChange.send()
    }

    func markAskedFeeling() {
        guard var checkIn = pendingCheckIn else { return }
        checkIn.phase = .askedFeeling
        pendingCheckIn = checkIn
        save(checkIn)
        if !isAssistantTabActive {
            notifyAssistantMessagePending()
        }
    }

    func markCompleted() {
        guard var checkIn = pendingCheckIn else { return }
        checkIn.phase = .completed
        pendingCheckIn = checkIn
        save(checkIn)
        clearUnreadAssistantMessage()
        NotificationService.shared.cancelPostWorkoutCheckIn(sessionId: checkIn.sessionId)
    }

    func clearIfCompleted() {
        guard pendingCheckIn?.phase == .completed else { return }
        pendingCheckIn = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func save(_ checkIn: PendingPostWorkoutCheckIn) {
        if let data = try? JSONEncoder().encode(checkIn) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() -> PendingPostWorkoutCheckIn? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let checkIn = try? JSONDecoder().decode(PendingPostWorkoutCheckIn.self, from: data) else {
            return nil
        }
        return checkIn
    }
}
