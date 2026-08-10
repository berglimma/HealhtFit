import SwiftUI
import UIKit
import MessageUI

private struct NutritionistMailDraft: Identifiable {
    let id = UUID()
    let recipients: [String]
    let subject: String
    let body: String
}

struct MealPlanView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var trainingNutritionSync: TrainingNutritionSyncService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedDay = 0
    @State private var selectedOption = 0
    @State private var selectedMealId: UUID?
    @State private var showShoppingList = false
    @State private var nutritionTab = 0
    @State private var caloricDeficit = 400
    @State private var mailDraft: NutritionistMailDraft?
    @State private var pendingMailResult: MFMailComposeResult?
    @State private var showMailUnavailableAlert = false
    @State private var showEmailSentAlert = false
    @State private var showEmailFailedAlert = false
    @State private var emailWasSent = false
    @State private var showMealPlanUpdatedAlert = false

    private var selectedGoal: FitnessGoal {
        authService.currentUser?.goal ?? .muscleGain
    }

    private var selectedBiotype: Biotype {
        authService.currentUser?.biotype ?? .mesomorph
    }

    private var previewProfile: UserProfile? {
        guard var user = authService.currentUser else { return nil }
        user.goal = selectedGoal
        user.biotype = selectedBiotype
        user.caloricDeficit = caloricDeficit
        return user
    }

    var body: some View {
        NavigationStack {
            contentWithLifecycleHandlers
        }
        .requiresSubscription(.mealPlan)
    }

    private var contentWithLifecycleHandlers: some View {
        contentWithAlerts
            .onAppear(perform: syncFromProfile)
            .onChange(of: authService.currentUser?.goal) { _, _ in syncFromProfile() }
            .onChange(of: authService.currentUser?.biotype) { _, _ in syncFromProfile() }
            .onChange(of: authService.currentUser?.id) { _, _ in syncFromProfile() }
            .onChange(of: authService.currentUser?.weight) { _, _ in regeneratePlanFromProfileIfPossible() }
            .onChange(of: authService.currentUser?.height) { _, _ in regeneratePlanFromProfileIfPossible() }
            .onChange(of: authService.currentUser?.age) { _, _ in regeneratePlanFromProfileIfPossible() }
            .onChange(of: authService.currentUser?.gender) { _, _ in regeneratePlanFromProfileIfPossible() }
            .onChange(of: authService.currentUser?.caloricDeficit) { _, _ in syncCaloricDeficitFromProfile() }
            .onChange(of: selectedDay) { _, _ in
                selectedOption = 0
                selectedMealId = nil
            }
            .onChange(of: selectedOption) { _, _ in
                selectedMealId = nil
            }
    }

    private var contentWithAlerts: some View {
        contentWithSheets
            .alert("E-mail enviado", isPresented: $showEmailSentAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                emailSentAlertMessage
            }
            .alert("Falha no envio", isPresented: $showEmailFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Não foi possível enviar o e-mail. Verifique se há uma conta de e-mail configurada no iPhone (Ajustes → Mail → Contas).")
            }
            .alert("E-mail indisponível", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Configure uma conta de e-mail no iPhone ou cadastre o e-mail do nutricionista no Perfil.")
            }
            .alert("Cardápio atualizado", isPresented: $showMealPlanUpdatedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Seu cardápio semanal foi atualizado com base nas suas preferências e metas.")
            }
    }

    private var contentWithSheets: some View {
        mealPlanChrome
            .sheet(isPresented: $showShoppingList) {
                ShoppingListView()
            }
            .sheet(item: $mailDraft, onDismiss: presentAlertForPendingMailResult) { draft in
                nutritionistMailSheet(draft)
            }
    }

    private var mealPlanChrome: some View {
        mealPlanContent
            .scrollDismissesKeyboard(.interactively)
            .numericKeyboardDismiss()
            .background(AppTheme.background)
            .navigationTitle("Nutrição")
            .toolbar { shoppingCartToolbar }
    }

    @ViewBuilder
    private var mealPlanContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if trainingNutritionSync.hasActiveTrainingFocus {
                    trainingFocusBanner
                        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                        .padding(.top, 8)
                        .adaptiveContentWidth()
                }
                bodyMetricsSection
                menuPreferencesSection
                nutritionModeContent
            }
        }
    }

    private var trainingFocusBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("Cardápio alinhado ao treino")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(trainingNutritionSync.displayFocusLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                if let summary = trainingNutritionSync.adjustmentSummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let title = trainingNutritionSync.activeWorkoutTitle {
                    Text(title.replacingOccurrences(of: "Guiado — ", with: ""))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private var nutritionModeContent: some View {
        Picker("Modo", selection: $nutritionTab) {
            Text("Plano").tag(0)
            Text("Cardápio").tag(1)
            Text("Suplementos").tag(2)
            Text("Análise").tag(3)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))

        if nutritionTab == 2 {
            SupplementsLogView()
        } else if nutritionTab == 3 {
            MealPhotoAnalysisView()
        } else if mealPlanService.customMenuSelection.isReadyToBuild {
            if nutritionTab == 0 {
                weeklyPlanSection
            } else {
                menuBuilderSection
            }

            nutritionistReportSection
                .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .padding(.bottom, 24)
                .adaptiveContentWidth()
        } else {
            preferencesRequiredState
        }
    }

    @ToolbarContentBuilder
    private var shoppingCartToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showShoppingList = true
            } label: {
                Image(systemName: "cart.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private func nutritionistMailSheet(_ draft: NutritionistMailDraft) -> some View {
        MailComposeView(
            recipients: draft.recipients,
            subject: draft.subject,
            body: draft.body
        ) { result in
            pendingMailResult = result
            mailDraft = nil
        }
    }

    @ViewBuilder
    private var emailSentAlertMessage: some View {
        if let user = authService.currentUser {
            Text("O relatório de nutrição foi enviado para \(user.nutritionistName.isEmpty ? user.nutritionistEmail : user.nutritionistName) com sucesso.")
        } else {
            Text("O relatório de nutrição foi enviado com sucesso.")
        }
    }

    private func syncCaloricDeficitFromProfile() {
        if let deficit = authService.currentUser?.caloricDeficit {
            caloricDeficit = min(deficit, UserProfile.maxCaloricDeficit)
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

                BiotypeIdentificationHint(biotype: selectedBiotype)
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

            if let profile = previewProfile {
                Text("Dados físicos vêm do Perfil (peso, altura, idade e sexo).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

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
            .buttonStyle(PrimaryButtonStyle(isEnabled: hasProfileMetrics && mealPlanService.customMenuSelection.isReadyToBuild))
            .disabled(!hasProfileMetrics || !mealPlanService.customMenuSelection.isReadyToBuild)
        }
        .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .adaptiveContentWidth()
        .background(AppTheme.cardBackground)
    }

    private var weeklyPlanSection: some View {
        Group {
            if !mealPlanService.weeklyPlan.isEmpty {
                dayPicker

                if selectedDay < mealPlanService.weeklyPlan.count {
                    let dayPlan = mealPlanService.weeklyPlan[selectedDay]
                    let safeOption = min(selectedOption, max(dayPlan.options.count - 1, 0))
                    let activeOption = dayPlan.options[safeOption]

                    VStack(spacing: 16) {
                        mealReminderNotice
                        optionPicker(for: dayPlan, selected: safeOption)
                        macrosSummary(activeOption)
                        Text("Toque na refeição para selecionar e marque como concluída quando comer.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(activeOption.meals) { meal in
                            MealCard(
                                meal: meal,
                                isSelected: selectedMealId == meal.id,
                                onSelect: {
                                    selectedMealId = meal.id
                                },
                                onToggleCompleted: {
                                    selectedMealId = meal.id
                                    mealPlanService.toggleMealCompleted(
                                        dayIndex: selectedDay,
                                        optionIndex: safeOption,
                                        mealId: meal.id
                                    )
                                }
                            )
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

    private var menuPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Você tolera lactose?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    ForEach(LactoseTolerance.allCases) { tolerance in
                        Button {
                            updateLactoseTolerance(tolerance)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tolerance.icon)
                                    .font(.title3)
                                Text(tolerance.rawValue)
                                    .font(.caption.weight(.bold))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(
                                mealPlanService.customMenuSelection.lactoseTolerance == tolerance
                                    ? .white
                                    : AppTheme.textPrimary
                            )
                            .background(
                                mealPlanService.customMenuSelection.lactoseTolerance == tolerance
                                    ? AppTheme.accent
                                    : AppTheme.background
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let lactose = mealPlanService.customMenuSelection.lactoseTolerance {
                    Text(lactose.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Responda antes de montar o cardápio.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Você consome muito doce?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    ForEach(SweetConsumptionLevel.allCases) { level in
                        Button {
                            updateSweetConsumption(level)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: level.icon)
                                    .font(.title3)
                                Text(level.rawValue)
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(
                                mealPlanService.customMenuSelection.sweetConsumption == level
                                    ? .white
                                    : AppTheme.textPrimary
                            )
                            .background(
                                mealPlanService.customMenuSelection.sweetConsumption == level
                                    ? AppTheme.accent
                                    : AppTheme.background
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(mealPlanService.customMenuSelection.sweetConsumption.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                if let warning = mealPlanService.customMenuSelection.sweetConsumption.warningMessage {
                    let level = mealPlanService.customMenuSelection.sweetConsumption
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Atenção ao consumo de doces", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(level.warningColor)
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(level.warningColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if selectedGoal == .fatLoss {
                Label("Modo perda de gordura: opções restritivas com baixo carboidrato e sem frituras.", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }
        .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .adaptiveContentWidth()
        .padding(.vertical, 8)
    }

    private var nutritionistReportSection: some View {
        VStack(spacing: 12) {
            if let user = authService.currentUser, user.hasNutritionist {
                Button {
                    sendNutritionReport(to: user)
                } label: {
                    Label(
                        emailWasSent ? "Relatório enviado" : L10n.Nutrition.sendReport,
                        systemImage: emailWasSent ? "checkmark.circle.fill" : "envelope.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(emailWasSent ? Color.green : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(mailDraft != nil || emailWasSent || mealPlanService.weeklyPlan.isEmpty)

                if emailWasSent {
                    Label("E-mail enviado ao nutricionista", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }

                if !user.nutritionistName.isEmpty {
                    Text("Para: \(user.nutritionistName) · \(user.nutritionistEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Para: \(user.nutritionistEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("O relatório de Nutrição é enviado apenas ao nutricionista. Treinos continuam indo só para o personal.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Label("Nutricionista não cadastrado", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Cadastre nome e e-mail do nutricionista no Perfil para enviar o relatório desta aba.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 8)
    }

    private var preferencesRequiredState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Responda sobre lactose e doces para montar seu cardápio.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var menuBuilderSection: some View {
        VStack(spacing: 16) {
            if let profile = previewProfile {
                macrosSummary(mealPlanService.builtMenuOption(for: profile))

                Text("Escolha uma opção para cada refeição do dia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(MealType.allCases) { mealType in
                    mealSlotBuilder(mealType: mealType, profile: profile)
                }

                Button {
                    applyMetricsAndRegenerate()
                    nutritionTab = 0
                    if let dayCount = mealPlanService.weeklyPlan.first?.options.count {
                        selectedOption = max(dayCount - 1, 0)
                    }
                } label: {
                    Label("Salvar no Plano Semanal", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: hasProfileMetrics))
                .disabled(!hasProfileMetrics)
                .padding(.top, 8)
            } else {
                Text("Complete Seus Dados no Perfil (peso, altura, idade e sexo) para montar o cardápio.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 24)
            }
        }
        .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .padding(.bottom, 24)
        .adaptiveContentWidth()
    }

    @ViewBuilder
    private func mealSlotBuilder(mealType: MealType, profile: UserProfile) -> some View {
        if let lactose = mealPlanService.customMenuSelection.lactoseTolerance {
            let sweetLevel = mealPlanService.customMenuSelection.sweetConsumption
            let options = MealCatalog.templates(
                for: mealType,
                sweetLevel: sweetLevel,
                goal: profile.goal,
                lactoseTolerance: lactose
            )
            let selectedID = mealPlanService.customMenuSelection.selectedTemplateID(for: mealType)

            VStack(alignment: .leading, spacing: 10) {
            Label(mealType.rawValue, systemImage: mealType.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options) { template in
                        let isSelected = selectedID == template.id
                        let scaled = template.scaled(
                            to: max(Int(Double(profile.dailyCalorieTarget) * mealType.calorieShare), 120),
                            proteinMultiplier: profile.goal == .muscleGain ? 2 : 1
                        )

                        Button {
                            mealPlanService.updateMealSelection(template.id, for: mealType, profile: profile)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(template.name)
                                        .font(.caption.weight(.bold))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    if template.isFatLossFocused {
                                        Image(systemName: "flame.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    if template.isSweet {
                                        Image(systemName: "birthday.cake.fill")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.accentSecondary)
                                    }
                                    if template.containsLactose {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.blue.opacity(0.8))
                                    }
                                }
                                Text("\(scaled.calories) kcal")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.accentSecondary)
                                Text("P:\(scaled.protein)g C:\(scaled.carbs)g")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(width: 148, alignment: .leading)
                            .padding(10)
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
            .padding()
            .background(AppTheme.cardBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func updateSweetConsumption(_ level: SweetConsumptionLevel) {
        mealPlanService.updateSweetConsumption(level, profile: previewProfile ?? authService.currentUser)
    }

    private func updateLactoseTolerance(_ tolerance: LactoseTolerance) {
        mealPlanService.updateLactoseTolerance(tolerance, profile: previewProfile ?? authService.currentUser)
    }

    private var hasProfileMetrics: Bool {
        guard let user = authService.currentUser else { return false }
        return user.weight >= 30 && user.weight <= 300
            && user.height >= 100 && user.height <= 250
            && user.age >= 14 && user.age <= 100
    }

    private func sendNutritionReport(to user: UserProfile) {
        let recipient = user.nutritionistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            showMailUnavailableAlert = true
            return
        }
        guard !mealPlanService.weeklyPlan.isEmpty else { return }

        let subject = NutritionReportBuilder.emailSubject(athleteName: user.name)
        let body = NutritionReportBuilder.emailBody(
            athlete: user,
            weeklyPlan: mealPlanService.weeklyPlan,
            customMenu: mealPlanService.customMenuSelection,
            shoppingList: mealPlanService.shoppingList,
            selectedOptionIndex: selectedOption
        )

        if MailComposeView.canSendMail {
            pendingMailResult = nil
            mailDraft = NutritionistMailDraft(
                recipients: [recipient],
                subject: subject,
                body: body
            )
        } else if let url = MailComposeView.mailtoURL(
            recipients: [recipient],
            subject: subject,
            body: body
        ) {
            UIApplication.shared.open(url) { accepted in
                if accepted {
                    emailWasSent = true
                } else {
                    showMailUnavailableAlert = true
                }
            }
        } else {
            showMailUnavailableAlert = true
        }
    }

    private func presentAlertForPendingMailResult() {
        guard let result = pendingMailResult else { return }
        pendingMailResult = nil

        switch result {
        case .sent:
            emailWasSent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailSentAlert = true
            }
        case .failed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailFailedAlert = true
            }
        case .cancelled, .saved:
            break
        @unknown default:
            break
        }
    }

    private func syncFromProfile() {
        guard let user = authService.currentUser else { return }
        caloricDeficit = min(user.caloricDeficit, UserProfile.maxCaloricDeficit)

        if mealPlanService.basalMetabolicRate == 0 {
            mealPlanService.basalMetabolicRate = user.basalMetabolicRate
            mealPlanService.estimatedTDEE = user.estimatedTDEE
            mealPlanService.caloricDeficit = user.caloricDeficit
            mealPlanService.dailyCalorieTarget = user.dailyCalorieTarget
        }
    }

    private func regeneratePlanFromProfileIfPossible() {
        guard let user = authService.currentUser else { return }
        mealPlanService.regeneratePlanIfNeeded(for: user)
    }

    private var isDeficitEnabled: Bool {
        selectedGoal == .fatLoss || selectedGoal == .maintenance
    }

    private func caloricDeficitSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Déficit Calórico")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Gasto diário estimado (TDEE): \(profile.estimatedTDEE) kcal")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack {
                Text("Déficit diário")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        adjustCaloricDeficit(by: -50)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isDeficitEnabled && caloricDeficit > 0 ? AppTheme.accent : AppTheme.textSecondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDeficitEnabled || caloricDeficit <= 0)

                    Text("-\(caloricDeficit) kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                        .frame(minWidth: 72)

                    Button {
                        adjustCaloricDeficit(by: 50)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isDeficitEnabled && caloricDeficit < UserProfile.maxCaloricDeficit ? AppTheme.accent : AppTheme.textSecondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDeficitEnabled || caloricDeficit >= UserProfile.maxCaloricDeficit)
                }
            }

            if !isDeficitEnabled {
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

    private func adjustCaloricDeficit(by delta: Int) {
        let newValue = min(max(caloricDeficit + delta, 0), UserProfile.maxCaloricDeficit)
        guard newValue != caloricDeficit, var user = authService.currentUser else { return }
        caloricDeficit = newValue
        user.caloricDeficit = newValue
        authService.updateProfile(user)
        mealPlanService.caloricDeficit = newValue
        mealPlanService.dailyCalorieTarget = user.dailyCalorieTarget
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
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
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
    }

    private func updateGoal(_ goal: FitnessGoal) {
        guard var user = authService.currentUser, user.goal != goal else { return }
        user.goal = goal
        if goal == .fatLoss && user.caloricDeficit == 0 {
            user.caloricDeficit = 400
            caloricDeficit = 400
        }
        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
    }

    private func applyMetricsAndRegenerate() {
        guard mealPlanService.customMenuSelection.isReadyToBuild,
              var user = authService.currentUser else { return }

        user.goal = selectedGoal
        user.biotype = selectedBiotype
        user.caloricDeficit = caloricDeficit
        authService.updateProfile(user)
        mealPlanService.generatePlan(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
        showMealPlanUpdatedAlert = true
    }

    private var mealReminderNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(AppTheme.accentSecondary)
            Text("Configure em Perfil se deseja notificações de alimentação e os horários habituais de cada refeição. Os alertas disparam no horário cadastrado.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func optionPicker(for dayPlan: DailyMealPlan, selected: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(dayPlan.dayOfWeek) — escolha um cardápio")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 8) {
                ForEach(Array(dayPlan.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        selectedOption = index
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.name)
                                .font(.caption.weight(.bold))
                            Text(option.subtitle)
                                .font(.caption2)
                                .lineLimit(1)
                            Text("\(option.totalCalories) kcal")
                                .font(.caption2.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .foregroundStyle(selected == index ? .white : AppTheme.textPrimary)
                        .background(selected == index ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func macrosSummary(_ option: MealPlanOption) -> some View {
        let completedCount = option.meals.filter(\.isCompleted).count
        let totalMeals = option.meals.count
        let eatenCalories = option.meals.filter(\.isCompleted).reduce(0) { $0 + $1.calories }

        return VStack(spacing: 12) {
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
                MacroPill(label: "Calorias", value: "\(option.totalCalories)", unit: "kcal", color: AppTheme.accentSecondary)
                MacroPill(label: "Proteína", value: "\(option.totalProtein)", unit: "g", color: AppTheme.accent)
            }

            if mealPlanService.dailyCalorieTarget > 0 {
                let difference = option.totalCalories - mealPlanService.dailyCalorieTarget
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

            if totalMeals > 0 {
                HStack {
                    Label(
                        "Refeições: \(completedCount)/\(totalMeals) concluídas",
                        systemImage: completedCount == totalMeals ? "checkmark.seal.fill" : "fork.knife.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completedCount == totalMeals ? AppTheme.accent : AppTheme.textSecondary)
                    Spacer()
                    Text("\(eatenCalories) kcal feitas")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onToggleCompleted: (() -> Void)? = nil
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    onToggleCompleted?()
                } label: {
                    Image(systemName: meal.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(meal.isCompleted ? AppTheme.accent : AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(meal.isCompleted ? "Marcar como não concluída" : "Marcar como concluída")

                Button {
                    onSelect?()
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: meal.mealType.icon)
                            .foregroundStyle(meal.isCompleted ? AppTheme.accent : AppTheme.accentSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(meal.mealType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                if meal.isCompleted {
                                    Text(L10n.Nutrition.mealCompleted)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.accent.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(meal.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                                .strikethrough(meal.isCompleted, color: AppTheme.textSecondary)
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
                .buttonStyle(.plain)
            }

            if isSelected {
                Text(meal.isCompleted
                     ? "Selecionada · toque no círculo para desmarcar a conclusão"
                     : "Selecionada · toque no círculo para marcar como concluída")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
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

                Button {
                    onToggleCompleted?()
                } label: {
                    Label(
                        meal.isCompleted ? L10n.Nutrition.markIncomplete : L10n.Nutrition.markCompleted,
                        systemImage: meal.isCompleted ? "xmark.circle" : "checkmark.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(meal.isCompleted ? AppTheme.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(meal.isCompleted ? AppTheme.background : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(
                    isSelected ? AppTheme.accent.opacity(0.8) : (meal.isCompleted ? AppTheme.accent.opacity(0.35) : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .opacity(meal.isCompleted && !isSelected ? 0.85 : 1)
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
