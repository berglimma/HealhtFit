package com.healthfit.android.ui.nutrition

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector
import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.SweetConsumptionLevel
import kotlin.math.max
import kotlin.math.roundToInt

data class PlannedMeal(
    val id: String,
    val slot: String,
    val title: String,
    val kcal: Int,
    val proteinG: Int,
    val carbsG: Int,
    val fatG: Int,
    val icon: ImageVector,
) {
    val kcalLabel: String get() = "$kcal kcal"
    val macrosLabel: String get() = "P:${proteinG}g C:${carbsG}g G:${fatG}g"
}

data class MealPlanOption(
    val name: String,
    val subtitle: String,
    val meals: List<PlannedMeal>,
) {
    val totalCalories: Int get() = meals.sumOf { it.kcal }
    val totalProtein: Int get() = meals.sumOf { it.proteinG }
}

data class DailyMealPlan(
    val dayOfWeek: String,
    val options: List<MealPlanOption>,
)

data class WeeklyMealPlan(
    val calorieTarget: Int,
    val days: List<DailyMealPlan>,
) {
    fun day(index: Int): DailyMealPlan? = days.getOrNull(index)
}

/**
 * Cardápio semanal local — espelha iOS MealPlanService.buildWeeklyPlan
 * (dias + Simples / Opção 2 / Opção 3 / Meu Cardápio).
 */
object MealPlanGenerator {

    private data class Template(
        val slot: String,
        val name: String,
        val calories: Int,
        val protein: Int,
        val carbs: Int,
        val fat: Int,
        val containsLactose: Boolean = false,
        val isSweet: Boolean = false,
        val fatLoss: Boolean = false,
        val share: Double,
        val icon: ImageVector,
        val isFasting: Boolean = false,
    )

    private val weekDays = listOf(
        "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo",
    )

    /** Slots alinhados ao iOS `MealType.planSlots` (inclui Jejum). */
    private val slots = listOf(
        "Café da Manhã",
        "Colação",
        "Almoço",
        "Lanche da Tarde",
        "Jantar",
        "Jejum",
    )

