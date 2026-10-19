package com.healthfit.android.ui.assistant

import android.content.Context
import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.BodyType
import com.healthfit.android.ui.workouts.Muscle
import com.healthfit.android.ui.workouts.WorkoutExercise
import com.healthfit.android.ui.workouts.WorkoutSheet
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

enum class AssistantWorkoutGender { Male, Female }

enum class AssistantWorkoutGoalFocus(val label: String, val shortLabel: String) {
    MuscleGain("Ganho de massa", "Hipertrofia"),
    Endurance("Resistência", "Resistência"),
    FatLoss("Perda de gordura", "Emagrecimento"),
}

enum class AssistantTrainingExperience(val label: String) {
    FirstTime("Primeira vez"),
    Returning("Retomando"),
    Beginner("Iniciante"),
    Intermediate("Intermediário"),
    Advanced("Avançado"),
}

enum class AssistantTrainingLocation { Gym, HomeOnly }

enum class WorkoutBuilderPhase {
    Idle,
    AskingGender,
    AskingHomeOnly,
    AskingAlreadyTrains,
    AskingFirstTime,
    AskingExperienceLevel,
    AskingFocus,
    Confirming,
}

data class WorkoutBuilderDraft(
    val phase: WorkoutBuilderPhase = WorkoutBuilderPhase.Idle,
    val gender: AssistantWorkoutGender? = null,
    val location: AssistantTrainingLocation? = null,
    val experience: AssistantTrainingExperience? = null,
    val focus: AssistantWorkoutGoalFocus? = null,
)

object AssistantWorkoutBuilder {
    const val ProfessionalDisclaimer =
        "Sugestão educativa do IAssistente — essencial validar com um profissional de Educação Física."

    val quickGender = listOf("Masculino", "Feminino")
    val quickHome = listOf("Sim, só em casa", "Não, na academia")
    val quickAlreadyTrains = listOf("Sim, já treino", "Não, ainda não")
    val quickFirstTime = listOf("Sim, primeira vez", "Não, já treinei antes")
    val quickLevel = listOf("Iniciante", "Intermediário", "Avançado")
    val quickFocus = listOf("Ganho de massa", "Resistência", "Perda de gordura")
    val quickConfirm = listOf("Sim, autorizo", "Não, cancelar")

    fun detectsIntent(text: String): Boolean {
        val n = norm(text)
        return listOf(
            "montar treino", "criar treino", "gerar treino", "montar ficha", "criar ficha",
            "gerar ficha", "treino sem personal", "ficha personalizada", "sugestao de treino",
        ).any { n.contains(it) }
    }

    fun startMessage(name: String): String {
        val greeting = if (name.isBlank()) "" else "$name, "
        return """
            ${greeting}posso montar uma sugestão de treino personalizada.

            Vou entender seu perfil: gênero, casa ou academia, se já treina e o foco — depois gero a ficha com todos os grupos musculares.

            $ProfessionalDisclaimer

            Primeiro: deseja treino **Masculino** ou **Feminino**?
        """.trimIndent()
    }

