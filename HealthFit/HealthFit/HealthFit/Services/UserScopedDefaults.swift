import Foundation

/// Namespace de UserDefaults por usuário autenticado.
/// Chaves: `healthfit.u.{uid}.{logicalKey}`.
enum UserScopedDefaults {
    private static let migrationFlagPrefix = "healthfit.u.migrated."

    static func prefix(for uid: String) -> String {
        let safe = uid.replacingOccurrences(of: "/", with: "_")
        return "healthfit.u.\(safe)."
    }

    static func key(_ logicalKey: String, uid: String) -> String {
        prefix(for: uid) + logicalKey
    }

    /// Migra valor de chave global legada para o escopo do uid (uma vez).
    static func migrateIfNeeded(
        logicalKey: String,
        legacyKey: String,
        uid: String,
        defaults: UserDefaults = .standard
    ) {
        let scoped = key(logicalKey, uid: uid)
        let flag = migrationFlagPrefix + uid + "." + logicalKey
        guard defaults.object(forKey: flag) == nil else { return }

        if defaults.object(forKey: scoped) == nil, let legacy = defaults.object(forKey: legacyKey) {
            defaults.set(legacy, forKey: scoped)
            defaults.removeObject(forKey: legacyKey)
        }
        defaults.set(true, forKey: flag)
    }

    static func data(forLogicalKey logicalKey: String, uid: String?, legacyKey: String? = nil) -> Data? {
        guard let uid, !uid.isEmpty else {
            guard let legacyKey else { return nil }
            return UserDefaults.standard.data(forKey: legacyKey)
        }
        if let legacyKey {
            migrateIfNeeded(logicalKey: logicalKey, legacyKey: legacyKey, uid: uid)
        }
        return UserDefaults.standard.data(forKey: key(logicalKey, uid: uid))
            ?? legacyKey.flatMap { UserDefaults.standard.data(forKey: $0) }
    }

    static func setData(_ data: Data?, forLogicalKey logicalKey: String, uid: String?, legacyKey: String? = nil) {
        guard let uid, !uid.isEmpty else {
            if let legacyKey {
                if let data {
                    UserDefaults.standard.set(data, forKey: legacyKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: legacyKey)
                }
            }
            return
        }
        let scoped = key(logicalKey, uid: uid)
        if let data {
            UserDefaults.standard.set(data, forKey: scoped)
        } else {
            UserDefaults.standard.removeObject(forKey: scoped)
        }
        if let legacyKey {
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    static func remove(logicalKey: String, uid: String?, legacyKey: String? = nil) {
        if let uid, !uid.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(logicalKey, uid: uid))
        }
        if let legacyKey {
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }
}
