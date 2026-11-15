import Foundation

/// Shared App Group + snapshot for Home / Lock Screen widgets (main app + widget extension).
enum HealthFitWidgetShared {
    static let appGroupId = "group.luan.com.healthfit.app"
    static let snapshotKey = "healthfit.widget.snapshot.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }
}

struct HealthFitWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var liftWeightKg: Int?
    var liftExerciseName: String
    var liftEquipmentHint: String
    var workoutsThisWeek: Int
    var weeklyGoal: Int
    var todayCalories: Int
    var workoutOfDayTitle: String
    var workoutOfDaySubtitle: String
    var streakDays: Int

    static let placeholder = HealthFitWidgetSnapshot(
        updatedAt: .now,
        liftWeightKg: 139,
        liftExerciseName: "Supino Reto",
        liftEquipmentHint: "Barra",
        workoutsThisWeek: 3,
        weeklyGoal: 3,
        todayCalories: 63,
        workoutOfDayTitle: "Treino do dia",
        workoutOfDaySubtitle: "Sugestão com base na sua rotina",
        streakDays: 3
    )

    static func load() -> HealthFitWidgetSnapshot {
        guard let data = HealthFitWidgetShared.defaults.data(forKey: HealthFitWidgetShared.snapshotKey),
              let decoded = try? JSONDecoder().decode(HealthFitWidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        HealthFitWidgetShared.defaults.set(data, forKey: HealthFitWidgetShared.snapshotKey)
    }

    var liftPrimaryLabel: String {
        if let kg = liftWeightKg, kg > 0 { return "\(kg) kg" }
        return "—"
    }

    var liftSecondaryLabel: String {
        let name = liftExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let equip = liftEquipmentHint.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Sem carga recente" }
        if equip.isEmpty { return name }
        return "\(name) • \(equip)"
    }

    var progressFraction: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(weeklyGoal), 1)
    }

    var progressLabel: String { "\(workoutsThisWeek)/\(max(weeklyGoal, 1))" }
}
