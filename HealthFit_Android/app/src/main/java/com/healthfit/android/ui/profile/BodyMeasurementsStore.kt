package com.healthfit.android.ui.profile

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject

/**
 * Medidas corporais do Perfil — usadas no comparativo de Evolução Corporal (igual iOS).
 */
object BodyMeasurementsStore {
    private const val Prefs = "healthfit_body_measures"
    private const val KeyCurrent = "current"
    private const val KeyPrevious = "previous"

    fun userId(): String =
        runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull().orEmpty()
            .ifBlank { "local" }

    fun loadCurrent(context: Context): BodyMeasurements =
        decode(prefs(context).getString(scoped(KeyCurrent), null))

    fun loadPrevious(context: Context): BodyMeasurements? {
        val raw = prefs(context).getString(scoped(KeyPrevious), null) ?: return null
        return decode(raw).takeIf { it.hasAnyValue }
    }

    fun saveCurrent(context: Context, map: Map<String, String>) {
        val prev = loadCurrent(context)
        val values = BodyMeasurements.fieldLabels.associateWith { label ->
            map[label]?.replace(',', '.')?.toDoubleOrNull()?.takeIf { it > 0 }
        }.filterValues { it != null }.mapValues { it.value!! }

        val next = BodyMeasurements(
            valuesCm = values,
            measuredAtMillis = System.currentTimeMillis(),
        )

        // Snapshot anterior quando já havia medidas e passou o intervalo (ou primeira troca).
        if (prev.hasAnyValue) {
            val due = prev.measuredAtMillis?.let {
                BodyMeasurements.daysBetween(it) >= BodyMeasurements.COMPARISON_INTERVAL_DAYS
            } == true
            if (due || loadPrevious(context) == null) {
                prefs(context).edit().putString(scoped(KeyPrevious), encode(prev)).apply()
            }
        }

        prefs(context).edit().putString(scoped(KeyCurrent), encode(next)).apply()
    }

    fun asEditableMap(context: Context): MutableMap<String, String> {
        val current = loadCurrent(context)
        return BodyMeasurements.fieldLabels.associateWith { label ->
            current.valuesCm[label]?.let { v ->
                if (v == v.toLong().toDouble()) v.toLong().toString() else "%.1f".format(v)
            }.orEmpty()
        }.toMutableMap()
    }

    private fun scoped(key: String) = "${userId()}.$key"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)

    private fun encode(m: BodyMeasurements): String =
        JSONObject()
            .put("measuredAtMillis", m.measuredAtMillis ?: JSONObject.NULL)
            .put(
                "valuesCm",
                JSONObject().also { o ->
                    m.valuesCm.forEach { (k, v) -> o.put(k, v) }
                },
            )
            .toString()

    private fun decode(raw: String?): BodyMeasurements {
        if (raw.isNullOrBlank()) return BodyMeasurements.empty
        return runCatching {
            val o = JSONObject(raw)
            val valuesObj = o.optJSONObject("valuesCm") ?: JSONObject()
            val values = mutableMapOf<String, Double>()
            valuesObj.keys().forEach { key ->
                val v = valuesObj.optDouble(key, Double.NaN)
                if (!v.isNaN() && v > 0) values[key] = v
            }
            BodyMeasurements(
                valuesCm = values,
                measuredAtMillis = o.optLong("measuredAtMillis").takeIf { o.has("measuredAtMillis") && !o.isNull("measuredAtMillis") },
            )
        }.getOrDefault(BodyMeasurements.empty)
    }
}
