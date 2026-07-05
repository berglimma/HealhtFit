import AuthenticationServices
import SwiftUI

struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var wellnessService: DailyWellnessService

    let requiresPassword: Bool
    let requiresAppleReauthentication: Bool

    @State private var password = ""
    @State private var confirmed = false
    @State private var appleReauthenticated = false
    @State private var currentAppleNonce = ""
    @State private var showDeleteConfirmation = false

    private static let farewellMessage =
        "Tudo bem! Sentiremos sua falta, mas volte quando sentir falta do HealthFit. " +
        "Fico triste pois você está indo e tínhamos metas incríveis."

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Esta ação é permanente. Sua conta, treinos na nuvem, perfil e dados locais serão removidos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if requiresPassword {
                    Section("Confirme sua senha") {
                        SecureField("Senha atual", text: $password)
                    }
                } else if requiresAppleReauthentication {
                    Section("Confirme com a Apple") {
                        if appleReauthenticated {
                            Label("Identidade confirmada", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            SignInWithAppleButton(.continue) { request in
                                let nonce = AppleSignInNonce.randomNonce()
                                currentAppleNonce = nonce
                                request.requestedScopes = []
                                request.nonce = AppleSignInNonce.sha256(nonce)
                            } onCompletion: { result in
                                Task {
                                    let ok = await authService.reauthenticateWithApple(
                                        result: result,
                                        rawNonce: currentAppleNonce
                                    )
                                    if ok { appleReauthenticated = true }
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 44)
                        }
                    }
                } else {
                    Section("Confirmação") {
                        Text("Será necessário confirmar seu login com Google para concluir a exclusão.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Entendo que não poderei recuperar minha conta", isOn: $confirmed)
                }

                if let error = authService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Excluir Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Excluir", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(!canDelete || authService.isLoading)
                }
            }
            .alert("Deseja mesmo excluir sua conta?", isPresented: $showDeleteConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Sim, excluir conta", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text(Self.farewellMessage)
            }
            .interactiveDismissDisabled(authService.isLoading)
            .overlay {
                if authService.isLoading {
                    ProgressView("Excluindo conta…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var canDelete: Bool {
        guard confirmed else { return false }
        if requiresPassword {
            return password.count >= 6
        }
        if requiresAppleReauthentication {
            return appleReauthenticated
        }
        return true
    }

    private func deleteAccount() async {
        let success = await authService.deleteAccount(
            password: requiresPassword ? password : nil,
            workoutStore: workoutStore,
            mealPlanService: mealPlanService,
            wellnessService: wellnessService,
            skipReauthentication: requiresAppleReauthentication && appleReauthenticated
        )
        if success {
            dismiss()
        }
    }
}
