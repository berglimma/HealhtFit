import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var showLogoutAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ProfileAvatarView(
                                    image: authService.profileImage,
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
                                Text(authService.profileImage == nil ? "Toque para adicionar foto" : "Toque para alterar foto")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Spacer()

                            if authService.profileImage != nil {
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
                        HStack(spacing: 10) {
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
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(FitnessGoal.allCases) { goal in
                                GoalCard(goal: goal, isSelected: user.goal == goal) {
                                    updateGoal(goal)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.cardBackground)

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
            .navigationTitle("Perfil")
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
