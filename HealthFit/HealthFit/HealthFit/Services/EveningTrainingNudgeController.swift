import Foundation
import ActivityKit

@MainActor
final class EveningTrainingNudgeController {
    static let shared = EveningTrainingNudgeController()

    private var activity: Activity<EveningTrainingNudgeAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isActive: Bool {
        activity != nil || !Activity<EveningTrainingNudgeAttributes>.activities.isEmpty
    }

    /// Inicia (ou reinicia) a Live Activity do lembrete noturno com countdown até `endDate`.
    func start(
        dayKey: String,
        statusMessage: String,
        motivationalMessage: String,
        endDate: Date
    ) {
        guard isSupported else { return }
        guard endDate > .now else { return }

        // Não competir com treino ativo na tela bloqueada.
        guard Activity<WorkoutLiveActivityAttributes>.activities.isEmpty else { return }

        endImmediate()

        let state = EveningTrainingNudgeAttributes.ContentState(
            statusMessage: statusMessage,
            motivationalMessage: motivationalMessage,
            countdownEndDate: endDate
        )
        let attributes = EveningTrainingNudgeAttributes(dayKey: dayKey)
        let content = ActivityContent(state: state, staleDate: endDate)

        do {
            let requested = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activity = requested
            // Agenda o fim automático mesmo com o app suspenso.
            Task {
                await requested.end(content, dismissalPolicy: .after(endDate))
            }
        } catch {
            print("[HealthFit] Evening nudge Live Activity falhou: \(error.localizedDescription)")
        }
    }

    func end() {
        endImmediate()
    }

    private func endImmediate() {
        if let activity {
            let finalState = activity.content.state
            Task {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            self.activity = nil
        }

        for orphan in Activity<EveningTrainingNudgeAttributes>.activities {
            Task {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
