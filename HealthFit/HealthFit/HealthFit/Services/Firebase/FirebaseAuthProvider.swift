import Foundation
import FirebaseAuth

struct AuthenticatedFirebaseUser: Equatable {
    let uid: String
    let email: String
    let displayName: String?

    static func from(_ user: User) -> AuthenticatedFirebaseUser? {
        let resolvedEmail = user.email
            ?? user.providerData.compactMap(\.email).first
            ?? "\(user.uid)@users.healthfit.app"

        return AuthenticatedFirebaseUser(
            uid: user.uid,
            email: resolvedEmail,
            displayName: user.displayName
        )
    }
}

enum FirebaseAuthProvider {
    static var currentUser: AuthenticatedFirebaseUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthenticatedFirebaseUser.from(user)
    }

    static func addStateListener(
        _ handler: @escaping (AuthenticatedFirebaseUser?) -> Void
    ) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            guard let user else {
                handler(nil)
                return
            }
            handler(AuthenticatedFirebaseUser.from(user))
        }
    }

    static func removeStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    private static var stateListenerHandle: AuthStateDidChangeListenerHandle?

    static func startObservingState(
        _ handler: @escaping (AuthenticatedFirebaseUser?) -> Void
    ) {
        stopObservingState()
        stateListenerHandle = addStateListener(handler)
    }

    static func stopObservingState() {
        guard let handle = stateListenerHandle else { return }
        removeStateListener(handle)
        stateListenerHandle = nil
    }

    static func signIn(email: String, password: String) async throws -> AuthenticatedFirebaseUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        guard let mapped = AuthenticatedFirebaseUser.from(result.user) else {
            throw NSError(
                domain: AuthErrorDomain,
                code: AuthErrorCode.invalidEmail.rawValue,
                userInfo: nil
            )
        }
        return mapped
    }

    static func createUser(email: String, password: String) async throws -> AuthenticatedFirebaseUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        guard let mapped = AuthenticatedFirebaseUser.from(result.user) else {
            throw NSError(
                domain: AuthErrorDomain,
                code: AuthErrorCode.invalidEmail.rawValue,
                userInfo: nil
            )
        }
        return mapped
    }

    static func signOut() throws {
        SocialSignInService.signOutGoogleSession()
        try Auth.auth().signOut()
    }

    static func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
