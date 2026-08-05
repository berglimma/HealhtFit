import Foundation
import Combine
import UIKit
import AuthenticationServices
import FirebaseAuth

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var profileImage: UIImage?
    @Published var profileBackgroundImage: UIImage?
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

    func register(
        name: String,
        email: String,
        password: String,
        biotype: Biotype,
        goal: FitnessGoal,
        dateOfBirth: Date,
        countryCode: String = CountryOption.defaultCode()
    ) async {
        guard ensureFirebaseReady() else { return }

        isLoading = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty, normalizedEmail.contains("@") else {
            errorMessage = "Preencha todos os campos corretamente"
            isLoading = false
            return
        }

        guard UserProfile.isValidDateOfBirth(dateOfBirth) else {
            errorMessage = "Informe uma data de nascimento válida (14 a 100 anos)."
            isLoading = false
            return
        }

        guard PasswordPolicy.isValid(password) else {
            errorMessage = PasswordPolicy.failureMessage
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
                goal: goal,
                dateOfBirth: dateOfBirth,
                countryCode: countryCode
            )
            persistSession(with: profile)
            isLoading = false
            syncProfileToCloud(profile)
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
        NotificationService.shared.cancelCardioInactivityReminder()
        NotificationService.shared.cancelMeditationInactivityReminder()
        NotificationService.shared.cancelHealthIconRedReminder()
        NotificationService.shared.cancelDailyMotivationNotifications()
        NotificationService.shared.cancelWaterReminders()
        NotificationService.shared.cancelSupplementReminders()
        NotificationService.shared.updateMealReminders(hasMealPlan: false)
        EveningTrainingNudgeService.cancelAll()
        WorkoutLiveActivitySync.end()

        if FirebaseBootstrap.isConfigured {
            try? FirebaseAuthProvider.signOut()
        }

        clearLocalSession()
    }

    func deleteAccount(
        password: String?,
        workoutStore: WorkoutStore,
        mealPlanService: MealPlanService,
        wellnessService: DailyWellnessService,
        skipReauthentication: Bool = false
    ) async -> Bool {
        guard ensureFirebaseReady(), let user = currentUser else {
            errorMessage = "Nenhuma conta ativa encontrada."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            if !skipReauthentication {
                try await reauthenticateForDeletion(password: password)
            }
            try await deleteRemoteData(userId: user.id)
            purgeLocalData(
                uid: user.id,
                email: user.email,
                workoutStore: workoutStore,
                mealPlanService: mealPlanService,
                wellnessService: wellnessService
            )
            try await FirebaseAuthProvider.deleteCurrentUser()
            clearLocalSession()
            isLoading = false
            return true
        } catch {
            errorMessage = AuthErrorMapper.message(for: error)
            isLoading = false
            return false
        }
    }

    func reauthenticateWithApple(result: Result<ASAuthorization, Error>, rawNonce: String) async -> Bool {
        guard ensureFirebaseReady() else { return false }

        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return false
            }
            errorMessage = AuthErrorMapper.message(for: error)
            return false
        case .success(let authorization):
            isLoading = true
            errorMessage = nil
            do {
                try await SocialSignInService.reauthenticateWithApple(
                    authorization: authorization,
                    rawNonce: rawNonce
                )
                isLoading = false
                return true
            } catch let error as SocialSignInError where error == .cancelled {
                isLoading = false
                return false
            } catch {
                errorMessage = AuthErrorMapper.message(for: error)
                isLoading = false
                return false
            }
        }
    }

    var usesPasswordProvider: Bool {
        guard FirebaseBootstrap.isConfigured else { return false }
        let provider = FirebaseAuthProvider.primarySignInProvider
        return provider == EmailAuthProviderID || provider == nil
    }

    var usesAppleProvider: Bool {
        FirebaseAuthProvider.primarySignInProvider == "apple.com"
    }

    func updateProfile(_ profile: UserProfile) {
        var profile = profile
        profile.updatedAt = .now
        currentUser = profile
        saveCachedProfile(profile)
        markProfileDirty(true, userId: profile.id)
        NotificationService.shared.refreshRecurringNotifications()
        syncProfileToCloud(profile)
    }

    /// Garante envio pendente ao Firebase (ex.: ao ir para background).
    func flushProfileToCloudIfNeeded() {
        guard let user = currentUser, isProfileDirty(userId: user.id) else { return }
        syncProfileToCloud(user)
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

    func updateProfileBackgroundImage(_ image: UIImage?) {
        guard let uid = currentUser?.id else { return }

        if let image {
            Self.saveBackgroundImage(image, for: uid)
            profileBackgroundImage = image
        } else {
            Self.deleteBackgroundImage(for: uid)
            profileBackgroundImage = nil
        }
    }

    func loadProfileImage() {
        guard let user = currentUser else {
            profileImage = nil
            profileBackgroundImage = nil
            return
        }
        profileImage = Self.loadImage(for: user.id) ?? Self.loadLegacyImage(for: user.email)
        profileBackgroundImage = Self.loadBackgroundImage(for: user.id)
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
            Task { await refreshProfileFromCloud(userId: authUser.uid, email: authUser.email) }
            return
        }

        if let migrated = migrateLegacyProfile(for: authUser) {
            persistSession(with: migrated)
            Task { await refreshProfileFromCloud(userId: authUser.uid, email: authUser.email) }
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
        Task { await refreshProfileFromCloud(userId: authUser.uid, email: authUser.email) }
    }

    private func syncProfileToCloud(_ profile: UserProfile) {
        guard ProfileFirestoreService.isAvailable else { return }
        let profileToSave = profile
        Task {
            do {
                try await ProfileFirestoreService.saveProfile(profileToSave)
                await MainActor.run {
                    reconcileSuccessfulCloudSave(profileToSave)
                }
            } catch {
                print("[HealthFit] Falha ao salvar perfil no Firebase: \(error.localizedDescription)")
            }
        }
    }

    private func reconcileSuccessfulCloudSave(_ saved: UserProfile) {
        guard let current = currentUser, current.id == saved.id else {
            markProfileDirty(false, userId: saved.id)
            return
        }

        if current.updatedAt > saved.updatedAt {
            // Há alteração local mais nova — mantém dirty e reenvia.
            markProfileDirty(true, userId: current.id)
            syncProfileToCloud(current)
            return
        }

        markProfileDirty(false, userId: saved.id)
    }

    private func refreshProfileFromCloud(userId: String, email: String) async {
        guard ProfileFirestoreService.isAvailable else { return }

        do {
            if let remote = try await ProfileFirestoreService.fetchProfile(userId: userId) {
                var remoteProfile = remote
                remoteProfile.id = userId
                if remoteProfile.email != email {
                    remoteProfile.email = email
                }

                let local = currentUser?.id == userId
                    ? currentUser
                    : loadCachedProfile(uid: userId)
                let dirty = isProfileDirty(userId: userId)

                if let local, dirty || local.updatedAt > remoteProfile.updatedAt {
                    // Local é mais recente (ou sync pendente): não sobrescreve e empurra ao Firebase.
                    var kept = local
                    if kept.email != email {
                        kept.email = email
                        kept.updatedAt = .now
                        saveCachedProfile(kept)
                        currentUser = kept
                    }
                    try await ProfileFirestoreService.saveProfile(kept)
                    await MainActor.run {
                        markProfileDirty(false, userId: userId)
                        persistSession(with: kept)
                    }
                } else {
                    await MainActor.run {
                        markProfileDirty(false, userId: userId)
                        persistSession(with: remoteProfile)
                    }
                }
            } else if let local = currentUser, local.id == userId {
                try await ProfileFirestoreService.saveProfile(local)
                await MainActor.run {
                    markProfileDirty(false, userId: userId)
                }
            }
        } catch {
            print("[HealthFit] Falha ao carregar perfil do Firebase: \(error.localizedDescription)")
            if let local = currentUser, local.id == userId {
                syncProfileToCloud(local)
            }
        }
    }

    private func profileDirtyKey(for userId: String) -> String {
        "healthfit_profile_dirty_\(userId)"
    }

    private func markProfileDirty(_ dirty: Bool, userId: String) {
        UserDefaults.standard.set(dirty, forKey: profileDirtyKey(for: userId))
    }

    private func isProfileDirty(userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: profileDirtyKey(for: userId))
    }

    private func persistSession(with profile: UserProfile) {
        currentUser = profile
        isAuthenticated = true
        saveCachedProfile(profile)
        loadProfileImage()
        NotificationService.shared.refreshRecurringNotifications()
        NotificationService.shared.refreshWorkoutInactivityReminder(
            lastWorkoutAt: nil,
            accountCreatedAt: profile.createdAt
        )
        NotificationService.shared.refreshCardioInactivityReminder(
            lastCardioAt: nil,
            accountCreatedAt: profile.createdAt
        )
        NotificationService.shared.refreshMeditationInactivityReminder(
            lastMeditationAt: nil,
            accountCreatedAt: profile.createdAt
        )
    }

    private func clearLocalSession() {
        currentUser = nil
        profileImage = nil
        profileBackgroundImage = nil
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
        NotificationService.shared.refreshRecurringNotifications()
    }

    @discardableResult
    private func ensureFirebaseReady() -> Bool {
        guard FirebaseBootstrap.isConfigured else {
            errorMessage = "Firebase não configurado. Adicione o GoogleService-Info.plist do seu projeto."
            return false
        }
        return true
    }

    private func reauthenticateForDeletion(password: String?) async throws {
        guard let provider = FirebaseAuthProvider.primarySignInProvider else {
            if let email = currentUser?.email, let password, !password.isEmpty {
                try await FirebaseAuthProvider.reauthenticate(email: email, password: password)
            }
            return
        }

        switch provider {
        case EmailAuthProviderID:
            guard let email = currentUser?.email,
                  let password,
                  !password.isEmpty else {
                throw NSError(
                    domain: AuthErrorDomain,
                    code: AuthErrorCode.requiresRecentLogin.rawValue
                )
            }
            try await FirebaseAuthProvider.reauthenticate(email: email, password: password)
        case "google.com":
            try await SocialSignInService.reauthenticateWithGoogle()
        case "apple.com":
            throw AccountDeletionError.appleReauthenticationRequired
        default:
            if let email = currentUser?.email, let password, !password.isEmpty {
                try await FirebaseAuthProvider.reauthenticate(email: email, password: password)
            }
        }
    }

    private func deleteRemoteData(userId: String) async throws {
        guard WorkoutFirestoreService.isAvailable else { return }
        try await DailyWellnessFirestoreService.deleteAllEntries(userId: userId)
        try await WorkoutFirestoreService.deleteAllUserData(userId: userId)
    }

    private func purgeLocalData(
        uid: String,
        email: String,
        workoutStore: WorkoutStore,
        mealPlanService: MealPlanService,
        wellnessService: DailyWellnessService
    ) {
        NotificationService.shared.cancelWorkoutInactivityReminder()
        NotificationService.shared.cancelCardioInactivityReminder()
        NotificationService.shared.cancelMeditationInactivityReminder()
        NotificationService.shared.cancelHealthIconRedReminder()
        NotificationService.shared.cancelDailyMotivationNotifications()
        NotificationService.shared.cancelWaterReminders()
        NotificationService.shared.cancelSupplementReminders()
        NotificationService.shared.updateMealReminders(hasMealPlan: false)
        NotificationService.shared.cancelDailyAssistantCheckIn()
        NotificationService.shared.cancelDailyEveningAssistantCheckIn()
        EveningTrainingNudgeService.cancelAll()
        WorkoutLiveActivitySync.end()

        workoutStore.clearAllLocalData()
        mealPlanService.clearAllLocalData()
        wellnessService.clearAllLocalData()
        TrainingNutritionSyncService.shared.clear()
        WeeklyReportService.shared.reset()
        MonthlyReportService.shared.reset()
        AssistantSupplementNudgeEngine.reset()
        WorkoutShareCardStore.shared.reset()
        PostWorkoutCheckInService.shared.resetForAccountDeletion()
        DailyMorningCheckInService.shared.resetForAccountDeletion()
        DailyEveningCheckInService.shared.resetForAccountDeletion()
        AppIconInactivityService.shared.resetForAccountDeletion()

        UserDataCleaner.clearAllLocalData(uid: uid, email: email)
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

    private static func profileBackgroundURL(for uid: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeUID = uid.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("profile_bg_\(safeUID).jpg")
    }

    private static func loadBackgroundImage(for uid: String) -> UIImage? {
        let url = profileBackgroundURL(for: uid)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private static func saveBackgroundImage(_ image: UIImage, for uid: String) {
        let resized = image.resizedForProfile(maxSide: 1_200)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: profileBackgroundURL(for: uid), options: .atomic)
    }

    private static func deleteBackgroundImage(for uid: String) {
        let url = profileBackgroundURL(for: uid)
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
