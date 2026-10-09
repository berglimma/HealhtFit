package com.healthfit.android.ui.home

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.healthfit.designsystem.HealthFitColors

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

/** Biotipo e objetivo compartilhados entre Perfil e Nutrição. */
class AthleteProfile {
    var bodyType by mutableStateOf(BodyType.Mesomorph)
    var objective by mutableStateOf("Perda de Gordura")
    var heightCm by mutableStateOf("176")
}
