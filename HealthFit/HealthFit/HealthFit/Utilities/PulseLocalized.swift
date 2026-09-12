import Foundation

/// Catálogo localizado do Pulse (pt-BR, en, es, fr, de, it) alinhado a `AppLanguage`.
enum PulseLocalized {
    private static var language: AppLanguage {
        let code = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        return AppLanguage.resolved(fromStoredCode: code)
    }

    private static var localeCode: String { language.rawValue }

    static func tr(_ key: String) -> String { L10n.tr(key) }

    static func trf(_ key: String, _ args: CVarArg...) -> String {
        let format = L10n.tr(key)
        return String(format: format, locale: language.locale, arguments: args)
    }

    // MARK: - Challenges (JSON)

    static var challengeTemplates: [String] { challenges(for: localeCode) }

    private static var challengeCache: [String: [String]] = [:]

    private static func challenges(for code: String) -> [String] {
        if let cached = challengeCache[code] { return cached }
        guard let url = Bundle.main.url(forResource: "PulseChallenges", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
        else {
            return []
        }
        let list = root[code] ?? root["pt-BR"] ?? []
        challengeCache[code] = list
        return list
    }

    // MARK: - Terms

    static var termsBody: String {
        let name = "PulseTerms_\(localeCode.replacingOccurrences(of: "-", with: "_"))"
        if let url = Bundle.main.url(forResource: name, withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        if let url = Bundle.main.url(forResource: "PulseTerms_pt_BR", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return PulseExperimental.termsBodyFallbackPT
    }
}
