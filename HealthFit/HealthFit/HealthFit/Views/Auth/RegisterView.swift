import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedBiotype: Biotype = .mesomorph
    @State private var selectedGoal: FitnessGoal = .muscleGain

    private var isValid: Bool {
        !name.isEmpty && email.contains("@") && password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Criar Conta")
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Configure seu perfil de atleta")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 16) {
                        TextField("Nome completo", text: $name)
                            .textFieldStyle(HealthFitTextFieldStyle())

                        TextField("E-mail", text: $email)
                            .textFieldStyle(HealthFitTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Senha (mín. 6 caracteres)", text: $password)
                            .textFieldStyle(HealthFitTextFieldStyle())

                        SecureField("Confirmar senha", text: $confirmPassword)
                            .textFieldStyle(HealthFitTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biotipo")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        HStack(spacing: 10) {
                            ForEach(Biotype.allCases) { biotype in
                                BiotypeCard(
                                    biotype: biotype,
                                    isSelected: selectedBiotype == biotype
                                ) {
                                    selectedBiotype = biotype
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objetivo")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(FitnessGoal.allCases) { goal in
                                GoalCard(goal: goal, isSelected: selectedGoal == goal) {
                                    selectedGoal = goal
                                }
                            }
                        }
                    }

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Cadastrar") {
                        Task {
                            await authService.register(
                                name: name,
                                email: email,
                                password: password,
                                biotype: selectedBiotype,
                                goal: selectedGoal
                            )
                            if authService.isAuthenticated { dismiss() }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: isValid))
                    .disabled(!isValid || authService.isLoading)

                    DeveloperCreditView()
                        .padding(.top, 8)
                }
                .padding(AppTheme.padding)
            }

            if authService.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(AppTheme.accent).scaleEffect(1.5)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BiotypeCard: View {
    let biotype: Biotype
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: biotype.icon)
                    .font(.title3)
                Text(biotype.rawValue)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: goal.icon)
                Text(goal.rawValue)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
