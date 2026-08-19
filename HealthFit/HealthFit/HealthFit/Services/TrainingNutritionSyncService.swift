import Foundation
import Combine

/// Persiste o foco/nível de treino ativo e ajusta meta calórica + cardápio.
@MainActor
final class TrainingNutritionSyncService: ObservableObject {
    static let shared = TrainingNutritionSyncService()

    @Published private(set) var activeFocus: WorkoutFocus?
    @Published private(set) var activeLevel: WorkoutLevel?
    @Published private(set) var activeWorkoutTitle: String?
    @Published private(set) var adjustmentSummary: String?

    private let focusKey = "healthfit_training_focus"
    private let levelKey = "healthfit_training_level"
    private let titleKey = "healthfit_training_workout_title"
    private let summaryKey = "healthfit_training_nutrition_summary"

    private init() {
        load()
    }

    var hasActiveTrainingFocus: Bool {
        activeFocus != nil || activeLevel != nil
    }

    var displayFocusLabel: String {
        if let focus = activeFocus {
            return focus.rawValue
        }
        if let level = activeLevel {
            return "Série \(level.pluralTitle.lowercased())"
        }
        return "Treino guiado"
    }

    /// Aplica o cardápio conforme o treino selecionado e regenera o plano se possível.
    /// Trocar de ficha remove o cardápio alinhado ao treino anterior.
    @discardableResult
    func applySelection(
        template: GuidedWorkoutTemplate,
        authService: AuthService,
        mealPlanService: MealPlanService
    ) -> String {
        let isSwitchingWorkout = hasActiveTrainingFocus
            && normalizedTitle(activeWorkoutTitle) != normalizedTitle(template.title)
        if isSwitchingWorkout {
            clearAlignedPlan(using: mealPlanService)
            return "O cardápio alinhado ao treino anterior foi removido. Monte um cardápio personalizado em Nutrição, na aba Cardápio."
        }

        let plan = Self.nutritionPlan(for: template.focus, level: template.level)
        activeFocus = template.focus
        activeLevel = template.level
        activeWorkoutTitle = template.title
        adjustmentSummary = plan.summary
        persist()

        guard var user = authService.currentUser else {
            return "Cardápio ajustado para \(plan.feedbackLabel). Conclua o login para sincronizar a meta."
        }

        user.goal = plan.goal
        user.caloricDeficit = plan.caloricDeficit
        authService.updateProfile(user)

        mealPlanService.caloricDeficit = user.caloricDeficit
        mealPlanService.dailyCalorieTarget = user.dailyCalorieTarget
        mealPlanService.basalMetabolicRate = user.basalMetabolicRate
        mealPlanService.estimatedTDEE = user.estimatedTDEE

        if mealPlanService.customMenuSelection.isReadyToBuild {
            if mealPlanService.weeklyPlan.isEmpty {
                mealPlanService.generatePlan(for: user)
            } else {
                mealPlanService.regeneratePlanIfNeeded(for: user)
            }
        }

        return "Cardápio ajustado para \(plan.feedbackLabel)"
    }

    /// Remove o alinhamento treino ↔ cardápio e apaga o plano semanal gerado por ele.
    func clearAlignedPlan(using mealPlanService: MealPlanService) {
        guard hasActiveTrainingFocus else { return }
        clear()
        mealPlanService.clearWeeklyPlan()
    }

    /// Ao abrir outro treino (não a ficha que gerou o alinhamento), o cardápio alinhado some.
    func discardAlignedPlanIfDifferentWorkout(openedTitle: String, mealPlanService: MealPlanService) {
        guard hasActiveTrainingFocus else { return }
        if normalizedTitle(activeWorkoutTitle) == normalizedTitle(openedTitle) { return }
        clearAlignedPlan(using: mealPlanService)
    }

