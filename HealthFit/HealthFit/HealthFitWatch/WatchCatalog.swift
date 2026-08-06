import Foundation

/// Catálogos leves espelhando o iPhone — o Watch não compartilha o target principal.
enum WatchCatalog {
    struct StrengthProgram: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        let firstExercise: String
    }

    struct CardioActivity: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String
        let isWaterSport: Bool
        let isKitesurf: Bool
        let isSwimming: Bool
    }

    /// Modos de kitesurf (espelham o setup do iPhone / Surf).
    struct WaterRideOption: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String
        let detail: String
    }

    static let kiteRidingModes: [WaterRideOption] = [
        .init(id: "bigAir", name: "Big Air", icon: "arrow.up.to.line", detail: "Saltos e tempo de ar"),
        .init(id: "speed", name: "Speed", icon: "gauge.with.dots.needle.67percent", detail: "Velocidade e percurso"),
        .init(id: "coaching", name: "Coaching", icon: "person.badge.clock", detail: "Treino guiado"),
        .init(id: "downwind", name: "Downwind", icon: "wind", detail: "Percurso a favor do vento")
    ]

    /// Pranchas de surf no Watch (mesmo espírito do setup Surf no iPhone).
    static let surfBoards: [WaterRideOption] = [
        .init(id: "shortboard", name: "Shortboard", icon: "figure.surfing", detail: "Performance"),
        .init(id: "longboard", name: "Longboard", icon: "figure.surfing", detail: "Estabilidade"),
        .init(id: "fish", name: "Fish", icon: "figure.surfing", detail: "Ondas pequenas"),
        .init(id: "funboard", name: "Funboard", icon: "figure.surfing", detail: "Intermediário"),
        .init(id: "softTop", name: "Soft top", icon: "figure.surfing", detail: "Iniciante")
    ]

    /// Pranchas kite — escolhas rápidas parecidas com o setup Surf.
    static let kiteBoards: [WaterRideOption] = [
        .init(id: "twinTip", name: "Twin Tip", icon: "rectangle.split.2x1", detail: "Freeride e saltos"),
        .init(id: "directional", name: "Directional", icon: "wind", detail: "Rides direcionais"),
        .init(id: "foil", name: "Foil Board", icon: "water.waves.and.arrow.up", detail: "Hydrofoil"),
        .init(id: "strapless", name: "Strapless", icon: "wind", detail: "Sem straps")
    ]

    struct MeditationTopic: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String
        let colorName: String
        let prompts: [String]
    }

    enum DurationOption: Int, CaseIterable, Identifiable {
        case five = 5
        case ten = 10
        case fifteen = 15
        case twenty = 20
        case thirty = 30
        case fortyFive = 45
        case sixty = 60

        var id: Int { rawValue }
        var label: String { "\(rawValue) min" }
        var seconds: Int { rawValue * 60 }
    }

    static let strengthPrograms: [StrengthProgram] = [
        .init(id: "m-a", title: "Masculino A — Peito e Tríceps", icon: "figure.strengthtraining.traditional", firstExercise: "Supino reto"),
        .init(id: "m-b", title: "Masculino B — Costas e Bíceps", icon: "figure.strengthtraining.traditional", firstExercise: "Puxada frontal"),
        .init(id: "m-c", title: "Masculino C — Pernas", icon: "figure.strengthtraining.traditional", firstExercise: "Agachamento"),
        .init(id: "m-d", title: "Masculino D — Ombros e Trapézio", icon: "figure.strengthtraining.traditional", firstExercise: "Desenvolvimento"),
        .init(id: "f-a", title: "Feminino A — Glúteos e Posteriores", icon: "figure.strengthtraining.functional", firstExercise: "Elevação pélvica"),
        .init(id: "f-b", title: "Feminino B — Pernas e Core", icon: "figure.strengthtraining.functional", firstExercise: "Agachamento sumô"),
        .init(id: "f-c", title: "Feminino C — Costas e Postura", icon: "figure.strengthtraining.functional", firstExercise: "Remada curvada"),
        .init(id: "f-d", title: "Feminino D — Full Body e Ombros", icon: "figure.strengthtraining.functional", firstExercise: "Desenvolvimento"),
        .init(id: "c-a", title: "Casa A — Full Body", icon: "house.fill", firstExercise: "Agachamento livre"),
        .init(id: "c-b", title: "Casa B — Core e Abdômen", icon: "house.fill", firstExercise: "Prancha"),
        .init(id: "c-c", title: "Casa C — HIIT Em Casa", icon: "house.fill", firstExercise: "Polichinelos"),
        .init(id: "c-d", title: "Casa D — Pernas e Glúteos", icon: "house.fill", firstExercise: "Afundo"),
        .init(id: "c-e", title: "Casa E — Superiores", icon: "house.fill", firstExercise: "Flexão de braço"),
        .init(id: "c-f", title: "Casa F — Mobilidade e Postura", icon: "house.fill", firstExercise: "Gato-camelo"),
        .init(id: "mob-a", title: "Mobilidade A — Aquecimento Geral", icon: "figure.flexibility", firstExercise: "Círculos de ombro"),
        .init(id: "mob-b", title: "Mobilidade B — Ombros e Peito", icon: "figure.flexibility", firstExercise: "Abertura peitoral"),
        .init(id: "mob-c", title: "Mobilidade C — Quadril e Posterior", icon: "figure.flexibility", firstExercise: "Along. isquiotibial"),
        .init(id: "mob-d", title: "Mobilidade D — Torácica e Escápulas", icon: "figure.flexibility", firstExercise: "Rotação torácica"),
        .init(id: "mob-e", title: "Mobilidade E — Pós-treino", icon: "figure.flexibility", firstExercise: "Respiração + alongamento"),
    ]

    static let cardioActivities: [CardioActivity] = [
        .init(id: "run", name: "Corrida", icon: "figure.run", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "walk", name: "Caminhada", icon: "figure.walk", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "mtb", name: "Mountain bike", icon: "bicycle", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "bike", name: "Bicicleta pedal", icon: "figure.outdoor.cycle", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "ergo", name: "Bicicleta ergométrica", icon: "figure.indoor.cycle", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "surf", name: "Surf", icon: "figure.surfing", isWaterSport: true, isKitesurf: false, isSwimming: false),
        .init(id: "kite", name: "Kitesurf", icon: "wind", isWaterSport: true, isKitesurf: true, isSwimming: false),
        .init(id: "ellip", name: "Elíptico", icon: "figure.step.training", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "rope", name: "Pular Corda", icon: "figure.jumprope", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "stairs", name: "Escada", icon: "figure.stair.stepper", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "climb", name: "Escalada", icon: "figure.climbing", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "row", name: "Remo", icon: "figure.rower", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "swim", name: "Natação", icon: "figure.pool.swim", isWaterSport: false, isKitesurf: false, isSwimming: true),
        .init(id: "jack", name: "Polichinelo", icon: "figure.mixed.cardio", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "burpee", name: "Burpees", icon: "figure.highintensity.intervaltraining", isWaterSport: false, isKitesurf: false, isSwimming: false),
    ]

    static let meditationTopics: [MeditationTopic] = [
        .init(
            id: "breath",
            name: "Respiração Consciente",
            icon: "wind",
            colorName: "blue",
            prompts: [
                "Sente-se confortavelmente e feche os olhos.",
                "Inspire lentamente pelo nariz contando até quatro.",
                "Expire suavemente contando até seis.",
                "Quando a mente divagar, volte à respiração.",
                "Finalize agradecendo por este momento."
            ]
        ),
        .init(
            id: "body",
            name: "Relaxamento Corporal",
            icon: "figure.mind.and.body",
            colorName: "teal",
            prompts: [
                "Relaxe os pés e as pernas.",
                "Solte quadris, abdômen e costas.",
                "Relaxe ombros, braços e rosto.",
                "Sinta o corpo mais leve a cada expiração.",
                "Mova os dedos e abra os olhos devagar."
            ]
        ),
        .init(
            id: "grat",
            name: "Gratidão",
            icon: "heart.fill",
            colorName: "pink",
            prompts: [
                "Traga à mente algo pelo qual é grato.",
                "Sinta a gratidão se expandir no peito.",
                "Agradeça pela saúde e pelas pequenas vitórias.",
                "Carregue essa sensação pelo resto do dia."
            ]
        ),
        .init(
            id: "focus",
            name: "Foco e Clareza",
            icon: "brain.head.profile",
            colorName: "indigo",
            prompts: [
                "Você está presente aqui e agora.",
                "Visualize seu objetivo com clareza.",
                "Cada respiração traz mais foco.",
                "Afirme: eu tenho foco e força."
            ]
        ),
        .init(
            id: "anxiety",
            name: "Redução de Ansiedade",
            icon: "leaf.fill",
            colorName: "green",
            prompts: [
                "Nomeie 3 coisas que você vê agora.",
                "Inspire 4s · segure 2s · expire 6s.",
                "Os pensamentos são nuvens — deixe-os passar.",
                "Retorne ao dia com mais leveza."
            ]
        ),
        .init(
            id: "sleep",
            name: "Sono e Descanso",
            icon: "moon.stars.fill",
            colorName: "purple",
            prompts: [
                "Diminua a respiração lentamente.",
                "Relaxe o rosto e a mandíbula.",
                "Conte de 10 a 1 a cada expiração.",
                "Permita-se descansar em paz."
            ]
        ),
        .init(
            id: "recover",
            name: "Recuperação Pós-Treino",
            icon: "figure.cooldown",
            colorName: "orange",
            prompts: [
                "Agradeça ao corpo pelo trabalho de hoje.",
                "Envia relaxamento aos músculos trabalhados.",
                "A hidratação e o sono completam a recuperação.",
                "Você treinou bem — agora recupere."
            ]
        )
    ]
}
