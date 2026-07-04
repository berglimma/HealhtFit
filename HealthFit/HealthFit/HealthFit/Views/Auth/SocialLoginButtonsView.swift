import AuthenticationServices
import SwiftUI

struct SocialLoginButtonsView: View {
    enum Style {
        case full
        case iconCards
    }

    @EnvironmentObject var authService: AuthService

    var style: Style = .full
    @State private var currentAppleNonce = ""

    var body: some View {
        VStack(spacing: 12) {
            switch style {
            case .full:
                fullWidthButtons
            case .iconCards:
                iconCardButtons
            }

            divider
        }
    }

    private var fullWidthButtons: some View {
        Group {
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
                configureAppleRequest(request)
            } onCompletion: { result in
                Task { await authService.signInWithApple(result: result, rawNonce: currentAppleNonce) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(authService.isLoading)
        }
    }

    private var iconCardButtons: some View {
        HStack(spacing: 16) {
            Button {
                Task { await authService.signInWithGoogle() }
            } label: {
                SocialLoginIconCard(systemImage: "g.circle.fill")
            }
            .disabled(authService.isLoading)
            .accessibilityLabel("Entrar com Google")

            ZStack {
                SocialLoginIconCard(systemImage: "apple.logo")

                SignInWithAppleButton(.signIn) { request in
                    configureAppleRequest(request)
                } onCompletion: { result in
                    Task { await authService.signInWithApple(result: result, rawNonce: currentAppleNonce) }
                }
                .signInWithAppleButtonStyle(.white)
                .opacity(0.02)
                .frame(width: 64, height: 64)
            }
            .disabled(authService.isLoading)
            .accessibilityLabel("Entrar com Apple")
        }
        .frame(maxWidth: .infinity)
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.randomNonce()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
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

private struct SocialLoginIconCard: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 1.2)
            )
            .shadow(color: AppTheme.accent.opacity(0.25), radius: 8, y: 4)
    }
}

#Preview("Full") {
    SocialLoginButtonsView()
        .environmentObject(AuthService())
        .padding()
        .background(AppTheme.background)
}

#Preview("Icon Cards") {
    SocialLoginButtonsView(style: .iconCards)
        .environmentObject(AuthService())
        .padding()
        .background(AppTheme.background)
}
