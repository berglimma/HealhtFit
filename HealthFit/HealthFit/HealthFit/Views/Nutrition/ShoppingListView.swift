import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategory: ShoppingCategory?

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory != nil
    }

    private var filteredListItems: [ShoppingItem] {
        mealPlanService.filteredShoppingList(query: searchText, category: selectedCategory)
    }

    private var groupedItems: [(ShoppingCategory, [ShoppingItem])] {
        let grouped = Dictionary(grouping: filteredListItems, by: \.category)
        return ShoppingCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    private var catalogResults: [ShoppingCatalogItem] {
        ShoppingCatalog.search(query: searchText, category: selectedCategory)
    }

    private var catalogItemsToAdd: [ShoppingCatalogItem] {
        catalogResults.filter { !mealPlanService.containsShoppingItem(named: $0.name) }
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
                if isSearchActive {
                    searchResultsSection
                }

                summarySection

                if !mealPlanService.topPurchasedItems.isEmpty && !isSearchActive {
                    mostPurchasedSection
                }

                if !isSearchActive {
                    energyDrinksSection
                }

                if groupedItems.isEmpty && isSearchActive {
                    ContentUnavailableView(
                        "Nenhum item na lista",
                        systemImage: "cart",
                        description: Text("Use os resultados abaixo para adicionar à lista de compras.")
                    )
                } else {
                    shoppingSections
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Buscar proteínas, vegetais, frutas..."
            )
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

    private var searchResultsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterChip(
                        title: "Todos",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(ShoppingCatalog.searchableCategories) { category in
                        CategoryFilterChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if catalogItemsToAdd.isEmpty {
                Text(searchText.isEmpty
                     ? "Todos os itens desta categoria já estão na sua lista."
                     : "Nenhum item encontrado para \"\(searchText)\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(catalogItemsToAdd) { catalogItem in
                    CatalogSearchResultRow(item: catalogItem) {
                        mealPlanService.addCatalogItem(catalogItem)
                    }
                }
            }
        } header: {
            Label("Adicionar à lista", systemImage: "plus.magnifyingglass")
        } footer: {
            Text("Pesquise ou filtre por categoria: proteínas, vegetais, frutas, grãos, laticínios e suplementos.")
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text("Lista Semanal")
                        .font(.headline)
                    Text("\(purchasedCount)/\(mealPlanService.shoppingList.count) itens comprados")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isSearchActive {
                        Text("\(filteredListItems.count) itens exibidos")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }
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
    }

    private var mostPurchasedSection: some View {
        Section {
            ForEach(Array(mealPlanService.topPurchasedItems.prefix(8))) { stat in
                HStack(spacing: 12) {
                    Image(systemName: "cart.fill")
                        .foregroundStyle(AppTheme.accentSecondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.displayName)
                            .font(.subheadline.weight(.medium))
                        Text(stat.purchaseCount == 1
                             ? "Comprado 1 vez"
                             : "Comprado \(stat.purchaseCount) vezes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(stat.purchaseCount)x")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("Mais comprados", systemImage: "chart.bar.fill")
        } footer: {
            Text("Itens marcados como comprados na lista são contabilizados aqui.")
        }
    }

    private var energyDrinksSection: some View {
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
    }

    @ViewBuilder
    private var shoppingSections: some View {
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

    private var energyDrinksBinding: Binding<Int> {
        Binding(
            get: { mealPlanService.customMenuSelection.energyDrinksPerWeek },
            set: { newValue in
                mealPlanService.updateEnergyDrinksPerWeek(newValue, profile: authService.currentUser)
            }
        )
    }
}

private struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CatalogSearchResultRow: View {
    let item: ShoppingCatalogItem
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .foregroundStyle(AppTheme.accentSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text(item.defaultQuantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adicionar \(item.name)")
        }
        .padding(.vertical, 2)
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
