import Foundation
import SwiftUI

import Combine
/// Idiomas com traduções em `Localizable.xcstrings`.
enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case portuguese = "pt-BR"
    case english = "en"
    case spanish = "es"
    case french = "fr"

    static let storageKey = "healthfit_app_language"
    static let defaultLanguage: AppLanguage = .portuguese

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Nome nativo (não traduzido) + bandeira para o seletor.
    var flag: String {
        switch self {
        case .portuguese: return "🇧🇷"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        }
    }

    var nativeName: String {
        switch self {
        case .portuguese: return "Português"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }

    var menuLabel: String { "\(flag)  \(nativeName)" }

    static func resolved(fromStoredCode code: String?) -> AppLanguage {
        AppLanguage(rawValue: code ?? "") ?? defaultLanguage
    }
}

/// Preferência de idioma do dispositivo (persiste entre logout/login).
@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    var locale: Locale { language.locale }

    init(userDefaults: UserDefaults = .standard) {
        let saved = userDefaults.string(forKey: AppLanguage.storageKey)
        if let saved, let resolved = AppLanguage(rawValue: saved) {
            language = resolved
        } else {
            language = AppLanguage.defaultLanguage
            // didSet não roda no init — grava o padrão pt-BR explicitamente.
            userDefaults.set(AppLanguage.defaultLanguage.rawValue, forKey: AppLanguage.storageKey)
        }
    }
}