    fun handle(
        text: String,
        draft: WorkoutBuilderDraft,
        athlete: AthleteProfile,
        weightKg: Float = 75f,
        heightCm: Float = 175f,
        age: Int = 28,
    ): Pair<WorkoutBuilderDraft, String> {
        return when (draft.phase) {
            WorkoutBuilderPhase.Idle -> draft to ""
            WorkoutBuilderPhase.AskingGender -> {
                val gender = parseGender(text) ?: return draft to
                    "Não entendi o perfil. Responda **Masculino** ou **Feminino**."
                draft.copy(phase = WorkoutBuilderPhase.AskingHomeOnly, gender = gender) to """
                    Perfil ${if (gender == AssistantWorkoutGender.Female) "feminino" else "masculino"} selecionado.

                    Você deseja treinar **apenas em casa** (peso corporal, sem academia)?
                    Responda **Sim, só em casa** ou **Não, na academia**.
                """.trimIndent()
            }
            WorkoutBuilderPhase.AskingHomeOnly -> {
                val home = parseHomeOnly(text) ?: return draft to
                    "Prefere treinar só em casa ou na academia? Responda **Sim, só em casa** ou **Não, na academia**."
                val loc = if (home) AssistantTrainingLocation.HomeOnly else AssistantTrainingLocation.Gym
                val place = if (home) "em casa" else "na academia"
                draft.copy(phase = WorkoutBuilderPhase.AskingAlreadyTrains, location = loc) to """
                    Beleza — montarei a ficha para treinar $place.

                    Você **já treina** atualmente?
                    Responda **Sim, já treino** ou **Não, ainda não**.
                """.trimIndent()
            }
            WorkoutBuilderPhase.AskingAlreadyTrains -> {
                val already = parseYesNo(text) ?: return draft to
                    "Me diga se você já treina: **Sim, já treino** ou **Não, ainda não**."
                if (already) {
                    draft.copy(phase = WorkoutBuilderPhase.AskingExperienceLevel) to """
                        Ótimo — então vamos calibrar a intensidade.

                        Qual o seu nível hoje?
                        • **Iniciante**
                        • **Intermediário**
                        • **Avançado**
                    """.trimIndent()
                } else {
                    val firstPrompt = if (draft.location == AssistantTrainingLocation.HomeOnly) {
                        "É a sua **primeira vez** com treinos estruturados em casa?"
                    } else {
                        "É a sua **primeira vez na academia**?"
                    }
                    draft.copy(phase = WorkoutBuilderPhase.AskingFirstTime) to """
                        Sem problemas — começamos com calma e **cargas bem leves**.

                        $firstPrompt
                        Responda **Sim, primeira vez** ou **Não, já treinei antes**.
                    """.trimIndent()
                }
            }
            WorkoutBuilderPhase.AskingFirstTime -> {
                val first = parseYesNo(text) ?: return draft to
                    "Responda **Sim, primeira vez** ou **Não, já treinei antes**."
                val exp = if (first) AssistantTrainingExperience.FirstTime else AssistantTrainingExperience.Returning
                val note = when {
                    draft.location == AssistantTrainingLocation.HomeOnly && first ->
                        "Perfil: primeira vez em casa — cargas leves e foco em técnica (use os GIFs)."
                    draft.location == AssistantTrainingLocation.HomeOnly ->
                        "Perfil: retomando em casa — progressão cuidadosa sem equipamentos."
                    first ->
                        "Perfil: primeira vez na academia — cargas bem baixas e foco em técnica."
                    else ->
                        "Perfil: retomando após pausa — progressão cuidadosa."
                }
                draft.copy(phase = WorkoutBuilderPhase.AskingFocus, experience = exp) to """
                    $note

                    Qual o foco do treino?
                    • Ganho de massa
                    • Resistência
                    • Perda de gordura
                """.trimIndent()
            }
            WorkoutBuilderPhase.AskingExperienceLevel -> {
                val level = parseLevel(text) ?: return draft to
                    "Escolha o nível: **Iniciante**, **Intermediário** ou **Avançado**."
                val loadNote = if (level == AssistantTrainingExperience.Beginner) {
                    " Vou usar **cargas bem baixas** nesta ficha."
                } else {
                    ""
                }
                draft.copy(phase = WorkoutBuilderPhase.AskingFocus, experience = level) to """
                    Nível ${level.label.lowercase()} anotado.$loadNote

                    Qual o foco do treino?
                    • Ganho de massa
                    • Resistência
                    • Perda de gordura
                """.trimIndent()
            }
            WorkoutBuilderPhase.AskingFocus -> {
                val focus = parseFocus(text) ?: return draft to
                    "Escolha um foco: **Ganho de massa**, **Resistência** ou **Perda de gordura**."
                val gender = draft.gender ?: AssistantWorkoutGender.Male
                val loc = draft.location ?: AssistantTrainingLocation.Gym
                val exp = draft.experience ?: AssistantTrainingExperience.Intermediate
                draft.copy(phase = WorkoutBuilderPhase.Confirming, focus = focus) to confirmationSummary(
                    gender, focus, athlete, exp, loc, weightKg, heightCm, age,
                )
            }
            WorkoutBuilderPhase.Confirming -> {
                if (isNegative(text)) {
                    return WorkoutBuilderDraft() to
                        "Tudo bem — cancelei a criação. Quando quiser, diga “montar treino” novamente."
                }
                if (!isAffirmative(text)) {
                    return draft to "Para continuar, responda **Sim, autorizo** ou **Não, cancelar**."
                }
                // Sheet creation handled by caller after this message path — return marker.
                draft to "__CREATE__"
            }
        }
    }

