package com.healthfit.android.ui.profile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.core.content.FileProvider
import com.google.firebase.auth.FirebaseAuth
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/**
 * Evolução Corporal — fluxo local alinhado ao iOS (ciclo 30 dias, 6 slots, avaliações).
 */
object BodyEvolutionStore {
    private const val Prefs = "healthfit_body_evolution"
    private const val KeyState = "state"
    private const val KeyPendingAssistant = "pendingAssistant"

    fun userId(): String =
        runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull().orEmpty()
            .ifBlank { "local" }

    fun loadMeta(context: Context): BodyEvolutionMeta = loadState(context).meta

    fun loadEvaluations(context: Context): List<BodyEvolutionEvaluation> = loadState(context).evaluations

    fun statusLabel(context: Context): String = loadMeta(context).statusLabel

    fun cyclePhase(context: Context): BodyEvolutionCyclePhase {
        val set = loadMeta(context).activePhotoSet ?: return BodyEvolutionCyclePhase.Empty
        return if (set.isEligibleForComparison()) {
            BodyEvolutionCyclePhase.ReadyToCompare
        } else {
            BodyEvolutionCyclePhase.Waiting(set.daysUntilComparisonEligible())
        }
    }

    fun photoFile(context: Context, setId: String, slot: BodyPhotoSlot): File =
        File(photosDir(context, setId), "${slot.key}.jpg")

    fun loadDraftPaths(context: Context): Map<BodyPhotoSlot, String> {
        val phase = cyclePhase(context)
        if (phase is BodyEvolutionCyclePhase.ReadyToCompare) return emptyMap()
        val set = loadMeta(context).activePhotoSet ?: return emptyMap()
        val result = mutableMapOf<BodyPhotoSlot, String>()
        for (entry in set.photos.filter { it.hasPhoto }) {
            val file = photoFile(context, set.id, entry.slot)
            if (file.exists()) result[entry.slot] = file.absolutePath
        }
        return result
    }

