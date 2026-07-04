import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var authService: AuthService

    let initialEmail: String

    @State private var email: String
    @State private var successMessage: String?
    @State private var errorMessage: String?

    init(initialEmail: String = "") {
        self.initialEmail = initialEmail
        _email = State(initialValue: initialEmail)
    }

    private var canSubmit: Bool {
        email.contains("@") && !authService.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.accent)

                        Text("Redefinir senha")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Enviaremos um link para o seu e-mail com instruções para criar uma nova senha.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    TextField("E-mail", text: $email)
                        .textFieldStyle(HealthFitTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let successMessage {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await sendResetLink() }
                    } label: {
                        Text("Enviar link de redefinição")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: canSubmit))
                    .disabled(!canSubmit)

                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .frame(maxWidth: DeviceLayout.formMaxWidth(for: horizontalSizeClass))
                .frame(maxWidth: .infinity)

                if authService.isLoading {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.5)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func sendResetLink() async {
        successMessage = nil
        errorMessage = nil

        let sent = await authService.resetPassword(email: email)
        if sent {
            successMessage = "Link enviado! Verifique sua caixa de entrada e o spam."
        } else {
            errorMessage = authService.errorMessage
        }
    }
}

#Preview {
    ForgotPasswordView(initialEmail: "atleta@test.com")
        .environmentObject(AuthService())
}
