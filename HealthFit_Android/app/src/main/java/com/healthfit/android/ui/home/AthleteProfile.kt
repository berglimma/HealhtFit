package com.healthfit.android.ui.home

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.healthfit.designsystem.HealthFitColors

/** Consumo de doces — espelha iOS `SweetConsumptionLevel`. */
enum class SweetConsumptionLevel(
    val title: String,
    val detail: String,
    val warning: String?,
    val warningColor: Color,
) {
    Low(
        title = "Pouco",
        detail = "Priorizamos opções com pouco açúcar e frutas no lugar de doces.",
        warning = null,
        warningColor = Color.Transparent,
    ),
    Moderate(
        title = "Moderado",
        detail = "Cardápio equilibrado com doces ocasionais.",
        warning = "Atenção: consumo moderado de doces pode elevar o açúcar diário acima do recomendado. Prefira frutas, limite sobremesas a poucos dias na semana e evite açúcar em excesso em bebidas e lanches.",
        warningColor = Color(0xFFFF9A3C),
    ),
    High(
        title = "Muito",
        detail = "Incluímos sobremesas e lanches doces — acompanhe as porções.",
        warning = "Atenção: consumo elevado de doces aumenta o risco de ganho de gordura, picos de glicemia, inflamação e compulsão alimentar. A OMS recomenda que açúcares livres fiquem abaixo de 10% das calorias diárias — o ideal é manter em torno de 5%.",
        warningColor = Color(0xFFFF4D4D),
    ),
}

enum class BodyType(
    val title: String,
    val summary: String,
    val detail: String,
    val accent: Color,
) {
    Ectomorph(
        "Ectomorfo",
        "Corpo magro, ombros e quadris estreitos, pulsos e tornozelos finos. Ganha pouco…",
        "Ombros e quadris estreitos, metabolismo acelerado. O cardápio prioriza energia e proteína em todas as refeições.",
        Color(0xFF4DA3FF),
    ),
    Mesomorph(
        "Mesomorfo",
        "Ombros largos, cintura marcada e estrutura atlética. Ganha músculo e perde gordura…",
        "Ombros largos, cintura marcada e estrutura atlética. Ganha músculo e perde gordura com relativa facilidade.",
        HealthFitColors.Accent,
    ),
    Endomorph(
        "Endomorfo",
        "Estrutura mais arredondada, acumula gordura com facilidade (cintura e quadril)…",
        "Estrutura mais arredondada. O plano reduz ultraprocessados e mantém a proteína alta.",
        Color(0xFFFF9A3C),
    ),
}

/** Biotipo, objetivo e preferências de Nutrição compartilhados com o IAssistente. */
class AthleteProfile {
    var bodyType by mutableStateOf(BodyType.Mesomorph)
    var objective by mutableStateOf("Perda de Gordura")
    var heightCm by mutableStateOf("176")
    var lactoseTolerant by mutableStateOf(true)
    var sweetConsumption by mutableStateOf(SweetConsumptionLevel.Moderate)
}