    private val catalog: List<Template> = listOf(
        Template("Café da Manhã", "Simples — ovos, pão e banana", 380, 24, 42, 12, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Omelete Proteico", 380, 30, 22, 16, containsLactose = true, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Aveia com Frutas", 360, 14, 58, 8, containsLactose = true, isSweet = true, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Panqueca de Banana", 340, 18, 42, 10, isSweet = true, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Pão com Ovo e Abacate", 400, 22, 35, 18, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Crepioca de Frango", 390, 34, 28, 12, fatLoss = true, share = 0.22, icon = Icons.Filled.WbSunny),
        Template("Café da Manhã", "Claras com Vegetais", 320, 36, 18, 8, fatLoss = true, share = 0.22, icon = Icons.Filled.WbSunny),

        Template("Colação", "Simples — banana e ovos", 220, 14, 24, 8, share = 0.10, icon = Icons.Filled.Spa),
        Template("Colação", "Maçã com Pasta de Amendoim", 250, 8, 27, 12, isSweet = true, share = 0.10, icon = Icons.Filled.Spa),
        Template("Colação", "Shake de Whey", 220, 28, 18, 4, containsLactose = true, isSweet = true, share = 0.10, icon = Icons.Filled.Spa),
        Template("Colação", "Iogurte com Castanhas", 200, 15, 14, 10, containsLactose = true, share = 0.10, icon = Icons.Filled.Spa),
        Template("Colação", "Kiwi com Castanhas", 170, 4, 22, 8, isSweet = true, fatLoss = true, share = 0.10, icon = Icons.Filled.Spa),
        Template("Colação", "Atum com Torrada", 210, 22, 16, 6, fatLoss = true, share = 0.10, icon = Icons.Filled.Spa),

        Template("Almoço", "Simples — arroz, feijão e frango", 560, 46, 58, 12, share = 0.32, icon = Icons.Filled.WbSunny),
        Template("Almoço", "Frango com Arroz e Brócolis", 560, 48, 58, 12, share = 0.32, icon = Icons.Filled.WbSunny),
        Template("Almoço", "Carne Magra com Feijão Light", 580, 52, 42, 18, fatLoss = true, share = 0.32, icon = Icons.Filled.WbSunny),
        Template("Almoço", "Peixe com Quinoa", 520, 44, 48, 14, fatLoss = true, share = 0.32, icon = Icons.Filled.WbSunny),
        Template("Almoço", "Bowl de Carne e Feijão", 600, 46, 62, 16, share = 0.32, icon = Icons.Filled.WbSunny),
        Template("Almoço", "Tilápia com Salada e Batata Doce", 480, 42, 40, 12, fatLoss = true, share = 0.32, icon = Icons.Filled.WbSunny),

        Template("Lanche da Tarde", "Simples — pão com ovo", 230, 16, 26, 8, share = 0.12, icon = Icons.Filled.Spa),
        Template("Lanche da Tarde", "Tapioca com Queijo", 250, 13, 30, 8, containsLactose = true, share = 0.12, icon = Icons.Filled.Spa),
        Template("Lanche da Tarde", "Wrap de Frango", 280, 26, 28, 8, share = 0.12, icon = Icons.Filled.Spa),
        Template("Lanche da Tarde", "Iogurte de Coco com Fruta", 200, 6, 22, 10, isSweet = true, share = 0.12, icon = Icons.Filled.Spa),
        Template("Lanche da Tarde", "Ovo cozido e Cenoura", 180, 14, 10, 8, fatLoss = true, share = 0.12, icon = Icons.Filled.Spa),

        Template("Jantar", "Simples — arroz, frango e legumes", 480, 42, 44, 12, share = 0.24, icon = Icons.Filled.NightsStay),
        Template("Jantar", "Atum com Salada", 420, 40, 18, 14, fatLoss = true, share = 0.24, icon = Icons.Filled.NightsStay),
        Template("Jantar", "Frango Grelhado com Legumes", 450, 44, 28, 12, fatLoss = true, share = 0.24, icon = Icons.Filled.NightsStay),
        Template("Jantar", "Omelete de Claras com Salada", 320, 36, 12, 10, fatLoss = true, share = 0.24, icon = Icons.Filled.NightsStay),
        Template("Jantar", "Carne Moída com Purê Light", 520, 40, 42, 16, share = 0.24, icon = Icons.Filled.NightsStay),

        Template(
            "Jejum", "Jejum", 0, 0, 0, 0,
            share = 0.0, icon = Icons.Filled.Timer, isFasting = true,
        ),
    )

    fun generateWeekly(
        calorieTarget: Int,
        athlete: AthleteProfile,
        seed: Int = 0,
    ): WeeklyMealPlan {
        val target = calorieTarget.coerceIn(1200, 4500)
        val fatLoss = athlete.objective.contains("Gordura", ignoreCase = true) ||
            athlete.objective.contains("Perda", ignoreCase = true)
        val optionTemplates = if (fatLoss) {
            listOf(
                "Simples" to "Alimentos básicos",
                "Opção 2" to "Low carb restrito",
                "Opção 3" to "Leve e saciante",
            )
        } else {
            listOf(
                "Simples" to "Alimentos básicos",
                "Opção 2" to "Equilibrado",
                "Opção 3" to "Prático e leve",
            )
        }

        val days = weekDays.mapIndexed { dayIndex, dayName ->
            val recommended = optionTemplates.mapIndexed { optionIndex, (name, subtitle) ->
                val variation = if (optionIndex == 0) seed else seed + dayIndex + optionIndex
                MealPlanOption(
                    name = name,
                    subtitle = subtitle,
                    meals = mealsForDay(
                        calorieTarget = target,
                        athlete = athlete,
                        variation = variation,
                        dayIndex = dayIndex,
                        optionIndex = optionIndex,
                    ),
                )
            }
            val custom = MealPlanOption(
                name = "Meu Cardápio",
                subtitle = "Montado por você",
                meals = mealsForDay(
                    calorieTarget = target,
                    athlete = athlete,
                    variation = seed + dayIndex + 10,
                    dayIndex = dayIndex,
                    optionIndex = 3,
                ),
            )
            DailyMealPlan(dayOfWeek = dayName, options = recommended + custom)
        }
        return WeeklyMealPlan(calorieTarget = target, days = days)
    }

    /** Compat: um dia (hoje) com a opção Simples. */
    fun generate(
        calorieTarget: Int,
        athlete: AthleteProfile,
        variation: Int = 0,
    ): List<PlannedMeal> =
        generateWeekly(calorieTarget, athlete, variation).days.first().options.first().meals

    private fun mealsForDay(
        calorieTarget: Int,
        athlete: AthleteProfile,
        variation: Int,
        dayIndex: Int,
        optionIndex: Int,
    ): List<PlannedMeal> {
        val fatLoss = athlete.objective.contains("Gordura", ignoreCase = true) ||
            athlete.objective.contains("Perda", ignoreCase = true)
        val muscle = athlete.objective.contains("Massa", ignoreCase = true)
        val proteinMul = if (muscle) 1.15 else 1.0
        val lactoseOk = athlete.lactoseTolerant
        val sweet = athlete.sweetConsumption

        return slots.mapIndexed { slotIndex, slot ->
            val options = catalog
                .filter { it.slot == slot }
                .filter { lactoseOk || !it.containsLactose }
                .let { list ->
                    when (sweet) {
                        SweetConsumptionLevel.Low -> {
                            val savory = list.filter { !it.isSweet }
                            val sweets = list.filter { it.isSweet }.take(if (fatLoss) 0 else 1)
                            savory + sweets
                        }
                        SweetConsumptionLevel.Moderate -> list
                        SweetConsumptionLevel.High -> list.filter { it.isSweet } + list.filter { !it.isSweet }
                    }
                }
                .let { list ->
                    if (fatLoss) {
                        val focused = list.filter { it.fatLoss || it.isFasting }
                        val rest = list.filter { !it.fatLoss && !it.isFasting }
                        (focused + rest).ifEmpty { list }
                    } else {
                        list
                    }
                }
                .ifEmpty { catalog.filter { it.slot == slot } }

            val pick = options[(variation + slotIndex) % options.size]
            if (pick.isFasting) {
                return@mapIndexed PlannedMeal(
                    id = "$dayIndex-$optionIndex-$slot",
                    slot = slot,
                    title = pick.name,
                    kcal = 0,
                    proteinG = 0,
                    carbsG = 0,
                    fatG = 0,
                    icon = pick.icon,
                )
            }
            val mealTarget = max((calorieTarget * pick.share).roundToInt(), 120)
            scale(pick, mealTarget, proteinMul, "$dayIndex-$optionIndex-$slot")
        }
    }

    private fun scale(
        template: Template,
        targetKcal: Int,
        proteinMul: Double,
        id: String,
    ): PlannedMeal {
        val base = template.calories.coerceAtLeast(1)
        val factor = targetKcal.toDouble() / base.toDouble()
        return PlannedMeal(
            id = id,
            slot = template.slot,
            title = template.name,
            kcal = targetKcal,
            proteinG = (template.protein * factor * proteinMul).roundToInt().coerceAtLeast(1),
            carbsG = (template.carbs * factor).roundToInt().coerceAtLeast(0),
            fatG = (template.fat * factor).roundToInt().coerceAtLeast(0),
            icon = template.icon,
        )
    }
}
