import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    private var groupedItems: [(ShoppingCategory, [ShoppingItem])] {
        let grouped = Dictionary(grouping: mealPlanService.shoppingList, by: \.category)
        return ShoppingCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    private var purchasedCount: Int {
        mealPlanService.shoppingList.filter(\.isPurchased).count
    }

    private var energyDrinksPerWeek: Int {
        mealPlanService.customMenuSelection.energyDrinksPerWeek
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Lista Semanal")
                                .font(.headline)
                            Text("\(purchasedCount)/\(mealPlanService.shoppingList.count) itens comprados")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ProgressView(
                            value: Double(purchasedCount),
                            total: Double(max(mealPlanService.shoppingList.count, 1))
                        )
                        .frame(width: 60)
                        .tint(AppTheme.accent)
                    }
                }

                Section {
                    Stepper(
                        value: energyDrinksBinding,
                        in: 0...14,
                        step: 1
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Energéticos por semana")
                                .font(.subheadline.weight(.medium))
                            Text(energyDrinksPerWeek == 0
                                 ? "Não incluir na lista"
                                 : "\(energyDrinksPerWeek) un na lista de compras")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if energyDrinksPerWeek > 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Alerta OMS", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text(SupplementGuidance.whoEnergyDrinkWarning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Bebidas", systemImage: "bolt.fill")
                } footer: {
                    Text("Informe quantos energéticos você pretende comprar nesta semana.")
                }

                ForEach(groupedItems, id: \.0) { category, items in
                    Section {
                        ForEach(items) { item in
                            ShoppingItemRow(item: item) {
                                mealPlanService.togglePurchased(item)
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    } footer: {
                        if category == .supplements {
                            Text("Pré-treino: \(SupplementGuidance.preWorkoutCaffeineLimit).")
                        }
                    }
                }
            }
            .navigationTitle("Lista de Compras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        mealPlanService.generateShoppingList()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var energyDrinksBinding: Binding<Int> {
        Binding(
            get: { mealPlanService.customMenuSelection.energyDrinksPerWeek },
            set: { newValue in
                mealPlanService.updateEnergyDrinksPerWeek(newValue, profile: authService.currentUser)
            }
        )
    }
}

struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? AppTheme.accent : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    Text(item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
