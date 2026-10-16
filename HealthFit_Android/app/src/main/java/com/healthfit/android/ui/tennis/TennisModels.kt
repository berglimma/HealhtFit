package com.healthfit.android.ui.tennis

enum class TennisSessionType(val title: String, val detail: String, val loadWeight: Double) {
    Match("Partida", "Jogo competitivo — carga alta e recuperação crítica", 1.25),
    Training("Treino", "Treino livre ou com parceiro — volume controlado", 1.0),
    Drill("Drill", "Blocos técnicos (saque, devolução, rede)", 0.9),
    Lesson("Aula", "Aula com professor — intensidade variável", 0.85),
}

enum class TennisMatchFormat(val title: String, val loadWeight: Double) {
    Singles("Simples", 1.0),
    Doubles("Duplas", 0.85),
}

enum class TennisCourtSurface(
    val title: String,
    val detail: String,
    val isOutdoor: Boolean,
) {
    HardOutdoor("Duro (outdoor)", "Ritmo rápido · GPS de cobertura da movimentação", true),
    HardIndoor("Duro (indoor)", "Sem GPS de quadra — foco em FC, picos e placar", false),
    Clay("Saibro", "Deslizamentos · GPS de cobertura na quadra", true),
    Grass("Grama", "Rebote rápido · GPS de cobertura", true),
    Carpet("Carpete", "Indoor sintético — pivôs curtos · sem GPS de rota", false),
}

enum class TennisSkillLevel(val title: String, val highZoneGoalPercent: Int) {
    Beginner("Iniciante", 25),
    Intermediate("Intermediário", 35),
    Advanced("Avançado", 45),
}

enum class TennisHandedness(val title: String) {
    Right("Destro"),
    Left("Canhoto"),
}

data class TennisSessionSetup(
    val sessionType: TennisSessionType = TennisSessionType.Training,
    val matchFormat: TennisMatchFormat = TennisMatchFormat.Singles,
    val surface: TennisCourtSurface = TennisCourtSurface.HardOutdoor,
    val skillLevel: TennisSkillLevel = TennisSkillLevel.Intermediate,
    val handedness: TennisHandedness = TennisHandedness.Right,
    val targetSets: Int = 0,
    val targetMinutes: Int = 0,
    val useZoneGoal: Boolean = true,
    val courtName: String = "",
) {
    val minutes: Int get() = if (targetMinutes > 0) targetMinutes else 60

    fun detailLine(): String = buildList {
        add(sessionType.title)
        add(matchFormat.title)
        add(surface.title)
        add(skillLevel.title)
        add(handedness.title)
        if (targetSets > 0) add("$targetSets set(s)")
        if (courtName.isNotBlank()) add(courtName)
        if (useZoneGoal) add("zona alta ~${skillLevel.highZoneGoalPercent}%")
        add("$minutes min")
    }.joinToString(" · ")
}
