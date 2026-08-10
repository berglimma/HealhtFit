import Foundation

/// Registro de análise de refeição por foto — só macros e rótulo; a imagem é descartada.
struct MealPhotoAnalysisEntry: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var mealType: MealType
    var dayKey: String
    var foodLabel: String
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var calories: Int
    var confidence: Double
    var analyzedAt: Date
    /// Indica que a foto foi usada só na análise e não foi armazenada.
    var photoDiscarded: Bool

    init(
        id: String = UUID().uuidString,
        mealType: MealType,
        dayKey: String = DailyWellnessEntry.dayKey(for: .now),
        foodLabel: String,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        calories: Int? = nil,
        confidence: Double = 0,
        analyzedAt: Date = .now,
        photoDiscarded: Bool = true
    ) {
        self.id = id
        self.mealType = mealType
        self.dayKey = dayKey
        self.foodLabel = foodLabel
        self.proteinGrams = max(0, proteinGrams)
        self.carbsGrams = max(0, carbsGrams)
        self.fatGrams = max(0, fatGrams)
        self.calories = calories ?? Self.estimatedCalories(
            protein: self.proteinGrams,
            carbs: self.carbsGrams,
            fat: self.fatGrams
        )
        self.confidence = min(max(confidence, 0), 1)
        self.analyzedAt = analyzedAt
        self.photoDiscarded = photoDiscarded
    }

    static func estimatedCalories(protein: Int, carbs: Int, fat: Int) -> Int {
        Int((Double(protein) * 4 + Double(carbs) * 4 + Double(fat) * 9).rounded())
    }
}

struct MealPhotoAnalysisDraft: Equatable {
    var mealType: MealType
    var foodLabel: String
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var calories: Int
    var confidence: Double

    var isValid: Bool {
        !foodLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (proteinGrams > 0 || carbsGrams > 0 || fatGrams > 0)
    }

    func asEntry(dayKey: String = DailyWellnessEntry.dayKey(for: .now)) -> MealPhotoAnalysisEntry {
        MealPhotoAnalysisEntry(
            mealType: mealType,
            dayKey: dayKey,
            foodLabel: foodLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            calories: calories,
            confidence: confidence,
            photoDiscarded: true
        )
    }
}
