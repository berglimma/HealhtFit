import SwiftUI

struct RegisterView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var authService: AuthService
    
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
                    
                    VStack(spacing: 10) {
                        TextField(
                            "",
                            text: $name,
                            prompt: Text("Nome  Completo")
                                .foregroundStyle(Color.black.opacity(0.6))
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                        
                        
                        TextField(
                            "",
                            text: $email,
                            prompt: Text("E-mail")
                                .foregroundStyle(Color.black.opacity(0.6))
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                        
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text("Senha (mín. 6 caracteres)")
                                .foregroundStyle(Color.black.opacity(0.6))
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                        
                        SecureField(
                            "",
                            text: $confirmPassword,
                            prompt: Text("Confirmar senha")
                                .foregroundStyle(Color.black.opacity(0.6))
                            
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biotipo")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        AdaptiveBiotypeRow {
                            ForEach(Biotype.allCases) { biotype in
                                BiotypeCard(
                                    biotype: biotype,
                                    isSelected: selectedBiotype == biotype
                                ) {
                                    selectedBiotype = biotype
                                }
                                .frame(minWidth: DeviceLayout.isPad ? 128 : 100)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objetivo")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        AdaptiveGoalGrid {
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
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 15)
                    .background(
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: isValid ? AppTheme.accent.opacity(0.45) : .clear,
                        radius: 10, x: 0, y: 6
                    )
                    .cornerRadius(15)
                    .opacity(authService.isLoading ? 0.6 : 1)
                    .disabled(!isValid || authService.isLoading)
                    
                    DeveloperCreditView()
                        .padding(.top, 8)
                    
                    if authService.isLoading {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView().tint(AppTheme.accent).scaleEffect(1.5)
                    }
                }
                .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .padding(.bottom, 32)
                .adaptiveContentWidth(DeviceLayout.formMaxWidth(for: horizontalSizeClass))
            }
        }
    }
}

struct BiotypeCard: View {
    let biotype: Biotype
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                
                Image(systemName: biotype.icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : biotype.color)
                
                Text(biotype.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? biotype.color : AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? biotype.color : biotype.color.opacity(0.20),
                        lineWidth: 1.5
                    )
            )
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
            VStack(spacing: 5) {
                Image(systemName: goal.icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : goal.color)
                
                Text(goal.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
            .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthService())
    
}
