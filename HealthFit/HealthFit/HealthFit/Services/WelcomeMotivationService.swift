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
        weeklyWorkoutCount: Int,
        healthIconStatus: WellnessHealthIconStatus = .yellow
    ) -> WelcomeMotivationContext {
        let firstName = athleteName.components(separatedBy: " ").first ?? athleteName
        let level = resolveUsageLevel(
            hoursSinceLastOpen: hoursSinceLastOpen,
            hoursSinceLastWorkout: hoursSinceLastWorkout,
            weeklyWorkoutCount: weeklyWorkoutCount
        )
        // Glow do "Carregando…" segue sono/água do dia (verde = ambos atualizados).
        let glow = glowColor(for: healthIconStatus)

        switch level {
        case .active:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .workout,
                headline: "Bora treinar, \(firstName)!",
                message: MotivationMessages.welcomeActiveMessage(),
                submessage: healthSubmessage(for: healthIconStatus)
                    ?? "Musculação, cardio ou meditação — escolha seu próximo passo.",
                slides: activeSlides,
                glowColorName: glow
            )
        case .moderateInactivity:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .comeback,
                headline: "Que bom ter você de volta!",
                message: MotivationMessages.welcomeComebackMessage(),
                submessage: healthSubmessage(for: healthIconStatus)
                    ?? "Retome com um treino leve ou alguns minutos de meditação.",
                slides: comebackSlides,
                glowColorName: glow
            )
        case .lowUsage:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .overcome,
                headline: "Sentimos sua falta!",
                message: MotivationMessages.welcomeLowUsageMessage(),
                submessage: healthSubmessage(for: healthIconStatus)
                    ?? "Superação começa com um passo. Treino ou meditação — você consegue.",
                slides: overcomeSlides,
                glowColorName: glow
            )
        case .missedYou:
            return WelcomeMotivationContext(
                usageLevel: level,
                theme: .overcome,
                headline: "Sentimos sua falta, \(firstName)!",
                message: MotivationMessages.welcomeMissedYouMessage(),
                submessage: healthSubmessage(for: healthIconStatus)
                    ?? "Seu corpo e sua mente agradecem quando você volta. Comece hoje.",
                slides: overcomeSlides,
                glowColorName: glow
            )
        }
    }

    /// Cor do carregamento inicial: prioriza sono/água do dia sobre inatividade de abertura.
    private static func glowColor(
        for health: WellnessHealthIconStatus
    ) -> WelcomeMotivationContext.WelcomeGlowColor {
        switch health {
        case .green:
            return .accent
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }

    private static func healthSubmessage(for health: WellnessHealthIconStatus) -> String? {
        switch health {
        case .green:
            return "Sono e água em dia — ótimo cuidado. Agora escolha o próximo passo."
        case .yellow:
            return "Atualize sono e água no Início/Perfil para voltar ao verde."
        case .red:
            return "Há mais de 24h sem registro de sono/água. Atualize agora para cuidar da rotina."
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
