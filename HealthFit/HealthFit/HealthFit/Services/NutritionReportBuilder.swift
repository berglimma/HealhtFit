import Foundation

enum NutritionReportBuilder {
    static func emailSubject(athleteName: String) -> String {
        "Relatório de Nutrição — \(athleteName) — HealthFit"
    }

    static func emailBody(
        athlete: UserProfile,
        weeklyPlan: [DailyMealPlan],
        customMenu: CustomMenuSelection,
        shoppingList: [ShoppingItem],
        selectedOptionIndex: Int = 0,
        generatedAt: Date = .now
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "pt_BR")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let greetingName = athlete.nutritionistName.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = [
            "Olá\(greetingName.isEmpty ? "" : " \(greetingName)"),",
            "",
            "Segue o relatório de nutrição do aluno \(athlete.name) (HealthFit):",
            "",
            "Gerado em: \(dateFormatter.string(from: generatedAt))",
            "",
            "— Perfil nutricional —",
            "Aluno: \(athlete.name)",
            "E-mail: \(athlete.email)",
            "Sexo: \(athlete.gender.rawValue)",
            "Idade: \(athlete.age) anos",
            "Peso: \(String(format: "%.1f", athlete.weight)) kg",
            "Altura: \(String(format: "%.0f", athlete.height)) cm",
            "IMC: \(String(format: "%.1f", athlete.bmi))",
            "Biotipo: \(athlete.biotype.rawValue)",
            "Objetivo: \(athlete.goal.rawValue)",
            "Déficit/ajuste calórico: \(athlete.caloricDeficit) kcal",
            "TMB: \(athlete.basalMetabolicRate) kcal",
            "TDEE estimado: \(athlete.estimatedTDEE) kcal",
            "Meta calórica diária: \(athlete.dailyCalorieTarget) kcal",
            ""
        ]

        lines.append("— Preferências alimentares —")
        lines.append("Consumo de doce: \(customMenu.sweetConsumption.rawValue)")
        if let lactose = customMenu.lactoseTolerance {
            lines.append("Tolerância à lactose: \(lactose.rawValue)")
        } else {
            lines.append("Tolerância à lactose: não informada")
        }
        lines.append("Energéticos/semana: \(customMenu.energyDrinksPerWeek)")
        lines.append("Energéticos/dia: \(customMenu.energyDrinksPerDay)")
        lines.append("")

        if weeklyPlan.isEmpty {
            lines.append("Cardápio semanal: ainda não gerado.")
            lines.append("")
        } else {
            lines.append("— Cardápio semanal —")
            for day in weeklyPlan {
                let option = preferredOption(from: day, selectedIndex: selectedOptionIndex)
                lines.append("")
                lines.append("\(day.dayOfWeek) — \(option?.name ?? "Sem opção")")
                if let subtitle = option?.subtitle, !subtitle.isEmpty {
                    lines.append("(\(subtitle))")
                }
                if let option {
                    lines.append(
                        "Totais do dia: \(option.totalCalories) kcal · \(option.totalProtein) g proteína"
                    )
                    for meal in option.meals {
                        let status = meal.isCompleted ? "Concluída" : "Pendente"
                        lines.append(
                            "• \(meal.mealType.rawValue) [\(status)]: \(meal.name) — \(meal.calories) kcal (P \(meal.protein)g / C \(meal.carbs)g / G \(meal.fat)g)"
                        )
                        if !meal.ingredients.isEmpty {
                            lines.append("  Ingredientes: \(meal.ingredients.joined(separator: ", "))")
                        }
                    }
                    let completed = option.meals.filter(\.isCompleted).count
                    lines.append("Progresso do dia: \(completed)/\(option.meals.count) refeições concluídas")
                }
            }
            lines.append("")
        }

        if !shoppingList.isEmpty {
            let purchased = shoppingList.filter(\.isPurchased).count
            lines.append("— Lista de compras (resumo) —")
            lines.append("Itens: \(shoppingList.count) · Comprados: \(purchased) · Pendentes: \(shoppingList.count - purchased)")
            for item in shoppingList.prefix(40) {
                let mark = item.isPurchased ? "✓" : "○"
                lines.append("\(mark) \(item.name) — \(item.quantity) (\(item.category.rawValue))")
            }
            if shoppingList.count > 40 {
                lines.append("… e mais \(shoppingList.count - 40) item(ns).")
            }
            lines.append("")
        }

        lines.append("Este relatório é exclusivo para o nutricionista cadastrado no perfil do aluno.")
        lines.append("Atenciosamente,")
        lines.append("HealthFit")

        return lines.joined(separator: "\n")
    }

    static func preferredOption(from day: DailyMealPlan, selectedIndex: Int) -> MealPlanOption? {
        guard !day.options.isEmpty else { return nil }
        if let montado = day.options.first(where: { $0.name.localizedCaseInsensitiveContains("Montado") }) {
            return montado
        }
        let index = min(max(selectedIndex, 0), day.options.count - 1)
        return day.options[index]
    }
}
