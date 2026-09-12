import Combine
import Foundation
import UIKit
import FirebaseFirestore

/// Garante que o usuário use a versão publicada na App Store.
/// iOS não permite atualização silenciosa: bloqueamos o app e abrimos a loja.
@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    @Published private(set) var isChecking = false
    @Published private(set) var requiresUpdate = false
    @Published private(set) var storeVersion: String?
    @Published private(set) var installedVersion: String
    @Published private(set) var updateMessage: String
    @Published private(set) var appStoreURL: URL?
    /// Incrementado quando flags remotas/locais do Pulse mudam — views observam para re-render.
    @Published private(set) var pulseFlagsEpoch: Int = 0

    private var lastCheckedAt: Date?
    private let minimumRecheckInterval: TimeInterval = 90

    private static let defaultMessage =
        "Há uma nova versão do HealthFit na App Store. Atualize para continuar com as melhorias e correções mais recentes."

    private init() {
        installedVersion = Self.currentMarketingVersion()
        updateMessage = Self.defaultMessage
        appStoreURL = URL(string: "https://apps.apple.com/app/id\(Self.fallbackAppStoreId)")
    }

    /// ID numérico da App Store (atualize se o app receber outro ID após a publicação).
    static let fallbackAppStoreId = "6798621208"

    static func currentMarketingVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func currentBundleIdentifier() -> String {
        Bundle.main.bundleIdentifier ?? "luan.com.healthfit.app"
    }

    /// Checa App Store + Firestore (`appConfig/ios`) ao abrir / voltar ao app.
    /// Flags do Pulse (`pulseEnabled`, `pulseCloudSyncEnabled`) são aplicadas mesmo em DEBUG.
    func checkForRequiredUpdate(force: Bool = false) async {
        if !force, let lastCheckedAt,
           Date().timeIntervalSince(lastCheckedAt) < minimumRecheckInterval,
           requiresUpdate {
            return
        }

        isChecking = true
        defer {
            isChecking = false
            lastCheckedAt = Date()
        }

        installedVersion = Self.currentMarketingVersion()

        async let store = fetchAppStoreVersion()
        async let remote = fetchRemoteMinimumConfig()

        let storeInfo = await store
        let remoteConfig = await remote

        applyPulseRemoteFlags(remoteConfig)

        #if DEBUG
        // Em debug/simulador não bloqueia o desenvolvimento local.
        if ProcessInfo.processInfo.environment["HEALTHFIT_FORCE_UPDATE_CHECK"] != "1" {
            requiresUpdate = false
            return
        }
        #endif

        if let storeInfo {
            storeVersion = storeInfo.version
            if let url = storeInfo.trackViewURL {
                appStoreURL = url
            } else if let trackId = storeInfo.trackId {
                appStoreURL = URL(string: "https://apps.apple.com/app/id\(trackId)")
            }
        }

        if let message = remoteConfig?.message, !message.isEmpty {
            updateMessage = message
        } else {
            updateMessage = Self.defaultMessage
        }

        if let remoteURL = remoteConfig?.appStoreURL {
            appStoreURL = remoteURL
        }

        let latestFromStore = storeInfo?.version
        let minimum = remoteConfig?.minimumVersion
        let latestHint = remoteConfig?.latestVersion ?? latestFromStore

        var needsUpdate = false

        if let minimum, Self.isVersion(installedVersion, lessThan: minimum) {
            needsUpdate = true
        }
        if let latestHint, Self.isVersion(installedVersion, lessThan: latestHint) {
            needsUpdate = true
        }
        // Política pedida: sempre exigir a versão mais recente da loja quando houver.
        if remoteConfig?.forceUpdateOnNewerStoreVersion != false,
           let latestFromStore,
           Self.isVersion(installedVersion, lessThan: latestFromStore) {
            needsUpdate = true
        }

        requiresUpdate = needsUpdate
    }

    /// Notifica a UI após toggles locais (Labs).
    func notifyPulseLocalFlagChange() {
        pulseFlagsEpoch &+= 1
    }

    private func applyPulseRemoteFlags(_ remoteConfig: RemoteAppConfig?) {
        let ui = remoteConfig?.pulseEnabled ?? false
        let cloud = remoteConfig?.pulseCloudSyncEnabled ?? false
        let changed = ui != PulseExperimental.remoteUIEnabled
            || cloud != PulseExperimental.remoteCloudSyncEnabled
        PulseExperimental.applyRemoteFlags(uiEnabled: ui, cloudSyncEnabled: cloud)
        if changed {
            pulseFlagsEpoch &+= 1
        }
    }

    func openAppStore() {
        let url = appStoreURL
            ?? URL(string: "https://apps.apple.com/app/id\(Self.fallbackAppStoreId)")
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Sources

    private struct AppStoreLookupResult {
        var version: String
        var trackId: Int?
        var trackViewURL: URL?
    }

    private struct RemoteAppConfig {
        var minimumVersion: String?
        var latestVersion: String?
        var message: String?
        var appStoreURL: URL?
        /// Default true — bloqueia se a loja tiver versão maior.
        var forceUpdateOnNewerStoreVersion: Bool
        /// Kill-switch / rollout do Pulse (default false = off para a maioria).
        var pulseEnabled: Bool
        var pulseCloudSyncEnabled: Bool
    }

    private func fetchAppStoreVersion() async -> AppStoreLookupResult? {
        let bundleId = Self.currentBundleIdentifier()
        // country=br melhora o match para publicação BR.
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=br") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let version = first["version"] as? String,
                !version.isEmpty
            else {
                return nil
            }

            let trackId = first["trackId"] as? Int
            let trackViewURL = (first["trackViewUrl"] as? String).flatMap(URL.init(string:))
            return AppStoreLookupResult(version: version, trackId: trackId, trackViewURL: trackViewURL)
        } catch {
            #if DEBUG
            print("[HealthFit] App Store lookup failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private func fetchRemoteMinimumConfig() async -> RemoteAppConfig? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        do {
            let snap = try await Firestore.firestore()
                .collection("appConfig")
                .document("ios")
                .getDocument()
            guard let data = snap.data() else {
                return RemoteAppConfig(
                    forceUpdateOnNewerStoreVersion: true,
                    pulseEnabled: false,
                    pulseCloudSyncEnabled: false
                )
            }
            let message = data["updateMessage"] as? String
            let appStoreURLString = data["appStoreURL"] as? String
            let force = (data["forceUpdateOnNewerStoreVersion"] as? Bool)
                ?? (data["forceUpdate"] as? Bool)
                ?? true
            return RemoteAppConfig(
                minimumVersion: data["minimumVersion"] as? String,
                latestVersion: data["latestVersion"] as? String,
                message: message,
                appStoreURL: appStoreURLString.flatMap(URL.init(string:)),
                forceUpdateOnNewerStoreVersion: force,
                pulseEnabled: data["pulseEnabled"] as? Bool ?? false,
                pulseCloudSyncEnabled: data["pulseCloudSyncEnabled"] as? Bool ?? false
            )
        } catch {
            #if DEBUG
            print("[HealthFit] appConfig/ios read failed: \(error.localizedDescription)")
            #endif
            return RemoteAppConfig(
                forceUpdateOnNewerStoreVersion: true,
                pulseEnabled: false,
                pulseCloudSyncEnabled: false
            )
        }
    }

    // MARK: - Version compare

    /// Semântico simples: "1.2.0" < "1.10.0".
    static func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        compareVersions(lhs, rhs) == .orderedAscending
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = normalizedComponents(lhs)
        let right = normalizedComponents(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func normalizedComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let digits = part.prefix(while: { $0.isNumber })
                return Int(digits) ?? 0
            }
    }
}
