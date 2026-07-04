import AuthenticationServices
import SwiftUI

struct SocialLoginButtonsView: View {
    @EnvironmentObject var authService: AuthService

    @State private var currentAppleNonce = ""

    var body: some View {
        VStack(spacing: 12) {
            Button {
                Task { await authService.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("Continuar com Google")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
            .disabled(authService.isLoading)

            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.randomNonce()
                currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } onCompletion: { result in
                Task { await authService.signInWithApple(result: result, rawNonce: currentAppleNonce) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(authService.isLoading)

            divider
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.textSecondary.opacity(0.35))
                .frame(height: 1)
            Text("ou")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Rectangle()
                .fill(AppTheme.textSecondary.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SocialLoginButtonsView()
        .environmentObject(AuthService())
        .padding()
        .background(AppTheme.background)
}
