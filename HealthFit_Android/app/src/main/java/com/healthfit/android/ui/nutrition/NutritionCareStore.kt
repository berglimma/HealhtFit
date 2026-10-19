package com.healthfit.android.ui.nutrition

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class NutritionAnamnesis(
    val chiefComplaint: String = "",
    val medicalHistory: String = "",
    val medications: String = "",
    val allergies: String = "",
    val surgeries: String = "",
    val familyHistory: String = "",
    val digestiveIssues: String = "",
    val waterIntakeLiters: Double = 2.0,
    val alcoholUse: String = "",
    val smoking: String = "Não",
    val physicalActivity: String = "",
    val stressLevel: Int = 5,
    val sleepHours: Double = 7.0,
    val bowelFunction: String = "",
    val menstrualNotes: String = "",
    val foodAversions: String = "",
    val eatingOutFrequency: String = "",
    val supplementsInUse: String = "",
    val previousDiets: String = "",
    val notes: String = "",
    val updatedAtMillis: Long = 0L,
) {
    val completionPercent: Int
        get() {
            val fields = listOf(
                chiefComplaint, medicalHistory, medications, allergies, surgeries,
                familyHistory, digestiveIssues, alcoholUse, smoking, physicalActivity,
                bowelFunction, foodAversions, eatingOutFrequency, previousDiets,
            )
            val filled = fields.count { it.trim().isNotEmpty() }
            return ((filled.toDouble() / fields.size) * 100).toInt()
        }
}

enum class NutritionQuestionnaireKind(
    val id: String,
    val title: String,
    val detail: String,
    val questions: List<Pair<String, String>>,
) {
    HealthGeneral(
        "healthGeneral",
        "Questionário de saúde",
        "Histórico clínico, sintomas e medicamentos.",
        listOf(
            "q1" to "Possui alguma condição de saúde já acompanhada por um médico?",
            "q2" to "Usa medicamentos contínuos? Quais?",
            "q3" to "Tem alergias alimentares ou medicamentosas?",
            "q4" to "Já fez exames recentes (glicemia, lipídios, TSH)?",
            "q5" to "Há sintomas gastrointestinais frequentes?",
        ),
    ),
    MetabolicTracking(
        "metabolicTracking",
        "Rastreamento metabólico",
        "Energia, fome, retenção e sinais metabólicos.",
        listOf(
            "m1" to "Como está sua energia ao longo do dia?",
            "m2" to "Sente fome excessiva ou queda de energia após comer?",
            "m3" to "Há retenção de líquido ou inchaço?",
            "m4" to "Como está o funcionamento intestinal?",
            "m5" to "Percebe sudorese, palpitações ou frio nas extremidades?",
        ),
    ),
    EatingPattern(
        "eatingPattern",
        "Padrão alimentar",
        "Horários, porções e frequência de refeições.",
        listOf(
            "e1" to "Quantas refeições faz por dia?",
            "e2" to "Costuma pular café da manhã ou jantar?",
            "e3" to "Come fora de casa com que frequência?",
            "e4" to "Há horários irregulares de alimentação?",
            "e5" to "Consome doces ou ultraprocessados com que frequência?",
        ),
    ),
    SleepType(
        "sleepType",
        "Tipo de sono",
        "Qualidade, duração e rotina de sono.",
        listOf(
            "s1" to "Quantas horas dorme por noite, em média?",
            "s2" to "Tem dificuldade para dormir ou acordar?",
            "s3" to "Usa telas perto da hora de dormir?",
            "s4" to "Acorda descansado na maior parte dos dias?",
            "s5" to "Ronca ou suspeita de apneia do sono?",
        ),
    ),
    HydrationHabits(
        "hydrationHabits",
        "Hidratação e hábitos",
        "Água, café, álcool e líquidos no dia.",
        listOf(
            "h1" to "Quantos litros de água bebe por dia?",
            "h2" to "Quantas xícaras de café/chá com cafeína?",
            "h3" to "Consome bebidas alcoólicas? Com que frequência?",
            "h4" to "Bebe refrigerante ou suco industrializado?",
            "h5" to "Sente sede com frequência ao longo do dia?",
        ),
    ),
    EmotionalEating(
        "emotionalEating",
        "Fome emocional",
        "Gatilhos emocionais e compulsão alimentar.",
        listOf(
            "x1" to "Come por ansiedade, estresse ou tédio?",
            "x2" to "Há episódios de compulsão alimentar?",
            "x3" to "Come à noite sem fome física?",
            "x4" to "Associa comida a recompensa ou conforto?",
            "x5" to "Já tentou estratégias para lidar com gatilhos emocionais?",
        ),
    );

    companion object {
        fun fromId(id: String): NutritionQuestionnaireKind =
            entries.firstOrNull { it.id == id } ?: HealthGeneral
    }
}

