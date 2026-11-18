import Foundation

/// Catálogos leves espelhando o iPhone — o Watch não compartilha o target principal.
enum WatchCatalog {
    struct StrengthExercise: Identifiable, Hashable {
        let id: String
        let name: String
        let sets: Int
        let reps: String
        let restSeconds: Int
    }

    struct StrengthProgram: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        let exercises: [StrengthExercise]

        var firstExercise: String { exercises.first?.name ?? title }
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

    /// Trilha CrossFit / Hyrox — nomes alinhados ao iPhone (`CrossFitTrack`).
    struct CrossFitTrack: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String
        let formats: [CrossFitFormat]
    }

    struct CrossFitFormat: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        /// `0` = cronômetro livre (For Time / prova).
        let targetSeconds: Int

        var isAMRAP: Bool { title.uppercased().hasPrefix("AMRAP") }
        var isEMOM: Bool { title.uppercased().hasPrefix("EMOM") }
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

    private static func ex(
        _ name: String,
        sets: Int = 3,
        reps: String = "12",
        rest: Int = 60
    ) -> StrengthExercise {
        StrengthExercise(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: name,
            sets: sets,
            reps: reps,
            restSeconds: rest
        )
    }

    static let strengthPrograms: [StrengthProgram] = [
        .init(
            id: "m-a",
            title: "Masculino A — Peito e Tríceps",
            icon: "figure.strengthtraining.traditional",
            exercises: [
                ex("Supino reto", sets: 4, reps: "8-10", rest: 90),
                ex("Supino inclinado", sets: 3, reps: "10", rest: 75),
                ex("Crucifixo", sets: 3, reps: "12", rest: 60),
                ex("Tríceps pulley", sets: 3, reps: "12", rest: 60),
                ex("Tríceps testa", sets: 3, reps: "10", rest: 60)
            ]
        ),
        .init(
            id: "m-b",
            title: "Masculino B — Costas e Bíceps",
            icon: "figure.strengthtraining.traditional",
            exercises: [
                ex("Puxada frontal", sets: 4, reps: "8-10", rest: 90),
                ex("Remada curvada", sets: 3, reps: "10", rest: 75),
                ex("Remada unilateral", sets: 3, reps: "10", rest: 60),
                ex("Rosca direta", sets: 3, reps: "12", rest: 60),
                ex("Rosca martelo", sets: 3, reps: "12", rest: 60)
            ]
        ),
        .init(
            id: "m-c",
            title: "Masculino C — Pernas",
            icon: "figure.strengthtraining.traditional",
            exercises: [
                ex("Agachamento", sets: 4, reps: "8-10", rest: 90),
                ex("Leg press", sets: 3, reps: "12", rest: 75),
                ex("Afundo", sets: 3, reps: "10", rest: 60),
                ex("Mesa flexora", sets: 3, reps: "12", rest: 60),
                ex("Panturrilha em pé", sets: 4, reps: "15", rest: 45)
            ]
        ),
        .init(
            id: "m-d",
            title: "Masculino D — Ombros e Trapézio",
            icon: "figure.strengthtraining.traditional",
            exercises: [
                ex("Desenvolvimento", sets: 4, reps: "8-10", rest: 90),
                ex("Elevação lateral", sets: 3, reps: "12", rest: 60),
                ex("Elevação frontal", sets: 3, reps: "12", rest: 60),
                ex("Encolhimento", sets: 3, reps: "12", rest: 60),
                ex("Face pull", sets: 3, reps: "15", rest: 45)
            ]
        ),
        .init(
            id: "f-a",
            title: "Feminino A — Glúteos e Posteriores",
            icon: "figure.strengthtraining.functional",
            exercises: [
                ex("Elevação pélvica", sets: 4, reps: "12", rest: 60),
                ex("Stiff", sets: 3, reps: "10", rest: 75),
                ex("Abdução no cabo", sets: 3, reps: "15", rest: 45),
                ex("Coice no cabo", sets: 3, reps: "12", rest: 45),
                ex("Mesa flexora", sets: 3, reps: "12", rest: 60)
            ]
        ),
        .init(
            id: "f-b",
            title: "Feminino B — Pernas e Core",
            icon: "figure.strengthtraining.functional",
            exercises: [
                ex("Agachamento sumô", sets: 4, reps: "12", rest: 75),
                ex("Leg press", sets: 3, reps: "12", rest: 60),
                ex("Afundo", sets: 3, reps: "10", rest: 60),
                ex("Prancha", sets: 3, reps: "40s", rest: 45),
                ex("Abdominal bicicleta", sets: 3, reps: "20", rest: 45)
            ]
        ),
        .init(
            id: "f-c",
            title: "Feminino C — Costas e Postura",
            icon: "figure.strengthtraining.functional",
            exercises: [
                ex("Remada curvada", sets: 3, reps: "12", rest: 60),
                ex("Puxada frontal", sets: 3, reps: "12", rest: 60),
                ex("Face pull", sets: 3, reps: "15", rest: 45),
                ex("Superman", sets: 3, reps: "12", rest: 45),
                ex("Prancha", sets: 3, reps: "40s", rest: 45)
            ]
        ),
        .init(
            id: "f-d",
            title: "Feminino D — Full Body e Ombros",
            icon: "figure.strengthtraining.functional",
            exercises: [
                ex("Desenvolvimento", sets: 3, reps: "10", rest: 60),
                ex("Agachamento livre", sets: 3, reps: "12", rest: 60),
                ex("Remada curvada", sets: 3, reps: "12", rest: 60),
                ex("Elevação lateral", sets: 3, reps: "12", rest: 45),
                ex("Prancha", sets: 3, reps: "40s", rest: 45)
            ]
        ),
        .init(
            id: "c-a",
            title: "Casa A — Full Body",
            icon: "house.fill",
            exercises: [
                ex("Agachamento livre", sets: 3, reps: "15", rest: 45),
                ex("Flexão de braço", sets: 3, reps: "10", rest: 45),
                ex("Afundo", sets: 3, reps: "12", rest: 45),
                ex("Remada com mochila", sets: 3, reps: "12", rest: 45),
                ex("Prancha", sets: 3, reps: "40s", rest: 40)
            ]
        ),
        .init(
            id: "c-b",
            title: "Casa B — Core e Abdômen",
            icon: "house.fill",
            exercises: [
                ex("Prancha", sets: 3, reps: "40s", rest: 40),
                ex("Abdominal crunch", sets: 3, reps: "20", rest: 40),
                ex("Abdominal bicicleta", sets: 3, reps: "20", rest: 40),
                ex("Elevação de pernas", sets: 3, reps: "12", rest: 40),
                ex("Prancha lateral", sets: 3, reps: "30s", rest: 40)
            ]
        ),
        .init(
            id: "c-c",
            title: "Casa C — HIIT Em Casa",
            icon: "house.fill",
            exercises: [
                ex("Polichinelos", sets: 4, reps: "30s", rest: 30),
                ex("Burpees", sets: 3, reps: "10", rest: 40),
                ex("Agachamento livre", sets: 3, reps: "15", rest: 30),
                ex("Mountain climbers", sets: 3, reps: "30s", rest: 30),
                ex("Flexão de braço", sets: 3, reps: "10", rest: 40)
            ]
        ),
        .init(
            id: "c-d",
            title: "Casa D — Pernas e Glúteos",
            icon: "house.fill",
            exercises: [
                ex("Afundo", sets: 3, reps: "12", rest: 45),
                ex("Agachamento livre", sets: 3, reps: "15", rest: 45),
                ex("Elevação pélvica", sets: 3, reps: "15", rest: 40),
                ex("Elevação de panturrilha", sets: 3, reps: "20", rest: 30),
                ex("Agachamento sumô", sets: 3, reps: "15", rest: 45)
            ]
        ),
        .init(
            id: "c-e",
            title: "Casa E — Superiores",
            icon: "house.fill",
            exercises: [
                ex("Flexão de braço", sets: 3, reps: "10", rest: 45),
                ex("Remada com mochila", sets: 3, reps: "12", rest: 45),
                ex("Elevação lateral", sets: 3, reps: "12", rest: 40),
                ex("Tríceps no banco", sets: 3, reps: "12", rest: 40),
                ex("Prancha", sets: 3, reps: "40s", rest: 40)
            ]
        ),
        .init(
            id: "c-f",
            title: "Casa F — Mobilidade e Postura",
            icon: "house.fill",
            exercises: [
                ex("Gato-camelo", sets: 3, reps: "10", rest: 20),
                ex("Rotação torácica", sets: 3, reps: "8", rest: 20),
                ex("Alongamento de peito", sets: 2, reps: "30s", rest: 15),
                ex("Alongamento de quadril", sets: 2, reps: "30s", rest: 15),
                ex("Respiração diafragmática", sets: 2, reps: "60s", rest: 10)
            ]
        ),
        .init(
            id: "c-g",
            title: "Casa G — Atleta Full Body",
            icon: "house.fill",
            exercises: [
                ex("Flexão de braço", sets: 4, reps: "12", rest: 45),
                ex("Superman", sets: 3, reps: "12", rest: 40),
                ex("Agachamento livre", sets: 4, reps: "15", rest: 45),
                ex("Afundo", sets: 3, reps: "12", rest: 45),
                ex("Prancha", sets: 3, reps: "40s", rest: 40)
            ]
        ),
        .init(
            id: "c-h",
            title: "Casa H — Push Em Casa",
            icon: "house.fill",
            exercises: [
                ex("Flexão de braço", sets: 4, reps: "12", rest: 45),
                ex("Flexão inclinada", sets: 3, reps: "12", rest: 45),
                ex("Flexão diamante", sets: 3, reps: "10", rest: 45),
                ex("Mergulho no banco", sets: 3, reps: "12", rest: 45),
                ex("Prancha", sets: 3, reps: "40s", rest: 40)
            ]
        ),
        .init(
            id: "c-i",
            title: "Casa I — Pull Em Casa",
            icon: "house.fill",
            exercises: [
                ex("Superman", sets: 4, reps: "12", rest: 40),
                ex("Ponte de glúteos", sets: 3, reps: "15", rest: 40),
                ex("Prancha", sets: 3, reps: "45s", rest: 40),
                ex("Elevação de pernas", sets: 3, reps: "12", rest: 40),
                ex("Mountain climbers", sets: 3, reps: "24", rest: 40)
            ]
        ),
        .init(
            id: "c-j",
            title: "Casa J — Pernas Em Casa",
            icon: "house.fill",
            exercises: [
                ex("Agachamento livre", sets: 4, reps: "15", rest: 50),
                ex("Afundo", sets: 4, reps: "12", rest: 45),
                ex("Elevação pélvica", sets: 4, reps: "15", rest: 45),
                ex("Isometria na parede", sets: 3, reps: "40s", rest: 45),
                ex("Panturrilha", sets: 4, reps: "20", rest: 30)
            ]
        ),
        .init(
            id: "c-k",
            title: "Casa K — Core Power",
            icon: "house.fill",
            exercises: [
                ex("Prancha", sets: 3, reps: "45s", rest: 40),
                ex("Dead bug", sets: 3, reps: "12", rest: 40),
                ex("Bird dog", sets: 3, reps: "12", rest: 40),
                ex("Flutter kick", sets: 3, reps: "30s", rest: 40),
                ex("Russian twist", sets: 3, reps: "24", rest: 40)
            ]
        ),
        .init(
            id: "c-l",
            title: "Casa L — HIIT Queima",
            icon: "house.fill",
            exercises: [
                ex("Joelho alto", sets: 4, reps: "40s", rest: 30),
                ex("Agachamento com salto", sets: 4, reps: "12", rest: 40),
                ex("Burpees", sets: 4, reps: "10", rest: 40),
                ex("Mountain climbers", sets: 4, reps: "30", rest: 30),
                ex("Polichinelos", sets: 3, reps: "40", rest: 30)
            ]
        ),
        .init(
            id: "c-m",
            title: "Casa M — Posterior Em Casa",
            icon: "house.fill",
            exercises: [
                ex("Ponte de glúteos", sets: 4, reps: "15", rest: 40),
                ex("Elevação pélvica", sets: 4, reps: "15", rest: 45),
                ex("Superman", sets: 3, reps: "12", rest: 40),
                ex("Bird dog", sets: 3, reps: "12", rest: 40),
                ex("Afundo", sets: 3, reps: "12", rest: 45)
            ]
        ),
        .init(
            id: "c-n",
            title: "Casa N — Express Full Body",
            icon: "house.fill",
            exercises: [
                ex("Polichinelos", sets: 3, reps: "30", rest: 25),
                ex("Agachamento livre", sets: 3, reps: "15", rest: 30),
                ex("Flexão de braço", sets: 3, reps: "10", rest: 30),
                ex("Flexão pike", sets: 3, reps: "8", rest: 35),
                ex("Prancha", sets: 2, reps: "40s", rest: 30)
            ]
        ),
        .init(
            id: "mob-a",
            title: "Mobilidade A — Alongamento Dinâmico",
            icon: "figure.flexibility",
            exercises: [
                ex("Alongamento mundial", sets: 2, reps: "10", rest: 15),
                ex("Círculos de braço", sets: 2, reps: "12", rest: 15),
                ex("Rotação de quadril", sets: 2, reps: "10", rest: 15),
                ex("Afundo com rotação", sets: 2, reps: "8", rest: 20),
                ex("Agachamento livre", sets: 2, reps: "10", rest: 20)
            ]
        ),
        .init(
            id: "mob-e",
            title: "Mobilidade E — Alongamento Estático",
            icon: "figure.flexibility",
            exercises: [
                ex("Alongamento de peito", sets: 2, reps: "40s", rest: 15),
                ex("Alongamento de quadríceps", sets: 2, reps: "40s", rest: 15),
                ex("Alongamento de posteriores", sets: 2, reps: "40s", rest: 15),
                ex("Alongamento de ombro", sets: 2, reps: "40s", rest: 15),
                ex("Alongamento de pescoço", sets: 2, reps: "30s", rest: 10)
            ]
        )
    ]

    static let cardioActivities: [CardioActivity] = [
        .init(id: "run", name: "Corrida", icon: "figure.run", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "walk", name: "Caminhada", icon: "figure.walk", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "treadmill", name: "Esteira Ergométrica", icon: "figure.run.treadmill", isWaterSport: false, isKitesurf: false, isSwimming: false),
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
        .init(id: "tennis", name: "Tênis", icon: "figure.tennis", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "jack", name: "Polichinelo", icon: "figure.mixed.cardio", isWaterSport: false, isKitesurf: false, isSwimming: false),
        .init(id: "burpee", name: "Burpees", icon: "figure.highintensity.intervaltraining", isWaterSport: false, isKitesurf: false, isSwimming: false),
    ]

    static let crossFitTracks: [CrossFitTrack] = [
        .init(
            id: "wod",
            name: "Treino Crossfit",
            icon: "figure.cross.training",
            formats: [
                .init(id: "amrap12", title: "AMRAP 12", detail: "Máximo de rounds em 12 min", targetSeconds: 12 * 60),
                .init(id: "amrap15", title: "AMRAP 15", detail: "Máximo de rounds em 15 min", targetSeconds: 15 * 60),
                .init(id: "amrap20", title: "AMRAP 20", detail: "Clássico de condicionamento", targetSeconds: 20 * 60),
                .init(id: "emom12", title: "EMOM 12", detail: "A cada minuto, um bloco", targetSeconds: 12 * 60),
                .init(id: "emom16", title: "EMOM 16", detail: "Blocos longos", targetSeconds: 16 * 60),
                .init(id: "fortime", title: "For Time", detail: "Complete o WOD no menor tempo", targetSeconds: 0),
                .init(id: "chipper", title: "Chipper", detail: "Lista longa, uma vez", targetSeconds: 0),
                .init(id: "open", title: "Livre", detail: "Cronômetro aberto", targetSeconds: 0)
            ]
        ),
        .init(
            id: "hyrox",
            name: "Método Hyrox",
            icon: "flag.checkered",
            formats: [
                .init(id: "race", title: "Simulação de prova", detail: "8 estações + corridas", targetSeconds: 0),
                .init(id: "half", title: "Meia prova", detail: "~30–45 min", targetSeconds: 40 * 60),
                .init(id: "station", title: "Foco em estação", detail: "Técnica e volume", targetSeconds: 20 * 60),
                .init(id: "doubles", title: "Doubles", detail: "Revezamento em dupla", targetSeconds: 0),
                .init(id: "open", title: "Livre", detail: "Cronômetro aberto", targetSeconds: 0)
            ]
        )
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
