import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

/// Registro de token FCM para push Duo (Cloud Functions).
@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    private var boundUserId: String?
    private var didRequestAuth = false

    private override init() {
        super.init()
    }

    /// Liga o serviço após login / restore de sessão.
    func bind(userId: String?) {
        boundUserId = userId
        guard let userId, !userId.isEmpty else { return }
        guard FirebaseBootstrap.isConfigured else { return }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        Task {
            await requestAuthorizationIfNeeded()
            UIApplication.shared.registerForRemoteNotifications()
            await refreshAndUploadToken(for: userId)
        }
    }

    func clearBinding() {
        boundUserId = nil
    }

    func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        guard let userId = boundUserId else { return }
        Task { await refreshAndUploadToken(for: userId) }
    }

    private func requestAuthorizationIfNeeded() async {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[HealthFit] Push auth failed: \(error.localizedDescription)")
        }
    }

    private func refreshAndUploadToken(for userId: String) async {
        guard FirebaseBootstrap.isConfigured else { return }
        do {
            let token = try await Messaging.messaging().token()
            try await saveToken(token, userId: userId)
        } catch {
            print("[HealthFit] FCM token refresh failed: \(error.localizedDescription)")
        }
    }

    private func saveToken(_ token: String, userId: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20 else { return }

        let docId = Self.tokenDocumentId(for: trimmed)
        let ref = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("fcmTokens")
            .document(docId)

        try await ref.setData([
            "token": trimmed,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp(),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        ], merge: true)
    }

    private static func tokenDocumentId(for token: String) -> String {
        // ID estável e curto (Firestore doc id ≤ 1500 bytes).
        let digest = token.utf8.reduce(into: UInt64(5381)) { hash, byte in
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(digest, radix: 16)
    }
}

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { @MainActor in
            guard let userId = boundUserId else { return }
            try? await saveToken(fcmToken, userId: userId)
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let kind = (userInfo["kind"] as? String) ?? ""
        let type = (userInfo["type"] as? String) ?? ""
        let teamId = (userInfo["teamId"] as? String) ?? ""
        let teamName = (userInfo["teamName"] as? String) ?? ""
        Task { @MainActor in
            routeDuoPushIfNeeded(kind: kind, type: type, teamId: teamId, teamName: teamName)
            completionHandler()
        }
    }

    @MainActor
    private func routeDuoPushIfNeeded(kind: String, type: String, teamId: String, teamName: String) {
        guard kind == "DUO_TEAM" || type.hasPrefix("duoChat") else { return }
        guard !teamId.isEmpty else { return }
        DuoNavigationRouter.shared.openChat(teamId: teamId, teamName: teamName)
    }
}

/// Bridge UIKit para APNs device token.
final class HealthFitAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.applicationDidRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[HealthFit] APNs registration failed: \(error.localizedDescription)")
    }
}
