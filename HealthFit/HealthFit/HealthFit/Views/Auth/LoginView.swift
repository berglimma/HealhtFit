import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.gradientPrimary)
                            .symbolEffect(.pulse)

                        Text("HealthFit")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Seu personal trainer inteligente")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 48)

                    VStack(spacing: 16) {
                        TextField("E-mail", text: $email)
                            .textFieldStyle(HealthFitTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Senha", text: $password)
                            .textFieldStyle(HealthFitTextFieldStyle())
                            .textContentType(.password)

                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button("Entrar") {
                            Task { await authService.login(email: email, password: password) }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !email.isEmpty && password.count >= 6))
                        .disabled(email.isEmpty || password.count < 6 || authService.isLoading)
                    }
                    .padding(.horizontal, AppTheme.padding)

                    Spacer()

                    DeveloperCreditView()
                        .padding(.horizontal, AppTheme.padding)
                        .padding(.bottom, 8)

                    Button("Criar conta") {
                        showRegister = true
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
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
        }
    }
}

struct HealthFitTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
