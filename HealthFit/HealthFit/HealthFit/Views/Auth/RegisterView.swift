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
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    @State private var selectedCountryCode = CountryOption.defaultCode()
    @State private var acceptedTerms = false
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
            && PasswordPolicy.isValid(password)
            && password == confirmPassword
            && UserProfile.isValidDateOfBirth(dateOfBirth)
            && acceptedTerms
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

                    SocialLoginButtonsView(style: .iconCards)
                        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                        .frame(maxWidth: DeviceLayout.formMaxWidth(for: horizontalSizeClass))
                        .frame(maxWidth: .infinity)
                    
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
                            prompt: Text("Senha")
                                .foregroundStyle(Color.black.opacity(0.6))
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        
                        SecureField(
                            "",
                            text: $confirmPassword,
                            prompt: Text("Confirmar senha")
                                .foregroundStyle(Color.black.opacity(0.6))
                            
                        )
                        .textFieldStyle(HealthFitTextFieldStyle())
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        PasswordRequirementsView(
                            password: password,
                            confirmPassword: confirmPassword
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data de nascimento *")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        DatePicker(
                            "Data de nascimento",
                            selection: $dateOfBirth,
                            in: ...Calendar.current.date(byAdding: .year, value: -14, to: .now)!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Obrigatório · idade atual: \(UserProfile.age(from: dateOfBirth)) anos")
                            .font(.caption)
                            .foregroundStyle(
                                UserProfile.isValidDateOfBirth(dateOfBirth)
                                    ? AppTheme.textSecondary
                                    : .red
                            )

                        Text("País")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Picker("País", selection: $selectedCountryCode) {
                            ForEach(CountryOption.catalog) { country in
                                Text("\(country.flagEmoji)  \(country.name)").tag(country.code)
                            }
                        }
                        .pickerStyle(.menu)
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
                            }
                        }

                        BiotypeIdentificationHint(biotype: selectedBiotype)
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

                    Toggle(isOn: $acceptedTerms) {
                        Text("Li e aceito os Termos de Uso e a Política de Privacidade")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)

                    LegalLinksView()
                    
            Button("Cadastrar") {
                        Task {
                            await authService.register(
                                name: name,
                                email: email,
                                password: password,
                                biotype: selectedBiotype,
                                goal: selectedGoal,
                                dateOfBirth: dateOfBirth,
                                countryCode: selectedCountryCode
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
            VStack(spacing: 6) {
                Image(systemName: biotype.icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : biotype.color)
                    .frame(height: 24)

                Text(biotype.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(biotype.identificationGuide)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 128)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(isSelected ? biotype.color : AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? biotype.color : biotype.color.opacity(0.20),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct BiotypeIdentificationHint: View {
    let biotype: Biotype

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Como saber se você é \(biotype.rawValue.lowercased())", systemImage: "questionmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(biotype.color)
            Text(biotype.identificationGuide)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(biotype.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .background(isSelected ? goal.color : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthService())
    
}
