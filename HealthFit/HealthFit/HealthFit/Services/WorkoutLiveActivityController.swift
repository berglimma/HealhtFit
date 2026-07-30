import Foundation
import ActivityKit
import UIKit

@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private var activity: Activity<WorkoutLiveActivityAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
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

        if let activity {
            Task {
                await activity.update(
                    ActivityContent(state: state, staleDate: staleDate(for: state))
                )
            }
            return
        }

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

    func end() {
        guard let activity else { return }
        let finalState = activity.content.state
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.activity = nil

        // Encerra qualquer atividade residual do app.
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
