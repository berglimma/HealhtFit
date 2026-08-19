import Foundation

/// Chaves de localização (pt-BR, en, es, fr).
enum L10n {
    static func tr(_ key: String) -> String {
        let code = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        let language = AppLanguage.resolved(fromStoredCode: code)
        return String(localized: String.LocalizationValue(key), locale: language.locale)
    }

    enum Tab {
        static var home: String { tr("tab.home") }
        static var workouts: String { tr("tab.workouts") }
        static var nutrition: String { tr("tab.nutrition") }
        static var assistant: String { tr("tab.assistant") }
        static var profile: String { tr("tab.profile") }
    }

    enum Auth {
        static var appTagline: String { tr("auth.app_tagline") }
        static var email: String { tr("auth.email") }
        static var emailPlaceholder: String { tr("auth.email_placeholder") }
        static var password: String { tr("auth.password") }
        static var passwordPlaceholder: String { tr("auth.password_placeholder") }
        static var forgotPassword: String { tr("auth.forgot_password") }
        static var signIn: String { tr("auth.sign_in") }
        static var createAccount: String { tr("auth.create_account") }
        static var createAccountSubtitle: String { tr("auth.create_account_subtitle") }
        static var registerTitle: String { tr("auth.register_title") }
        static var registerSubtitle: String { tr("auth.register_subtitle") }
        static var fullName: String { tr("auth.full_name") }
        static var confirmPassword: String { tr("auth.confirm_password") }
        static var biotype: String { tr("auth.biotype") }
        static var goal: String { tr("auth.goal") }
        static var acceptTerms: String { tr("auth.accept_terms") }
        static var register: String { tr("auth.register") }
        static var continueGoogle: String { tr("auth.continue_google") }
        static var continueApple: String { tr("auth.continue_apple") }
        static var or: String { tr("auth.or") }
        static var resetTitle: String { tr("auth.reset_title") }
        static var resetSubtitle: String { tr("auth.reset_subtitle") }
        static var resetSend: String { tr("auth.reset_send") }
        static var close: String { tr("auth.close") }
    }

    enum Common {
        static var yes: String { tr("common.yes") }
        static var no: String { tr("common.no") }
        static var cancel: String { tr("common.cancel") }
        static var save: String { tr("common.save") }
        static var ok: String { tr("common.ok") }
        static var loading: String { tr("common.loading") }
    }

    enum Profile {
        static var personalTrainer: String { tr("profile.personal_trainer") }
        static var hasPersonalTrainer: String { tr("profile.has_personal_trainer") }
        static var nutritionist: String { tr("profile.nutritionist") }
        static var hasNutritionist: String { tr("profile.has_nutritionist") }
        static var trainerName: String { tr("profile.trainer_name") }
        static var trainerEmail: String { tr("profile.trainer_email") }
        static var nutritionistName: String { tr("profile.nutritionist_name") }
        static var nutritionistEmail: String { tr("profile.nutritionist_email") }
        static var accountRole: String { tr("profile.account_role") }
        static var accountRoleStudent: String { tr("profile.account_role.student") }
        static var accountRolePersonal: String { tr("profile.account_role.personal") }
        static var accountRoleNutritionist: String { tr("profile.account_role.nutritionist") }
        static var accountRolePersonalAndNutrition: String { tr("profile.account_role.personal_and_nutrition") }
    }

    enum Settings {
        static var language: String { tr("settings.language") }
    }

    enum Workout {
        static var strength: String { tr("workout.section.strength") }
        static var home: String { tr("workout.section.home") }
        static var cardio: String { tr("workout.section.cardio") }
        static var meditation: String { tr("workout.section.meditation") }
        static var mobility: String { tr("workout.mobility") }
        static var homeTitle: String { tr("workout.home_title") }
        static var male: String { tr("workout.male") }
        static var female: String { tr("workout.female") }
    }

    enum Nutrition {
        static var sendReport: String { tr("nutrition.send_report") }
        static var mealCompleted: String { tr("nutrition.meal_completed") }
        static var markCompleted: String { tr("nutrition.mark_completed") }
        static var markIncomplete: String { tr("nutrition.mark_incomplete") }
    }
}
