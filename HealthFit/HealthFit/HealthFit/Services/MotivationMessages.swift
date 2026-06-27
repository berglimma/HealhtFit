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
}
