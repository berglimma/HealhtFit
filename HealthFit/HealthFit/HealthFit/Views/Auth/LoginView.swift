import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 12) {
                        PulsingHeartIconView(size: DeviceLayout.isPad ? 88 : 72)

                        Text("HealthFit")
                            .font(.system(size: DeviceLayout.isPad ? 42 : 36, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Seu personal trainer inteligente")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 48)

                    VStack(spacing: 16) {
                        SocialLoginButtonsView(style: .iconCards)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-mail")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)

                            ZStack(alignment: .leading) {
                                if email.isEmpty {
                                    Text("seu@email.com")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                        .padding(.horizontal, 16)
                                        .allowsHitTesting(false)
                                }

                                TextField("", text: $email)
                                    .textFieldStyle(HealthFitTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .tint(AppTheme.accent)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Senha")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)

                            ZStack(alignment: .leading) {
                                if password.isEmpty {
                                    Text("Sua senha")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent.opacity(0.55))
                                        .padding(.horizontal, 16)
                                        .allowsHitTesting(false)
                                }

                                SecureField("", text: $password)
                                    .textFieldStyle(HealthFitTextFieldStyle())
                                    .textContentType(.password)
                                    .tint(AppTheme.accent)
                            }
                        }

                        Button("Esqueci minha senha") {
                            showForgotPassword = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .center)

                        if !authService.isFirebaseReady {
                            Text("Firebase não configurado. Substitua o GoogleService-Info.plist pelo arquivo do Firebase Console.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button {
                            Task { await authService.login(email: email, password: password) }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Entrar")
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !email.isEmpty && password.count >= 6))
                        .disabled(email.isEmpty || password.count < 6 || authService.isLoading)
                        .padding(.top, 8)

                        CreateAccountCard {
                            showRegister = true
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                    .frame(maxWidth: DeviceLayout.formMaxWidth(for: horizontalSizeClass))
                    .frame(maxWidth: .infinity)

                    Spacer()
                    
                    DeveloperCreditView()
                        .padding(.horizontal, AppTheme.padding)
                        .padding(.bottom, 32)
                }
                
                if authService.isLoading {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.5)
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(initialEmail: email)
            }
        }
    }
}

struct CreateAccountCard: View {
    let action: () -> Void

    private let workoutIcons = [
        "figure.strengthtraining.traditional",
        "dumbbell.fill",
        "figure.run",
        "figure.yoga",
        "figure.mind.and.body",
        "flame.fill"
    ]

    @State private var iconIndex = 0

    private let iconTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.14))
                        .frame(width: 92, height: 92)

                    Circle()
                        .stroke(AppTheme.accent.opacity(0.35), lineWidth: 2)
                        .frame(width: 92, height: 92)

                    Image(systemName: workoutIcons[iconIndex])
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(AppTheme.gradientPrimary)
                        .modifier(RepeatingBounceSymbolEffect(speed: 0.6))
                        .id(workoutIcons[iconIndex])
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.35), value: iconIndex)

                VStack(spacing: 4) {
                    Text("Criar conta")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Monte seu plano e comece a treinar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: AppTheme.accent.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .onReceive(iconTimer) { _ in
            iconIndex = (iconIndex + 1) % workoutIcons.count
        }
    }
}

struct HealthFitTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
