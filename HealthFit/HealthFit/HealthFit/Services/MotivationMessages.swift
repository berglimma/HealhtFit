import Foundation

enum MotivationMessages {
    static let daily: [String] = [
        "Hoje é dia de evoluir! Cada treino te aproxima do seu objetivo. 💪",
        "Disciplina vence motivação. Apareça hoje e faça acontecer!",
        "Seu corpo consegue mais do que sua mente imagina. Vamos treinar!",
        "Um treino de cada vez. A consistência constrói resultados.",
        "Não espere estar pronto — comece e o resto vem no caminho.",
        "Grandes conquistas começam com pequenas decisões. Treine hoje!",
        "O suor de hoje é o orgulho de amanhã. Bora!",
        "Você não precisa ser perfeito, só precisa aparecer na academia.",
        "Cada repetição conta. Faça valer o seu dia!",
        "Treinar é investir em você. Faça esse depósito hoje.",
        "Foco, força e fé no processo. Seu treino te espera!",
        "Quem treina hoje, agradece amanhã. Não deixe passar!",
        "Transformação exige ação. Dê o primeiro passo agora.",
        "Seu futuro eu está torcendo por você. Vai treinar!",
        "A dor do treino passa. O orgulho fica. 💥",
        "Hoje você pode ser 1% melhor que ontem. Comece agora!",
        "Não negocie com a preguiça. Seu objetivo vale mais!",
        "Treinar fortalece corpo e mente. Cuide dos dois hoje.",
        "Resultados não caem do céu — são construídos no chão da academia.",
        "Acorde com propósito. Treine com intensidade.",
        "Você já venceu ao decidir treinar. Agora execute!",
        "Consistência é o segredo. Mais um dia, mais uma vitória.",
        "Desafie seus limites hoje. Eles existem para ser superados.",
        "Energia vem de ação. Mova-se e sinta a diferença!",
        "Seu treino de hoje é o alicerce do amanhã. Construa!",
        "Não compare — supere. Foque no seu progresso.",
        "A motivação vem treinando. Dê o pontapé inicial!",
        "Cada dia é uma nova chance de ser mais forte.",
        "Treinar é autocuidado. Priorize-se hoje!",
        "Força não é só física — é escolher continuar. Vamos!",
        "O melhor treino é aquele que você faz. Faça o de hoje!"
    ]

    static let workoutStart: [String] = [
        "Hora de brilhar! Aqueça bem e dê o seu melhor neste treino. 🔥",
        "Treino iniciado! Foco total, técnica perfeita e muita energia!",
        "Você veio até aqui — agora é hora de conquistar cada série!",
        "Respire fundo, concentre-se e mostre do que é capaz!",
        "Cada série é uma oportunidade. Aproveite ao máximo!",
        "Treino começou! Hidrate-se, respire e execute com intensidade.",
        "Hoje é seu dia! Entre na zona e faça valer cada minuto.",
        "A jornada começa agora. Força, foco e determinação!"
    ]

    static func dailyMessage(for date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return daily[(day - 1) % daily.count]
    }

    static func workoutStartMessage(workoutTitle: String, athleteName: String) -> String {
        let template = workoutStart[abs(workoutTitle.hashValue) % workoutStart.count]
        return "\(athleteName), \(template) Treino: \(workoutTitle)."
    }

    static func workoutEndMessage(session: WorkoutSession, athleteName: String) -> String {
        let duration = DurationFormatting.format(seconds: Int(session.duration))
        let exercises = "\(session.completedExercises)/\(session.totalExercises)"
        return "\(athleteName), treino finalizado! \(session.workoutTitle) — \(duration), \(exercises) exercícios concluídos. Parabéns pelo esforço! 🏆"
    }

    static let inactivityReminder: [String] = [
        "Faz mais de 48h que você não treina. Seu corpo sente falta — bora retomar hoje? 💪",
        "Dois dias sem treino ou cardio. A consistência é o segredo — volte hoje!",
        "48h sem atividade registrada. Um treino curto já faz diferença. Vamos?",
        "Sentimos sua falta! Há 2 dias sem treino — retome sua rotina agora.",
        "A pausa foi longa. Seu próximo treino começa com uma decisão — faça acontecer hoje!"
    ]

    static let appUsageInactivityReminder: [String] = [
        "Seu ícone do app está quebrado 💔 Abra o HealthFit e volte às atividades físicas hoje!",
        "Faz mais de 48h sem abrir o app. Seu corpo precisa de movimento — retome seus treinos agora!",
        "A inatividade afeta sua saúde. Volte ao HealthFit e cuide do seu condicionamento físico!",
        "Que tal retomar a rotina? Abra o app e dê o primeiro passo de volta aos treinos.",
        "Seu progresso espera por você. Reabra o HealthFit e volte a se movimentar!"
    ]

    static let cardioCalorieExceeded: [String] = [
        "Meta superada! Você foi além — essa é mentalidade de campeão! 🔥",
        "Ultrapassou a meta de calorias! Corpo respondendo, mente vencendo!",
        "Mais calorias que o planejado — superação pura. Continue assim!",
        "Você queimou além do objetivo! Disciplina e intensidade em ação!",
        "Meta batida com folga! Cada gota de suor valeu a pena!",
        "Imparável! Superou a meta calórica — orgulho do esforço de hoje!",
        "Além do limite planejado — é assim que se evolui de verdade!",
        "Calorias extras queimadas = progresso extra. Você é forte demais!",
        "Meta? Você passou direto! Energia e determinação em alta!",
        "Superação total! O Apple Watch confirma: você deu tudo de si!"
    ]

