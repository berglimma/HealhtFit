package com.healthfit.android.ui.assistant

import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

enum class DayPartWindow {
    Morning, Afternoon, Evening, Rest
}

/**
 * Port of iOS `MotivationMessages` — greetings, daily pushes, water/meal reminders,
 * workout/cardio/meditation start/end, inactivity and chat welcome copy.
 */
object MotivationMessages {

    enum class MealType(val label: String) {
        Breakfast("Café da manhã"),
        MorningSnack("Lanche da manhã"),
        Lunch("Almoço"),
        AfternoonSnack("Lanche da tarde"),
        Dinner("Jantar"),
        Supper("Ceia"),
    }

    fun dayPartWindow(calendar: Calendar = Calendar.getInstance()): DayPartWindow {
        return when (calendar.get(Calendar.HOUR_OF_DAY)) {
            in 5..11 -> DayPartWindow.Morning
            in 12..17 -> DayPartWindow.Afternoon
            in 18..19 -> DayPartWindow.Evening
            else -> DayPartWindow.Rest
        }
    }

    fun dayPartGreeting(calendar: Calendar = Calendar.getInstance()): String = when (dayPartWindow(calendar)) {
        DayPartWindow.Morning -> "Bom dia"
        DayPartWindow.Afternoon -> "Boa tarde"
        DayPartWindow.Evening -> "Boa noite"
        DayPartWindow.Rest -> restGreeting(calendar)
    }

    fun restGreeting(calendar: Calendar = Calendar.getInstance()): String {
        val options = listOf("Bom descanso", "Descanse bem", "Boa noite de descanso")
        val day = calendar.get(Calendar.DAY_OF_YEAR)
        return options[(day - 1).mod(options.size)]
    }

    fun namedGreeting(name: String?, calendar: Calendar = Calendar.getInstance()): String {
        val greeting = dayPartGreeting(calendar)
        val trimmed = name?.trim().orEmpty()
        return if (trimmed.isEmpty()) "$greeting!" else "$greeting, $trimmed!"
    }

    private val weekdayWorkoutMotivation = listOf(
        "Segunda a quarta: semana em construção. Treine com foco e avance 1% hoje! 💪",
        "Corpo e mente agradecem a consistência. Abra o HealthFit e faça seu treino!",
        "Hoje é dia de evoluir! Cada série te aproxima do objetivo.",
        "Disciplina vence desculpa. Apareça, aqueça e execute o treino do dia!",
        "Quem treina no meio da semana colhe o fim de semana mais leve. Bora!",
        "Seu futuro eu está pedindo esse treino. Não negociemos com a preguiça!",
        "Foco total: técnica boa, intensidade certa e hidratação. Você consegue!",
    )

    private val thursdayMotivation = listOf(
        "#TBD Quinta é dia de virar a chave: treine com presença e feche a semana forte! 🔥",
        "#TBD Lembre quem você quer ser. Um treino agora muda o restante da semana.",
        "#TBD Não espere sexta para começar — conquiste hoje o que o fim de semana celebra.",
        "#TBD Corpo em movimento, mente no objetivo. Sua melhor versão treina na quinta!",
        "#TBD Throwback de disciplina: volte ao foco, complete o treino e orgulhe-se.",
    )

    private val fridayMotivation = listOf(
        "#sextou Se for sair, prefira bebidas leves e em baixa quantidade — e não pule o treino de hoje! 🥂💪",
        "#sextou Celebre com consciência: se for beber, escolha opções leves e poucas doses. Seu treino te espera!",
        "#sextou Sextou com equilíbrio: treine, hidrate e, se sair, priorize bebidas leves e baixa quantidade.",
        "#sextou Diversão sem exagero: prefira bebidas leves e em pouca quantidade. Seu corpo agradece amanhã!",
        "#sextou Feche a semana treinando. Se for para algum lugar, bebidas leves e baixa quantidade mantêm o progresso.",
    )

