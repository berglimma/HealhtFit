import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var wellnessService: DailyWellnessService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showLogoutAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var trainerName = ""
    @State private var trainerEmail = ""
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
                                    initial: String(user.name.prefix(1).uppercased())
                                )
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(profileImage == nil ? "Toque para adicionar foto" : "Toque para alterar foto")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Spacer()

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

                    Section("Sono e Hidratação") {
                        if let user = authService.currentUser {
                            wellnessSection(for: user)
                        }
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
                syncWellnessFields()
            }
            .onChange(of: authService.currentUser) { _, _ in
                syncTrainerFields()
            }
            .onChange(of: wellnessService.todayEntry) { _, _ in
                syncWellnessFields()
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

            Text("Cálculo: 35 ml por kg de peso corporal (\(String(format: "%.1f", user.weight)) kg).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ProgressView(value: wellnessService.waterProgress(for: user))
                .tint(.blue)

            HStack {
                Text("\(wellnessService.todayEntry.waterIntakeMl) ml ingeridos")
                    .font(.caption)
                Spacer()
                Text(wellnessService.waterStatusMessage(for: user))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            Stepper(
                "Copos (250 ml): \(wellnessService.todayEntry.waterIntakeMl / 250)",
                value: Binding(
                    get: { wellnessService.todayEntry.waterIntakeMl },
                    set: { wellnessService.updateWaterIntake($0) }
                ),
                in: 0...user.recommendedDailyWaterML + 1000,
                step: 250
            )

            HStack(spacing: 10) {
                Button("+250 ml") { wellnessService.addWater(250) }
                Button("+500 ml") { wellnessService.addWater(500) }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func syncWellnessFields() {
        sleepHoursInput = wellnessService.todaySleepHours ?? 7
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
