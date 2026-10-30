package com.healthfit.android.ui.profile

import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.max

enum class BodyPhotoSlot(val key: String, val title: String) {
    Front("front", "Frente"),
    Back("back", "Costas"),
    LeftSide("leftSide", "Lado esquerdo"),
    RightSide("rightSide", "Lado direito"),
    Abdomen("abdomen", "Abdômen"),
    Extra("extra", "Extra");

    companion object {
        fun fromKey(key: String): BodyPhotoSlot? = entries.firstOrNull { it.key == key }
    }
}

data class BodyPhotoEntry(
    val slot: BodyPhotoSlot,
    val localFileName: String? = null,
) {
    val hasPhoto: Boolean get() = !localFileName.isNullOrBlank()
}

data class BodyPhotoSet(
    val id: String = UUID.randomUUID().toString(),
    val capturedAtMillis: Long = System.currentTimeMillis(),
    val photos: List<BodyPhotoEntry> = BodyPhotoSlot.entries.map { BodyPhotoEntry(it) },
) {
    val filledCount: Int get() = photos.count { it.hasPhoto }
    val hasAnyPhoto: Boolean get() = filledCount > 0

    fun entry(slot: BodyPhotoSlot): BodyPhotoEntry? = photos.firstOrNull { it.slot == slot }

    fun upsert(entry: BodyPhotoEntry): BodyPhotoSet {
        val next = photos.toMutableList()
        val idx = next.indexOfFirst { it.slot == entry.slot }
        if (idx >= 0) next[idx] = entry else next.add(entry)
        return copy(photos = next)
    }

    fun daysUntilComparisonEligible(now: Long = System.currentTimeMillis()): Int {
        val elapsed = BodyMeasurements.daysBetween(capturedAtMillis, now)
        return max(BodyMeasurements.COMPARISON_INTERVAL_DAYS - elapsed, 0)
    }

    fun isEligibleForComparison(now: Long = System.currentTimeMillis()): Boolean =
        BodyMeasurements.daysBetween(capturedAtMillis, now) >= BodyMeasurements.COMPARISON_INTERVAL_DAYS
}

data class BodyEvolutionMeta(
    val activePhotoSet: BodyPhotoSet? = null,
    val lastEvaluationAtMillis: Long? = null,
) {
    val statusLabel: String
        get() {
            val set = activePhotoSet ?: return "Inicie o acompanhamento (fotos opcionais e privadas)."
            if (set.isEligibleForComparison()) {
                return if (set.hasAnyPhoto) {
                    "Pronto para nova comparação (30 dias concluídos)."
                } else {
                    "Pronto para comparar medidas (30 dias concluídos). Fotos continuam opcionais."
                }
            }
            val remaining = set.daysUntilComparisonEligible()
            val photoNote = if (set.hasAnyPhoto) {
                "${set.filledCount} foto(s) privadas salvas. "
            } else {
                "Sem fotos neste lote (opcional). "
            }
            return "${photoNote}Próxima comparação em $remaining dia(s)."
        }
}

data class BodyMeasurementChange(
    val label: String,
    val previous: Double,
    val current: Double,
) {
    val delta: Double get() = current - previous
    val id: String get() = label
}

data class BodyMeasurements(
    val valuesCm: Map<String, Double> = emptyMap(),
    val measuredAtMillis: Long? = null,
) {
    val hasAnyValue: Boolean get() = valuesCm.values.any { it > 0 }

    companion object {
        const val COMPARISON_INTERVAL_DAYS = 30
        val empty = BodyMeasurements()

        val fieldLabels = listOf(
            "Pescoço", "Ombros", "Peito", "Braço direito", "Braço esquerdo",
            "Cintura", "Abdômen", "Quadril",
            "Coxa direita", "Coxa esquerda", "Panturrilha direita", "Panturrilha esquerda",
        )

        fun daysBetween(fromMillis: Long, toMillis: Long = System.currentTimeMillis()): Int {
            val diff = abs(toMillis - fromMillis)
            return TimeUnit.MILLISECONDS.toDays(diff).toInt()
        }

        fun formatCm(value: Double): String =
            if (value == value.toLong().toDouble()) "${value.toLong()} cm" else "%.1f cm".format(value)

        fun formatDelta(delta: Double): String {
            val sign = if (delta > 0) "+" else ""
            return if (delta == delta.toLong().toDouble()) {
                "$sign${delta.toLong()} cm"
            } else {
                "$sign%.1f cm".format(delta)
            }
        }

        fun changes(from: BodyMeasurements, to: BodyMeasurements): List<BodyMeasurementChange> {
            return fieldLabels.mapNotNull { label ->
                val prev = from.valuesCm[label] ?: return@mapNotNull null
                val curr = to.valuesCm[label] ?: return@mapNotNull null
                if (abs(curr - prev) < 0.05) return@mapNotNull null
                BodyMeasurementChange(label, prev, curr)
            }
        }
    }
}

