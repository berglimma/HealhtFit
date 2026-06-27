import SwiftUI
import UIKit

struct MealPlanView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDay = 0
    @State private var showShoppingList = false
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var selectedGender: Gender = .male
    @State private var selectedGoal: FitnessGoal = .muscleGain
    @State private var selectedBiotype: Biotype = .mesomorph
    @State private var caloricDeficit = 400

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
        user.caloricDeficit = caloricDeficit
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
                            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                            .padding(.bottom, 24)
                            .adaptiveContentWidth()
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
            .onChange(of: caloricDeficit) { _, newValue in
                guard var user = authService.currentUser, user.caloricDeficit != newValue else { return }
                user.caloricDeficit = newValue
                authService.updateProfile(user)
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
                AdaptiveBiotypeRow {
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
                AdaptiveGoalGrid {
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
                caloricDeficitSection(profile: profile)

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
                        subtitle: deficitSubtitle(for: profile),
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
                    Label("TDEE: \(profile.estimatedTDEE) kcal", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
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
        .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .adaptiveContentWidth()
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
        caloricDeficit = user.caloricDeficit

        if mealPlanService.basalMetabolicRate == 0 {
            mealPlanService.basalMetabolicRate = user.basalMetabolicRate
            mealPlanService.estimatedTDEE = user.estimatedTDEE
            mealPlanService.caloricDeficit = user.caloricDeficit
            mealPlanService.dailyCalorieTarget = user.dailyCalorieTarget
        }
    }

    private func caloricDeficitSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Déficit Calórico")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Gasto diário estimado (TDEE): \(profile.estimatedTDEE) kcal")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Stepper(value: $caloricDeficit, in: 0...1000, step: 50) {
                HStack {
                    Text("Déficit diário")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("-\(caloricDeficit) kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
            .disabled(selectedGoal == .muscleGain || selectedGoal == .endurance)

            if selectedGoal == .muscleGain || selectedGoal == .endurance {
                Text("Déficit desativado para objetivos de ganho de massa ou resistência.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Meta calórica final")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(profile.dailyCalorieTarget) kcal/dia")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }

                if profile.effectiveCaloricDeficit > 0 {
                    HStack {
                        Text("Perda estimada")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text(String(format: "~%.2f kg/semana", profile.estimatedWeeklyWeightLoss))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
            }
            .padding()
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func deficitSubtitle(for profile: UserProfile) -> String {
        if profile.effectiveCaloricDeficit > 0 {
            return "TDEE − \(profile.effectiveCaloricDeficit) kcal"
        }
        return "Com treino"
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
        if goal == .fatLoss && user.caloricDeficit == 0 {
            user.caloricDeficit = 400
            caloricDeficit = 400
        }
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
        user.caloricDeficit = caloricDeficit
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
                    if mealPlanService.caloricDeficit > 0 {
                        Text("Déficit: −\(mealPlanService.caloricDeficit) kcal")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
                HStack {
                    Text("TMB: \(mealPlanService.basalMetabolicRate) kcal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("TDEE: \(mealPlanService.estimatedTDEE) kcal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            HStack(spacing: 16) {
                MacroPill(label: "Calorias", value: "\(plan.totalCalories)", unit: "kcal", color: AppTheme.accentSecondary)
                MacroPill(label: "Proteína", value: "\(plan.totalProtein)", unit: "g", color: AppTheme.accent)
            }

            if mealPlanService.dailyCalorieTarget > 0 {
                let difference = plan.totalCalories - mealPlanService.dailyCalorieTarget
                HStack {
                    Text("vs meta diária")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(difference == 0 ? "Na meta" : "\(difference > 0 ? "+" : "")\(difference) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(difference <= 0 ? AppTheme.accent : AppTheme.accentSecondary)
                }
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