    fun savePickedUri(context: Context, uri: Uri, slot: BodyPhotoSlot, draftDir: File): File {
        draftDir.mkdirs()
        val dest = File(draftDir, "${slot.key}.jpg")
        val bitmap = context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Não foi possível ler a foto." }
            BitmapFactory.decodeStream(input)
        } ?: error("Imagem inválida.")
        val reduced = downsample(bitmap, 1200)
        FileOutputStream(dest).use { out ->
            reduced.compress(Bitmap.CompressFormat.JPEG, 82, out)
        }
        if (reduced !== bitmap) bitmap.recycle()
        return dest
    }

    fun saveBaseline(context: Context, draftPaths: Map<BodyPhotoSlot, String>) {
        val meta = loadMeta(context)
        val active = meta.activePhotoSet
        if (active != null && active.isEligibleForComparison()) {
            error("Já passou o ciclo de 30 dias. Use Comparar evolução.")
        }
        val setId = active?.id ?: UUID.randomUUID().toString()
        val capturedAt = active?.capturedAtMillis ?: System.currentTimeMillis()
        var photoSet = BodyPhotoSet(id = setId, capturedAtMillis = capturedAt)

        for (slot in BodyPhotoSlot.entries) {
            val path = draftPaths[slot] ?: continue
            val src = File(path)
            if (!src.exists()) continue
            val dest = photoFile(context, setId, slot)
            dest.parentFile?.mkdirs()
            src.copyTo(dest, overwrite = true)
            photoSet = photoSet.upsert(BodyPhotoEntry(slot, "${slot.key}.jpg"))
        }

        // Preserva slots já salvos que não foram reenviados.
        active?.photos?.forEach { entry ->
            if (entry.hasPhoto && draftPaths[entry.slot] == null) {
                photoSet = photoSet.upsert(entry)
            }
        }

        persist(context, BodyEvolutionMeta(activePhotoSet = photoSet, lastEvaluationAtMillis = meta.lastEvaluationAtMillis), loadEvaluations(context))
    }

    fun compare(
        context: Context,
        athleteName: String,
        draftPaths: Map<BodyPhotoSlot, String>,
    ): BodyEvolutionComparisonResult {
        val meta = loadMeta(context)
        val previousSet = meta.activePhotoSet ?: error("Inicie o acompanhamento antes de comparar.")
        if (!previousSet.isEligibleForComparison()) {
            error("Aguarde ${previousSet.daysUntilComparisonEligible()} dia(s) para comparar.")
        }

        val previousMeasures = BodyMeasurementsStore.loadPrevious(context)
            ?: BodyMeasurementsStore.loadCurrent(context)
        val currentMeasures = BodyMeasurementsStore.loadCurrent(context)
        val comparison = BodyMeasurementComparison.make(previousMeasures, currentMeasures)

        if (draftPaths.isEmpty() && comparison == null && !currentMeasures.hasAnyValue) {
            error("Atualize as medidas no Perfil ou adicione fotos opcionais para comparar.")
        }

        val previousImages = mutableMapOf<BodyPhotoSlot, String>()
        for (entry in previousSet.photos.filter { it.hasPhoto }) {
            val file = photoFile(context, previousSet.id, entry.slot)
            if (file.exists()) previousImages[entry.slot] = file.absolutePath
        }

        val newSetId = UUID.randomUUID().toString()
        var newSet = BodyPhotoSet(id = newSetId, capturedAtMillis = System.currentTimeMillis())
        val currentImages = mutableMapOf<BodyPhotoSlot, String>()
        for (slot in BodyPhotoSlot.entries) {
            val path = draftPaths[slot] ?: continue
            val src = File(path)
            if (!src.exists()) continue
            val dest = photoFile(context, newSetId, slot)
            dest.parentFile?.mkdirs()
            src.copyTo(dest, overwrite = true)
            currentImages[slot] = dest.absolutePath
            newSet = newSet.upsert(BodyPhotoEntry(slot, "${slot.key}.jpg"))
        }

        val evaluationId = UUID.randomUUID().toString()
        val summary = BodyEvolutionEvaluation.makeSummary(
            comparison = comparison,
            photoCountPrevious = previousSet.filledCount,
            photoCountCurrent = newSet.filledCount,
        )

        var evaluation = BodyEvolutionEvaluation(
            id = evaluationId,
            createdAtMillis = System.currentTimeMillis(),
            previousMeasurements = previousMeasures,
            currentMeasurements = currentMeasures,
            changes = comparison?.changes.orEmpty(),
            periodDays = comparison?.periodDays
                ?: BodyMeasurements.daysBetween(previousSet.capturedAtMillis, newSet.capturedAtMillis),
            previousPhotoSetId = previousSet.id,
            currentPhotoSetId = newSet.id,
            summaryText = summary,
            previousPhotosDeleted = false,
        )

        writePdf(context, evaluation, athleteName)

        // Apaga fotos do baseline anterior (privadas).
        deleteLocalPhotoSet(context, previousSet.id)
        evaluation = evaluation.copy(previousPhotosDeleted = previousSet.filledCount > 0)

        val deletionNotice = if (previousSet.filledCount > 0) {
            "As ${previousSet.filledCount} foto(s) anteriores foram excluídas automaticamente. " +
                "Somente você podia vê-las. Os PDFs das últimas ${BodyEvolutionEvaluation.MAX_RETAINED} avaliações permanecem salvos."
        } else {
            "Avaliação salva sem fotos anteriores. Os PDFs das últimas ${BodyEvolutionEvaluation.MAX_RETAINED} avaliações ficam neste aparelho."
        }

        val evaluations = (listOf(evaluation) + loadEvaluations(context).filter { it.id != evaluation.id })
            .sortedByDescending { it.createdAtMillis }
            .take(BodyEvolutionEvaluation.MAX_RETAINED)

        // Limpa PDFs antigos além do limite.
        val keepIds = evaluations.map { it.id }.toSet()
        pdfDir(context).listFiles()?.forEach { file ->
            val id = file.nameWithoutExtension
            if (id !in keepIds) file.delete()
        }

        persist(
            context,
            BodyEvolutionMeta(activePhotoSet = newSet, lastEvaluationAtMillis = evaluation.createdAtMillis),
            evaluations,
        )

        queueAssistantMessage(context, summary)

        return BodyEvolutionComparisonResult(
            evaluation = evaluation,
            previousImages = previousImages,
            currentImages = currentImages,
            measurementComparison = comparison,
            deletionNotice = deletionNotice,
        )
    }

    fun pdfFile(context: Context, evaluationId: String): File? {
        val file = File(pdfDir(context), "$evaluationId.pdf")
        return file.takeIf { it.exists() }
    }

    fun sharePdfUri(context: Context, evaluationId: String): Uri? {
        val file = pdfFile(context, evaluationId) ?: return null
        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
    }

    fun consumePendingAssistantMessage(context: Context): String? {
        val prefs = prefs(context)
        val msg = prefs.getString(KeyPendingAssistant, null) ?: return null
        prefs.edit().remove(KeyPendingAssistant).apply()
        return msg
    }

    fun draftWorkingDir(context: Context): File =
        File(context.cacheDir, "BodyEvolutionDraft").apply { mkdirs() }

    // region persistence

    private data class LocalState(
        val meta: BodyEvolutionMeta,
        val evaluations: List<BodyEvolutionEvaluation>,
    )

    private fun loadState(context: Context): LocalState {
        val raw = prefs(context).getString(scoped(KeyState), null) ?: return LocalState(BodyEvolutionMeta(), emptyList())
        return runCatching { decodeState(JSONObject(raw)) }.getOrDefault(LocalState(BodyEvolutionMeta(), emptyList()))
    }

    private fun persist(context: Context, meta: BodyEvolutionMeta, evaluations: List<BodyEvolutionEvaluation>) {
        prefs(context).edit().putString(scoped(KeyState), encodeState(meta, evaluations)).apply()
    }

    private fun encodeState(meta: BodyEvolutionMeta, evaluations: List<BodyEvolutionEvaluation>): String {
        val metaObj = JSONObject()
            .put("lastEvaluationAtMillis", meta.lastEvaluationAtMillis ?: JSONObject.NULL)
        meta.activePhotoSet?.let { set ->
            metaObj.put(
                "activePhotoSet",
                JSONObject()
                    .put("id", set.id)
                    .put("capturedAtMillis", set.capturedAtMillis)
                    .put(
                        "photos",
                        JSONArray().also { arr ->
                            set.photos.forEach { entry ->
                                arr.put(
                                    JSONObject()
                                        .put("slot", entry.slot.key)
                                        .put("localFileName", entry.localFileName ?: JSONObject.NULL),
                                )
                            }
                        },
                    ),
            )
        }
        val evalArr = JSONArray()
        evaluations.forEach { e ->
            evalArr.put(
                JSONObject()
                    .put("id", e.id)
                    .put("createdAtMillis", e.createdAtMillis)
                    .put("periodDays", e.periodDays)
                    .put("previousPhotoSetId", e.previousPhotoSetId)
                    .put("currentPhotoSetId", e.currentPhotoSetId)
                    .put("summaryText", e.summaryText)
                    .put("previousPhotosDeleted", e.previousPhotosDeleted)
                    .put("previousMeasurements", encodeMeasures(e.previousMeasurements))
                    .put("currentMeasurements", encodeMeasures(e.currentMeasurements))
                    .put(
                        "changes",
                        JSONArray().also { arr ->
                            e.changes.forEach { c ->
                                arr.put(
                                    JSONObject()
                                        .put("label", c.label)
                                        .put("previous", c.previous)
                                        .put("current", c.current),
                                )
                            }
                        },
                    ),
            )
        }
        return JSONObject().put("meta", metaObj).put("evaluations", evalArr).toString()
    }

    private fun decodeState(o: JSONObject): LocalState {
        val metaObj = o.optJSONObject("meta") ?: JSONObject()
        val setObj = metaObj.optJSONObject("activePhotoSet")
        val set = setObj?.let { decodePhotoSet(it) }
        val meta = BodyEvolutionMeta(
            activePhotoSet = set,
            lastEvaluationAtMillis = metaObj.optLong("lastEvaluationAtMillis")
                .takeIf { metaObj.has("lastEvaluationAtMillis") && !metaObj.isNull("lastEvaluationAtMillis") },
        )
        val evals = mutableListOf<BodyEvolutionEvaluation>()
        val arr = o.optJSONArray("evaluations") ?: JSONArray()
        for (i in 0 until arr.length()) {
            val e = arr.optJSONObject(i) ?: continue
            val changes = mutableListOf<BodyMeasurementChange>()
            val cArr = e.optJSONArray("changes") ?: JSONArray()
            for (j in 0 until cArr.length()) {
                val c = cArr.optJSONObject(j) ?: continue
                changes += BodyMeasurementChange(
                    label = c.optString("label"),
                    previous = c.optDouble("previous"),
                    current = c.optDouble("current"),
                )
            }
            evals += BodyEvolutionEvaluation(
                id = e.optString("id"),
                createdAtMillis = e.optLong("createdAtMillis"),
                previousMeasurements = decodeMeasures(e.optJSONObject("previousMeasurements")),
                currentMeasurements = decodeMeasures(e.optJSONObject("currentMeasurements")),
                changes = changes,
                periodDays = e.optInt("periodDays", 30),
                previousPhotoSetId = e.optString("previousPhotoSetId"),
                currentPhotoSetId = e.optString("currentPhotoSetId"),
                summaryText = e.optString("summaryText"),
                previousPhotosDeleted = e.optBoolean("previousPhotosDeleted"),
            )
        }
        return LocalState(meta, evals)
    }

    private fun decodePhotoSet(o: JSONObject): BodyPhotoSet {
        val photos = mutableListOf<BodyPhotoEntry>()
        val arr = o.optJSONArray("photos") ?: JSONArray()
        for (i in 0 until arr.length()) {
            val p = arr.optJSONObject(i) ?: continue
            val slot = BodyPhotoSlot.fromKey(p.optString("slot")) ?: continue
            val name = p.optString("localFileName").takeIf { it.isNotBlank() && !p.isNull("localFileName") }
            photos += BodyPhotoEntry(slot, name)
        }
        val bySlot = photos.associateBy { it.slot }
        val full = BodyPhotoSlot.entries.map { bySlot[it] ?: BodyPhotoEntry(it) }
        return BodyPhotoSet(
            id = o.optString("id", UUID.randomUUID().toString()),
            capturedAtMillis = o.optLong("capturedAtMillis", System.currentTimeMillis()),
            photos = full,
        )
    }

    private fun encodeMeasures(m: BodyMeasurements): JSONObject =
        JSONObject()
            .put("measuredAtMillis", m.measuredAtMillis ?: JSONObject.NULL)
            .put(
                "valuesCm",
                JSONObject().also { o -> m.valuesCm.forEach { (k, v) -> o.put(k, v) } },
            )

    private fun decodeMeasures(o: JSONObject?): BodyMeasurements {
        if (o == null) return BodyMeasurements.empty
        val valuesObj = o.optJSONObject("valuesCm") ?: JSONObject()
        val values = mutableMapOf<String, Double>()
        valuesObj.keys().forEach { key ->
            val v = valuesObj.optDouble(key, Double.NaN)
            if (!v.isNaN() && v > 0) values[key] = v
        }
        return BodyMeasurements(
            valuesCm = values,
            measuredAtMillis = o.optLong("measuredAtMillis")
                .takeIf { o.has("measuredAtMillis") && !o.isNull("measuredAtMillis") },
        )
    }

    private fun rootDir(context: Context): File =
        File(context.filesDir, "BodyEvolution/${userId()}").apply { mkdirs() }

    private fun photosDir(context: Context, setId: String): File =
        File(rootDir(context), "photos/$setId").apply { mkdirs() }

    private fun pdfDir(context: Context): File =
        File(rootDir(context), "pdfs").apply { mkdirs() }

    private fun deleteLocalPhotoSet(context: Context, setId: String) {
        val dir = File(rootDir(context), "photos/$setId")
        dir.listFiles()?.forEach { it.delete() }
        dir.delete()
    }

    private fun writePdf(context: Context, evaluation: BodyEvolutionEvaluation, athleteName: String) {
        val doc = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = doc.startPage(pageInfo)
        val canvas: Canvas = page.canvas
        val title = Paint().apply {
            textSize = 18f
            isFakeBoldText = true
        }
        val body = Paint().apply { textSize = 11f }
        var y = 48f
        fun line(text: String, paint: Paint = body) {
            val words = text.split(' ')
            var current = ""
            for (w in words) {
                val trial = if (current.isEmpty()) w else "$current $w"
                if (paint.measureText(trial) > 500f) {
                    canvas.drawText(current, 48f, y, paint)
                    y += paint.textSize + 6f
                    current = w
                } else {
                    current = trial
                }
            }
            if (current.isNotEmpty()) {
                canvas.drawText(current, 48f, y, paint)
                y += paint.textSize + 10f
            }
        }
        val df = SimpleDateFormat("dd MMM yyyy HH:mm", Locale("pt", "BR"))
        line("HealthFit — Evolução Corporal", title)
        line("Atleta: ${athleteName.ifBlank { "—" }}")
        line("Avaliação: ${df.format(Date(evaluation.createdAtMillis))}")
        line("Período: ${evaluation.periodDays} dia(s)")
        y += 8f
        line(evaluation.summaryText)
        if (evaluation.changes.isNotEmpty()) {
            y += 8f
            val section = Paint().apply {
                textSize = 14f
                isFakeBoldText = true
            }
            line("Medidas que variaram:", section)
            evaluation.changes.forEach { c ->
                line("${c.label}: ${BodyMeasurements.formatCm(c.previous)} → ${BodyMeasurements.formatCm(c.current)} (${BodyMeasurements.formatDelta(c.delta)})")
            }
        }
        doc.finishPage(page)
        val out = File(pdfDir(context), "${evaluation.id}.pdf")
        FileOutputStream(out).use { doc.writeTo(it) }
        doc.close()
    }

    private fun downsample(src: Bitmap, maxSide: Int): Bitmap {
        val longest = maxOf(src.width, src.height)
        if (longest <= maxSide) return src
        val scale = maxSide.toFloat() / longest
        val w = (src.width * scale).toInt().coerceAtLeast(1)
        val h = (src.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(src, w, h, true)
    }

    private fun queueAssistantMessage(context: Context, summary: String) {
        val message = """
            Sua evolução corporal foi atualizada.

            $summary

            Abra Perfil → Evolução Corporal para ver o comparativo e o PDF da avaliação.
        """.trimIndent()
        prefs(context).edit().putString(KeyPendingAssistant, message).apply()
    }

    private fun scoped(key: String) = "${userId()}.$key"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
