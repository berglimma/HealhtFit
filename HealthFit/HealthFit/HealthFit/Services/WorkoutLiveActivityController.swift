import Foundation
import ActivityKit

@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private var activity: Activity<WorkoutLiveActivityAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// True if this process tracks an activity or the system still has any workout LA.
    var hasActiveLiveActivity: Bool {
        activity != nil || !Activity<WorkoutLiveActivityAttributes>.activities.isEmpty
    }

    func startOrUpdate(
        session: WorkoutSession,
        exerciseName: String,
        setsLabel: String,
        exerciseElapsedSeconds: Int,
        isResting: Bool,
        restEndDate: Date?
    ) {
        guard isSupported else { return }

        let timerStart = Date().addingTimeInterval(-TimeInterval(max(0, exerciseElapsedSeconds)))
        let state = WorkoutLiveActivityAttributes.ContentState(
            phase: isResting ? .rest : .exercise,
            exerciseName: exerciseName.isEmpty ? "Exercício" : exerciseName,
            setsLabel: setsLabel,
            exerciseTimerStart: timerStart,
            restEndDate: isResting ? restEndDate : nil,
            workoutTitle: session.workoutTitle
        )

        // Never let the evening nudge share the lock screen with a workout LA.
        if EveningTrainingNudgeController.shared.isActive {
            EveningTrainingNudgeService.handleActiveWorkoutStarted()
        }

        adoptOrCullExistingActivities()

        if let activity {
            Task {
                await activity.update(
                    ActivityContent(state: state, staleDate: staleDate(for: state))
                )
            }
            return
        }

        // Creating the only workout LA — clear nudge fully (cancel + reschedule).
        EveningTrainingNudgeService.handleActiveWorkoutStarted()

        // Belt-and-suspenders: never request while any workout LA remains.
        endAllActivities()

        let attributes = WorkoutLiveActivityAttributes(sessionId: session.id.uuidString)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate(for: state)),
                pushType: nil
            )
        } catch {
            print("[HealthFit] Live Activity falhou: \(error.localizedDescription)")
        }
    }

    /// Ends every workout Live Activity (tracked + system orphans). Safe when `activity` is nil.
    func end() {
        endAllActivities()
    }

    /// App launch / foreground: drop orphans when idle; keep a single LA when a session is active.
    func reconcile(hasActiveSession: Bool) {
        guard isSupported else {
            activity = nil
            return
        }

        if !hasActiveSession {
            endAllActivities()
            return
        }

        adoptOrCullExistingActivities()
    }

    // MARK: - Private

    /// Prefer one existing system activity over creating another (e.g. after process restart).
    private func adoptOrCullExistingActivities() {
        let existing = Activity<WorkoutLiveActivityAttributes>.activities

        if let tracked = activity {
            if existing.contains(where: { $0.id == tracked.id }) {
                for orphan in existing where orphan.id != tracked.id {
                    Task {
                        await orphan.end(nil, dismissalPolicy: .immediate)
                    }
                }
                return
            }
            // Tracked activity was dismissed or expired — drop the stale reference.
            activity = nil
        }

        guard let first = existing.first else { return }
        activity = first
        for orphan in existing.dropFirst() {
            Task {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func endAllActivities() {
        if let activity {
            let finalState = activity.content.state
            Task {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        self.activity = nil

        for orphan in Activity<WorkoutLiveActivityAttributes>.activities {
            Task {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func staleDate(for state: WorkoutLiveActivityAttributes.ContentState) -> Date {
        if state.phase == .rest, let end = state.restEndDate {
            return end.addingTimeInterval(60)
        }
        return Date().addingTimeInterval(60 * 60)
    }
}
