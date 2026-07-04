import Foundation
import Combine
import UIKit
import AuthenticationServices

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var profileImage: UIImage?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isRestoringSession = true
    @Published var errorMessage: String?

    var isFirebaseReady: Bool { FirebaseBootstrap.isConfigured }

    private let legacyUserDefaultsKey = "healthfit_current_user"

    init() {
        FirebaseBootstrap.configure()
        observeAuthState()
    }

    deinit {
        FirebaseAuthProvider.stopObservingState()
    }

    func login(email: String, password: String) async {
        guard ensureFirebaseReady() else { return }

        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard normalizedEmail.contains("@"), password.count >= 6 else {
            errorMessage = "E-mail ou senha inválidos"
            isLoading = false
            return
        }

        do {
            let authUser = try await FirebaseAuthProvider.signIn(email: normalizedEmail, password: password)
            applyAuthenticatedUser(authUser, fallbackName: nil)
            isLoading = false
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            isLoading = false
        }
    }

    func register(name: String, email: String, password: String, biotype: Biotype, goal: FitnessGoal) async {
        guard ensureFirebaseReady() else { return }

        isLoading = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty, normalizedEmail.contains("@"), password.count >= 6 else {
            errorMessage = "Preencha todos os campos corretamente"
            isLoading = false
            return
        }

        do {
            let authUser = try await FirebaseAuthProvider.createUser(email: normalizedEmail, password: password)
            let profile = UserProfile(
                id: authUser.uid,
                name: trimmedName,
                email: normalizedEmail,
                biotype: biotype,
                goal: goal
            )
            persistSession(with: profile)
            isLoading = false
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            isLoading = false
        }
    }

    @discardableResult
    func resetPassword(email: String) async -> Bool {
        guard ensureFirebaseReady() else { return false }

        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard normalizedEmail.contains("@") else {
            errorMessage = "Informe um e-mail válido."
            isLoading = false
            return false
        }

        do {
            try await FirebaseAuthProvider.sendPasswordReset(email: normalizedEmail)
            isLoading = false
            return true
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            isLoading = false
            return false
        }
    }

    func signInWithGoogle() async {
        guard ensureFirebaseReady() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let authUser = try await SocialSignInService.signInWithGoogle()
            applyAuthenticatedUser(authUser, fallbackName: authUser.displayName)
            isLoading = false
        } catch let error as SocialSignInError where error == .cancelled {
            isLoading = false
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            isLoading = false
        }
    }

    func signInWithApple(result: Result<ASAuthorization, Error>, rawNonce: String) async {
        guard ensureFirebaseReady() else { return }

        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = AuthErrorMapper.message(for: error)
            return
        case .success(let authorization):
            isLoading = true
            errorMessage = nil

            do {
                let signInResult = try await SocialSignInService.signInWithApple(
                    authorization: authorization,
                    rawNonce: rawNonce
                )
                applyAuthenticatedUser(signInResult.user, fallbackName: signInResult.suggestedName)
                isLoading = false
            } catch let error as SocialSignInError where error == .cancelled {
                isLoading = false
            } catch {
                errorMessage = AuthErrorMapper.message(for: error)
                isLoading = false
            }
        }
    }

    func logout() {
        NotificationService.shared.cancelWorkoutInactivityReminder()
        NotificationService.shared.cancelDailyMotivationNotifications()

        if FirebaseBootstrap.isConfigured {
            try? FirebaseAuthProvider.signOut()
        }

        clearLocalSession()
    }

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        saveCachedProfile(profile)
        NotificationService.shared.scheduleDailyMotivationNotifications()
    }

    func updateProfileImage(_ image: UIImage?) {
        guard let uid = currentUser?.id else { return }

        if let image {
            Self.saveImage(image, for: uid)
            profileImage = image
        } else {
            Self.deleteImage(for: uid)
            profileImage = nil
        }
    }

    func loadProfileImage() {
        guard let user = currentUser else {
            profileImage = nil
            return
        }
        profileImage = Self.loadImage(for: user.id) ?? Self.loadLegacyImage(for: user.email)
    }

    // MARK: - Private

    private func observeAuthState() {
        guard FirebaseBootstrap.isConfigured else {
            restoreLegacyLocalSessionIfNeeded()
            isRestoringSession = false
            return
        }

        FirebaseAuthProvider.startObservingState { [weak self] authUser in
            guard let self else { return }

            if let authUser {
                self.applyAuthenticatedUser(authUser, fallbackName: nil)
            } else {
                self.clearLocalSession()
            }
            self.isRestoringSession = false
        }
    }

    private func applyAuthenticatedUser(_ authUser: AuthenticatedFirebaseUser, fallbackName: String?) {
        if let cached = loadCachedProfile(uid: authUser.uid) {
            var profile = cached
            if profile.email != authUser.email {
                profile.email = authUser.email
                saveCachedProfile(profile)
            }
            persistSession(with: profile)
            return
        }

        if let migrated = migrateLegacyProfile(for: authUser) {
            persistSession(with: migrated)
            return
        }

        let defaultName = fallbackName
            ?? authUser.displayName
            ?? authUser.email.components(separatedBy: "@").first?.capitalized
            ?? "Atleta"

        let profile = UserProfile(
            id: authUser.uid,
            name: defaultName,
            email: authUser.email
        )
        persistSession(with: profile)
    }

    private func persistSession(with profile: UserProfile) {
        currentUser = profile
        isAuthenticated = true
        saveCachedProfile(profile)
        loadProfileImage()
        NotificationService.shared.scheduleDailyMotivationNotifications()
        NotificationService.shared.refreshWorkoutInactivityReminder(
            lastWorkoutAt: nil,
            accountCreatedAt: profile.createdAt
        )
    }

    private func clearLocalSession() {
        currentUser = nil
        profileImage = nil
        isAuthenticated = false
    }

    private func profileCacheKey(for uid: String) -> String {
        "healthfit_profile_\(uid)"
    }

    private func saveCachedProfile(_ user: UserProfile) {
        let key = profileCacheKey(for: user.id)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadCachedProfile(uid: String) -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey(for: uid)),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return user
    }

    private func migrateLegacyProfile(for authUser: AuthenticatedFirebaseUser) -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: legacyUserDefaultsKey),
              var legacy = try? JSONDecoder().decode(UserProfile.self, from: data),
              legacy.email.lowercased() == authUser.email.lowercased() else {
            return nil
        }

        legacy.id = authUser.uid
        legacy.email = authUser.email
        saveCachedProfile(legacy)
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        return legacy
    }

    private func restoreLegacyLocalSessionIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: legacyUserDefaultsKey),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        currentUser = user
        isAuthenticated = true
        loadProfileImage()
        NotificationService.shared.scheduleDailyMotivationNotifications()
    }

    @discardableResult
    private func ensureFirebaseReady() -> Bool {
        guard FirebaseBootstrap.isConfigured else {
            errorMessage = "Firebase não configurado. Adicione o GoogleService-Info.plist do seu projeto."
            return false
        }
        return true
    }

    private static func loadLegacyImage(for email: String) -> UIImage? {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        let url = directory.appendingPathComponent("profile_\(safeEmail).jpg")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private static func profileImageURL(for uid: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeUID = uid.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("profile_\(safeUID).jpg")
    }

    private static func loadImage(for uid: String) -> UIImage? {
        let url = profileImageURL(for: uid)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private static func saveImage(_ image: UIImage, for uid: String) {
        let resized = image.resizedForProfile(maxSide: 400)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: profileImageURL(for: uid), options: .atomic)
    }

    private static func deleteImage(for uid: String) {
        let url = profileImageURL(for: uid)
        try? FileManager.default.removeItem(at: url)
    }
}

private extension UIImage {
    func resizedForProfile(maxSide: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxSide else { return self }

        let scale = maxSide / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
