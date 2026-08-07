import Foundation
import FirebaseCore
import FirebaseAuth

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configure() {
        guard !isConfigured else { return }
        guard Self.hasValidConfiguration else {
            #if DEBUG
            print("[HealthFit] Firebase não configurado. Adicione GoogleService-Info.plist do Firebase Console.")
            #endif
            return
        }

        FirebaseApp.configure()
        isConfigured = true
        AppAnalytics.configureAfterFirebase()

        #if DEBUG
        configureAuthEmulatorIfNeeded()
        #endif
    }

    private static var hasValidConfiguration: Bool {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let appID = plist["GOOGLE_APP_ID"] as? String,
              let apiKey = plist["API_KEY"] as? String else {
            return false
        }

        let placeholders = ["REPLACE_ME", "YOUR_", "TODO"]
        let combined = "\(appID)\(apiKey)"
        return placeholders.allSatisfy { !combined.contains($0) }
    }

    #if DEBUG
    private static func configureAuthEmulatorIfNeeded() {
        guard ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "1" else { return }
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        print("[HealthFit] Firebase Auth Emulator ativo (127.0.0.1:9099)")
    }
    #endif
}
