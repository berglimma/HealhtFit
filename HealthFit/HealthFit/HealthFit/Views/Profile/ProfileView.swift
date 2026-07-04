import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showLogoutAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var trainerName = ""
    @State private var trainerEmail = ""
    @State private var displayName = ""
    @State private var sleepHoursInput: Double = 7

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    let profileImage = authService.profileImage
                    Section {
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ProfileAvatarView(
                                    image: profileImage,
                                    initial: String(user.greetingName.prefix(1).uppercased())
                                )
                            }
                            .buttonStyle(.plain)

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

                            Spacer()

                            PulsingHeartIconView(size: 44)

                            if profileImage != nil {
                                Button {
                                    selectedPhotoItem = nil
                                    authService.updateProfileImage(nil)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }

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

                    Section("Objetivo") {
                        AdaptiveGoalGrid {
                            ForEach(FitnessGoal.allCases) { goal in
                                GoalCard(goal: goal, isSelected: user.goal == goal) {
                                    updateGoal(goal)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    Section("Personal Trainer") {
                        TextField("Nome do Personal", text: $trainerName)
                            .textContentType(.name)
                            .onChange(of: trainerName) { _, _ in
                                savePersonalTrainer()
                            }

                        TextField("E-mail do Personal", text: $trainerEmail)
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
                    }

                    Section("Ícone do App") {
                        let projectedState = AppIconInactivityService.shared.projectedIconState()

                        HStack(spacing: 14) {
                            PulsingHeartIconView(
                                size: 40,
                                glowColor: projectedState.glowColor
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(projectedState.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(projectedState.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        if let nextChange = AppIconInactivityService.shared.formattedTimeUntilNextChange() {
                            Label(nextChange, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                        }

                        Label("Ao abrir o app, o ícone volta ao verde.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Section("Sono e Hidratação") {
                        if let user = authService.currentUser {
                            wellnessSection(for: user)
                        }
                    }

                    Section("Energéticos e Pré-treino") {
                        energyDrinksSection
                    }

                    Section("Perfil Físico") {
                        LabeledContent("Peso", value: String(format: "%.1f kg", user.weight))
                        LabeledContent("Altura", value: String(format: "%.0f cm", user.height))
                        LabeledContent("Idade", value: "\(user.age) anos")
                        LabeledContent("Sexo", value: user.gender.rawValue)
                        LabeledContent("IMC", value: String(format: "%.1f", user.bmi))
                        LabeledContent("Metabolismo Basal", value: "\(user.basalMetabolicRate) kcal")
                        LabeledContent("Meta Calórica", value: "\(user.dailyCalorieTarget) kcal")
                    }

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

                    Section("Sobre") {
                        LabeledContent("App", value: "HealthFit")
                        LabeledContent("Desenvolvedor", value: AppInfo.developerName)
                        Text(AppInfo.developerCredit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Sair da Conta", role: .destructive) {
                            showLogoutAlert = true
                        }
                    }
                }
            }
            .adaptiveContentWidth()
            .navigationTitle("Perfil")
            .onAppear {
                syncTrainerFields()
                syncDisplayNameField()
                syncWellnessFields()
                syncPreWorkoutFromWorkouts()
            }
            .onChange(of: authService.currentUser) { _, _ in
                syncTrainerFields()
                syncDisplayNameField()
            }
            .onChange(of: wellnessService.todayEntry) { _, _ in
                syncWellnessFields()
            }
            .onChange(of: workoutStore.sessionHistory.count) { _, _ in
                syncPreWorkoutFromWorkouts()
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    authService.updateProfileImage(image)
                }
            }
            .alert("Sair da conta?", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Sair", role: .destructive) {
                    authService.logout()
                }
            }
        }
    }

    private func syncTrainerFields() {
        trainerName = authService.currentUser?.personalTrainerName ?? ""
        trainerEmail = authService.currentUser?.personalTrainerEmail ?? ""
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
                in: 0...(user.recommendedDailyWaterML + 1000) / WaterServing.glassML,
                step: 1
            )

            Stepper(
                "Garrafas (\(WaterServing.bottleML) ml): \(wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl / WaterServing.bottleML },
                    set: { wellnessService.updateWaterIntake($0 * WaterServing.bottleML) }
                ),
                in: 0...(user.recommendedDailyWaterML + 1000) / WaterServing.bottleML,
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

    private func savePersonalTrainer() {
        guard var user = authService.currentUser else { return }
        let name = trainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = trainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.personalTrainerName != name || user.personalTrainerEmail != email else { return }
        user.personalTrainerName = name
        user.personalTrainerEmail = email
        authService.updateProfile(user)
    }

    private func updateGoal(_ goal: FitnessGoal) {
        guard var user = authService.currentUser, user.goal != goal else { return }
        user.goal = goal
        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
    }

    private func updateBiotype(_ biotype: Biotype) {
        guard var user = authService.currentUser, user.biotype != biotype else { return }
        user.biotype = biotype
        authService.updateProfile(user)
        mealPlanService.regeneratePlanIfNeeded(for: user)
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