data class NutritionQuestionnaireResponse(
    val kindId: String,
    val answers: Map<String, String> = emptyMap(),
    val updatedAtMillis: Long = 0L,
) {
    fun answeredCount(kind: NutritionQuestionnaireKind): Int =
        kind.questions.count { (qid, _) -> answers[qid].orEmpty().trim().isNotEmpty() }

    fun isComplete(kind: NutritionQuestionnaireKind): Boolean =
        answeredCount(kind) >= kind.questions.size
}

enum class NutritionGoalStatus(val title: String) {
    Active("Ativa"),
    Completed("Concluída"),
    Paused("Pausada"),
}

data class NutritionGoal(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val detail: String = "",
    val status: NutritionGoalStatus = NutritionGoalStatus.Active,
    val authorIsCoach: Boolean = false,
    val syncedWithCoach: Boolean = false,
    val createdAtMillis: Long = System.currentTimeMillis(),
    val updatedAtMillis: Long = System.currentTimeMillis(),
)

data class NutritionCheckIn(
    val id: String = UUID.randomUUID().toString(),
    val dateMillis: Long = System.currentTimeMillis(),
    val weightKg: Double? = null,
    val adherence: Int = 3,
    val hunger: Int = 3,
    val energy: Int = 3,
    val notes: String = "",
)

data class NutritionCareBundle(
    val anamnesis: NutritionAnamnesis = NutritionAnamnesis(),
    val questionnaires: List<NutritionQuestionnaireResponse> = emptyList(),
    val goals: List<NutritionGoal> = emptyList(),
    val checkIns: List<NutritionCheckIn> = emptyList(),
)

/**
 * Local nutrition care store (anamnese, questionários, metas, check-in).
 * Mirrors iOS NutritionCareStore; cloud publish stays behind Coach write gates.
 */
object NutritionCareStore {
    private const val Prefs = "nutrition_care.v1"
    private const val KeyBundle = "bundle"

    fun loadBundle(context: Context): NutritionCareBundle {
        val prefs = prefs(context)
        val raw = prefs.getString(KeyBundle, null)
        if (raw != null) {
            return runCatching { decodeBundle(JSONObject(raw)) }.getOrDefault(legacyAnamnesisOnly(prefs))
        }
        return legacyAnamnesisOnly(prefs)
    }

    fun loadAnamnesis(context: Context): NutritionAnamnesis = loadBundle(context).anamnesis

    fun saveAnamnesis(context: Context, anamnesis: NutritionAnamnesis) {
        val bundle = loadBundle(context)
        saveBundle(
            context,
            bundle.copy(anamnesis = anamnesis.copy(updatedAtMillis = System.currentTimeMillis())),
        )
    }

    fun responseFor(context: Context, kind: NutritionQuestionnaireKind): NutritionQuestionnaireResponse {
        val found = loadBundle(context).questionnaires.firstOrNull { it.kindId == kind.id }
        return found ?: NutritionQuestionnaireResponse(kindId = kind.id)
    }

    fun upsertQuestionnaire(context: Context, response: NutritionQuestionnaireResponse) {
        val bundle = loadBundle(context)
        val stamped = response.copy(updatedAtMillis = System.currentTimeMillis())
        val others = bundle.questionnaires.filterNot { it.kindId == stamped.kindId }
        saveBundle(context, bundle.copy(questionnaires = others + stamped))
    }

    fun addGoal(context: Context, goal: NutritionGoal) {
        val bundle = loadBundle(context)
        saveBundle(context, bundle.copy(goals = listOf(goal) + bundle.goals))
    }

