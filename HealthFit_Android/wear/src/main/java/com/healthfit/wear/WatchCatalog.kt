package com.healthfit.wear

/** Catálogos leves espelhando o iPhone/Apple Watch (WatchCatalog.swift). */
object WatchCatalog {
    data class StrengthProgram(val id: String, val title: String, val firstExercise: String)

    data class CardioActivity(
        val id: String,
        val name: String,
        val isWaterSport: Boolean = false,
        val isKitesurf: Boolean = false,
        val isSwimming: Boolean = false,
    )

    data class WaterRideOption(val id: String, val name: String, val detail: String)

    data class MeditationTopic(
        val id: String,
        val name: String,
        val colorName: String,
        val prompts: List<String>,
    )

    enum class DurationOption(val minutes: Int) {
        Five(5), Ten(10), Fifteen(15), Twenty(20), Thirty(30), FortyFive(45), Sixty(60);

        val label: String get() = "$minutes min"
        val seconds: Int get() = minutes * 60
    }

    /** Durações disponíveis na meditação (5/10/15/20 min). */
    val meditationDurations: List<DurationOption> = listOf(
        DurationOption.Five,
        DurationOption.Ten,
        DurationOption.Fifteen,
        DurationOption.Twenty,
    )

    val kiteRidingModes = listOf(
        WaterRideOption("bigAir", "Big Air", "Saltos e tempo de ar"),
        WaterRideOption("speed", "Speed", "Velocidade e percurso"),
        WaterRideOption("coaching", "Coaching", "Treino guiado"),
        WaterRideOption("downwind", "Downwind", "Percurso a favor do vento"),
    )

    val surfBoards = listOf(
        WaterRideOption("shortboard", "Shortboard", "Performance"),
        WaterRideOption("longboard", "Longboard", "Estabilidade"),
        WaterRideOption("fish", "Fish", "Ondas pequenas"),
        WaterRideOption("funboard", "Funboard", "Intermediário"),
        WaterRideOption("softTop", "Soft top", "Iniciante"),
    )

    val kiteBoards = listOf(
        WaterRideOption("twinTip", "Twin Tip", "Freeride e saltos"),
        WaterRideOption("directional", "Directional", "Rides direcionais"),
        WaterRideOption("foil", "Foil Board", "Hydrofoil"),
        WaterRideOption("strapless", "Strapless", "Sem straps"),
    )

    val strengthPrograms = listOf(
        StrengthProgram("m-a", "Masculino A — Peito e Tríceps", "Supino reto"),
        StrengthProgram("m-b", "Masculino B — Costas e Bíceps", "Puxada frontal"),
        StrengthProgram("m-c", "Masculino C — Pernas", "Agachamento"),
        StrengthProgram("m-d", "Masculino D — Ombros e Trapézio", "Desenvolvimento"),
        StrengthProgram("f-a", "Feminino A — Glúteos e Posteriores", "Elevação pélvica"),
        StrengthProgram("f-b", "Feminino B — Pernas e Core", "Agachamento sumô"),
        StrengthProgram("f-c", "Feminino C — Costas e Postura", "Remada curvada"),
        StrengthProgram("f-d", "Feminino D — Full Body e Ombros", "Desenvolvimento"),
        StrengthProgram("c-a", "Casa A — Full Body", "Agachamento livre"),
        StrengthProgram("c-b", "Casa B — Core e Abdômen", "Prancha"),
        StrengthProgram("c-c", "Casa C — HIIT Em Casa", "Polichinelos"),
        StrengthProgram("c-d", "Casa D — Pernas e Glúteos", "Afundo"),
        StrengthProgram("c-e", "Casa E — Superiores", "Flexão de braço"),
        StrengthProgram("c-f", "Casa F — Mobilidade e Postura", "Gato-camelo"),
        StrengthProgram("mob-a", "Mobilidade A — Alongamento Dinâmico", "Alongamento mundial"),
        StrengthProgram("mob-e", "Mobilidade E — Alongamento Estático", "Alongamento de peito"),
    )

    val cardioActivities = listOf(
        CardioActivity("run", "Corrida"),
        CardioActivity("walk", "Caminhada"),
        CardioActivity("treadmill", "Esteira Ergométrica"),
        CardioActivity("mtb", "Mountain bike"),
        CardioActivity("bike", "Bicicleta pedal"),
        CardioActivity("ergo", "Bicicleta ergométrica"),
        CardioActivity("surf", "Surf", isWaterSport = true),
        CardioActivity("kite", "Kitesurf", isWaterSport = true, isKitesurf = true),
        CardioActivity("ellip", "Elíptico"),
        CardioActivity("rope", "Pular Corda"),
        CardioActivity("stairs", "Escada"),
        CardioActivity("climb", "Escalada"),
        CardioActivity("row", "Remo"),
        CardioActivity("swim", "Natação", isSwimming = true),
        CardioActivity("jack", "Polichinelo"),
        CardioActivity("burpee", "Burpees"),
    )

    val meditationTopics = listOf(
        MeditationTopic(
            "breath", "Respiração Consciente", "blue",
            listOf(
                "Sente-se confortavelmente e feche os olhos.",
                "Inspire lentamente pelo nariz contando até quatro.",
                "Expire suavemente contando até seis.",
                "Quando a mente divagar, volte à respiração.",
                "Finalize agradecendo por este momento.",
            ),
        ),
        MeditationTopic(
            "body", "Relaxamento Corporal", "teal",
            listOf(
                "Relaxe os pés e as pernas.",
                "Solte quadris, abdômen e costas.",
                "Relaxe ombros, braços e rosto.",
                "Sinta o corpo mais leve a cada expiração.",
                "Mova os dedos e abra os olhos devagar.",
            ),
        ),
        MeditationTopic(
            "grat", "Gratidão", "pink",
            listOf(
                "Traga à mente algo pelo qual é grato.",
                "Sinta a gratidão se expandir no peito.",
                "Agradeça pela saúde e pelas pequenas vitórias.",
                "Carregue essa sensação pelo resto do dia.",
            ),
        ),
        MeditationTopic(
            "focus", "Foco e Clareza", "indigo",
            listOf(
                "Você está presente aqui e agora.",
                "Visualize seu objetivo com clareza.",
                "Cada respiração traz mais foco.",
                "Afirme: eu tenho foco e força.",
            ),
        ),
        MeditationTopic(
            "anxiety", "Redução de Ansiedade", "green",
            listOf(
                "Nomeie 3 coisas que você vê agora.",
                "Inspire 4s · segure 2s · expire 6s.",
                "Os pensamentos são nuvens — deixe-os passar.",
                "Retorne ao dia com mais leveza.",
            ),
        ),
        MeditationTopic(
            "sleep", "Sono e Descanso", "purple",
            listOf(
                "Diminua a respiração lentamente.",
                "Relaxe o rosto e a mandíbula.",
                "Conte de 10 a 1 a cada expiração.",
                "Permita-se descansar em paz.",
            ),
        ),
        MeditationTopic(
            "recover", "Recuperação Pós-Treino", "orange",
            listOf(
                "Agradeça ao corpo pelo trabalho de hoje.",
                "Envia relaxamento aos músculos trabalhados.",
                "A hidratação e o sono completam a recuperação.",
                "Você treinou bem — agora recupere.",
            ),
        ),
    )

    fun cardio(id: String): CardioActivity? = cardioActivities.firstOrNull { it.id == id }
    fun strength(id: String): StrengthProgram? = strengthPrograms.firstOrNull { it.id == id }
    fun meditation(id: String): MeditationTopic? = meditationTopics.firstOrNull { it.id == id }
}
