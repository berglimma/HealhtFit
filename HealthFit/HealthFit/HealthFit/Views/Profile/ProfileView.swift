import SwiftUI
import PhotosUI
import Photos
import UIKit

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var evolutionService: BodyEvolutionService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountSheet = false
    @State private var showProfilePhotoPicker = false
    @State private var trainerName = ""
    @State private var trainerEmail = ""
    @State private var usesPersonalTrainer = false
    @State private var nutritionistName = ""
    @State private var nutritionistEmail = ""
    @State private var usesNutritionist = false
    @State private var displayName = ""
    @State private var sleepHoursInput: Double = 7
    @State private var neckText = ""
    @State private var shouldersText = ""
    @State private var chestText = ""
    @State private var rightArmText = ""
    @State private var leftArmText = ""
    @State private var waistText = ""
    @State private var abdomenText = ""
    @State private var hipText = ""
    @State private var rightThighText = ""
    @State private var leftThighText = ""
    @State private var rightCalfText = ""
    @State private var leftCalfText = ""
    @State private var showMeasurementsSavedAlert = false
    @State private var measurementsSaveError: String?
    @State private var measurementComparison: BodyMeasurementComparison?
    @State private var showMeasurementComparison = false
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var selectedGender: Gender = .male
    @State private var showBodyDataSavedAlert = false
    @State private var showEmptyMeasurementsAlert = false
    @State private var bodyDataSaveError: String?

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    profileHeaderSection(for: user)
                    displayNameSection(for: user)
                    biotypeSection(for: user)
                    personalTrainerSection
                    nutritionistSection
                    healthIconSection
                    Section("Sono e Hidratação") {
                        wellnessSection(for: user)
                    }
                    Section("Energéticos e Pré-treino") {
                        energyDrinksSection
                    }
                    Section("Seus Dados") {
                        bodyDataSection(for: user)
                    }
                    Section("Medidas Corporais") {
                        bodyMeasurementsSection(for: user)
                    }
                    Section("Evolução Corporal") {
                        // NavigationLink puro no List responde a toque simples; evita Button/wrapper.
                        NavigationLink {
                            BodyEvolutionView()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Fotos e comparativo (30 dias)", systemImage: "camera.viewfinder")
                                Text(evolutionService.meta.statusLabel)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("Fotos opcionais e privadas — só você acessa.")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    integrationsSection
                    restTimerSection
                    aboutSection
                    Section("Legal") {
                        LegalLinksView(style: .list, showsSupportLink: true)
                    }
                    accountActionsSection
                }
            }
            .adaptiveContentWidth()
            .navigationTitle("Perfil")
            .scrollDismissesKeyboard(.immediately)
            .numericKeyboardDismiss()
            // Não usa dismissKeyboardOnTap(): TapGesture no List compete com PhotosPicker/Buttons
            // e força long-press. Teclado fecha via scroll + botão OK do numericKeyboardDismiss.
            .onAppear {
                syncTrainerFields()
                syncDisplayNameField()
                syncWellnessFields()
                syncPreWorkoutFromWorkouts()
                syncBodyMeasurementFields()
                syncBodyDataFields()
                if let userId = authService.currentUser?.id {
                    Task { await evolutionService.loadIfNeeded(userId: userId) }
                }
            }
            .onChange(of: authService.currentUser) { _, _ in
                syncTrainerFields()
                syncDisplayNameField()
                syncBodyMeasurementFields()
                syncBodyDataFields()
            }
            .onChange(of: wellnessService.todayEntry) { _, _ in
                syncWellnessFields()
            }
            .onChange(of: workoutStore.sessionHistory.count) { _, _ in
                syncPreWorkoutFromWorkouts()
            }
            .sheet(isPresented: $showProfilePhotoPicker) {
                ProfilePHPicker { image in
                    showProfilePhotoPicker = false
                    guard let image else { return }
                    authService.updateProfileImage(image)
                }
                .ignoresSafeArea()
            }
            .alert("Sair da conta?", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Sair", role: .destructive) {
                    authService.logout()
                }
            }
            .alert("Medidas salvas", isPresented: $showMeasurementsSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("As medidas corporais foram salvas e sincronizadas com o Firebase. Elas entram no relatório enviado ao personal.")
            }
            .alert("Dados salvos", isPresented: $showBodyDataSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Peso, altura, idade e sexo foram sincronizados com o Firebase.")
            }
            .alert("Medidas necessárias", isPresented: $showEmptyMeasurementsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Por favor, preencha as medidas para salvar.")
            }
            .sheet(isPresented: $showMeasurementComparison) {
                if let comparison = measurementComparison {
                    BodyMeasurementComparisonView(comparison: comparison)
                }
            }
            .alert(
                "Não foi possível salvar",
                isPresented: Binding(
                    get: { measurementsSaveError != nil || bodyDataSaveError != nil },
                    set: { if !$0 {
                        measurementsSaveError = nil
                        bodyDataSaveError = nil
                    } }
                )
            ) {
                Button("OK", role: .cancel) {
                    measurementsSaveError = nil
                    bodyDataSaveError = nil
                }
            } message: {
                Text(measurementsSaveError ?? bodyDataSaveError ?? "")
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                DeleteAccountSheet(
                    requiresPassword: authService.usesPasswordProvider,
                    requiresAppleReauthentication: authService.usesAppleProvider
                )
            }
        }
    }

    @ViewBuilder
    private func profileHeaderSection(for user: UserProfile) -> some View {
        let profileImage = authService.profileImage
        Section {
            HStack(spacing: 16) {
                // Button + PHPicker sheet: PhotosPicker dentro de List costuma exigir long-press.
                Button {
                    showProfilePhotoPicker = true
                } label: {
                    ProfileAvatarView(
                        image: profileImage,
                        initial: String(user.greetingName.prefix(1).uppercased())
                    )
                    .contentShape(Circle())
                }
                .buttonStyle(ListSafeButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.shownName)
                        .font(.headline)
                    Text(user.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profileImage == nil ? "Toque para adicionar foto" : "Toque para alterar foto")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                let healthStatus = wellnessService.healthIconStatus()
                PulsingHeartIconView(size: 44, glowColor: healthStatus.glowColor)

                if profileImage != nil {
                    Button {
                        authService.updateProfileImage(nil)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ListSafeButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func displayNameSection(for user: UserProfile) -> some View {
        Section("Como você gostaria de ser chamado?") {
            TextField("Seu apelido ou primeiro nome", text: $displayName)
                .textContentType(.nickname)
                .onChange(of: displayName) { _, _ in
                    saveDisplayName()
                }

            if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               displayName.trimmingCharacters(in: .whitespacesAndNewlines) != user.name {
                Text("Nome completo: \(user.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Usado nas saudações, motivação e mensagens do app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func biotypeSection(for user: UserProfile) -> some View {
        Section("Biotipo") {
            AdaptiveBiotypeRow {
                ForEach(Biotype.allCases) { biotype in
                    BiotypeCard(
                        biotype: biotype,
                        isSelected: user.biotype == biotype
                    ) {
                        updateBiotype(biotype)
                    }
                }
            }
            .padding(.vertical, 4)

            BiotypeIdentificationHint(biotype: user.biotype)
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    @ViewBuilder
    private var personalTrainerSection: some View {
        Section(L10n.Profile.personalTrainer) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Profile.hasPersonalTrainer)
                    .font(.subheadline.weight(.medium))
                Picker("Possui personal?", selection: $usesPersonalTrainer) {
                    Text(L10n.Common.no).tag(false)
                    Text(L10n.Common.yes).tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesPersonalTrainer) { _, enabled in
                    updatePersonalTrainerAvailability(enabled)
                }
            }

            if usesPersonalTrainer {
                TextField(L10n.Profile.trainerName, text: $trainerName)
                    .textContentType(.name)
                    .onChange(of: trainerName) { _, _ in
                        savePersonalTrainer()
                    }

                TextField(L10n.Profile.trainerEmail, text: $trainerEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: trainerEmail) { _, _ in
                        savePersonalTrainer()
                    }

                if authService.currentUser?.hasPersonalTrainer == true {
                    Label("Relatórios de treino poderão ser enviados por e-mail", systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text("Cadastre o e-mail para enviar relatórios após cada treino.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sem personal cadastrado. A edição de nome e e-mail fica bloqueada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var nutritionistSection: some View {
        Section(L10n.Profile.nutritionist) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Profile.hasNutritionist)
                    .font(.subheadline.weight(.medium))
                Picker("Possui nutricionista?", selection: $usesNutritionist) {
                    Text(L10n.Common.no).tag(false)
                    Text(L10n.Common.yes).tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usesNutritionist) { _, enabled in
                    updateNutritionistAvailability(enabled)
                }
            }

            if usesNutritionist {
                TextField(L10n.Profile.nutritionistName, text: $nutritionistName)
                    .textContentType(.name)
                    .onChange(of: nutritionistName) { _, _ in
                        saveNutritionist()
                    }

                TextField(L10n.Profile.nutritionistEmail, text: $nutritionistEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: nutritionistEmail) { _, _ in
                        saveNutritionist()
                    }

                if authService.currentUser?.hasNutritionist == true {
                    Label("Relatórios da aba Nutrição poderão ser enviados por e-mail", systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text("Cadastre o e-mail para enviar o relatório de nutrição ao nutricionista.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sem nutricionista cadastrado. A edição de nome e e-mail fica bloqueada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var healthIconSection: some View {
        Section("Ícone de Saúde") {
            let healthStatus = wellnessService.healthIconStatus()

            HStack(alignment: .top, spacing: 14) {
                PulsingHeartIconView(
                    size: 40,
                    glowColor: healthStatus.glowColor
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(healthStatus.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthStatus.glowColor)

                    Text(wellnessService.healthIconDetailMessage())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("O ícone do app na tela inicial usa a mesma cor.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var integrationsSection: some View {
        Section("Integrações") {
            HStack {
                Label("HealthKit", systemImage: "heart.text.square.fill")
                Spacer()
                Text(healthKitManager.isAuthorized ? "Conectado" : "Pendente")
                    .foregroundStyle(healthKitManager.isAuthorized ? .green : .orange)
                    .font(.caption)
            }

            HStack {
                Label("Apple Watch", systemImage: "applewatch")
                Spacer()
                Text("Sincronização ativa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Notificações", systemImage: "bell.fill")
                Spacer()
                Text("Ativas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var restTimerSection: some View {
        Section("Cronômetro de Descanso") {
            Stepper(
                "Descanso padrão: \(timerService.configuredRestSeconds)s",
                value: Binding(
                    get: { timerService.configuredRestSeconds },
                    set: { timerService.configure(restSeconds: $0, maxRest: timerService.maxRestSeconds, notifications: timerService.notificationEnabled) }
                ),
                in: 15...300,
                step: 15
            )

            Stepper(
                "Alerta após: \(timerService.maxRestSeconds)s",
                value: Binding(
                    get: { timerService.maxRestSeconds },
                    set: { timerService.configure(restSeconds: timerService.configuredRestSeconds, maxRest: $0, notifications: timerService.notificationEnabled) }
                ),
                in: 30...600,
                step: 30
            )

            Toggle("Notificações de descanso", isOn: Binding(
                get: { timerService.notificationEnabled },
                set: { timerService.configure(restSeconds: timerService.configuredRestSeconds, maxRest: timerService.maxRestSeconds, notifications: $0) }
            ))
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("Sobre") {
            LabeledContent("App", value: "HealthFit")
            LabeledContent("Desenvolvedores", value: AppInfo.developerPeople)
            Text(AppInfo.developerCredit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accountActionsSection: some View {
        Section {
            Button("Sair da Conta", role: .destructive) {
                showLogoutAlert = true
            }

            Button("Excluir Conta", role: .destructive) {
                showDeleteAccountSheet = true
            }
        }
    }

    private func syncTrainerFields() {
        trainerName = authService.currentUser?.personalTrainerName ?? ""
        trainerEmail = authService.currentUser?.personalTrainerEmail ?? ""
        usesPersonalTrainer = authService.currentUser?.usesPersonalTrainer ?? false
        nutritionistName = authService.currentUser?.nutritionistName ?? ""
        nutritionistEmail = authService.currentUser?.nutritionistEmail ?? ""
        usesNutritionist = authService.currentUser?.usesNutritionist ?? false
    }

    private func syncDisplayNameField() {
        displayName = authService.currentUser?.displayName ?? ""
    }

    private func saveDisplayName() {
        guard var user = authService.currentUser else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.displayName != trimmed else { return }
        user.displayName = trimmed
        authService.updateProfile(user)
    }

    @ViewBuilder
    private func wellnessSection(for user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Horas de sono (hoje)")
                .font(.subheadline.weight(.medium))

            HStack {
                Text(String(format: "%.1f h", sleepHoursInput))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if let assessment = wellnessService.todaySleepAssessment {
                    Label(assessment.title, systemImage: assessment.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(assessment.color)
                } else {
                    let preview = SleepAssessment.evaluate(hours: sleepHoursInput)
                    Label(preview.title, systemImage: preview.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(preview.color)
                }
            }

            Slider(value: $sleepHoursInput, in: 0...12, step: 0.5)
                .tint(AppTheme.accent)
                .onChange(of: sleepHoursInput) { _, newValue in
                    wellnessService.logSleep(hours: newValue)
                }

            if let assessment = wellnessService.todaySleepAssessment {
                Text(assessment.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Registre seu sono ao abrir o app ou ajuste o controle acima.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 12) {
            Text("Água recomendada")
                .font(.subheadline.weight(.medium))

            HStack {
                Label(
                    String(format: "%.1f L / dia", user.recommendedDailyWaterLiters),
                    systemImage: "drop.fill"
                )
                .foregroundStyle(.blue)
                Spacer()
                Text("\(user.recommendedDailyWaterML) ml")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("Cálculo: 35 ml por kg de peso corporal (\(String(format: "%.1f", user.weight)) kg). Equivale a cerca de \(user.recommendedWaterGlasses) copos (\(WaterServing.glassML) ml) ou \(user.recommendedWaterBottles) garrafas (\(WaterServing.bottleML) ml).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ProgressView(value: wellnessService.waterProgress(for: user))
                .tint(
                    wellnessService.hasMetWaterGoal(for: user)
                        ? AppTheme.accent
                        : .red
                )

            HStack {
                Text("\(wellnessService.todayEntry.waterIntakeMl) ml ingeridos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        wellnessService.hasMetWaterGoal(for: user)
                            ? AppTheme.accent
                            : .red
                    )
                Spacer()
                Text(wellnessService.waterStatusMessage(for: user))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        wellnessService.hasMetWaterGoal(for: user)
                            ? AppTheme.accent
                            : .red
                    )
                    .multilineTextAlignment(.trailing)
            }

            Stepper(
                "Copos (\(WaterServing.glassML) ml): \(wellnessService.todayEntry.waterIntakeMl / WaterServing.glassML)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl / WaterServing.glassML },
                    set: { wellnessService.updateWaterIntake($0 * WaterServing.glassML) }
                ),
                in: 0...WaterServing.maxDailyIntakeML / WaterServing.glassML,
                step: 1
            )

            Stepper(
                "Garrafas (\(WaterServing.bottleML) ml): \(wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML },
                    set: { wellnessService.updateWaterIntake($0 * WaterServing.bottleML) }
                ),
                in: 0...WaterServing.maxDailyIntakeML / WaterServing.bottleML,
                step: 1
            )

            HStack(spacing: 10) {
                Button("+1 copo") { wellnessService.addWater(WaterServing.glassML) }
                Button("+1 garrafa") { wellnessService.addWater(WaterServing.bottleML) }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func syncWellnessFields() {
        sleepHoursInput = wellnessService.todaySleepHours ?? 7
    }

    private func syncPreWorkoutFromWorkouts() {
        wellnessService.applyPreWorkoutFromWorkouts(trackedWorkoutSessions)
    }

    private var trackedWorkoutSessions: [WorkoutSession] {
        var sessions = workoutStore.sessionHistory
        if let activeSession = workoutStore.activeSession {
            sessions.append(activeSession)
        }
        return sessions
    }

    private var todayPreWorkoutEntries: [PreWorkoutSessionEntry] {
        WorkoutReportBuilder.todayPreWorkoutEntries(from: trackedWorkoutSessions)
    }

    @ViewBuilder
    private var energyDrinksSection: some View {
        let energyCount = wellnessService.todayEntry.energyDrinksCount
        let preWorkoutCount = wellnessService.todayEntry.preWorkoutCount

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quantos energéticos você bebe durante o dia?")
                    .font(.subheadline.weight(.medium))

                HStack {
                    Label(
                        energyCount == 0 ? "Nenhum" : "\(energyCount) hoje",
                        systemImage: "bolt.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(energyCount > 1 ? .orange : AppTheme.accent)

                    Spacer()

                    Text(energyCount == 1 ? "1 unidade" : "\(energyCount) unidades")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Stepper(
                    value: Binding(
                        get: { wellnessService.todayEntry.energyDrinksCount },
                        set: { wellnessService.updateEnergyDrinksCount($0) }
                    ),
                    in: 0...10,
                    step: 1
                ) {
                    Text("Energéticos hoje")
                }

                if energyCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Alerta OMS", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(SupplementGuidance.whoEnergyDrinkWarning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if energyCount == 0 {
                    Text("Ótimo! Menos cafeína ajuda no sono e na recuperação muscular.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Consumo moderado. Evite energéticos à noite para não prejudicar o sono.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Quantos pré-treinos você tomou hoje?")
                    .font(.subheadline.weight(.medium))

                HStack {
                    Label(
                        preWorkoutCount == 0 ? "Nenhum" : "\(preWorkoutCount) hoje",
                        systemImage: "flame.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(preWorkoutCount > 1 ? .orange : AppTheme.accentSecondary)

                    Spacer()

                    Text(preWorkoutCount == 1 ? "1 dose" : "\(preWorkoutCount) doses")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Stepper(
                    value: Binding(
                        get: { wellnessService.todayEntry.preWorkoutCount },
                        set: { wellnessService.updatePreWorkoutCount($0) }
                    ),
                    in: 0...5,
                    step: 1
                ) {
                    Text("Pré-treino hoje")
                }

                if !todayPreWorkoutEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registrado ao iniciar treino")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(todayPreWorkoutEntries) { entry in
                            HStack(spacing: 8) {
                                Image(systemName: entry.tookPreWorkout ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)

                                Text(entry.workoutTitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Text(entry.tookPreWorkout ? "Sim, tomei" : "Não tomei")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Ao iniciar um treino, sua resposta sobre pré-treino aparecerá aqui.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if preWorkoutCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Alerta de pré-treino", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(SupplementGuidance.preWorkoutDailyLimitWarning)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if preWorkoutCount == 1 {
                    Text("Consumo dentro do limite diário recomendado.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(SupplementGuidance.preWorkoutCaffeineLimit.capitalized + ".")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if wellnessService.tookPreWorkoutAndEnergyDrinkToday {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Alerta de cafeína", systemImage: "exclamationmark.octagon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(SupplementGuidance.preWorkoutAndEnergyDrinkWarning)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 4)
    }

    private func updatePersonalTrainerAvailability(_ enabled: Bool) {
        guard var user = authService.currentUser else { return }
        if !enabled {
            trainerName = ""
            trainerEmail = ""
            user.personalTrainerName = ""
            user.personalTrainerEmail = ""
        }
        guard user.usesPersonalTrainer != enabled
                || user.personalTrainerName != trainerName
                || user.personalTrainerEmail != trainerEmail else { return }
        user.usesPersonalTrainer = enabled
        authService.updateProfile(user)
    }

    private func updateNutritionistAvailability(_ enabled: Bool) {
        guard var user = authService.currentUser else { return }
        if !enabled {
            nutritionistName = ""
            nutritionistEmail = ""
            user.nutritionistName = ""
            user.nutritionistEmail = ""
        }
        guard user.usesNutritionist != enabled
                || user.nutritionistName != nutritionistName
                || user.nutritionistEmail != nutritionistEmail else { return }
        user.usesNutritionist = enabled
        authService.updateProfile(user)
    }

    private func savePersonalTrainer() {
        guard usesPersonalTrainer else { return }
        guard var user = authService.currentUser else { return }
        let name = trainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = trainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.personalTrainerName != name
                || user.personalTrainerEmail != email
                || !user.usesPersonalTrainer else { return }
        user.usesPersonalTrainer = true
        user.personalTrainerName = name
        user.personalTrainerEmail = email
        authService.updateProfile(user)
    }

    private func saveNutritionist() {
        guard usesNutritionist else { return }
        guard var user = authService.currentUser else { return }
        let name = nutritionistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = nutritionistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.nutritionistName != name
                || user.nutritionistEmail != email
                || !user.usesNutritionist else { return }
        user.usesNutritionist = true
        user.nutritionistName = name
        user.nutritionistEmail = email
        authService.updateProfile(user)
    }

    private func syncBodyDataFields() {
        guard let user = authService.currentUser else { return }
        weightText = String(format: "%.1f", user.weight)
        heightText = String(format: "%.0f", user.height)
        ageText = "\(user.age)"
        selectedGender = user.gender
    }

    private var isBodyDataValid: Bool {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let age = Int(ageText) else { return false }
        return weight >= 30 && weight <= 300 && height >= 100 && height <= 250 && age >= 14 && age <= 100
    }

    @ViewBuilder
    private func bodyDataSection(for user: UserProfile) -> some View {
        Text("Esses dados alimentam o cálculo de calorias e o cardápio em Nutrição.")
            .font(.caption)
            .foregroundStyle(.secondary)

        MetricField(label: "Peso", unit: "kg", text: $weightText)
        MetricField(label: "Altura", unit: "cm", text: $heightText)
        MetricField(label: "Idade", unit: "anos", text: $ageText, keyboard: .numberPad)

        VStack(alignment: .leading, spacing: 6) {
            Text("Sexo")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Sexo", selection: $selectedGender) {
                ForEach(Gender.allCases) { gender in
                    Text(gender.rawValue).tag(gender)
                }
            }
            .pickerStyle(.segmented)
        }

        LabeledContent("IMC", value: String(format: "%.1f", previewBMI(for: user)))
        LabeledContent("Metabolismo Basal", value: "\(previewBMR(for: user)) kcal")
        LabeledContent("Meta Calórica", value: "\(previewCalorieTarget(for: user)) kcal")

        Button {
            saveBodyData()
        } label: {
            Label("Salvar dados", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListSafeButtonStyle())
        .tint(AppTheme.accent)
        .disabled(!isBodyDataValid)
    }

    private func previewProfile(from user: UserProfile) -> UserProfile {
        var preview = user
        if let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            preview.weight = weight
        }
        if let height = Double(heightText.replacingOccurrences(of: ",", with: ".")) {
            preview.height = height
        }
        if let age = Int(ageText) {
            preview.age = age
        }
        preview.gender = selectedGender
        return preview
    }

    private func previewBMI(for user: UserProfile) -> Double {
        previewProfile(from: user).bmi
    }

    private func previewBMR(for user: UserProfile) -> Int {
        previewProfile(from: user).basalMetabolicRate
    }

    private func previewCalorieTarget(for user: UserProfile) -> Int {
        previewProfile(from: user).dailyCalorieTarget
    }

    private func currentFormMeasurements(measuredAt: Date = .now) -> BodyMeasurements {
        BodyMeasurements(
            neckCm: parseMeasurement(neckText),
            shouldersCm: parseMeasurement(shouldersText),
            chestCm: parseMeasurement(chestText),
            rightArmCm: parseMeasurement(rightArmText),
            leftArmCm: parseMeasurement(leftArmText),
            waistCm: parseMeasurement(waistText),
            abdomenCm: parseMeasurement(abdomenText),
            hipCm: parseMeasurement(hipText),
            rightThighCm: parseMeasurement(rightThighText),
            leftThighCm: parseMeasurement(leftThighText),
            rightCalfCm: parseMeasurement(rightCalfText),
            leftCalfCm: parseMeasurement(leftCalfText),
            measuredAt: measuredAt
        )
    }

    private func saveBodyData() {
        guard var user = authService.currentUser,
              let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let height = Double(heightText.replacingOccurrences(of: ",", with: ".")),
              let age = Int(ageText),
              isBodyDataValid else { return }

        user.weight = weight
        user.height = height
        user.age = age
        user.gender = selectedGender

        // Medidas corporais são opcionais aqui; se houver valores no formulário, persiste também.
        applyMeasurementFields(to: &user)

        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
        showBodyDataSavedAlert = true
    }

    /// Aplica os campos de circunferência atuais ao perfil (sem alertas).
    private func applyMeasurementFields(to user: inout UserProfile) {
        let previousSnapshot = user.bodyMeasurements
        let shouldGenerateComparison = BodyMeasurements.isEligibleForPeriodComparison(
            previous: previousSnapshot
        )

        let measurements = currentFormMeasurements()

        // Só atualiza measuredAt/medidas se houver algum valor ou já existia aferição.
        guard measurements.hasAnyValue || previousSnapshot.hasAnyValue else { return }

        if shouldGenerateComparison && previousSnapshot.hasAnyValue {
            user.previousBodyMeasurements = previousSnapshot
        }
        user.bodyMeasurements = measurements

        if shouldGenerateComparison,
           let comparison = BodyMeasurementComparison.make(
            previous: previousSnapshot,
            current: measurements
           ) {
            measurementComparison = comparison
            // O alerta de dados salvos tem prioridade; o comparativo pode ser aberto depois.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showMeasurementComparison = true
            }
        }
    }

    private func syncBodyMeasurementFields() {
        let m = authService.currentUser?.bodyMeasurements ?? .empty
        neckText = formatMeasurementField(m.neckCm)
        shouldersText = formatMeasurementField(m.shouldersCm)
        chestText = formatMeasurementField(m.chestCm)
        rightArmText = formatMeasurementField(m.rightArmCm)
        leftArmText = formatMeasurementField(m.leftArmCm)
        waistText = formatMeasurementField(m.waistCm)
        abdomenText = formatMeasurementField(m.abdomenCm)
        hipText = formatMeasurementField(m.hipCm)
        rightThighText = formatMeasurementField(m.rightThighCm)
        leftThighText = formatMeasurementField(m.leftThighCm)
        rightCalfText = formatMeasurementField(m.rightCalfCm)
        leftCalfText = formatMeasurementField(m.leftCalfCm)
    }

    private func formatMeasurementField(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func parseMeasurement(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0, value < 500 else { return nil }
        return value
    }

    @ViewBuilder
    private func bodyMeasurementsSection(for user: UserProfile) -> some View {
        Text("Informe as circunferências em centímetros. Os campos vazios não entram no relatório.")
            .font(.caption)
            .foregroundStyle(.secondary)

        if let measuredAt = user.bodyMeasurements.measuredAt {
            Text("Última atualização: \(measuredAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(AppTheme.accent)
        }

        if let comparison = user.latestMeasurementComparison,
           comparison.periodDays >= BodyMeasurements.comparisonIntervalDays {
            Button {
                measurementComparison = comparison
                showMeasurementComparison = true
            } label: {
                Label(
                    "Ver comparativo de \(comparison.periodDays) dia(s)",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(ListSafeButtonStyle())
        } else if let measuredAt = user.bodyMeasurements.measuredAt {
            let days = BodyMeasurements.daysBetween(measuredAt)
            let remaining = max(BodyMeasurements.comparisonIntervalDays - days, 0)
            if remaining > 0 {
                Text("Comparativo disponível após \(remaining) dia(s), quando você atualizar as medidas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        measurementField("Pescoço", text: $neckText)
        measurementField("Ombros", text: $shouldersText)
        measurementField("Peito", text: $chestText)
        measurementField("Braço direito", text: $rightArmText)
        measurementField("Braço esquerdo", text: $leftArmText)
        measurementField("Cintura", text: $waistText)
        measurementField("Abdômen", text: $abdomenText)
        measurementField("Quadril", text: $hipText)
        measurementField("Coxa direita", text: $rightThighText)
        measurementField("Coxa esquerda", text: $leftThighText)
        measurementField("Panturrilha direita", text: $rightCalfText)
        measurementField("Panturrilha esquerda", text: $leftCalfText)

        Button {
            saveBodyMeasurements()
        } label: {
            Label("Salvar medidas", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListSafeButtonStyle())
        .tint(AppTheme.accent)
    }

    private func measurementField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("cm", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
        }
    }

    private func saveBodyMeasurements() {
        guard var user = authService.currentUser else { return }

        let measurements = currentFormMeasurements()
        guard measurements.hasAnyValue else {
            showEmptyMeasurementsAlert = true
            return
        }

        let previousSnapshot = user.bodyMeasurements
        let shouldGenerateComparison = BodyMeasurements.isEligibleForPeriodComparison(
            previous: previousSnapshot
        )

        applyMeasurementFields(to: &user)
        authService.updateProfile(user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)

        if shouldGenerateComparison,
           BodyMeasurementComparison.make(
            previous: previousSnapshot,
            current: user.bodyMeasurements
           ) != nil {
            // applyMeasurementFields já agenda o sheet do comparativo.
        } else {
            showMeasurementsSavedAlert = true
        }
    }

    private func updateBiotype(_ biotype: Biotype) {
        guard var user = authService.currentUser, user.biotype != biotype else { return }
        user.biotype = biotype
        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
        ProfileDataReminderService.shared.markBodyDataUpdated(for: user.id)
    }
}

private struct ProfileAvatarView: View {
    let image: UIImage?
    let initial: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(AppTheme.gradientPrimary)
                    Text(initial)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            Image(systemName: "camera.fill")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(6)
                .background(AppTheme.accent)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
        }
    }
}

private struct BodyMeasurementComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let comparison: BodyMeasurementComparison

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Comparativo de \(comparison.periodDays) dia(s)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Após atualizar as medidas, estas são as que variaram no período.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if let from = comparison.previous.measuredAt,
                       let to = comparison.current.measuredAt {
                        Text("\(from.formatted(date: .abbreviated, time: .omitted)) → \(to.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    if comparison.changes.isEmpty {
                        Text("Nenhuma medida variou entre as duas aferições.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(comparison.changes) { change in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(change.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(BodyMeasurements.formatCm(change.previous)) → \(BodyMeasurements.formatCm(change.current))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(BodyMeasurements.formatDelta(change.delta))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(change.delta < 0 ? .green : (change.delta > 0 ? .orange : AppTheme.textSecondary))
                                }
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Comparativo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Evita o atraso/long-press típico de `Button` dentro de `List` (UITableView).
private struct ListSafeButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded { configuration.trigger() }
            )
    }
}

private struct ProfilePHPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void

        init(onPick: @escaping (UIImage?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            let onPick = self.onPick
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    onPick(image)
                }
            }
        }
    }
}
