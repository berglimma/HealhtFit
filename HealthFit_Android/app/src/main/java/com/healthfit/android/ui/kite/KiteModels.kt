package com.healthfit.android.ui.kite

enum class KiteEquipmentType(val title: String, val detail: String) {
    TubeKite("Tube Kite", "Clássica com infláveis — freeride e Big Air"),
    FoilKite("Foil Kite", "Leve, bom em vento fraco e foiling"),
    Hybrid("Hybrid", "Compromisso tube + foil"),
    Trainer("Trainer / 2-linhas", "Aprendizado e treino em terra / água controlada"),
}

enum class KiteRidingMode(val title: String, val detail: String) {
    BigAir("Big Air", "Altitude e tempo de ar — foco em saltos"),
    Speed("Speed", "Velocidade máxima e percursos longos"),
    Coaching("Coaching", "Sessão instructiva, ritmo controlado"),
    Downwind("Downwind", "Saída longe do ponto, percurso a favor do vento"),
}

enum class WaterBoard(val title: String, val detail: String, val kite: Boolean) {
    Shortboard("Shortboard", "Performance e manobras", false),
    Longboard("Longboard", "Estabilidade e nose riders", false),
    Fish("Fish", "Ondas pequenas e velocidade", false),
    Funboard("Funboard", "Transição intermediária", false),
    SoftTop("Soft top / escola", "Iniciante e segurança", false),
    TwinTip("Twin Tip", "Freeride e saltos simétricos", true),
    Directional("Directional / Surfboard", "Ondas e rides direcionais", true),
    FoilBoard("Foil Board", "Voo acima da água (hydrofoil)", true),
    Strapless("Strapless", "Surf kite sem straps", true),
    ;

    companion object {
        val kiteBoards get() = entries.filter { it.kite }
        val surfBoards get() = entries.filter { !it.kite }
    }
}

data class WaterSpotInfo(
    val name: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val hasCoordinates: Boolean get() = latitude != null && longitude != null
}

data class MarineHourPoint(
    val epochMs: Long,
    val hourLabel: String,
    val seaLevelMeters: Double?,
    val waveHeightMeters: Double?,
)

data class TideExtremum(
    val high: Boolean,
    val epochMs: Long,
    val heightMeters: Double,
) {
    val kindLabel: String get() = if (high) "Preamar (est.)" else "Baixamar (est.)"
}

data class WindTideSnapshot(
    val latitude: Double,
    val longitude: Double,
    val locationLabel: String,
    val windSpeedKmh: Double,
    val windDirectionDegrees: Double,
    val windGustsKmh: Double?,
    val waveHeightMeters: Double?,
    val wavePeriodSeconds: Double?,
    val seaLevelHeightMeters: Double?,
    val marineHours: List<MarineHourPoint>,
    val tideExtrema: List<TideExtremum>,
    val fetchedAtMs: Long = System.currentTimeMillis(),
) {
    val windLabel: String get() = WindDirectionLabels.label(windDirectionDegrees)

    val estimatedPhaseLabel: String?
        get() {
            val levels = marineHours.mapNotNull { h -> h.seaLevelMeters?.let { h.epochMs to it } }
            if (levels.size < 2) return null
            val delta = levels[1].second - levels[0].second
            if (kotlin.math.abs(delta) < 0.01) return null
            return if (delta > 0) "Enchente (est.)" else "Vazante (est.)"
        }

    val estimatedTideLabel: String
        get() {
            tideExtrema.firstOrNull()?.let { next ->
                val time = android.text.format.DateFormat.format("HH:mm", next.epochMs)
                return "${next.kindLabel} ~$time"
            }
            if (seaLevelHeightMeters != null || marineHours.isNotEmpty()) {
                estimatedPhaseLabel?.let { return "$it · Nível do mar (estimado)" }
                return "Nível do mar (estimado)"
            }
            return "Não informado"
        }

    val displayTideHeightMeters: Double?
        get() = seaLevelHeightMeters?.let { kotlin.math.abs(it) }
            ?: tideExtrema.firstOrNull()?.heightMeters

    fun beachSportMessage(isKitesurf: Boolean): String {
        val wind = windSpeedKmh
        return when {
            isKitesurf && wind in 15.0..42.0 -> "Vento bom para kitesurf · ${wind.toInt()} km/h $windLabel"
            isKitesurf && wind < 15 -> "Vento fraco para kite · ${wind.toInt()} km/h"
            isKitesurf && wind > 42 -> "Vento forte — avalie com cuidado · ${wind.toInt()} km/h"
            !isKitesurf && (waveHeightMeters ?: 0.0) in 0.5..2.8 -> "Ondas favoráveis para surf"
            else -> "Condições: ${wind.toInt()} km/h $windLabel · $estimatedTideLabel"
        }
    }

    fun favorabilityLabel(isKitesurf: Boolean): String {
        val windOk = windSpeedKmh in 15.0..42.0
        val gustOk = windGustsKmh == null || (windGustsKmh - windSpeedKmh) < 18
        val midTide = estimatedPhaseLabel != null
        return when {
            isKitesurf && windOk && gustOk -> "Maré favorável"
            isKitesurf && windOk -> "Condições moderadas"
            midTide && !isKitesurf -> "Condições moderadas"
            windSpeedKmh <= 0 -> "Sem leitura de maré"
            else -> "Menos favorável"
        }
    }
}

object WindDirectionLabels {
    private val labels = listOf("N", "NE", "L", "SE", "S", "SO", "O", "NO")

    fun label(degrees: Double): String {
        val idx = (((degrees % 360) + 360) % 360 / 45.0).toInt() % 8
        return labels[idx]
    }
}

data class KiteSessionSetup(
    val equipment: KiteEquipmentType = KiteEquipmentType.TubeKite,
    val ridingMode: KiteRidingMode = KiteRidingMode.BigAir,
    val board: WaterBoard = WaterBoard.TwinTip,
    val spot: WaterSpotInfo = WaterSpotInfo(),
    val spotBuddyEnabled: Boolean = false,
    val windSummary: String = "",
    val tideSummary: String = "",
) {
    fun detailLine(minutes: Int): String = buildList {
        add(equipment.title)
        add(ridingMode.title)
        add(board.title)
        if (spot.name.isNotBlank()) add(spot.name)
        if (windSummary.isNotBlank()) add(windSummary)
        if (tideSummary.isNotBlank()) add(tideSummary)
        add("$minutes min")
    }.joinToString(" · ")
}

data class SurfSessionSetup(
    val board: WaterBoard = WaterBoard.Shortboard,
    val spot: WaterSpotInfo = WaterSpotInfo(),
    val windSummary: String = "",
    val tideSummary: String = "",
) {
    fun detailLine(minutes: Int): String = buildList {
        add(board.title)
        if (spot.name.isNotBlank()) add(spot.name)
        if (windSummary.isNotBlank()) add(windSummary)
        if (tideSummary.isNotBlank()) add(tideSummary)
        add("$minutes min")
    }.joinToString(" · ")
}