    fun quickReplies(phase: WorkoutBuilderPhase): List<String> = when (phase) {
        WorkoutBuilderPhase.AskingGender -> quickGender
        WorkoutBuilderPhase.AskingHomeOnly -> quickHome
        WorkoutBuilderPhase.AskingAlreadyTrains -> quickAlreadyTrains
        WorkoutBuilderPhase.AskingFirstTime -> quickFirstTime
        WorkoutBuilderPhase.AskingExperienceLevel -> quickLevel
        WorkoutBuilderPhase.AskingFocus -> quickFocus
        WorkoutBuilderPhase.Confirming -> quickConfirm
        WorkoutBuilderPhase.Idle -> emptyList()
    }

    fun buildSheet(
        gender: AssistantWorkoutGender,
        focus: AssistantWorkoutGoalFocus,
        athlete: AthleteProfile,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation,
        weightKg: Float = 75f,
    ): WorkoutSheet {
        var exercises = templateExercises(gender, focus, experience, location)
            .map { adjust(it, athlete, focus, experience, location, weightKg) }
        exercises = ensureAllMuscleGroups(exercises, gender, location, experience)

        val genderLabel = if (gender == AssistantWorkoutGender.Female) "Feminino" else "Masculino"
        val locationNote = if (location == AssistantTrainingLocation.HomeOnly) {
            "Treino em casa · peso corporal."
        } else {
            "Treino para academia / equipamentos."
        }
        val titlePrefix = if (location == AssistantTrainingLocation.HomeOnly) {
            "IAssistente — Casa ·"
        } else {
            "IAssistente —"
        }
        val description = "Gerado pelo IAssistente · ${focus.label} · ${experience.label} · $locationNote " +
            "Biotipo ${athlete.bodyType.title} · ${weightKg.roundToInt()} kg. $ProfessionalDisclaimer"

        return WorkoutSheet(
            title = "$titlePrefix ${focus.shortLabel} ($genderLabel)",
            description = description,
            exercises = exercises,
        )
    }

    fun createdHint(gender: AssistantWorkoutGender, location: AssistantTrainingLocation): String {
        val program = if (gender == AssistantWorkoutGender.Female) "Feminino" else "Masculino"
        val lines = mutableListOf(
            "Onde encontrar: **Treinos → Musculação → $program → Personalizados** (badge IAssistente).",
        )
        if (location == AssistantTrainingLocation.HomeOnly) {
            lines += "Dica: em **Treinos → Treine em Casa** há fichas prontas com demos para complementar."
        }
        return lines.joinToString("\n\n")
    }

    private fun confirmationSummary(
        gender: AssistantWorkoutGender,
        focus: AssistantWorkoutGoalFocus,
        athlete: AthleteProfile,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation,
        weightKg: Float,
        heightCm: Float,
        age: Int,
    ): String {
        val genderLabel = if (gender == AssistantWorkoutGender.Female) "feminino" else "masculino"
        val locExtra = if (location == AssistantTrainingLocation.HomeOnly) {
            "Ficha de peso corporal para fazer em casa (com demos em GIF)."
        } else {
            "Ficha com **todos os grupos musculares** para academia."
        }
        return """
            Resumo da sugestão:
            • Perfil de treino: $genderLabel
            • Local: ${if (location == AssistantTrainingLocation.HomeOnly) "Só em casa" else "Academia"}
            • Experiência: ${experience.label}
            • Foco: ${focus.label}
            • Peso: ${weightKg.roundToInt()} kg · Altura: ${heightCm.roundToInt()} cm · Idade: $age
            • Biotipo: ${athlete.bodyType.title}
            • $locExtra

            $ProfessionalDisclaimer

            Autoriza criar a ficha e deixar disponível em Treinos → Personalizados?
            Responda “Sim, autorizo” ou “Não, cancelar”.
        """.trimIndent()
    }