data class BodyMeasurementComparison(
    val previous: BodyMeasurements,
    val current: BodyMeasurements,
    val periodDays: Int,
    val changes: List<BodyMeasurementChange>,
) {
    companion object {
        fun make(previous: BodyMeasurements, current: BodyMeasurements): BodyMeasurementComparison? {
            if (!previous.hasAnyValue && !current.hasAnyValue) return null
            val from = previous.measuredAtMillis
            val to = current.measuredAtMillis
            val period = when {
                from != null && to != null -> BodyMeasurements.daysBetween(from, to)
                from != null -> BodyMeasurements.daysBetween(from)
                else -> BodyMeasurements.COMPARISON_INTERVAL_DAYS
            }
            return BodyMeasurementComparison(
                previous = previous,
                current = current,
                periodDays = period.coerceAtLeast(1),
                changes = BodyMeasurements.changes(previous, current),
            )
        }
    }
}

data class BodyEvolutionEvaluation(
    val id: String = UUID.randomUUID().toString(),
    val createdAtMillis: Long = System.currentTimeMillis(),
    val previousMeasurements: BodyMeasurements = BodyMeasurements.empty,
    val currentMeasurements: BodyMeasurements = BodyMeasurements.empty,
    val changes: List<BodyMeasurementChange> = emptyList(),
    val periodDays: Int = BodyMeasurements.COMPARISON_INTERVAL_DAYS,
    val previousPhotoSetId: String = "",
    val currentPhotoSetId: String = "",
    val summaryText: String = "",
    val previousPhotosDeleted: Boolean = false,
) {
    companion object {
        const val MAX_RETAINED = 4

        fun makeSummary(
            comparison: BodyMeasurementComparison?,
            photoCountPrevious: Int,
            photoCountCurrent: Int,
        ): String {
            val lines = mutableListOf<String>()
            if (comparison != null) {
                lines += "Comparativo de ${comparison.periodDays} dia(s)."
                if (comparison.changes.isEmpty()) {
                    lines += "Nenhuma circunferência variou de forma mensurável."
                } else {
                    comparison.changes
                        .sortedByDescending { abs(it.delta) }
                        .take(4)
                        .forEach { change ->
                            lines += "${change.label}: ${BodyMeasurements.formatCm(change.previous)} → ${BodyMeasurements.formatCm(change.current)} (${BodyMeasurements.formatDelta(change.delta)})."
                        }
                }
            } else {
                lines += "Comparação registrada. Atualize as medidas no Perfil para um relatório educativo mais completo."
            }
            lines += "Fotos: $photoCountPrevious → $photoCountCurrent (envio opcional e privado)."
            lines += if (photoCountPrevious > 0) {
                "As fotos anteriores foram excluídas após a comparação. Os PDFs das últimas $MAX_RETAINED avaliações permanecem salvos (somente você acessa)."
            } else {
                "Nenhuma foto anterior para excluir. Os PDFs das últimas $MAX_RETAINED avaliações permanecem salvos (somente você acessa)."
            }
            return lines.joinToString(" ")
        }
    }
}

sealed class BodyEvolutionCyclePhase {
    data object Empty : BodyEvolutionCyclePhase()
    data class Waiting(val daysRemaining: Int) : BodyEvolutionCyclePhase()
    data object ReadyToCompare : BodyEvolutionCyclePhase()
}

data class BodyEvolutionComparisonResult(
    val evaluation: BodyEvolutionEvaluation,
    val previousImages: Map<BodyPhotoSlot, String>,
    val currentImages: Map<BodyPhotoSlot, String>,
    val measurementComparison: BodyMeasurementComparison?,
    val deletionNotice: String,
)
