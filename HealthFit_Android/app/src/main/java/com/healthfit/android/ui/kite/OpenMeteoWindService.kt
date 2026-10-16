package com.healthfit.android.ui.kite

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

object OpenMeteoWindService {

    suspend fun fetch(latitude: Double, longitude: Double, locationLabel: String = "Localização"): Result<WindTideSnapshot> =
        withContext(Dispatchers.IO) {
            runCatching {
                val wind = getJson(forecastUrl(latitude, longitude))
                val marine = runCatching { getJson(marineUrl(latitude, longitude)) }.getOrNull()
                parse(wind, marine, latitude, longitude, locationLabel)
            }
        }

    private fun forecastUrl(lat: Double, lon: Double): String =
        "https://api.open-meteo.com/v1/forecast" +
            "?latitude=$lat&longitude=$lon" +
            "&current=wind_speed_10m,wind_direction_10m,wind_gusts_10m" +
            "&wind_speed_unit=kmh&timezone=auto"

    private fun marineUrl(lat: Double, lon: Double): String =
        "https://marine-api.open-meteo.com/v1/marine" +
            "?latitude=$lat&longitude=$lon" +
            "&current=wave_height,wave_period,sea_level_height_msl" +
            "&hourly=sea_level_height_msl,wave_height,wave_period" +
            "&forecast_days=1&timezone=auto"

    private fun getJson(url: String): JSONObject {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 12_000
            readTimeout = 12_000
            requestMethod = "GET"
        }
        try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = stream.bufferedReader().use { it.readText() }
            if (code !in 200..299) error("HTTP $code")
            return JSONObject(body)
        } finally {
            conn.disconnect()
        }
    }

    private fun parse(
        wind: JSONObject,
        marine: JSONObject?,
        lat: Double,
        lon: Double,
        locationLabel: String,
    ): WindTideSnapshot {
        val current = wind.getJSONObject("current")
        val speed = current.optDouble("wind_speed_10m", 0.0)
        val dir = current.optDouble("wind_direction_10m", 0.0)
        val gusts = current.optDouble("wind_gusts_10m").takeIf { !it.isNaN() && current.has("wind_gusts_10m") }

        var waveH: Double? = null
        var waveP: Double? = null
        var sea: Double? = null
        var hours = emptyList<MarineHourPoint>()
        var extrema = emptyList<TideExtremum>()

        if (marine != null) {
            marine.optJSONObject("current")?.let { c ->
                waveH = c.optDouble("wave_height").takeIf { c.has("wave_height") && !it.isNaN() }
                waveP = c.optDouble("wave_period").takeIf { c.has("wave_period") && !it.isNaN() }
                sea = c.optDouble("sea_level_height_msl").takeIf { c.has("sea_level_height_msl") && !it.isNaN() }
            }
            hours = parseHours(marine)
            extrema = estimateExtrema(hours)
        }

        return WindTideSnapshot(
            latitude = lat,
            longitude = lon,
            locationLabel = locationLabel,
            windSpeedKmh = speed,
            windDirectionDegrees = dir,
            windGustsKmh = gusts,
            waveHeightMeters = waveH,
            wavePeriodSeconds = waveP,
            seaLevelHeightMeters = sea,
            marineHours = hours.take(8),
            tideExtrema = extrema.take(4),
        )
    }

    private fun parseHours(marine: JSONObject): List<MarineHourPoint> {
        val hourly = marine.optJSONObject("hourly") ?: return emptyList()
        val times = hourly.optJSONArray("time") ?: return emptyList()
        val seaArr = hourly.optJSONArray("sea_level_height_msl")
        val waveArr = hourly.optJSONArray("wave_height")
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        val outFmt = SimpleDateFormat("HH:mm", Locale("pt", "BR"))
        val now = System.currentTimeMillis()
        val result = ArrayList<MarineHourPoint>()
        for (i in 0 until times.length()) {
            val t = times.optString(i) ?: continue
            val epoch = runCatching { fmt.parse(t)?.time }.getOrNull() ?: continue
            if (epoch < now - 30 * 60_000L) continue
            val sea = seaArr?.optDouble(i)?.takeIf { !it.isNaN() }
            val wave = waveArr?.optDouble(i)?.takeIf { !it.isNaN() }
            result += MarineHourPoint(
                epochMs = epoch,
                hourLabel = outFmt.format(epoch),
                seaLevelMeters = sea,
                waveHeightMeters = wave,
            )
            if (result.size >= 12) break
        }
        return result
    }

    private fun estimateExtrema(hours: List<MarineHourPoint>): List<TideExtremum> {
        val levels = hours.mapNotNull { h -> h.seaLevelMeters?.let { h.epochMs to it } }
        if (levels.size < 3) return emptyList()
        val out = ArrayList<TideExtremum>()
        for (i in 1 until levels.lastIndex) {
            val prev = levels[i - 1].second
            val cur = levels[i].second
            val next = levels[i + 1].second
            val high = cur >= prev && cur >= next && (abs(cur - prev) > 0.01 || abs(cur - next) > 0.01)
            val low = cur <= prev && cur <= next && (abs(cur - prev) > 0.01 || abs(cur - next) > 0.01)
            if (high || low) {
                out += TideExtremum(high = high, epochMs = levels[i].first, heightMeters = abs(cur))
            }
        }
        return out
    }
}
