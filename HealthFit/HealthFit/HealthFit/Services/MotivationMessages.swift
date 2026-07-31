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

    /// Segunda a quarta — foco em treino.
    static let weekdayWorkoutMotivation: [String] = [
        "Segunda a quarta: semana em construção. Treine com foco e avance 1% hoje! 💪",
        "Corpo e mente agradecem a consistência. Abra o HealthFit e faça seu treino!",
        "Hoje é dia de evoluir! Cada série te aproxima do objetivo.",
        "Disciplina vence desculpa. Apareça, aqueça e execute o treino do dia!",
        "Quem treina no meio da semana colhe o fim de semana mais leve. Bora!",
        "Seu futuro eu está pedindo esse treino. Não negociemos com a preguiça!",
        "Foco total: técnica boa, intensidade certa e hidratação. Você consegue!",
    ]

    /// Quinta — #TBD + motivação.
    static let thursdayMotivation: [String] = [
        "#TBD Quinta é dia de virar a chave: treine com presença e feche a semana forte! 🔥",
        "#TBD Lembre quem você quer ser. Um treino agora muda o restante da semana.",
        "#TBD Não espere sexta para começar — conquiste hoje o que o fim de semana celebra.",
        "#TBD Corpo em movimento, mente no objetivo. Sua melhor versão treina na quinta!",
        "#TBD Throwback de disciplina: volte ao foco, complete o treino e orgulhe-se.",
    ]

    /// Sexta — #sextou + bebidas leves + motivação.
    static let fridayMotivation: [String] = [
        "#sextou Se for sair, prefira bebidas leves e em baixa quantidade — e não pule o treino de hoje! 🥂💪",
        "#sextou Celebre com consciência: se for beber, escolha opções leves e poucas doses. Seu treino te espera!",
        "#sextou Sextou com equilíbrio: treine, hidrate e, se sair, priorize bebidas leves e baixa quantidade.",
        "#sextou Diversão sem exagero: prefira bebidas leves e em pouca quantidade. Seu corpo agradece amanhã!",
        "#sextou Feche a semana treinando. Se for para algum lugar, bebidas leves e baixa quantidade mantêm o progresso.",
    ]

    /// Sábado — FDS.
    static let saturdayMotivation: [String] = [
        "FDS chegou! Movimente-se com leveza — um treino curto ou cardio já faz o sábado valer. 🌤️",
        "FDS de verdade inclui autocuidado: treine, hidrate e descanse com qualidade.",
        "Sábado de FDS: mantenha o ritmo sem pressão. Um treino ativo deixa o fim de semana melhor!",
        "FDS em movimento! Aproveite o sábado para treinar e curtir a energia que o corpo devolve.",
        "FDS: equilíbrio entre descanso e ação. Um treino hoje deixa domingo ainda mais leve.",
    ]

    /// Domingo — motivação para fechar/semana.
    static let sundayMotivation: [String] = [
        "Domingo de recomeço: prepare corpo e mente — um treino ou alongamento muda a semana. ✨",
        "Domingo motivacional: organize a semana, hidrate-se e dê um treino de qualidade a si mesmo!",
        "Feche o ciclo com orgulho. Domingo é chance de treinar leve e começar segunda em alta.",
        "Domingo: respire, movimente e planeje. Sua consistência começa com a escolha de hoje!",
        "Motivação de domingo: cuide do corpo agora para a semana fluir com mais força e clareza.",
    ]

    static let workoutStartFocusMessage =
        "Ótimo, vamos treinar! Escolha sua playlist favorita e vamos pra cima! " +
        "Mesmo que esteja com alguém, treine no foco e evite conversar muito tempo! Vamos lá!"

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
        let weekday = Calendar.current.component(.weekday, from: date)
        // 1 = domingo … 7 = sábado
        switch weekday {
        case 5: // quinta
            return pick(from: thursdayMotivation, on: date)
        case 6: // sexta
            return pick(from: fridayMotivation, on: date)
        case 7: // sábado
            return pick(from: saturdayMotivation, on: date)
        case 1: // domingo
            return pick(from: sundayMotivation, on: date)
        default: // segunda a quarta
            return pick(from: weekdayWorkoutMotivation, on: date)
        }
    }

    static func dailyNotificationTitle(for date: Date = .now) -> String {
        _ = date
        return "Bom dia, HealthFit ☀️"
    }

    /// Motivação do lembrete das 18:00 — uma frase por dia da semana (Domingo…Sábado).
    static func eveningTrainingNudgeMessage(for date: Date = .now) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        // 1 = domingo … 7 = sábado
        switch weekday {
        case 1:
            return "Domingo ainda dá tempo: um treino leve fecha a semana com orgulho."
        case 2:
            return "Segunda pede ação. Não deixe o dia acabar sem treinar!"
        case 3:
            return "Terça é ritmo: mantenha a sequência e fortaleça o hábito."
        case 4:
            return "Quarta no meio do caminho — um treino agora muda o restante da semana."
        case 5:
            return "Quinta de virada: treine com presença e chegue forte no fim de semana."
        case 6:
            return "Sextou com disciplina: treine antes de celebrar o fim de semana."
        case 7:
            return "Sábado em movimento: um treino curto já faz o FDS valer a pena."
        default:
            return "Ainda dá tempo de treinar hoje. Seu corpo agradece!"
        }
    }

    private static func pick(from messages: [String], on date: Date) -> String {
        guard !messages.isEmpty else { return daily[0] }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return messages[(day - 1) % messages.count]
    }

    static func workoutStartMessage(workoutTitle: String, athleteName: String) -> String {
        "\(athleteName), \(workoutStartFocusMessage) Treino: \(workoutTitle)."
    }

    static let cardioStart: [String] = [
        "Cada passo te fortalece. Respire, mantenha o ritmo e vá além do que imaginava!",
        "Hoje o coração comanda: intensidade com inteligência. Você nasce pra se superar!",
        "Movimento é liberdade. Queime dúvidas, acelere conquistas — o cardio é seu aliado!",
        "Sua resistência cresce a cada minuto. Foque no agora e deixe o suor contar a história!",
        "Disciplina em movimento! Aqueça, acelere e prove pra você mesmo do que é capaz!",
        "Corpo em marcha, mente no objetivo. Este cardio é investimento no seu futuro!",
        "Não espere motivação — crie impulso. Um ritmo de cada vez até a meta!",
        "Você já começou: isso é metade da vitória. Agora sustente o fôlego e avance!"
    ]

    static let meditationStart: [String] = [
        "A quietude não é ausência — é presença plena. Encontre-se neste silêncio.",
        "Como a água reflete o céu, a mente calma reflete a verdade. Observe sem julgar.",
        "Quem domina a respiração começa a dominar a si mesmo. Inspire paz, expire o resto.",
        "O presente é o único tempo que existe. Nesta meditação, habite apenas o agora.",
        "A sabedoria nasce do silêncio interior. Deixe pensamentos passarem como nuvens.",
        "Não busque esvaziar a mente — apenas não se apegue ao que surge. Observe e solte.",
        "Em cada respiração há um recomeço. Cultive serenidade; o mundo espera do lado de fora.",
        "Conhece-te a ti mesmo no silêncio. Esta pausa é força, não fuga."
    ]

    static func cardioStartMessage(sessionTitle: String, athleteName: String) -> String {
        let tip = cardioStart[abs(sessionTitle.hashValue) % cardioStart.count]
        return "\(athleteName), \(tip) Sessão: \(sessionTitle)."
    }

    static func meditationStartMessage(sessionTitle: String, athleteName: String) -> String {
        let tip = meditationStart[abs(sessionTitle.hashValue) % meditationStart.count]
        return "\(athleteName), \(tip) Sessão: \(sessionTitle)."
    }

    static func workoutEndMessage(session: WorkoutSession, athleteName: String) -> String {
        if session.autoEndedByInactivity {
            return forgottenWorkoutEndNotification(
                workoutTitle: session.workoutTitle,
                athleteName: athleteName
            )
        }

        let duration = DurationFormatting.format(seconds: Int(session.duration))
        let title = session.workoutTitle.lowercased()

        if title.hasPrefix("meditação") || title.hasPrefix("meditacao") {
            return "\(athleteName), meditação concluída. \(session.workoutTitle) — \(duration). Que a clareza desta pausa acompanhe o seu dia."
        }

        if title.hasPrefix("cardio") {
            let calories = session.caloriesBurned > 0
                ? ", \(Int(session.caloriesBurned)) kcal"
                : ""
            return "\(athleteName), cardio finalizado! \(session.workoutTitle) — \(duration)\(calories). Resistência construída, mente reforçada! 🏃"
        }

        let exercises = "\(session.completedExercises)/\(session.totalExercises)"
        return "\(athleteName), treino finalizado! \(session.workoutTitle) — \(duration), \(exercises) exercícios concluídos. Parabéns pelo esforço! 🏆"
    }

    static let forgottenWorkoutEndMessages: [String] = [
        "Poxa, você esqueceu de finalizar o treino — mas não se preocupe, estou aqui pra te ajudar. 💙",
        "O treino ficou aberto por mais de 2h30 e eu encerrei por segurança. Sem culpa: o próximo você finaliza comigo!",
        "Esquecer de encerrar acontece. O importante é voltar, aprender e seguir firme. Estou com você! 💪",
        "Alerta de inatividade: o treino passou de 2h30 sem finalização. Eu cuidei do encerramento — agora respira e segue em frente.",
        "Poxa… o treino ficou sem finalizar. Tudo bem! Use isso como lembrete e conte comigo no próximo."
    ]

    static let forgottenWorkoutMotivation: [String] = [
        "Cada dia é uma nova chance de evoluir. Você não precisa ser perfeito — só consistente. 🌟",
        "Errar o processo faz parte. O que te define é voltar. Vamos juntos! 🔥",
        "Seu progresso não some porque um treino ficou aberto. Amanhã é recomeço.",
        "Disciplina também é lembrar de encerrar. Da próxima vez, eu te lembro — e você brilha!",
        "Corpo e mente agradecem a honestidade. Agora hidrate, descanse e retome com leveza."
    ]

    static func forgottenWorkoutEndNotification(workoutTitle: String, athleteName: String) -> String {
        let tip = forgottenWorkoutEndMessages[abs(workoutTitle.hashValue) % forgottenWorkoutEndMessages.count]
        return "\(athleteName), \(tip) Sessão: \(workoutTitle)."
    }

    static func forgottenWorkoutPendingNotification(workoutTitle: String) -> String {
        "O treino \"\(workoutTitle)\" passou de 2h30 sem finalização. Abra o HealthFit — vou encerrar e te ajudar a retomar com carinho."
    }

    static func forgottenWorkoutAssistantOpening(workoutTitle: String, athleteName: String) -> String {
        let name = athleteName.isEmpty ? "Atleta" : athleteName
        let empathy = forgottenWorkoutEndMessages.randomElement() ?? forgottenWorkoutEndMessages[0]
        let motivation = forgottenWorkoutMotivation.randomElement() ?? forgottenWorkoutMotivation[0]

        return """
        \(empathy)

        Olá, \(name)! 😢⚠️

        Notei que o treino "\(workoutTitle)" ficou iniciado por mais de 2h30 sem ser finalizado.
        Por segurança e para o relatório ficar correto, eu encerrei a sessão automaticamente.

        Lembrete importante: sempre finalize o treino na tela ativa (ou peça para encerrar) para o histórico, o personal e as metas baterem certo.

        \(motivation)

        Como você está se sentindo agora — corpo, energia e disposição?
        Me conte com sinceridade. Estou aqui pra te ajudar.
        """
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

    static let cardioInactivityReminder: [String] = [
        "Faz 48h sem cardio 🏃💨 Benefícios: coração mais forte, mais energia e queima de gordura. 20 min hoje já contam!",
        "Seu coração sente falta do ritmo ❤️🏃 Cardio regular melhora humor, sono e resistência. Bora na aba Treinos?",
        "2 dias sem cardio ⏱️ Condicionamento cai rápido — retome com caminhada, bike ou corrida leve hoje!",
    ]

    static let meditationInactivityReminder: [String] = [
        "Faz 48h sem meditar 🧘✨ Benefícios: menos estresse, mais foco e sono melhor. 5–10 min já transformam o dia!",
        "A mente também treina 🧠🕊️ Meditação reduz ansiedade e melhora recuperação. Que tal uma sessão curta agora?",
        "2 dias sem meditação ⏳ Respire fundo e volte à rotina — clareza mental impulsiona treinos e hábitos saudáveis.",
    ]

    static func cardioInactivityMessage() -> String {
        cardioInactivityReminder.randomElement() ?? cardioInactivityReminder[0]
    }

    static func meditationInactivityMessage() -> String {
        meditationInactivityReminder.randomElement() ?? meditationInactivityReminder[0]
    }

    static func healthIconYellowMessage(detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Atualize água e sono hoje para voltar ao verde 💛💧😴"
        }
        return "\(trimmed) 💛💧😴"
    }

    static func healthIconRedMessage(detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Mais de 24h sem atualizar água e sono. Registre agora no Perfil! 🚨❤️💧😴"
        }
        return "\(trimmed) 🚨❤️💧😴"
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

    static let waterReminderMessages = [
        "Hora de beber água! 💧 Hidratação mantém energia, foco e recuperação muscular.",
        "Pausa para hidratar! 💧 Seu corpo precisa de água agora — registre no Perfil.",
        "Lembrete de água 💧 Beba um copo agora e continue sua meta diária.",
        "Hidratação em dia = treino melhor 💧 Beba água neste momento.",
        "Água agora! 💧 Cada gole aproxima você da meta de hidratação.",
        "Não espere sede 💧 Beba água agora e mantenha o corpo funcionando bem.",
    ]

    static func waterReminderMessage(forHour hour: Int) -> String {
        let index = max(hour, 0) % waterReminderMessages.count
        return waterReminderMessages[index]
    }

    static func mealReminderMessage(for mealType: MealType) -> String {
        let time = MealReminderConfiguration.formattedMealTime(for: mealType)
        let tips = mealReminderTips
        let tip = tips[abs(mealType.rawValue.hashValue) % tips.count]
        return "Em 5 minutos: \(mealType.rawValue) (\(time)). \(tip)"
    }

    static let mealReminderTips = [
        "Separe o prato do cardápio e hidrate-se um pouco antes. 🥗",
        "Alerta do cardápio: prepare a refeição com calma e aproveite cada mordida.",
        "Lembrete nutricional: comer no horário ajuda energia, foco e resultados. 💪",
        "Seu cardápio te espera — organize a porção e evite pular esta refeição.",
        "5 minutos para se organizar: água, prato e atenção plena na comida. 🌿",
        "Constância no cardápio = evolução. Não deixe esta refeição passar!",
    ]
}
