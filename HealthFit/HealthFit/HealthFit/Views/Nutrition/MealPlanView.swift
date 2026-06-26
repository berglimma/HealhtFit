import SwiftUI
import UIKit

struct MealPlanView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @State private var selectedDay = 0
    @State private var showShoppingList = false
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var selectedGender: Gender = .male
    @State private var selectedGoal: FitnessGoal = .muscleGain
    @State private var selectedBiotype: Biotype = .mesomorph

    private var previewProfile: UserProfile? {
        guard var user = authService.currentUser else { return nil }
        if let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            user.weight = weight
        }
        if let height = Double(heightText.replacingOccurrences(of: ",", with: ".")) {
            user.height = height
        }
        if let age = Int(ageText) {
            user.age = age
        }
        user.gender = selectedGender
        user.goal = selectedGoal
        user.biotype = selectedBiotype
        return user
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    bodyMetricsSection

                    if !mealPlanService.weeklyPlan.isEmpty {
                        dayPicker

                        if selectedDay < mealPlanService.weeklyPlan.count {
                            let dayPlan = mealPlanService.weeklyPlan[selectedDay]
                            VStack(spacing: 16) {
                                macrosSummary(dayPlan)
                                ForEach(dayPlan.meals) { meal in
                                    MealCard(meal: meal)
                                }
                            }
                            .padding(AppTheme.padding)
                            .padding(.bottom, 24)
                        }
                    } else {
                        emptyState
                            .padding(.vertical, 40)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background)
            .navigationTitle("Nutrição")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShoppingList = true
                    } label: {
                        Image(systemName: "cart.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showShoppingList) {
                ShoppingListView()
            }
            .onAppear {
                syncFromProfile()
            }
            .onChange(of: authService.currentUser) { _, _ in
                syncFromProfile()
            }
        }
    }

    private var bodyMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plano para \(selectedBiotype.rawValue)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Objetivo: \(selectedGoal.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Biotipo")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Biotype.allCases) { biotype in
                        BiotypeCard(
                            biotype: biotype,
                            isSelected: selectedBiotype == biotype
                        ) {
                            updateBiotype(biotype)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Objetivo")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(FitnessGoal.allCases) { goal in
                        GoalCard(goal: goal, isSelected: selectedGoal == goal) {
                            updateGoal(goal)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Seus Dados")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 12) {
                    MetricField(label: "Peso", unit: "kg", text: $weightText)
                    MetricField(label: "Altura", unit: "cm", text: $heightText)
                }

                HStack(spacing: 12) {
                    MetricField(label: "Idade", unit: "anos", text: $ageText, keyboard: .numberPad)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sexo")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Picker("Sexo", selection: $selectedGender) {
                            ForEach(Gender.allCases) { gender in
                                Text(gender.rawValue).tag(gender)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            if let profile = previewProfile {
                HStack(spacing: 12) {
                    MetabolicCard(
                        title: "Metabolismo Basal",
                        subtitle: "TMB (repouso)",
                        value: "\(profile.basalMetabolicRate)",
                        unit: "kcal/dia",
                        icon: "heart.fill",
                        color: .red
                    )
                    MetabolicCard(
                        title: "Meta Diária",
                        subtitle: "Com treino",
                        value: "\(profile.dailyCalorieTarget)",
                        unit: "kcal/dia",
                        icon: "flame.fill",
                        color: AppTheme.accentSecondary
                    )
                }

                HStack {
                    Label("IMC: \(String(format: "%.1f", profile.bmi))", systemImage: "figure.stand")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
            }

            Button {
                applyMetricsAndRegenerate()
            } label: {
                Label("Atualizar Cardápio", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: isMetricsValid))
            .disabled(!isMetricsValid)
        }
        .padding()
        .background(AppTheme.cardBackground)
    }

    private var isMetricsValid: Bool {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let age = Int(ageText) else { return false }
        return weight >= 30 && weight <= 300 && height >= 100 && height <= 250 && age >= 14 && age <= 100
    }

    private func syncFromProfile() {
        guard let user = authService.currentUser else { return }
        selectedBiotype = user.biotype
        selectedGoal = user.goal
        weightText = String(format: "%.1f", user.weight)
        heightText = String(format: "%.0f", user.height)
        ageText = "\(user.age)"
        selectedGender = user.gender

        if mealPlanService.basalMetabolicRate == 0 {
            mealPlanService.basalMetabolicRate = user.basalMetabolicRate
            mealPlanService.dailyCalorieTarget = user.dailyCalorieTarget
        }
    }

    private func updateBiotype(_ biotype: Biotype) {
        guard var user = authService.currentUser, user.biotype != biotype else { return }
        user.biotype = biotype
        authService.updateProfile(user)
        selectedBiotype = biotype
        mealPlanService.regeneratePlanIfNeeded(for: user)
    }

    private func updateGoal(_ goal: FitnessGoal) {
        guard var user = authService.currentUser, user.goal != goal else { return }
        user.goal = goal
        authService.updateProfile(user)
        selectedGoal = goal
        mealPlanService.regeneratePlanIfNeeded(for: user)
    }

    private func applyMetricsAndRegenerate() {
        guard var user = authService.currentUser,
              let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let age = Int(ageText) else { return }

        user.weight = weight
        user.height = height
        user.age = age
        user.gender = selectedGender
        user.goal = selectedGoal
        user.biotype = selectedBiotype
        authService.updateProfile(user)
        mealPlanService.generatePlan(for: user)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(mealPlanService.weeklyPlan.enumerated()), id: \.element.id) { index, day in
                    Button {
                        selectedDay = index
                    } label: {
                        Text(day.dayOfWeek.prefix(3))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedDay == index ? .white : AppTheme.textSecondary)
                            .background(selectedDay == index ? AppTheme.accent : AppTheme.cardBackground)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func macrosSummary(_ plan: DailyMealPlan) -> some View {
        VStack(spacing: 12) {
            if mealPlanService.dailyCalorieTarget > 0 {
                HStack {
                    Text("Meta: \(mealPlanService.dailyCalorieTarget) kcal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("TMB: \(mealPlanService.basalMetabolicRate) kcal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            HStack(spacing: 16) {
                MacroPill(label: "Calorias", value: "\(plan.totalCalories)", unit: "kcal", color: AppTheme.accentSecondary)
                MacroPill(label: "Proteína", value: "\(plan.totalProtein)", unit: "g", color: AppTheme.accent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nenhum plano gerado")
                .foregroundStyle(AppTheme.textSecondary)
            Button("Gerar Cardápio") {
                applyMetricsAndRegenerate()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.padding)
    }
}

struct MealCard: View {
    let meal: Meal
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: meal.mealType.icon)
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.mealType.rawValue)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(meal.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(meal.calories) kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                        Text("P:\(meal.protein)g C:\(meal.carbs)g G:\(meal.fat)g")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if isExpanded {
                Divider().background(Color.white.opacity(0.1))
                Text("Ingredientes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(meal.ingredients, id: \.self) { ingredient in
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                        Text(ingredient)
                            .font(.caption)
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
                if !meal.instructions.isEmpty {
                    Text(meal.instructions)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

struct MetricField: View {
    let label: String
    let unit: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(keyboard)
                    .padding(10)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MetabolicCard: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MacroPill: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                Text(unit)
                    .font(.caption)
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