    fun updateGoal(context: Context, goal: NutritionGoal) {
        val bundle = loadBundle(context)
        val stamped = goal.copy(updatedAtMillis = System.currentTimeMillis())
        saveBundle(
            context,
            bundle.copy(goals = bundle.goals.map { if (it.id == stamped.id) stamped else it }),
        )
    }

    fun deleteGoal(context: Context, id: String) {
        val bundle = loadBundle(context)
        saveBundle(context, bundle.copy(goals = bundle.goals.filterNot { it.id == id }))
    }

    fun addCheckIn(context: Context, checkIn: NutritionCheckIn) {
        val bundle = loadBundle(context)
        saveBundle(context, bundle.copy(checkIns = listOf(checkIn) + bundle.checkIns))
    }

    fun markGoalsSynced(context: Context) {
        val bundle = loadBundle(context)
        saveBundle(
            context,
            bundle.copy(goals = bundle.goals.map { it.copy(syncedWithCoach = true) }),
        )
    }

    private fun saveBundle(context: Context, bundle: NutritionCareBundle) {
        prefs(context).edit()
            .putString(KeyBundle, encodeBundle(bundle).toString())
            .putString("anamnesis", encodeAnamnesis(bundle.anamnesis).toString())
            .apply()
    }

    private fun legacyAnamnesisOnly(prefs: android.content.SharedPreferences): NutritionCareBundle {
        val raw = prefs.getString("anamnesis", null) ?: return NutritionCareBundle()
        val anamnesis = runCatching { decodeAnamnesis(JSONObject(raw)) }.getOrDefault(NutritionAnamnesis())
        return NutritionCareBundle(anamnesis = anamnesis)
    }

    private fun encodeBundle(b: NutritionCareBundle) = JSONObject()
        .put("anamnesis", encodeAnamnesis(b.anamnesis))
        .put(
            "questionnaires",
            JSONArray().also { arr ->
                b.questionnaires.forEach { q ->
                    arr.put(
                        JSONObject()
                            .put("kindId", q.kindId)
                            .put("updatedAtMillis", q.updatedAtMillis)
                            .put(
                                "answers",
                                JSONObject().also { ao ->
                                    q.answers.forEach { (k, v) -> ao.put(k, v) }
                                },
                            ),
                    )
                }
            },
        )
        .put(
            "goals",
            JSONArray().also { arr ->
                b.goals.forEach { g ->
                    arr.put(
                        JSONObject()
                            .put("id", g.id)
                            .put("title", g.title)
                            .put("detail", g.detail)
                            .put("status", g.status.name)
                            .put("authorIsCoach", g.authorIsCoach)
                            .put("syncedWithCoach", g.syncedWithCoach)
                            .put("createdAtMillis", g.createdAtMillis)
                            .put("updatedAtMillis", g.updatedAtMillis),
                    )
                }
            },
        )
        .put(
            "checkIns",
            JSONArray().also { arr ->
                b.checkIns.forEach { c ->
                    arr.put(
                        JSONObject()
                            .put("id", c.id)
                            .put("dateMillis", c.dateMillis)
                            .put("weightKg", c.weightKg ?: JSONObject.NULL)
                            .put("adherence", c.adherence)
                            .put("hunger", c.hunger)
                            .put("energy", c.energy)
                            .put("notes", c.notes),
                    )
                }
            },
        )