    private func normalizedTitle(_ title: String?) -> String {
        (title ?? "")
            .replacingOccurrences(of: "Guiado — ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func clear() {
        activeFocus = nil
        activeLevel = nil
        activeWorkoutTitle = nil
        adjustmentSummary = nil
        UserDefaults.standard.removeObject(forKey: focusKey)
        UserDefaults.standard.removeObject(forKey: levelKey)
        UserDefaults.standard.removeObject(forKey: titleKey)
        UserDefaults.standard.removeObject(forKey: summaryKey)
    }

    // MARK: - Nutrition mapping

    struct NutritionPlan {
        let goal: FitnessGoal
        let caloricDeficit: Int
        let feedbackLabel: String
        let summary: String
    }

    static func nutritionPlan(for focus: WorkoutFocus?, level: WorkoutLevel?) -> NutritionPlan {
        if let focus {
            switch focus {
            case .muscleGain:
                return NutritionPlan(
                    goal: .muscleGain,
                    caloricDeficit: 0,
                    feedbackLabel: focus.rawValue,
                    summary: "Superávit calórico e proteína elevada para hipertrofia."
                )
            case .fatLoss:
                return NutritionPlan(
                    goal: .fatLoss,
                    caloricDeficit: 450,
                    feedbackLabel: focus.rawValue,
                    summary: "Déficit moderado com alta proteína para preservar músculo."
                )
            case .legs:
                return NutritionPlan(
                    goal: .muscleGain,
                    caloricDeficit: 0,
                    feedbackLabel: focus.rawValue,
                    summary: "Proteína alta e carboidratos reforçados para recuperação de pernas."
                )
            case .competition:
                return NutritionPlan(
                    goal: .endurance,
                    caloricDeficit: 0,
                    feedbackLabel: focus.rawValue,
                    summary: "Energia orientada a performance com leve superávit sobre o TDEE."
                )
            case .arms:
                return NutritionPlan(
                    goal: .muscleGain,
                    caloricDeficit: 0,
                    feedbackLabel: focus.rawValue,
                    summary: "Proteína elevada e calorias de ganho para volume de braços."
                )
            case .back:
                return NutritionPlan(
                    goal: .muscleGain,
                    caloricDeficit: 0,
                    feedbackLabel: focus.rawValue,
                    summary: "Proteína alta e carboidratos para suporte ao treino de costas."
                )
            }
        }

        switch level {
        case .beginner:
            return NutritionPlan(
                goal: .maintenance,
                caloricDeficit: 0,
                feedbackLabel: "Série iniciantes",
                summary: "Manutenção calórica com proteína adequada para adaptação."
            )
        case .intermediate:
            return NutritionPlan(
                goal: .muscleGain,
                caloricDeficit: 0,
                feedbackLabel: "Série intermediários",
                summary: "Leve superávit e proteína alta para progressão de volume."
            )
        case .advanced:
            return NutritionPlan(
                goal: .muscleGain,
                caloricDeficit: 0,
                feedbackLabel: "Série avançados",
                summary: "Superávit e recuperação reforçada para alta intensidade."
            )
        case .none:
            return NutritionPlan(
                goal: .maintenance,
                caloricDeficit: 0,
                feedbackLabel: "treino guiado",
                summary: "Cardápio alinhado ao treino selecionado."
            )
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let activeFocus {
            UserDefaults.standard.set(activeFocus.rawValue, forKey: focusKey)
        } else {
            UserDefaults.standard.removeObject(forKey: focusKey)
        }
        if let activeLevel {
            UserDefaults.standard.set(activeLevel.rawValue, forKey: levelKey)
        } else {
            UserDefaults.standard.removeObject(forKey: levelKey)
        }
        UserDefaults.standard.set(activeWorkoutTitle, forKey: titleKey)
        UserDefaults.standard.set(adjustmentSummary, forKey: summaryKey)
    }

    private func load() {
        if let raw = UserDefaults.standard.string(forKey: focusKey) {
            activeFocus = WorkoutFocus(rawValue: raw)
        }
        if let raw = UserDefaults.standard.string(forKey: levelKey) {
            activeLevel = WorkoutLevel(rawValue: raw)
        }
        activeWorkoutTitle = UserDefaults.standard.string(forKey: titleKey)
        adjustmentSummary = UserDefaults.standard.string(forKey: summaryKey)
    }
}
