import Foundation

/// Chaves de localização (pt-BR, en, es, fr).
enum L10n {
    static func tr(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    enum Tab {
        static let home = tr("tab.home")
        static let workouts = tr("tab.workouts")
        static let nutrition = tr("tab.nutrition")
        static let assistant = tr("tab.assistant")
        static let profile = tr("tab.profile")
    }

    enum Auth {
        static let appTagline = tr("auth.app_tagline")
        static let email = tr("auth.email")
        static let emailPlaceholder = tr("auth.email_placeholder")
        static let password = tr("auth.password")
        static let passwordPlaceholder = tr("auth.password_placeholder")
        static let forgotPassword = tr("auth.forgot_password")
        static let signIn = tr("auth.sign_in")
        static let createAccount = tr("auth.create_account")
        static let createAccountSubtitle = tr("auth.create_account_subtitle")
        static let registerTitle = tr("auth.register_title")
        static let registerSubtitle = tr("auth.register_subtitle")
        static let fullName = tr("auth.full_name")
        static let confirmPassword = tr("auth.confirm_password")
        static let biotype = tr("auth.biotype")
        static let goal = tr("auth.goal")
        static let acceptTerms = tr("auth.accept_terms")
        static let register = tr("auth.register")
        static let continueGoogle = tr("auth.continue_google")
        static let continueApple = tr("auth.continue_apple")
        static let or = tr("auth.or")
        static let resetTitle = tr("auth.reset_title")
        static let resetSubtitle = tr("auth.reset_subtitle")
        static let resetSend = tr("auth.reset_send")
        static let close = tr("auth.close")
    }

    enum Common {
        static let yes = tr("common.yes")
        static let no = tr("common.no")
        static let cancel = tr("common.cancel")
        static let save = tr("common.save")
        static let ok = tr("common.ok")
        static let loading = tr("common.loading")
    }

    enum Profile {
        static let personalTrainer = tr("profile.personal_trainer")
        static let hasPersonalTrainer = tr("profile.has_personal_trainer")
        static let nutritionist = tr("profile.nutritionist")
        static let hasNutritionist = tr("profile.has_nutritionist")
        static let trainerName = tr("profile.trainer_name")
        static let trainerEmail = tr("profile.trainer_email")
        static let nutritionistName = tr("profile.nutritionist_name")
        static let nutritionistEmail = tr("profile.nutritionist_email")
    }

    enum Workout {
        static let strength = tr("workout.section.strength")
        static let home = tr("workout.section.home")
        static let cardio = tr("workout.section.cardio")
        static let meditation = tr("workout.section.meditation")
        static let mobility = tr("workout.mobility")
        static let homeTitle = tr("workout.home_title")
        static let male = tr("workout.male")
        static let female = tr("workout.female")
    }

    enum Nutrition {
        static let sendReport = tr("nutrition.send_report")
        static let mealCompleted = tr("nutrition.meal_completed")
        static let markCompleted = tr("nutrition.mark_completed")
        static let markIncomplete = tr("nutrition.mark_incomplete")
    }
}