    static func cardioCalorieExceededMessage(currentCalories: Int, targetCalories: Int) -> String {
        let base = cardioCalorieExceeded[abs(currentCalories ^ targetCalories) % cardioCalorieExceeded.count]
        let extra = max(currentCalories - targetCalories, 0)
        if extra > 0 {
            return "\(base) +\(extra) kcal além da meta de \(targetCalories)."
        }
        return "\(base) Meta de \(targetCalories) kcal atingida!"
    }

    static func cardioCalorieProgressMessage(percent: Int) -> String {
        switch percent {
        case 0..<25: return "Aquecendo o motor — calorias subindo!"
        case 25..<50: return "Metade do caminho — mantenha o ritmo!"
        case 50..<75: return "Mais da metade! A meta está chegando!"
        case 75..<100: return "Reta final — quase lá!"
        default: return "Meta atingida — hora de celebrar!"
        }
    }

    static func inactivityMessage() -> String {
        inactivityReminder.randomElement() ?? inactivityReminder[0]
    }

    static func appUsageInactivityMessage() -> String {
        appUsageInactivityReminder.randomElement() ?? appUsageInactivityReminder[0]
    }

    static func welcomeActiveMessage() -> String {
        welcomeActiveMessages.randomElement() ?? welcomeActiveMessages[0]
    }

    static func welcomeComebackMessage() -> String {
        welcomeComebackMessages.randomElement() ?? welcomeComebackMessages[0]
    }

    static func welcomeLowUsageMessage() -> String {
        welcomeLowUsageMessages.randomElement() ?? welcomeLowUsageMessages[0]
    }

    static func welcomeMissedYouMessage() -> String {
        welcomeMissedYouMessages.randomElement() ?? welcomeMissedYouMessages[0]
    }

    private static let welcomeActiveMessages = [
        "Cada treino te aproxima do objetivo. Hoje é dia de evoluir!",
        "Disciplina vence motivação. Apareça e faça acontecer!",
        "Seu corpo está pronto — escolha uma ficha e comece agora.",
        "Consistência constrói resultados. Mais um dia, mais uma vitória!",
    ]

    private static let welcomeComebackMessages = [
        "Voltar já é vencer. Um treino leve hoje reativa seu ritmo.",
        "Pequenos passos retomam grandes jornadas. Bora de novo!",
        "O app estava esperando por você. Retome com calma e constância.",
        "Nunca é tarde para recomeçar. Treino ou meditação — você escolhe.",
    ]

    private static let welcomeLowUsageMessages = [
        "A pausa foi longa, mas seu progresso ainda está aqui. Volte hoje!",
        "Superação é retomar depois de parar. Um passo de cada vez.",
        "Seu corpo sente falta do movimento. Que tal 10 minutos de meditação ou um treino curto?",
        "Não espere estar pronto — comece e o resto vem no caminho.",
    ]

    private static let welcomeMissedYouMessages = [
        "Faz tempo que você não aparece. Sentimos sua falta — volte a cuidar de você!",
        "Seu ícone no app reflete a ausência. Retome treinos e hábitos saudáveis hoje.",
        "Cada dia longe é um dia a menos de evolução. Você é capaz de recomeçar agora.",
        "A inatividade não apaga seu progresso — mas a ação de hoje constrói o amanhã.",
        "Treino, meditação ou uma caminhada: qualquer movimento já é vitória.",
    ]

    static func chatWelcomeMotivation(hasSleepAlert: Bool, hasWaterAlert: Bool, hasWorkoutAlert: Bool) -> String {
        if hasWorkoutAlert {
            return workoutWelcomeMotivation.randomElement() ?? workoutWelcomeMotivation[0]
        }
        if hasSleepAlert {
            return sleepWelcomeMotivation.randomElement() ?? sleepWelcomeMotivation[0]
        }
        if hasWaterAlert {
            return waterWelcomeMotivation.randomElement() ?? waterWelcomeMotivation[0]
        }
        return dailyMessage()
    }

    private static let workoutWelcomeMotivation = [
        "A consistência constrói resultados. Só um treino hoje — seu corpo agradece amanhã!",
        "Cada dia é uma nova chance de retomar. Apareça na aba Treinos e dê o primeiro passo!",
        "Disciplina vence motivação. Um treino curto já reativa seu progresso — bora!",
        "Você já venceu ao abrir o app. Agora transforme intenção em ação — treine hoje!",
    ]

    private static let sleepWelcomeMotivation = [
        "Descanso é parte do treino. Priorize 7–9 h hoje — seu corpo recupera enquanto você dorme.",
        "Sono de qualidade acelera resultados. Hoje, cuide do descanso como cuida da dieta.",
        "Durma bem hoje — amanhã você treina com mais energia e foco.",
    ]

    private static let waterWelcomeMotivation = [
        "Hidratação é performance. Beba água agora e ao longo do dia — cada copo conta!",
        "Seu corpo precisa de água para treinar e recuperar. Complete a meta hoje!",
        "Água é combustível. Aproxime-se da meta ml a ml — você consegue!",
    ]
}
