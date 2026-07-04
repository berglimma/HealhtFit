import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

enum SocialSignInError: LocalizedError, Equatable {
    case googleNotConfigured
    case noViewController
    case missingToken
    case cancelled
    case invalidAppleCredential
    case missingAppleToken

    var errorDescription: String? {
        switch self {
        case .googleNotConfigured:
            return "Login com Google não configurado. Habilite o Google no Firebase e baixe o GoogleService-Info.plist novamente."
        case .noViewController:
            return "Não foi possível abrir a tela de login."
        case .missingToken, .missingAppleToken:
            return "Não foi possível validar o login. Tente novamente."
        case .cancelled:
            return nil
        case .invalidAppleCredential:
            return "Credencial da Apple inválida. Tente novamente."
        }
    }
}

@MainActor
enum SocialSignInService {
    static func signInWithGoogle() async throws -> AuthenticatedFirebaseUser {
        guard GoogleServiceInfo.isGoogleSignInConfigured,
              let clientID = GoogleServiceInfo.clientID else {
            throw SocialSignInError.googleNotConfigured
        }

        guard let presenter = Self.topViewController() else {
            throw SocialSignInError.noViewController
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw SocialSignInError.missingToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            guard let mapped = AuthenticatedFirebaseUser.from(authResult.user) else {
                throw SocialSignInError.missingToken
            }
            return mapped
        } catch let error as GIDSignInError where error.code == .canceled {
            throw SocialSignInError.cancelled
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                throw SocialSignInError.cancelled
            }
            throw error
        }
    }

    static func signInWithApple(
        authorization: ASAuthorization,
        rawNonce: String
    ) async throws -> (user: AuthenticatedFirebaseUser, suggestedName: String?) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw SocialSignInError.invalidAppleCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        guard let mapped = AuthenticatedFirebaseUser.from(authResult.user) else {
            throw SocialSignInError.missingAppleToken
        }

        let suggestedName = Self.formattedName(from: appleCredential.fullName)
            ?? authResult.user.displayName

        return (mapped, suggestedName)
    }

    private static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    nonisolated static func handleIncomingURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    nonisolated static func signOutGoogleSession() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }

        var controller = root
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
