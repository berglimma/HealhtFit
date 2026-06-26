import Foundation
import Combine
import UIKit

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var profileImage: UIImage?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaultsKey = "healthfit_current_user"

    init() {
        loadSavedUser()
        loadProfileImage()
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        try? await Task.sleep(nanoseconds: 800_000_000)

        guard !email.isEmpty, password.count >= 6 else {
            errorMessage = "E-mail ou senha inválidos"
            isLoading = false
            return
        }

        let name = email.components(separatedBy: "@").first?.capitalized ?? "Atleta"
        let user = UserProfile(name: name, email: email)
        currentUser = user
        isAuthenticated = true
        saveUser(user)
        loadProfileImage()
        isLoading = false
    }

    func register(name: String, email: String, password: String, biotype: Biotype, goal: FitnessGoal) async {
        isLoading = true
        errorMessage = nil

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        guard !name.isEmpty, email.contains("@"), password.count >= 6 else {
            errorMessage = "Preencha todos os campos corretamente"
            isLoading = false
            return
        }

        let user = UserProfile(name: name, email: email, biotype: biotype, goal: goal)
        currentUser = user
        isAuthenticated = true
        saveUser(user)
        loadProfileImage()
        isLoading = false
    }

    func logout() {
        currentUser = nil
        profileImage = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        saveUser(profile)
    }

    func updateProfileImage(_ image: UIImage?) {
        guard let email = currentUser?.email else { return }

        if let image {
            Self.saveImage(image, for: email)
            profileImage = image
        } else {
            Self.deleteImage(for: email)
            profileImage = nil
        }
    }

    func loadProfileImage() {
        guard let email = currentUser?.email else {
            profileImage = nil
            return
        }
        profileImage = Self.loadImage(for: email)
    }

    private func saveUser(_ user: UserProfile) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadSavedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        currentUser = user
        isAuthenticated = true
        loadProfileImage()
    }

    private static func profileImageURL(for email: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeEmail = email.lowercased().replacingOccurrences(of: "@", with: "_at_")
        return directory.appendingPathComponent("profile_\(safeEmail).jpg")
    }

    private static func loadImage(for email: String) -> UIImage? {
        let url = profileImageURL(for: email)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private static func saveImage(_ image: UIImage, for email: String) {
        let resized = image.resizedForProfile(maxSide: 400)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: profileImageURL(for: email), options: .atomic)
    }

    private static func deleteImage(for email: String) {
        let url = profileImageURL(for: email)
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
