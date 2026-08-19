import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategory: ShoppingCategory?
    @State private var showAddCustomItem = false
    @State private var customItemPrefillName = ""
    @State private var showWeeklyReport = false

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
                        customItemPrefillName = ""
                        showAddCustomItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Adicionar item personalizado")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        mealPlanService.generateShoppingList()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Regenerar lista")
                }
            }
            .sheet(isPresented: $showAddCustomItem) {
                AddCustomShoppingItemSheet(initialName: customItemPrefillName) {
                    searchText = ""
                    selectedCategory = nil
                }
            }
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyShoppingReportView(
                    report: mealPlanService.buildWeeklyShoppingReport(),
                    athleteName: authService.currentUser?.greetingName ?? "Atleta"
                )
            }
        }
        .requiresSubscription(.shoppingList)
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
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        customItemPrefillName = searchText
                        showAddCustomItem = true
                    } label: {
                        Label(
                            "Adicionar \"\(searchText)\" como item personalizado",
                            systemImage: "plus.circle.fill"
                        )
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                } else {
                    Text("Todos os itens desta categoria já estão na sua lista.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            Text("Pesquise no catálogo ou toque em + para criar um item personalizado e escolher a categoria.")
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

            Button {
                showWeeklyReport = true
            } label: {
                Label("Relatório de compras da semana", systemImage: "doc.text.fill")
                    .font(.subheadline.weight(.medium))
            }

            if mealPlanService.shoppingList.contains(where: { !mealPlanService.isItemInCurrentDiet($0) }) {
                Text("🤔 Itens em laranja não estão no cardápio atual. Você ainda pode marcá-los, mas a dieta rende mais se for seguida à risca.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var mostPurchasedSection: some View {
        let topItems = Array(mealPlanService.topPurchasedItems.prefix(8))

        return Section {
            ForEach(topItems) { stat in
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
            .onDelete { indexSet in
                let statsToRemove = indexSet.map { topItems[$0] }
                for stat in statsToRemove {
                    mealPlanService.removePurchaseStat(stat)
                }
            }
        } header: {
            Label("Mais comprados", systemImage: "chart.bar.fill")
        } footer: {
            Text("Itens marcados como comprados na lista são contabilizados aqui. Deslize para remover do histórico.")
        }
    }

    private var energyDrinksSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Energéticos por semana")
                        .font(.subheadline.weight(.medium))
                    Text(energyDrinksPerWeek == 0
                         ? "Toque em + para incluir na lista"
                         : "\(energyDrinksPerWeek) un na lista de compras")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        updateEnergyDrinks(max(energyDrinksPerWeek - 1, 0))
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(energyDrinksPerWeek > 0 ? AppTheme.accentSecondary : .gray.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(energyDrinksPerWeek == 0)

                    Text("\(energyDrinksPerWeek)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 36)
                        .contentTransition(.numericText())

                    Button {
                        updateEnergyDrinks(min(energyDrinksPerWeek + 1, 14))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(energyDrinksPerWeek < 14 ? AppTheme.accent : .gray.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(energyDrinksPerWeek >= 14)
                }
            }
            .padding(.vertical, 4)

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
            Text("Use + e − para ajustar a quantidade. O número aparece ao lado e entra na lista de compras.")
        }
    }

    private func updateEnergyDrinks(_ count: Int) {
        mealPlanService.updateEnergyDrinksPerWeek(count, profile: authService.currentUser)
    }

    @ViewBuilder
    private var shoppingSections: some View {
        ForEach(groupedItems, id: \.0) { category, items in
            Section {
                ForEach(items) { item in
                    ShoppingItemRow(
                        item: item,
                        isInDiet: mealPlanService.isItemInCurrentDiet(item)
                    ) {
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
    var isInDiet: Bool = true
    let onToggle: () -> Void

    private var nameColor: Color {
        if !isInDiet { return .orange }
        return item.isPurchased ? .secondary : .primary
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? (isInDiet ? AppTheme.accent : .orange) : (isInDiet ? Color.gray : Color.orange))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.name)
                            .strikethrough(item.isPurchased)
                            .foregroundStyle(nameColor)
                            .fontWeight(isInDiet ? .regular : .semibold)
                        if !isInDiet {
                            Text("🤔")
                                .font(.body)
                                .accessibilityLabel("Item fora da dieta")
                        }
                    }

                    Text(item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !isInDiet {
                        Text(MealPlanService.offDietShoppingMessage)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isInDiet ? "Marcar como comprado" : "Item fora do cardápio. Ainda pode marcar como comprado.")
    }
}

struct WeeklyShoppingReportView: View {
    @Environment(\.dismiss) private var dismiss

    let report: WeeklyShoppingReport
    let athleteName: String

    private var reportText: String {
        ShoppingReportBuilder.textReport(report, athleteName: athleteName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard
                    if !report.purchasedItems.isEmpty {
                        itemsCard(title: "Comprados", icon: "checkmark.circle.fill", items: report.purchasedItems)
                    }
                    if !report.pendingItems.isEmpty {
                        itemsCard(title: "Pendentes", icon: "circle", items: report.pendingItems)
                    }
                    if !report.topPurchasedThisWeek.isEmpty {
                        topPurchasedCard(
                            title: "Mais comprados nesta semana",
                            stats: report.topPurchasedThisWeek
                        )
                    }
                    if !report.topPurchasedAllTime.isEmpty {
                        topPurchasedCard(
                            title: "Mais comprados (histórico)",
                            stats: report.topPurchasedAllTime
                        )
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Relatório Semanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: reportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(report.periodLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 16) {
                reportMetric(value: "\(report.purchasedCount)/\(report.totalItems)", label: "Comprados")
                reportMetric(value: "\(report.completionPercent)%", label: "Progresso")
                reportMetric(value: "\(report.energyDrinksPerWeek)", label: "Energéticos")
            }

            ProgressView(
                value: Double(report.purchasedCount),
                total: Double(max(report.totalItems, 1))
            )
            .tint(AppTheme.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func reportMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func itemsCard(title: String, icon: String, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                        Text("\(item.quantity) · \(item.category.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func topPurchasedCard(title: String, stats: [ShoppingPurchaseStat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            ForEach(Array(stats.prefix(10).enumerated()), id: \.element.id) { index, stat in
                HStack {
                    Text("\(index + 1).")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accentSecondary)
                        .frame(width: 20, alignment: .leading)
                    Text(stat.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(stat.purchaseCount)x")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AddCustomShoppingItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mealPlanService: MealPlanService

    let initialName: String
    var onAdded: () -> Void = {}

    @State private var itemName = ""
    @State private var itemQuantity = "1 un"
    @State private var selectedCategory: ShoppingCategory = .other
    @State private var errorMessage: String?

    private var canAdd: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Nome do item", text: $itemName)
                        .textInputAutocapitalization(.words)

                    TextField("Quantidade", text: $itemQuantity)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(ShoppingCategory.allCases) { category in
                            ShoppingCategoryPickerCard(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Categoria")
                } footer: {
                    Text("Escolha em qual seção da lista o item deve aparecer.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Novo item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        addItem()
                    }
                    .disabled(!canAdd)
                }
            }
            .onAppear {
                if itemName.isEmpty {
                    itemName = initialName
                }
            }
        }
    }

    private func addItem() {
        let added = mealPlanService.addCustomShoppingItem(
            name: itemName,
            quantity: itemQuantity,
            category: selectedCategory
        )

        if added {
            onAdded()
            dismiss()
        } else if mealPlanService.containsShoppingItem(named: itemName) {
            errorMessage = "Este item já está na sua lista."
        } else {
            errorMessage = "Informe um nome válido para o item."
        }
    }
}

private struct ShoppingCategoryPickerCard: View {
    let category: ShoppingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : AppTheme.accent)

                Text(category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
