import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Funil mínimo de Analytics + Crashlytics (no-op se Firebase não estiver configurado).
enum AppAnalytics {
    static func configureAfterFirebase() {
        guard FirebaseBootstrap.isConfigured else { return }
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    static func setUserID(_ userId: String?) {
        guard FirebaseBootstrap.isConfigured else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId ?? "")
        #endif
    }

    static func log(_ name: String, parameters: [String: Any] = [:]) {
        guard FirebaseBootstrap.isConfigured else { return }
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
        #endif
    }

    static func signUp(method: String) {
        log("sign_up", parameters: ["method": method])
    }

    static func login(method: String) {
        log("login", parameters: ["method": method])
    }

    static func workoutCompleted(kind: String, calories: Int) {
        log("workout_completed", parameters: [
            "workout_kind": kind,
            "calories": calories
        ])
    }

    static func paywallView(feature: String?) {
        var params: [String: Any] = [:]
        if let feature { params["feature"] = feature }
        log("paywall_view", parameters: params)
    }

    static func purchaseSuccess(productId: String) {
        log("purchase_success", parameters: ["product_id": productId])
    }

    static func purchaseFail(productId: String?, reason: String) {
        var params: [String: Any] = ["reason": reason]
        if let productId { params["product_id"] = productId }
        log("purchase_fail", parameters: params)
    }

    static func accountDelete() {
        log("account_delete")
    }
}