    private val saturdayMotivation = listOf(
        "FDS chegou! Movimente-se com leveza — um treino curto ou cardio já faz o sábado valer. 🌤️",
        "FDS de verdade inclui autocuidado: treine, hidrate e descanse com qualidade.",
        "Sábado de FDS: mantenha o ritmo sem pressão. Um treino ativo deixa o fim de semana melhor!",
        "FDS em movimento! Aproveite o sábado para treinar e curtir a energia que o corpo devolve.",
        "FDS: equilíbrio entre descanso e ação. Um treino hoje deixa domingo ainda mais leve.",
    )

    private val sundayMotivation = listOf(
        "Domingo de recomeço: prepare corpo e mente — um treino ou alongamento muda a semana. ✨",
        "Domingo motivacional: organize a semana, hidrate-se e dê um treino de qualidade a si mesmo!",
        "Feche o ciclo com orgulho. Domingo é chance de treinar leve e começar segunda em alta.",
        "Domingo: respire, movimente e planeje. Sua consistência começa com a escolha de hoje!",
        "Motivação de domingo: cuide do corpo agora para a semana fluir com mais força e clareza.",
    )

    val daily = listOf(
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
        "O melhor treino é aquele que você faz. Faça o de hoje!",
    )

    fun dailyMessage(calendar: Calendar = Calendar.getInstance()): String {
        // Calendar.SUNDAY = 1 … SATURDAY = 7 (same as iOS)
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.THURSDAY -> pick(thursdayMotivation, calendar)
            Calendar.FRIDAY -> pick(fridayMotivation, calendar)
            Calendar.SATURDAY -> pick(saturdayMotivation, calendar)
            Calendar.SUNDAY -> pick(sundayMotivation, calendar)
            else -> pick(weekdayWorkoutMotivation, calendar)
        }
    }

    data class DashboardDisciplineBanner(val title: String, val subtitle: String, val cheer: String)

    fun dashboardDisciplineBanner(calendar: Calendar = Calendar.getInstance()): DashboardDisciplineBanner {
        val day = calendar.get(Calendar.DAY_OF_YEAR)
        return DashboardDisciplineBanner(
            title = dashboardDisciplineTitles[(day - 1).mod(dashboardDisciplineTitles.size)],
            subtitle = dashboardDisciplineSubtitles[(day - 1).mod(dashboardDisciplineSubtitles.size)],
            cheer = dashboardDisciplineCheers[(day - 1).mod(dashboardDisciplineCheers.size)],
        )
    }

    private val dashboardDisciplineTitles = listOf(
        "Disciplina hoje, resultados amanhã.",
        "Mostre pra você do que é capaz hoje.",
        "Um dia de foco vale mais que uma semana de desculpas.",
        "Consistência silenciosa, progresso barulhento.",
        "Treine por quem você quer ser amanhã.",
        "Pequeno esforço diário, grande transformação.",
        "Hoje você escolhe: evolução ou adiamento.",
        "A vitória começa quando você aparece.",
        "Seu corpo segue o que sua mente decide.",
        "Não espere motivação — pratique disciplina.",
        "Cada escolha de hoje molda o resultado.",
        "Força não é sorte. É repetição com intenção.",
        "O melhor treino é o que você faz agora.",
        "Menos perfeição, mais presença no processo.",
        "Quem treina hoje, agradece amanhã.",
        "Seu futuro eu já está torcendo por você.",
        "Disciplina é liberdade disfarçada de rotina.",
        "Avance 1% hoje. Isso já muda o jogo.",
        "Foque no próximo passo, não no fim da estrada.",
        "Resultados respeitam quem respeita o processo.",
        "Hoje é o dia que o ontem pediu.",
        "Coragem de começar, constância de continuar.",
        "Você não precisa estar pronto — precisa começar.",
        "A meta não some; a desculpa que some.",
        "Energia vem da ação. Mova-se.",
        "Treinar é investir em você. Faça o depósito.",
        "Sua melhor versão treina mesmo sem plateia.",
        "Feche o dia com orgulho, não com remorso.",
        "O suor de hoje vira confiança amanhã.",
        "Disciplina hoje. Orgulho depois.",
    )

    private val dashboardDisciplineSubtitles = listOf(
        "Pequenas escolhas, grandes conquistas.",
        "Apareça. Execute. Evolua.",
        "Um treino de cada vez — sem pressa e sem pausa.",
        "Técnica boa, intensidade certa, mente firme.",
        "Hidrate, respire e dê o seu melhor agora.",
        "O caminho é diário. O resultado é acumulado.",
        "Foque no que você controla: o próximo movimento.",
        "Consistência vence intensidade isolada.",
        "Seu progresso nasce nas decisões silenciosas.",
        "Hoje conta. Não deixe passar em branco.",
        "Menos comparação, mais construção.",
        "Cada repetição é um voto no seu objetivo.",
        "Corpo e mente agradecem quem aparece.",
        "A rotina que você cumpre vira identidade.",
        "Comece leve se precisar — só não pule o dia.",
    )

    private val dashboardDisciplineCheers = listOf(
        "VOCÊ CONSEGUE!", "BORA!", "FOCO!", "VAI!", "É HOJE!",
        "FIRME!", "EVOLUA!", "PRESENTE!", "FORÇA!", "SEGUE!",
    )

    fun dailyNotificationTitle(): String = "Bom dia, HealthFit ☀️"

    fun eveningTrainingNudgeMessage(calendar: Calendar = Calendar.getInstance()): String =
        when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> "Domingo ainda dá tempo: um treino leve fecha a semana com orgulho."
            Calendar.MONDAY -> "Segunda pede ação. Não deixe o dia acabar sem treinar!"
            Calendar.TUESDAY -> "Terça é ritmo: mantenha a sequência e fortaleça o hábito."
            Calendar.WEDNESDAY -> "Quarta no meio do caminho — um treino agora muda o restante da semana."
            Calendar.THURSDAY -> "Quinta de virada: treine com presença e chegue forte no fim de semana."
            Calendar.FRIDAY -> "Sextou com disciplina: treine antes de celebrar o fim de semana."
            Calendar.SATURDAY -> "Sábado em movimento: um treino curto já faz o FDS valer a pena."
            else -> "Ainda dá tempo de treinar hoje. Seu corpo agradece!"
        }

    private const val WorkoutStartFocus =
        "Ótimo, vamos treinar! Escolha sua playlist favorita e vamos pra cima! " +
            "Mesmo que esteja com alguém, treine no foco e evite conversar muito tempo! Vamos lá!"

    private val workoutStart = listOf(
        "Hora de brilhar! Aqueça bem e dê o seu melhor neste treino. 🔥",
        "Treino iniciado! Foco total, técnica perfeita e muita energia!",
        "Você veio até aqui — agora é hora de conquistar cada série!",
        "Respire fundo, concentre-se e mostre do que é capaz!",
        "Cada série é uma oportunidade. Aproveite ao máximo!",
        "Treino começou! Hidrate-se, respire e execute com intensidade.",
        "Hoje é seu dia! Entre na zona e faça valer cada minuto.",
        "A jornada começa agora. Força, foco e determinação!",
    )

    private val cardioStart = listOf(
        "Cada passo te fortalece. Respire, mantenha o ritmo e vá além do que imaginava!",
        "Hoje o coração comanda: intensidade com inteligência. Você nasce pra se superar!",
        "Movimento é liberdade. Queime dúvidas, acelere conquistas — o cardio é seu aliado!",
        "Sua resistência cresce a cada minuto. Foque no agora e deixe o suor contar a história!",
        "Disciplina em movimento! Aqueça, acelere e prove pra você mesmo do que é capaz!",
        "Corpo em marcha, mente no objetivo. Este cardio é investimento no seu futuro!",
        "Não espere motivação — crie impulso. Um ritmo de cada vez até a meta!",
        "Você já começou: isso é metade da vitória. Agora sustente o fôlego e avance!",
    )

    private val meditationStart = listOf(
        "A quietude não é ausência — é presença plena. Encontre-se neste silêncio.",
        "Como a água reflete o céu, a mente calma reflete a verdade. Observe sem julgar.",
        "Quem domina a respiração começa a dominar a si mesmo. Inspire paz, expire o resto.",
        "O presente é o único tempo que existe. Nesta meditação, habite apenas o agora.",
        "A sabedoria nasce do silêncio interior. Deixe pensamentos passarem como nuvens.",
        "Não busque esvaziar a mente — apenas não se apegue ao que surge. Observe e solte.",
        "Em cada respiração há um recomeço. Cultive serenidade; o mundo espera do lado de fora.",
        "Conhece-te a ti mesmo no silêncio. Esta pausa é força, não fuga.",
    )

    fun workoutStartMessage(workoutTitle: String, athleteName: String): String =
        "$athleteName, $WorkoutStartFocus Treino: $workoutTitle."

    fun workoutStartTip(seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        workoutStart[abs(seed) % workoutStart.size]

    fun cardioStartMessage(sessionTitle: String, athleteName: String): String {
        val tip = cardioStart[abs(sessionTitle.hashCode()) % cardioStart.size]
        return "$athleteName, $tip Sessão: $sessionTitle."
    }

    fun meditationStartMessage(sessionTitle: String, athleteName: String): String {
        val tip = meditationStart[abs(sessionTitle.hashCode()) % meditationStart.size]
        return "$athleteName, $tip Sessão: $sessionTitle."
    }

    fun workoutEndMessage(
        title: String,
        athleteName: String,
        durationLabel: String,
        completed: Int,
        total: Int,
        calories: Int?,
        autoEndedByInactivity: Boolean = false,
    ): String {
        if (autoEndedByInactivity) {
            return forgottenWorkoutEndNotification(title, athleteName)
        }
        val lower = title.lowercase(Locale.getDefault())
        if (lower.startsWith("meditação") || lower.startsWith("meditacao")) {
            return "$athleteName, meditação concluída. $title — $durationLabel. Que a clareza desta pausa acompanhe o seu dia."
        }
        if (lower.startsWith("cardio") || lower.contains("caminhada") || lower.contains("corrida")) {
            val kcal = if (calories != null && calories > 0) ", $calories kcal" else ""
            return "$athleteName, cardio finalizado! $title — $durationLabel$kcal. Resistência construída, mente reforçada! 🏃"
        }
        return "$athleteName, treino finalizado! $title — $durationLabel, $completed/$total exercícios concluídos. Parabéns pelo esforço! 🏆"
    }

    private val forgottenWorkoutEndMessages = listOf(
        "Poxa, você esqueceu de finalizar o treino — mas não se preocupe, estou aqui pra te ajudar. 💙",
        "O treino ficou aberto por mais de 2h30 e eu encerrei por segurança. Sem culpa: o próximo você finaliza comigo!",
        "Esquecer de encerrar acontece. O importante é voltar, aprender e seguir firme. Estou com você! 💪",
        "Alerta de inatividade: o treino passou de 2h30 sem finalização. Eu cuidei do encerramento — agora respira e segue em frente.",
        "Poxa… o treino ficou sem finalizar. Tudo bem! Use isso como lembrete e conte comigo no próximo.",
    )

    private val forgottenWorkoutMotivation = listOf(
        "Cada dia é uma nova chance de evoluir. Você não precisa ser perfeito — só consistente. 🌟",
        "Errar o processo faz parte. O que te define é voltar. Vamos juntos! 🔥",
        "Seu progresso não some porque um treino ficou aberto. Amanhã é recomeço.",
        "Disciplina também é lembrar de encerrar. Da próxima vez, eu te lembro — e você brilha!",
        "Corpo e mente agradecem a honestidade. Agora hidrate, descanse e retome com leveza.",
    )

    fun forgottenWorkoutEndNotification(workoutTitle: String, athleteName: String): String {
        val tip = forgottenWorkoutEndMessages[abs(workoutTitle.hashCode()) % forgottenWorkoutEndMessages.size]
        return "$athleteName, $tip Sessão: $workoutTitle."
    }

    fun forgottenWorkoutPendingNotification(workoutTitle: String): String =
        "O treino \"$workoutTitle\" passou de 2h30 sem finalização. Abra o HealthFit — vou encerrar e te ajudar a retomar com carinho."

    private val inactivityReminder = listOf(
        "Faz mais de 48h que você não treina. Seu corpo sente falta — bora retomar hoje? 💪",
        "Dois dias sem treino ou cardio. A consistência é o segredo — volte hoje!",
        "48h sem atividade registrada. Um treino curto já faz diferença. Vamos?",
        "Sentimos sua falta! Há 2 dias sem treino — retome sua rotina agora.",
        "A pausa foi longa. Seu próximo treino começa com uma decisão — faça acontecer hoje!",
    )

    private val appUsageInactivityReminder = listOf(
        "Seu ícone do app está quebrado 💔 Abra o HealthFit e volte às atividades físicas hoje!",
        "Faz mais de 48h sem abrir o app. Seu corpo precisa de movimento — retome seus treinos agora!",
        "A inatividade afeta sua saúde. Volte ao HealthFit e cuide do seu condicionamento físico!",
        "Que tal retomar a rotina? Abra o app e dê o primeiro passo de volta aos treinos.",
        "Seu progresso espera por você. Reabra o HealthFit e volte a se movimentar!",
    )

    private val cardioInactivityReminder = listOf(
        "Faz 48h sem cardio 🏃💨 Benefícios: coração mais forte, mais energia e queima de gordura. 20 min hoje já contam!",
        "Seu coração sente falta do ritmo ❤️🏃 Cardio regular melhora humor, sono e resistência. Bora na aba Treinos?",
        "2 dias sem cardio ⏱️ Condicionamento cai rápido — retome com caminhada, bike ou corrida leve hoje!",
    )

    private val meditationInactivityReminder = listOf(
        "Faz 48h sem meditar 🧘✨ Benefícios: menos estresse, mais foco e sono melhor. 5–10 min já transformam o dia!",
        "A mente também treina 🧠🕊️ Meditação reduz ansiedade e melhora recuperação. Que tal uma sessão curta agora?",
        "2 dias sem meditação ⏳ Respire fundo e volte à rotina — clareza mental impulsiona treinos e hábitos saudáveis.",
    )

    fun inactivityMessage(seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        inactivityReminder[abs(seed) % inactivityReminder.size]

    fun appUsageInactivityMessage(seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        appUsageInactivityReminder[abs(seed) % appUsageInactivityReminder.size]

    fun cardioInactivityMessage(seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        cardioInactivityReminder[abs(seed) % cardioInactivityReminder.size]

    fun meditationInactivityMessage(seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        meditationInactivityReminder[abs(seed) % meditationInactivityReminder.size]

    fun healthIconYellowMessage(detail: String): String {
        val trimmed = detail.trim()
        return if (trimmed.isEmpty()) {
            "Atualize água e sono hoje para voltar ao verde 💛💧😴"
        } else {
            "$trimmed 💛💧😴"
        }
    }

    fun healthIconRedMessage(detail: String): String {
        val trimmed = detail.trim()
        return if (trimmed.isEmpty()) {
            "Mais de 24h sem atualizar água e sono. Registre agora no Perfil! 🚨❤️💧😴"
        } else {
            "$trimmed 🚨❤️💧😴"
        }
    }

    fun chatWelcomeMotivation(
        hasSleepAlert: Boolean,
        hasWaterAlert: Boolean,
        hasWorkoutAlert: Boolean,
    ): String = when {
        hasWorkoutAlert -> pick(workoutWelcomeMotivation)
        hasSleepAlert -> pick(sleepWelcomeMotivation)
        hasWaterAlert -> pick(waterWelcomeMotivation)
        else -> dailyMessage()
    }

    private val workoutWelcomeMotivation = listOf(
        "A consistência constrói resultados. Só um treino hoje — seu corpo agradece amanhã!",
        "Cada dia é uma nova chance de retomar. Apareça na aba Treinos e dê o primeiro passo!",
        "Disciplina vence motivação. Um treino curto já reativa seu progresso — bora!",
        "Você já venceu ao abrir o app. Agora transforme intenção em ação — treine hoje!",
    )

    private val sleepWelcomeMotivation = listOf(
        "Descanso é parte do treino. Priorize 7–9 h hoje — seu corpo recupera enquanto você dorme.",
        "Sono de qualidade acelera resultados. Hoje, cuide do descanso como cuida da dieta.",
        "Durma bem hoje — amanhã você treina com mais energia e foco.",
    )

    private val waterWelcomeMotivation = listOf(
        "Hidratação é performance. Beba água agora e ao longo do dia — cada copo conta!",
        "Seu corpo precisa de água para treinar e recuperar. Complete a meta hoje!",
        "Água é combustível. Aproxime-se da meta ml a ml — você consegue!",
    )

    private val waterReminderMessages = listOf(
        "Hora de beber água! 💧 Hidratação mantém energia, foco e recuperação muscular.",
        "Pausa para hidratar! 💧 Seu corpo precisa de água agora — registre no Perfil.",
        "Lembrete de água 💧 Beba um copo agora e continue sua meta diária.",
        "Hidratação em dia = treino melhor 💧 Beba água neste momento.",
        "Água agora! 💧 Cada gole aproxima você da meta de hidratação.",
        "Não espere sede 💧 Beba água agora e mantenha o corpo funcionando bem.",
    )

    fun waterReminderMessage(forHour: Int): String =
        waterReminderMessages[forHour.coerceAtLeast(0) % waterReminderMessages.size]

    private val mealReminderTips = listOf(
        "Separe o prato do cardápio e hidrate-se. 🥗",
        "Alerta do cardápio: prepare a refeição com calma e aproveite cada mordida.",
        "Lembrete nutricional: comer no horário ajuda energia, foco e resultados. 💪",
        "Seu cardápio te espera — organize a porção e evite pular esta refeição.",
        "Água, prato e atenção plena na comida. 🌿",
        "Constância no cardápio = evolução. Não deixe esta refeição passar!",
    )

    fun mealReminderMessage(mealType: MealType, hour: Int, minute: Int): String {
        val tip = mealReminderTips[abs(mealType.name.hashCode()) % mealReminderTips.size]
        val time = "%02d:%02d".format(hour, minute)
        return "${mealType.label} às $time. $tip"
    }

    fun defaultMealClock(mealType: MealType): Pair<Int, Int> = when (mealType) {
        MealType.Breakfast -> 7 to 0
        MealType.MorningSnack -> 10 to 0
        MealType.Lunch -> 12 to 30
        MealType.AfternoonSnack -> 16 to 0
        MealType.Dinner -> 19 to 0
        MealType.Supper -> 21 to 30
    }

    fun supplementReminderBody(hour: Int): String = when (hour) {
        6 -> "Janela de suplemento da manhã — registre se fizer parte do seu plano."
        9 -> "Suplemento da manhã: marque o registro se estiver no plano."
        12 -> "Registre o suplemento do meio-dia, se fizer parte do seu plano."
        15 -> "Janela de suplemento da tarde."
        18 -> "Suplemento do fim da tarde, se estiver no plano."
        21 -> "Último registro de suplemento do dia."
        else -> "Lembrete de suplemento — registre se fizer parte do seu plano."
    }

    fun shareMotivationLine(isCardio: Boolean, seed: Int = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)): String =
        if (isCardio) {
            listOf(
                "Cada passo te aproxima do objetivo.",
                "Movimento é liberdade. Continue.",
                "Resistência se constrói um ritmo por vez.",
            )[abs(seed) % 3]
        } else {
            listOf(
                "A disciplina de hoje é o progresso de amanhã.",
                "Cada sessão conta.",
                pick(daily),
            )[abs(seed) % 3]
        }

    private fun pick(messages: List<String>, calendar: Calendar = Calendar.getInstance()): String {
        if (messages.isEmpty()) return daily.first()
        val day = calendar.get(Calendar.DAY_OF_YEAR)
        return messages[(day - 1).mod(messages.size)]
    }
}
