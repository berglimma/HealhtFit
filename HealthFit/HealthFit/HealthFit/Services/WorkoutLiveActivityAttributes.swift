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
        /// SF Symbol da modalidade (bike / corrida / caminhada / musculação…).
        var modalitySystemImage: String

        enum CodingKeys: String, CodingKey {
            case phase, exerciseName, setsLabel, exerciseTimerStart, restEndDate, workoutTitle
            case modalitySystemImage
        }

        init(
            phase: Phase,
            exerciseName: String,
            setsLabel: String,
            exerciseTimerStart: Date,
            restEndDate: Date?,
            workoutTitle: String,
            modalitySystemImage: String = "figure.strengthtraining.traditional"
        ) {
            self.phase = phase
            self.exerciseName = exerciseName
            self.setsLabel = setsLabel
            self.exerciseTimerStart = exerciseTimerStart
            self.restEndDate = restEndDate
            self.workoutTitle = workoutTitle
            self.modalitySystemImage = modalitySystemImage
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phase = try container.decode(Phase.self, forKey: .phase)
            exerciseName = try container.decode(String.self, forKey: .exerciseName)
            setsLabel = try container.decode(String.self, forKey: .setsLabel)
            exerciseTimerStart = try container.decode(Date.self, forKey: .exerciseTimerStart)
            restEndDate = try container.decodeIfPresent(Date.self, forKey: .restEndDate)
            workoutTitle = try container.decode(String.self, forKey: .workoutTitle)
            modalitySystemImage = try container.decodeIfPresent(String.self, forKey: .modalitySystemImage)
                ?? "figure.strengthtraining.traditional"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phase, forKey: .phase)
            try container.encode(exerciseName, forKey: .exerciseName)
            try container.encode(setsLabel, forKey: .setsLabel)
            try container.encode(exerciseTimerStart, forKey: .exerciseTimerStart)
            try container.encodeIfPresent(restEndDate, forKey: .restEndDate)
            try container.encode(workoutTitle, forKey: .workoutTitle)
            try container.encode(modalitySystemImage, forKey: .modalitySystemImage)
        }
    }

    var sessionId: String
}