    /** Garante peito, costas, pernas, ombros, braços e core na ficha gerada. */
    private fun ensureAllMuscleGroups(
        exercises: List<WorkoutExercise>,
        gender: AssistantWorkoutGender,
        location: AssistantTrainingLocation,
        experience: AssistantTrainingExperience,
    ): List<WorkoutExercise> {
        val present = exercises.map { it.muscle }.toSet()
        val needed = listOf(Muscle.chest, Muscle.back, Muscle.legs, Muscle.shoulders, Muscle.arms, Muscle.core)
        val extras = mutableListOf<WorkoutExercise>()
        val light = experience == AssistantTrainingExperience.FirstTime ||
            experience == AssistantTrainingExperience.Returning ||
            experience == AssistantTrainingExperience.Beginner
        val sets = if (light) 3 else 3
        val w: Float? = if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 8f else 16f

        fun add(name: String, muscle: Muscle, reps: Int, weight: Float? = w) {
            if (muscle !in present && extras.none { it.muscle == muscle }) {
                extras += WorkoutExercise(name, sets, reps, weight, muscle, if (light) 75 else 60)
            }
        }

        for (m in needed) {
            if (m in present) continue
            when (m) {
                Muscle.chest -> add(if (location == AssistantTrainingLocation.HomeOnly) "Flexão de Braços" else "Supino Reto", m, if (light) 10 else 12, if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 30f else 50f)
                Muscle.back -> add(if (location == AssistantTrainingLocation.HomeOnly) "Superman" else "Puxada Frontal", m, 12, if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 25f else 40f)
                Muscle.legs -> add("Agachamento Livre", m, if (light) 12 else 15, if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 30f else 60f)
                Muscle.shoulders -> add("Elevação Lateral", m, 12, if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 4f else 8f)
                Muscle.arms -> add(
                    if (gender == AssistantWorkoutGender.Female) "Mergulho no Banco" else "Rosca Direta",
                    m,
                    12,
                    if (location == AssistantTrainingLocation.HomeOnly) null else if (light) 6f else 12f,
                )
                Muscle.core -> add("Prancha", m, 30, null)
                Muscle.fullBody -> Unit
            }
        }
        return exercises + extras
    }

    private fun templateExercises(
        gender: AssistantWorkoutGender,
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation,
    ): List<WorkoutExercise> {
        val base = if (location == AssistantTrainingLocation.HomeOnly) {
            homeTemplates(gender, focus)
        } else {
            gymTemplates(gender, focus)
        }
        return when (experience) {
            AssistantTrainingExperience.FirstTime -> base.take(6).map { it.copy(sets = min(3, it.sets)) }
            AssistantTrainingExperience.Returning -> base.take(7).map { it.copy(sets = min(3, it.sets)) }
            else -> base
        }
    }

    private fun ex(name: String, sets: Int, reps: Int, weight: Float?, muscle: Muscle, rest: Int = 60) =
        WorkoutExercise(name, sets, reps, weight, muscle, rest)