    private fun decodeBundle(o: JSONObject): NutritionCareBundle {
        val anamnesis = decodeAnamnesis(o.optJSONObject("anamnesis") ?: JSONObject())
        val questionnaires = buildList {
            val arr = o.optJSONArray("questionnaires") ?: JSONArray()
            for (i in 0 until arr.length()) {
                val q = arr.optJSONObject(i) ?: continue
                val answersObj = q.optJSONObject("answers") ?: JSONObject()
                val answers = buildMap {
                    answersObj.keys().forEach { key -> put(key, answersObj.optString(key)) }
                }
                add(
                    NutritionQuestionnaireResponse(
                        kindId = q.optString("kindId"),
                        answers = answers,
                        updatedAtMillis = q.optLong("updatedAtMillis"),
                    ),
                )
            }
        }
        val goals = buildList {
            val arr = o.optJSONArray("goals") ?: JSONArray()
            for (i in 0 until arr.length()) {
                val g = arr.optJSONObject(i) ?: continue
                val status = runCatching {
                    NutritionGoalStatus.valueOf(g.optString("status", "Active"))
                }.getOrDefault(NutritionGoalStatus.Active)
                add(
                    NutritionGoal(
                        id = g.optString("id").ifBlank { UUID.randomUUID().toString() },
                        title = g.optString("title"),
                        detail = g.optString("detail"),
                        status = status,
                        authorIsCoach = g.optBoolean("authorIsCoach"),
                        syncedWithCoach = g.optBoolean("syncedWithCoach"),
                        createdAtMillis = g.optLong("createdAtMillis"),
                        updatedAtMillis = g.optLong("updatedAtMillis"),
                    ),
                )
            }
        }
        val checkIns = buildList {
            val arr = o.optJSONArray("checkIns") ?: JSONArray()
            for (i in 0 until arr.length()) {
                val c = arr.optJSONObject(i) ?: continue
                val weight = if (c.isNull("weightKg")) null else c.optDouble("weightKg")
                add(
                    NutritionCheckIn(
                        id = c.optString("id").ifBlank { UUID.randomUUID().toString() },
                        dateMillis = c.optLong("dateMillis"),
                        weightKg = weight,
                        adherence = c.optInt("adherence", 3),
                        hunger = c.optInt("hunger", 3),
                        energy = c.optInt("energy", 3),
                        notes = c.optString("notes"),
                    ),
                )
            }
        }
        return NutritionCareBundle(
            anamnesis = anamnesis,
            questionnaires = questionnaires,
            goals = goals,
            checkIns = checkIns,
        )
    }

    private fun encodeAnamnesis(a: NutritionAnamnesis) = JSONObject()
        .put("chiefComplaint", a.chiefComplaint)
        .put("medicalHistory", a.medicalHistory)
        .put("medications", a.medications)
        .put("allergies", a.allergies)
        .put("surgeries", a.surgeries)
        .put("familyHistory", a.familyHistory)
        .put("digestiveIssues", a.digestiveIssues)
        .put("waterIntakeLiters", a.waterIntakeLiters)
        .put("alcoholUse", a.alcoholUse)
        .put("smoking", a.smoking)
        .put("physicalActivity", a.physicalActivity)
        .put("stressLevel", a.stressLevel)
        .put("sleepHours", a.sleepHours)
        .put("bowelFunction", a.bowelFunction)
        .put("menstrualNotes", a.menstrualNotes)
        .put("foodAversions", a.foodAversions)
        .put("eatingOutFrequency", a.eatingOutFrequency)
        .put("supplementsInUse", a.supplementsInUse)
        .put("previousDiets", a.previousDiets)
        .put("notes", a.notes)
        .put("updatedAtMillis", a.updatedAtMillis)

    private fun decodeAnamnesis(o: JSONObject) = NutritionAnamnesis(
        chiefComplaint = o.optString("chiefComplaint"),
        medicalHistory = o.optString("medicalHistory"),
        medications = o.optString("medications"),
        allergies = o.optString("allergies"),
        surgeries = o.optString("surgeries"),
        familyHistory = o.optString("familyHistory"),
        digestiveIssues = o.optString("digestiveIssues"),
        waterIntakeLiters = o.optDouble("waterIntakeLiters", 2.0),
        alcoholUse = o.optString("alcoholUse"),
        smoking = o.optString("smoking").ifBlank { "Não" },
        physicalActivity = o.optString("physicalActivity"),
        stressLevel = o.optInt("stressLevel", 5),
        sleepHours = o.optDouble("sleepHours", 7.0),
        bowelFunction = o.optString("bowelFunction"),
        menstrualNotes = o.optString("menstrualNotes"),
        foodAversions = o.optString("foodAversions"),
        eatingOutFrequency = o.optString("eatingOutFrequency"),
        supplementsInUse = o.optString("supplementsInUse"),
        previousDiets = o.optString("previousDiets"),
        notes = o.optString("notes"),
        updatedAtMillis = o.optLong("updatedAtMillis"),
    )

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
