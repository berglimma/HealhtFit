import Foundation
import FirebaseCore

enum GoogleServiceInfo {
    static var clientID: String? {
        if let clientID = plistString(for: "CLIENT_ID") {
            return clientID
        }
        return FirebaseApp.app()?.options.clientID
    }

    static var reversedClientID: String? {
        if let reversed = plistString(for: "REVERSED_CLIENT_ID") {
            return reversed
        }
        guard let clientID = clientID else { return nil }
        return Self.reversedClientID(from: clientID)
    }

    static var isGoogleSignInConfigured: Bool {
        clientID != nil
    }

    private static func plistString(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let value = plist[key] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func reversedClientID(from clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return nil }
        let id = String(clientID.dropLast(suffix.count))
        return "com.googleusercontent.apps.\(id)"
    }
}
