import Foundation
import ActivityKit

/// Atributos compartilhados entre o app e a extensão de Live Activity.
struct WorkoutLiveActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case exercise
        case rest
    }

    public struct ContentState: Codable, Hashable {
        var phase: Phase
        var exerciseName: String
        var setsLabel: String
        /// Início efetivo do cronômetro do exercício (Date.now - elapsed).
        var exerciseTimerStart: Date
        /// Fim da pausa (countdown na tela bloqueada).
        var restEndDate: Date?
        var workoutTitle: String
    }

    var sessionId: String
}
