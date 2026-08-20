import SwiftUI

/// Sheet para criar/editar uma refeição livre (nome, macros e alimentos).
struct CreateUserMealSheet: View {
    let mealType: MealType
    let existing: MealTemplate?
    let dailyCalorieTarget: Int
    let onSave: (MealTemplate) -> Void
    let onDelete: ((UUID) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var calories: Int = 300
    @State private var protein: Int = 20
    @State private var carbs: Int = 30
    @State private var fat: Int = 10
    @State private var instructions: String = ""
    @State private var ingredients: [String] = []
    @State private var newFood: String = ""
    @State private var isSweet = false
    @State private var containsLactose = false

    private var suggestedCalories: Int {
        max(Int(Double(dailyCalorieTarget) * mealType.calorieShare), 120)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && calories > 0
            && !ingredients.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Refeição") {
                    TextField("Nome (ex.: Frango com batata)", text: $name)
                    LabeledContent("Tipo") {
                        Text(mealType.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Stepper("Calorias: \(calories) kcal", value: $calories, in: 50...2000, step: 10)
                    Stepper("Proteína: \(protein) g", value: $protein, in: 0...300, step: 1)
                    Stepper("Carboidrato: \(carbs) g", value: $carbs, in: 0...400, step: 1)
                    Stepper("Gordura: \(fat) g", value: $fat, in: 0...200, step: 1)
                    Button("Usar meta sugerida (\(suggestedCalories) kcal)") {
                        calories = suggestedCalories
                    }
                    .font(.caption)
                } header: {
                    Text("Macros")
                } footer: {
                    Text("Sugestão para \(mealType.shortLabel): cerca de \(suggestedCalories) kcal no seu plano.")
                }

                Section {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, food in
                        HStack {
                            Text(food)
                            Spacer()
                            Button(role: .destructive) {
                                ingredients.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    HStack {
                        TextField("Adicionar alimento", text: $newFood)
                            .textInputAutocapitalization(.sentences)
                        Button {
                            addFood()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .disabled(newFood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Alimentos")
                } footer: {
                    Text("Liste os alimentos desta refeição (ex.: 150g frango, 100g arroz, salada).")
                }

                Section("Detalhes opcionais") {
                    Toggle("Contém lactose", isOn: $containsLactose)
                    Toggle("É doce / sobremesa", isOn: $isSweet)
                    TextField("Modo de preparo (opcional)", text: $instructions, axis: .vertical)
                        .lineLimit(2...5)
                }

                if existing != nil, let onDelete {
                    Section {
                        Button("Excluir esta refeição", role: .destructive) {
                            onDelete(existing!.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Criar refeição" : "Editar refeição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private func bootstrap() {
        if let existing {
            name = existing.name
            calories = existing.calories
            protein = existing.protein
            carbs = existing.carbs
            fat = existing.fat
            ingredients = existing.ingredients
            instructions = existing.instructions
            isSweet = existing.isSweet
            containsLactose = existing.containsLactose
        } else {
            calories = suggestedCalories
        }
    }

    private func addFood() {
        let trimmed = newFood.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ingredients.append(trimmed)
        newFood = ""
    }

    private func save() {
        if !newFood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addFood()
        }
        let meal = MealTemplate(
            id: existing?.id ?? UUID(),
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            ingredients: ingredients,
            instructions: instructions,
            isSweet: isSweet,
            containsLactose: containsLactose
        )
        onSave(meal)
        dismiss()
    }
}
