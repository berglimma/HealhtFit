import Foundation
import HealthKit

enum ExternalWorkoutAssistantEngine {
    /// Sheet virtual para sessões importadas do Apple Saúde.
    static let externalSheetId = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

    static func activityDisplayName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Corrida"
        case .walking: return "Caminhada"
        case .cycling: return "Ciclismo"
        case .swimming: return "Natação"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Musculação"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .mindAndBody: return "Mind & Body"
        case .pilates: return "Pilates"
        case .dance, .socialDance, .cardioDance: return "Dança"
        case .tennis: return "Tênis"
        case .soccer: return "Futebol"
        case .basketball: return "Basquete"
        case .hiking: return "Trilha"
        case .rowing: return "Remo"
        case .climbing: return "Escalada"
        case .elliptical: return "Elíptico"
        case .stairClimbing: return "Escada"
        case .coreTraining: return "Core"
        case .flexibility: return "Flexibilidade"
        case .cooldown: return "Desaquecimento"
        case .martialArts: return "Artes marciais"
        case .boxing: return "Boxe"
        case .kickboxing: return "Kickboxing"
        case .surfingSports: return "Surf"
        case .paddleSports: return "Remada / paddle"
        case .crossTraining: return "Cross training"
        default: return "Treino"
        }
    }

    static func isCardioActivity(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining,
             .flexibility, .yoga, .pilates, .mindAndBody, .cooldown:
            return false
        default:
            return true
        }
    }

    static func sessionTitle(activityType: HKWorkoutActivityType, sourceName: String) -> String {
        let activity = activityDisplayName(for: activityType)
        if isCardioActivity(activityType) {
            return "Cardio — \(activity) (\(sourceName))"
        }
        return "\(activity) (\(sourceName))"
    }

    static func makeSession(from sample: HealthKitManager.ExternalWorkoutSample) -> WorkoutSession {
        let title = sessionTitle(activityType: sample.activityType, sourceName: sample.sourceName)
        var heartSamples: [HeartRateSample] = []
        if sample.averageHeartRate > 0 {
            heartSamples = [HeartRateSample(bpm: sample.averageHeartRate)]
        }
        return WorkoutSession(
            workoutSheetId: externalSheetId,
            workoutTitle: title,
            startedAt: sample.startedAt,
            endedAt: sample.endedAt,
            heartRateSamples: heartSamples,
            caloriesBurned: max(0, sample.calories),
            completedExercises: 1,
            totalExercises: 1,
            source: .appleHealthExternal,
            healthKitUUID: sample.healthKitUUID,
            externalSourceName: sample.sourceName
        )
    }

    static func assistantMessage(
        athleteName: String,
        activityName: String,
        sourceName: String,
        durationMinutes: Int,
        calories: Int
    ) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let minutes = max(1, durationMinutes)
        let kcalLine = calories > 0 ? " (~\(calories) kcal)" : ""

        return """
        \(name), vi que você iniciou um treino em outro app (\(sourceName)): **\(activityName)** — cerca de \(minutes) min\(kcalLine). 👀

        Já registrei isso no HealthFit para entrar nos seus relatórios e na evolução da semana.

        Seria excepcional treinar pelo HealthFit: monitoramento mais personalizado, IAssistente acompanhando, metas, cardápio alinhado e resultados mais constantes. Quando quiser, comece o próximo treino por aqui — eu cuido do resto com você. 💪
        """
    }

    static func notificationBody(activityName: String, sourceName: String) -> String {
        "Vi que você iniciou um treino em outro app (\(sourceName)): \(activityName). Registrei no HealthFit — use o app para evolução mais personalizada."
    }
}
