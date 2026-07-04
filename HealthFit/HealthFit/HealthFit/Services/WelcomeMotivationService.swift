import Foundation

enum WelcomeUsageLevel: Equatable {
    case active
    case moderateInactivity
    case lowUsage
    case missedYou
}

enum WelcomeAnimationTheme: Equatable {
    case workout
    case comeback
    case overcome
}

struct WelcomeMotivationSlide: Equatable {
    let icon: String
    let label: String
}

struct WelcomeMotivationContext: Equatable {
    let usageLevel: WelcomeUsageLevel
    let theme: WelcomeAnimationTheme
    let headline: String
    let message: String
    let submessage: String
    let slides: [WelcomeMotivationSlide]
    let glowColorName: WelcomeGlowColor

    enum WelcomeGlowColor: Equatable {
        case accent
        case yellow
        case orange
        case red
    }
}

enum WelcomeMotivationEngine {
    static func makeContext(
        athleteName: String,
        hoursSinceLastOpen: Double?,
        hoursSinceLastWorkout: Double?,
        weeklyWorkoutCount: Int
    ) -> WelcomeMotivationContext {
        let firstName = athleteName.components(separatedBy: " ").first ?? athleteName
        let level = resolveUsageLevel(
            hoursSinceLastOpen: hoursSinceLastOpen,
            hoursSinceLastWorkout: hoursSinceLastWorkout,
            weeklyWorkoutCount: weeklyWorkoutCount
        )

        switch level {
        case .active:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .workout,
                headline: "Bora treinar, \(firstName)!",
                message: MotivationMessages.welcomeActiveMessage(),
                submessage: "Musculação, cardio ou meditação — escolha seu próximo passo.",
                slides: activeSlides,
                glowColorName: .accent
            )
        case .moderateInactivity:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .comeback,
                headline: "Que bom ter você de volta!",
                message: MotivationMessages.welcomeComebackMessage(),
                submessage: "Retome com um treino leve ou alguns minutos de meditação.",
                slides: comebackSlides,
                glowColorName: .yellow
            )
        case .lowUsage:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .overcome,
                headline: "Sentimos sua falta!",
                message: MotivationMessages.welcomeLowUsageMessage(),
                submessage: "Superação começa com um passo. Treino ou meditação — você consegue.",
                slides: overcomeSlides,
                glowColorName: .orange
            )
        case .missedYou:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .overcome,
                headline: "Sentimos sua falta, \(firstName)!",
                message: MotivationMessages.welcomeMissedYouMessage(),
                submessage: "Seu corpo e sua mente agradecem quando você volta. Comece hoje.",
                slides: overcomeSlides,
                glowColorName: .red
            )
        }
    }

    private static func resolveUsageLevel(
        hoursSinceLastOpen: Double?,
        hoursSinceLastWorkout: Double?,
        weeklyWorkoutCount: Int
    ) -> WelcomeUsageLevel {
        if let hours = hoursSinceLastOpen {
            if hours >= 48 { return .missedYou }
            if hours >= 36 { return .lowUsage }
            if hours >= 24 { return .moderateInactivity }
        }

        if let workoutHours = hoursSinceLastWorkout, workoutHours >= 48, weeklyWorkoutCount < 2 {
            return .missedYou
        }

        if weeklyWorkoutCount == 0, hoursSinceLastOpen ?? 0 >= 24 {
            return .lowUsage
        }

        if weeklyWorkoutCount < 2, let workoutHours = hoursSinceLastWorkout, workoutHours >= 36 {
            return .moderateInactivity
        }

        return .active
    }

    private static let activeSlides: [WelcomeMotivationSlide] = [
        WelcomeMotivationSlide(icon: "dumbbell.fill", label: "Treino"),
        WelcomeMotivationSlide(icon: "figure.run", label: "Cardio"),
        WelcomeMotivationSlide(icon: "brain.head.profile", label: "Meditação"),
    ]

    private static let comebackSlides: [WelcomeMotivationSlide] = [
        WelcomeMotivationSlide(icon: "figure.strengthtraining.traditional", label: "Força"),
        WelcomeMotivationSlide(icon: "figure.run", label: "Movimento"),
        WelcomeMotivationSlide(icon: "leaf.fill", label: "Equilíbrio"),
    ]

    private static let overcomeSlides: [WelcomeMotivationSlide] = [
        WelcomeMotivationSlide(icon: "flame.fill", label: "Superação"),
        WelcomeMotivationSlide(icon: "dumbbell.fill", label: "Treino"),
        WelcomeMotivationSlide(icon: "brain.head.profile", label: "Meditação"),
    ]
}