    private fun homeTemplates(gender: AssistantWorkoutGender, focus: AssistantWorkoutGoalFocus): List<WorkoutExercise> =
        when (gender to focus) {
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.MuscleGain -> listOf(
                ex("Agachamento Livre", 4, 15, null, Muscle.legs),
                ex("Flexão de Braços", 4, 12, null, Muscle.chest),
                ex("Afundo", 3, 12, null, Muscle.legs),
                ex("Mergulho no Banco", 3, 12, null, Muscle.arms),
                ex("Superman", 3, 15, null, Muscle.back),
                ex("Flexão Diamante", 3, 10, null, Muscle.arms),
                ex("Elevação Lateral", 3, 12, null, Muscle.shoulders),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Mountain Climber", 3, 20, null, Muscle.fullBody),
            )
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.Endurance -> listOf(
                ex("Polichinelo", 3, 40, null, Muscle.fullBody),
                ex("Agachamento Livre", 3, 20, null, Muscle.legs),
                ex("Flexão de Braços", 3, 15, null, Muscle.chest),
                ex("Burpee", 3, 12, null, Muscle.fullBody),
                ex("Mountain Climber", 3, 30, null, Muscle.fullBody),
                ex("Superman", 3, 12, null, Muscle.back),
                ex("Elevação Lateral", 3, 15, null, Muscle.shoulders),
                ex("Prancha", 3, 45, null, Muscle.core),
            )
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.FatLoss -> listOf(
                ex("Polichinelo", 3, 35, null, Muscle.fullBody),
                ex("Agachamento Livre", 3, 18, null, Muscle.legs),
                ex("Burpee", 3, 12, null, Muscle.fullBody),
                ex("Flexão de Braços", 3, 12, null, Muscle.chest),
                ex("Afundo", 3, 14, null, Muscle.legs),
                ex("Superman", 3, 12, null, Muscle.back),
                ex("Mountain Climber", 3, 30, null, Muscle.fullBody),
                ex("Abdominal Crunch", 3, 20, null, Muscle.core),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
            AssistantWorkoutGender.Female to AssistantWorkoutGoalFocus.MuscleGain -> listOf(
                ex("Agachamento Livre", 4, 15, null, Muscle.legs),
                ex("Ponte de Glúteos", 4, 15, null, Muscle.legs),
                ex("Afundo", 3, 12, null, Muscle.legs),
                ex("Elevação Pélvica (Hip Thrust)", 3, 15, null, Muscle.legs),
                ex("Flexão de Braços", 3, 10, null, Muscle.chest),
                ex("Superman", 3, 12, null, Muscle.back),
                ex("Elevação Lateral", 3, 12, null, Muscle.shoulders),
                ex("Mergulho no Banco", 3, 10, null, Muscle.arms),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Russian Twist", 3, 20, null, Muscle.core),
            )
            AssistantWorkoutGender.Female to AssistantWorkoutGoalFocus.Endurance -> listOf(
                ex("Polichinelo", 3, 35, null, Muscle.fullBody),
                ex("Agachamento Livre", 3, 18, null, Muscle.legs),
                ex("Afundo", 3, 15, null, Muscle.legs),
                ex("Ponte de Glúteos", 3, 15, null, Muscle.legs),
                ex("Mountain Climber", 3, 30, null, Muscle.fullBody),
                ex("Flexão de Braços", 3, 10, null, Muscle.chest),
                ex("Superman", 3, 12, null, Muscle.back),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
            else -> listOf(
                ex("Polichinelo", 3, 35, null, Muscle.fullBody),
                ex("Agachamento Livre", 3, 18, null, Muscle.legs),
                ex("Burpee", 3, 10, null, Muscle.fullBody),
                ex("Ponte de Glúteos", 3, 15, null, Muscle.legs),
                ex("Afundo", 3, 14, null, Muscle.legs),
                ex("Flexão de Braços", 3, 10, null, Muscle.chest),
                ex("Mountain Climber", 3, 30, null, Muscle.fullBody),
                ex("Abdominal Oblíquo", 3, 20, null, Muscle.core),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
        }

    private fun gymTemplates(gender: AssistantWorkoutGender, focus: AssistantWorkoutGoalFocus): List<WorkoutExercise> =
        when (gender to focus) {
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.MuscleGain -> listOf(
                ex("Supino Reto", 4, 8, 70f, Muscle.chest),
                ex("Supino Inclinado", 4, 10, 55f, Muscle.chest),
                ex("Remada Curvada", 4, 8, 60f, Muscle.back),
                ex("Puxada Frontal", 3, 10, 50f, Muscle.back),
                ex("Agachamento Livre", 4, 8, 90f, Muscle.legs),
                ex("Leg Press 45°", 3, 10, 180f, Muscle.legs),
                ex("Desenvolvimento com Halteres", 3, 10, 20f, Muscle.shoulders),
                ex("Elevação Lateral", 3, 12, 8f, Muscle.shoulders),
                ex("Rosca Direta", 3, 10, 16f, Muscle.arms),
                ex("Tríceps Pulley", 3, 10, 30f, Muscle.arms),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.Endurance -> listOf(
                ex("Agachamento Livre", 3, 15, 50f, Muscle.legs),
                ex("Leg Press 45°", 3, 15, 100f, Muscle.legs),
                ex("Flexão de Braços", 3, 15, null, Muscle.chest),
                ex("Puxada Frontal", 3, 15, 35f, Muscle.back),
                ex("Elevação Lateral", 3, 15, 8f, Muscle.shoulders),
                ex("Rosca Direta", 3, 15, 12f, Muscle.arms),
                ex("Mountain Climber", 3, 30, null, Muscle.core),
                ex("Burpee", 3, 12, null, Muscle.fullBody),
                ex("Prancha", 3, 45, null, Muscle.core),
            )
            AssistantWorkoutGender.Male to AssistantWorkoutGoalFocus.FatLoss -> listOf(
                ex("Agachamento Livre", 3, 12, 60f, Muscle.legs),
                ex("Remada Curvada", 3, 12, 45f, Muscle.back),
                ex("Supino Reto", 3, 12, 50f, Muscle.chest),
                ex("Afundo", 3, 12, 16f, Muscle.legs),
                ex("Elevação Lateral", 3, 15, 8f, Muscle.shoulders),
                ex("Tríceps Pulley", 3, 12, 25f, Muscle.arms),
                ex("Burpee", 3, 12, null, Muscle.fullBody),
                ex("Mountain Climber", 3, 30, null, Muscle.core),
                ex("Abdominal Crunch", 3, 20, null, Muscle.core),
            )
            AssistantWorkoutGender.Female to AssistantWorkoutGoalFocus.MuscleGain -> listOf(
                ex("Elevação Pélvica (Hip Thrust)", 4, 12, 40f, Muscle.legs),
                ex("Agachamento Sumô", 4, 12, 40f, Muscle.legs),
                ex("Stiff", 4, 12, 30f, Muscle.legs),
                ex("Afundo Búlgaro", 3, 12, 12f, Muscle.legs),
                ex("Supino Inclinado", 3, 10, 20f, Muscle.chest),
                ex("Puxada Frontal", 3, 12, 30f, Muscle.back),
                ex("Remada Unilateral", 3, 12, 12f, Muscle.back),
                ex("Elevação Lateral", 3, 15, 6f, Muscle.shoulders),
                ex("Rosca Direta", 3, 12, 8f, Muscle.arms),
                ex("Tríceps Pulley", 3, 12, 15f, Muscle.arms),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
            AssistantWorkoutGender.Female to AssistantWorkoutGoalFocus.Endurance -> listOf(
                ex("Agachamento Livre", 3, 15, 30f, Muscle.legs),
                ex("Afundo", 3, 15, 8f, Muscle.legs),
                ex("Elevação Pélvica (Hip Thrust)", 3, 15, 25f, Muscle.legs),
                ex("Flexão de Braços", 3, 10, null, Muscle.chest),
                ex("Puxada Frontal", 3, 15, 25f, Muscle.back),
                ex("Elevação Lateral", 3, 15, 5f, Muscle.shoulders),
                ex("Mountain Climber", 3, 30, null, Muscle.core),
                ex("Bicicleta no Ar", 3, 20, null, Muscle.core),
                ex("Prancha", 3, 40, null, Muscle.core),
            )
            else -> listOf(
                ex("Agachamento Livre", 3, 12, 30f, Muscle.legs),
                ex("Elevação Pélvica (Hip Thrust)", 3, 12, 30f, Muscle.legs),
                ex("Afundo", 3, 12, 8f, Muscle.legs),
                ex("Flexão de Braços", 3, 10, null, Muscle.chest),
                ex("Puxada Frontal", 3, 12, 25f, Muscle.back),
                ex("Elevação Lateral", 3, 12, 5f, Muscle.shoulders),
                ex("Mergulho no Banco", 3, 10, null, Muscle.arms),
                ex("Mountain Climber", 3, 30, null, Muscle.core),
                ex("Abdominal Oblíquo", 3, 20, null, Muscle.core),
            )
        }

    private fun adjust(
        template: WorkoutExercise,
        athlete: AthleteProfile,
        focus: AssistantWorkoutGoalFocus,
        experience: AssistantTrainingExperience,
        location: AssistantTrainingLocation,
        weightKg: Float,
    ): WorkoutExercise {
        var sets = template.sets
        var reps = template.reps
        var rest = template.restSeconds
        var weight = template.weightKg

        if (location == AssistantTrainingLocation.HomeOnly) {
            weight = null
            when (experience) {
                AssistantTrainingExperience.FirstTime -> {
                    rest = min(90, rest + 15)
                    reps = max(8, reps - 2)
                }
                AssistantTrainingExperience.Returning, AssistantTrainingExperience.Beginner -> {
                    rest = min(75, rest + 10)
                }
                AssistantTrainingExperience.Advanced -> {
                    reps = min(30, reps + 4)
                    if (sets < 4) sets += 1
                }
                else -> Unit
            }
            return template.copy(sets = sets, reps = reps, restSeconds = rest, weightKg = weight)
        }

        val weightFactor = min(1.35f, max(0.65f, weightKg / 75f))
        val experienceFactor = when (experience) {
            AssistantTrainingExperience.FirstTime -> 0.40f
            AssistantTrainingExperience.Returning -> 0.50f
            AssistantTrainingExperience.Beginner -> 0.45f
            AssistantTrainingExperience.Intermediate -> 1.0f
            AssistantTrainingExperience.Advanced -> 1.15f
        }
        if (weight != null && weight > 0) {
            var scaled = (weight * weightFactor * experienceFactor)
            when (athlete.bodyType) {
                BodyType.Ectomorph -> scaled *= if (focus == AssistantWorkoutGoalFocus.MuscleGain) 0.9f else 0.95f
                BodyType.Endomorph -> scaled *= if (focus == AssistantWorkoutGoalFocus.FatLoss) 0.95f else 1.05f
                BodyType.Mesomorph -> Unit
            }
            weight = max(2f, scaled.roundToInt().toFloat())
        }
        when (experience) {
            AssistantTrainingExperience.FirstTime -> rest = min(150, rest + 25)
            AssistantTrainingExperience.Returning -> rest = min(140, rest + 15)
            AssistantTrainingExperience.Beginner -> rest = min(130, rest + 10)
            AssistantTrainingExperience.Advanced -> {
                if (sets < 4 && template.muscle in listOf(Muscle.chest, Muscle.back, Muscle.legs)) sets += 1
            }
            else -> Unit
        }
        return template.copy(sets = sets, reps = reps, restSeconds = rest, weightKg = weight)
    }

    private fun parseGender(text: String): AssistantWorkoutGender? {
        val n = norm(text)
        if (n.contains("feminin") || n == "f" || n.contains("mulher")) return AssistantWorkoutGender.Female
        if (n.contains("masculin") || n == "m" || n.contains("homem")) return AssistantWorkoutGender.Male
        return null
    }

    private fun parseHomeOnly(text: String): Boolean? {
        val n = norm(text)
        if (n.contains("sem academia") || n.contains("peso corporal") || n.contains("so em casa") || n.contains("só em casa")) {
            return true
        }
        if (n.contains("casa") && !n.contains("academia")) return true
        if (n.contains("academia") || n.contains("equipamento")) return false
        return null
    }

    private fun parseLevel(text: String): AssistantTrainingExperience? {
        val n = norm(text)
        return when {
            n.contains("avanc") -> AssistantTrainingExperience.Advanced
            n.contains("intermed") -> AssistantTrainingExperience.Intermediate
            n.contains("inici") -> AssistantTrainingExperience.Beginner
            else -> null
        }
    }

    private fun parseFocus(text: String): AssistantWorkoutGoalFocus? {
        val n = norm(text)
        return when {
            n.contains("massa") || n.contains("hipertrof") || n.contains("musculo") -> AssistantWorkoutGoalFocus.MuscleGain
            n.contains("resist") || n.contains("condicionamento") -> AssistantWorkoutGoalFocus.Endurance
            n.contains("gordura") || n.contains("emagrec") || n.contains("definir") || n.contains("perda") || n.contains("secar") ->
                AssistantWorkoutGoalFocus.FatLoss
            else -> null
        }
    }

    private fun parseYesNo(text: String): Boolean? {
        val n = norm(text)
        if (n.startsWith("nao") || n == "n" || n.startsWith("n ") || n.startsWith("n,")) return false
        if (n.startsWith("sim") || n == "s" || n.startsWith("s ") || n.startsWith("s,")) return true
        if (n.contains("ja treino") || n.contains("ja treinei") || n.contains("primeira vez")) {
            if (n.contains("nao") || n.contains("ainda nao")) return false
            if (n.contains("ja treino") || n.contains("primeira vez")) return true
        }
        return null
    }

    private fun isAffirmative(text: String): Boolean {
        val n = norm(text)
        return n.contains("autorizo") || n.startsWith("sim") || n == "s" || n.contains("pode criar") || n.contains("confirmo")
    }

    private fun isNegative(text: String): Boolean {
        val n = norm(text)
        return n.contains("cancel") || n.startsWith("nao") || n == "n"
    }

    private fun norm(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")
            .lowercase()
            .trim()
}

/** Persiste fichas geradas pelo IAssistente (aparecem em Personalizados). */
object AssistantGeneratedWorkouts {
    private const val Prefs = "assistant_workouts.v1"
    private const val KeySheets = "sheets"

    fun add(context: Context, sheet: WorkoutSheet, gender: AssistantWorkoutGender) {
        val all = loadAll(context).toMutableList()
        all.add(0, StoredSheet(gender = gender.name, sheet = sheet))
        save(context, all.take(20))
    }

    fun forGender(context: Context, female: Boolean): List<WorkoutSheet> {
        val want = if (female) AssistantWorkoutGender.Female.name else AssistantWorkoutGender.Male.name
        return loadAll(context).filter { it.gender == want }.map { it.sheet }
    }

    private data class StoredSheet(val gender: String, val sheet: WorkoutSheet)

    private fun loadAll(context: Context): List<StoredSheet> {
        val raw = context.getSharedPreferences(Prefs, Context.MODE_PRIVATE).getString(KeySheets, null)
            ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val exArr = o.getJSONArray("exercises")
                    val exercises = buildList {
                        for (j in 0 until exArr.length()) {
                            val e = exArr.getJSONObject(j)
                            add(
                                WorkoutExercise(
                                    name = e.getString("name"),
                                    sets = e.getInt("sets"),
                                    reps = e.getInt("reps"),
                                    weightKg = if (e.isNull("weightKg")) null else e.getDouble("weightKg").toFloat(),
                                    muscle = runCatching { Muscle.valueOf(e.getString("muscle")) }.getOrDefault(Muscle.fullBody),
                                    restSeconds = e.optInt("restSeconds", 60),
                                ),
                            )
                        }
                    }
                    add(
                        StoredSheet(
                            gender = o.getString("gender"),
                            sheet = WorkoutSheet(
                                title = o.getString("title"),
                                description = o.getString("description"),
                                exercises = exercises,
                            ),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun save(context: Context, sheets: List<StoredSheet>) {
        val arr = JSONArray()
        sheets.forEach { stored ->
            val ex = JSONArray()
            stored.sheet.exercises.forEach { e ->
                ex.put(
                    JSONObject()
                        .put("name", e.name)
                        .put("sets", e.sets)
                        .put("reps", e.reps)
                        .put("weightKg", e.weightKg ?: JSONObject.NULL)
                        .put("muscle", e.muscle.name)
                        .put("restSeconds", e.restSeconds),
                )
            }
            arr.put(
                JSONObject()
                    .put("gender", stored.gender)
                    .put("title", stored.sheet.title)
                    .put("description", stored.sheet.description)
                    .put("exercises", ex),
            )
        }
        context.getSharedPreferences(Prefs, Context.MODE_PRIVATE).edit().putString(KeySheets, arr.toString()).apply()
    }
}
