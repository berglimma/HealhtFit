package com.healthfit.android.ui.home

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.healthfit.android.R
import java.io.File
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Vídeo da retrospectiva do mês já encerrado.
 * Usa só as fotos locais do calendário Constância. Não grava nada no Firebase.
 * Duração máxima: 75 segundos.
 */
object MonthlyRetrospective {
    const val MAX_SECONDS = 75
    private const val FPS = 10
    private const val WIDTH = 720
    private const val HEIGHT = 1280

    private val phrases = listOf(
        "Cada treino contou.",
        "Você apareceu. Isso muda tudo.",
        "Constância é o seu diferencial.",
        "O corpo lembra o que você repetiu.",
        "Um dia de cada vez, o mês inteiro.",
        "Disciplina virou resultado.",
        "Você não pulou o dia difícil.",
        "A evolução está nessas fotos.",
        "Orgulho do caminho, não só da chegada.",
        "Força se constrói quando ninguém vê.",
        "Sua presença foi o treino mais importante.",
        "O mês ficou marcado na Constância.",
    )

    private val restPhrases = listOf(
        "Descansar também é treinar.",
        "O corpo cresce no descanso.",
        "Recuperação faz parte da constância.",
        "Você respeitou o limite.",
        "Superação inclui saber parar.",
        "O próximo treino agradece essa pausa.",
    )

    data class Video(
        val file: File,
        val monthLabel: String,
        val nextMonthLabel: String,
        val workoutCount: Int,
        val photoCount: Int,
    )

    fun finishedMonth(now: YearMonth = YearMonth.now()): YearMonth = now.minusMonths(1)

    fun finishedMonthLabel(now: YearMonth = YearMonth.now()): String = label(finishedMonth(now))

    fun render(context: Context, month: YearMonth = finishedMonth()): Video {
        val next = month.plusMonths(1)
        val monthLabel = label(month)
        val nextLabel = label(next)
        val sessions = sessionsIn(context, month)
        val photos = sessions.mapNotNull { session ->
            val path = session.photoPath ?: return@mapNotNull null
            val image = decodePhoto(path) ?: return@mapNotNull null
            Photo(
                image,
                session.title.ifBlank { "Treino" },
                dayLabel(session.endedAtMillis),
                ConstancyStore.dayKey(session.endedAtMillis),
            )
        }
        val monthPrefix = "%04d-%02d".format(java.util.Locale.US, month.year, month.monthValue)
        val restDays = ConstancyStore.loadRestDays(context)
            .filter { it.startsWith(monthPrefix) }
            .sorted()
        val slides = storyboard(
            context = context,
            monthLabel = monthLabel,
            nextLabel = nextLabel,
            workoutCount = sessions.size,
            photos = photos,
            restDays = restDays,
        )
        val frames = slides.sumOf { it.second }
        check(frames <= MAX_SECONDS * FPS) { "A retrospectiva passou de 75 segundos." }
        val dir = File(context.cacheDir, "retrospective").apply { mkdirs() }
        val file = File(dir, "HealthFit-Retrospectiva-${month.year}-${month.monthValue}.mp4")
        val upright = slides.map { (bitmap, frames) -> flipVertical(bitmap) to frames }
        FlyoverVideo.encodeHeldFrames(file, upright, FPS)
        photos.forEach { runCatching { it.bitmap.recycle() } }
        return Video(file, monthLabel, nextLabel, sessions.size, photos.size)
    }

    fun share(context: Context, video: Video) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", video.file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Retrospectiva HealthFit · ${video.monthLabel}")
            putExtra(
                Intent.EXTRA_TEXT,
                "Retrospectiva HealthFit de ${video.monthLabel}. Superação para ${video.nextMonthLabel}.",
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, "Compartilhar retrospectiva")
        if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
    }

    private data class Photo(val bitmap: Bitmap, val title: String, val day: String, val dayKey: String)

    private sealed class Moment {
        abstract val sortKey: String

        data class Shot(val photo: Photo) : Moment() {
            override val sortKey: String = photo.dayKey
        }

        data class Rest(val dayKey: String, val label: String) : Moment() {
            override val sortKey: String = dayKey
        }
    }

    private fun sessionsIn(context: Context, month: YearMonth): List<ConstancySession> {
        val cal = Calendar.getInstance()
        return ConstancyStore.loadSessions(context)
            .filter { session ->
                cal.timeInMillis = session.endedAtMillis
                cal.get(Calendar.YEAR) == month.year &&
                    cal.get(Calendar.MONTH) == month.monthValue - 1
            }
            .sortedBy { it.endedAtMillis }
    }

    private fun storyboard(
        context: Context,
        monthLabel: String,
        nextLabel: String,
        workoutCount: Int,
        photos: List<Photo>,
        restDays: List<String>,
    ): List<Pair<Bitmap, Int>> {
        val introFrames = 4 * FPS
        val outroFrames = 6 * FPS
        val budget = MAX_SECONDS * FPS - introFrames - outroFrames
        val heart = BitmapFactory.decodeResource(context.resources, R.drawable.brandheart)
        val slides = ArrayList<Pair<Bitmap, Int>>()
        slides += drawIntro(heart, monthLabel, workoutCount, photos.size, restDays.size) to introFrames
        val moments = buildList {
            photos.forEach { add(Moment.Shot(it)) }
            restDays.forEach { key -> add(Moment.Rest(key, dayLabelFromKey(key))) }
        }.sortedBy { it.sortKey }
        if (moments.isEmpty()) {
            val phraseFrames = (4 * FPS).coerceAtMost(budget / 4)
            phrases.take(4).forEachIndexed { index, phrase ->
                slides += drawPhrase(heart, phrase, index + 1) to phraseFrames
            }
        } else {
            val room = (budget / FPS).coerceAtLeast(1)
            val shots = moments.filterIsInstance<Moment.Shot>()
            val rests = moments.filterIsInstance<Moment.Rest>()
            val chosen = when {
                moments.size <= room -> moments
                shots.size >= room -> sample(shots, room)
                else -> {
                    val restKeep = sample(rests, room - shots.size).map { it.sortKey }.toSet()
                    moments.filter { it is Moment.Shot || (it is Moment.Rest && it.sortKey in restKeep) }
                }
            }
            val per = (budget / chosen.size).coerceAtLeast(1)
            chosen.forEachIndexed { index, moment ->
                val bitmap = when (moment) {
                    is Moment.Shot -> drawPhoto(heart, moment.photo, phrases[index % phrases.size])
                    is Moment.Rest -> drawRest(
                        context,
                        heart,
                        moment.label,
                        restPhrases[index % restPhrases.size],
                        index,
                    )
                }
                slides += bitmap to per
            }
        }
        slides += drawOutro(heart, monthLabel, nextLabel) to outroFrames
        return slides
    }

    private fun drawIntro(heart: Bitmap?, month: String, workouts: Int, photos: Int, restDays: Int): Bitmap {
        val bitmap = canvasBitmap()
        val canvas = Canvas(bitmap)
        paintBackground(canvas)
        drawHeart(canvas, heart, 390f, 220)
        var y = 640f
        y = drawCentered(canvas, "HEALTHFIT", titlePaint(34f, accent()), y)
        y = drawCentered(canvas, "RETROSPECTIVA", titlePaint(54f, Color.WHITE), y + 28f)
        y = drawCentered(canvas, month, bodyPaint(32f, Color.WHITE), y + 18f)
        y = drawCentered(canvas, count(workouts, "treino", "treinos"), bodyPaint(28f, muted()), y + 36f)
        val photoLine = if (photos == 0) {
            "Sem fotos neste mês"
        } else {
            count(photos, "foto na Constância", "fotos na Constância")
        }
        val restLine = if (restDays == 0) "Nenhum dia de descanso" else count(restDays, "dia de descanso", "dias de descanso")
        y = drawCentered(canvas, photoLine, bodyPaint(26f, accent()), y + 12f)
        drawCentered(canvas, restLine, bodyPaint(26f, Color.parseColor("#7DDCB4")), y + 10f)
        return bitmap
    }

    private fun drawPhoto(heart: Bitmap?, photo: Photo, phrase: String): Bitmap {
        val bitmap = canvasBitmap()
        val canvas = Canvas(bitmap)
        drawCover(canvas, photo.bitmap)
        val scrim = Paint().apply {
            shader = LinearGradient(
                0f,
                HEIGHT * 0.42f,
                0f,
                HEIGHT.toFloat(),
                Color.TRANSPARENT,
                Color.parseColor("#F0071018"),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, HEIGHT * 0.42f, WIDTH.toFloat(), HEIGHT.toFloat(), scrim)
        val top = Paint().apply {
            shader = LinearGradient(
                0f,
                0f,
                0f,
                280f,
                Color.parseColor("#CC071018"),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, WIDTH.toFloat(), 280f, top)
        drawMark(canvas, heart, 48f, 56f, 72)
        drawCentered(canvas, photo.day, bodyPaint(22f, muted()), 980f)
        drawCentered(canvas, photo.title, titlePaint(36f, Color.WHITE), 1020f)
        drawCentered(canvas, phrase, titlePaint(40f, Color.WHITE), 1110f)
        return bitmap
    }

    private val restCovers = intArrayOf(
        R.drawable.meditacaocoverrecuperacao,
        R.drawable.meditacaocoverrelaxamento,
        R.drawable.meditacaocoversono,
        R.drawable.meditacaocoverrespiracao,
    )

    private fun drawRest(context: Context, heart: Bitmap?, day: String, phrase: String, coverIndex: Int): Bitmap {
        val bitmap = canvasBitmap()
        val canvas = Canvas(bitmap)
        val cover = BitmapFactory.decodeResource(
            context.resources,
            restCovers[coverIndex % restCovers.size],
        )
        if (cover != null) {
            drawCover(canvas, cover)
            if (!cover.isRecycled) cover.recycle()
        } else {
            paintBackground(canvas)
        }
        val scrim = Paint().apply {
            shader = LinearGradient(
                0f,
                HEIGHT * 0.28f,
                0f,
                HEIGHT.toFloat(),
                Color.TRANSPARENT,
                Color.parseColor("#F0071018"),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, HEIGHT * 0.28f, WIDTH.toFloat(), HEIGHT.toFloat(), scrim)
        val top = Paint().apply {
            shader = LinearGradient(
                0f,
                0f,
                0f,
                280f,
                Color.parseColor("#CC071018"),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, WIDTH.toFloat(), 280f, top)
        drawHeart(canvas, heart, 280f, 180)
        var y = 500f
        y = drawCentered(canvas, "HEALTHFIT", titlePaint(28f, accent()), y)
        y = drawCentered(canvas, "DIA DE DESCANSO", titlePaint(44f, Color.WHITE), y + 20f)
        y = drawCentered(canvas, day, bodyPaint(28f, Color.WHITE), y + 12f)
        drawCentered(canvas, phrase, titlePaint(34f, Color.WHITE), y + 28f)
        return bitmap
    }

    private fun drawPhrase(heart: Bitmap?, phrase: String, index: Int): Bitmap {
        val bitmap = canvasBitmap()
        val canvas = Canvas(bitmap)
        paintBackground(canvas)
        drawHeart(canvas, heart, 430f, 180)
        drawCentered(canvas, "HEALTHFIT", titlePaint(28f, accent()), 660f)
        drawCentered(canvas, phrase, titlePaint(48f, Color.WHITE), 760f)
        drawCentered(canvas, "Constância  ·  $index", bodyPaint(24f, muted()), 1040f)
        return bitmap
    }

    private fun drawOutro(heart: Bitmap?, month: String, next: String): Bitmap {
        val bitmap = canvasBitmap()
        val canvas = Canvas(bitmap)
        paintBackground(canvas)
        drawHeart(canvas, heart, 340f, 240)
        var y = 620f
        y = drawCentered(canvas, "HEALTHFIT", titlePaint(36f, accent()), y)
        y = drawCentered(canvas, "SUPERAÇÃO", titlePaint(58f, Color.WHITE), y + 36f)
        y = drawCentered(canvas, "para $next", bodyPaint(32f, Color.WHITE), y + 16f)
        drawCentered(
            canvas,
            "Vá além do que você fez em $month.",
            bodyPaint(28f, muted()),
            y + 48f,
        )
        return bitmap
    }

    private fun flipVertical(source: Bitmap): Bitmap {
        val matrix = Matrix().apply { postScale(1f, -1f, source.width / 2f, source.height / 2f) }
        val flipped = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        if (flipped != source) source.recycle()
        return flipped
    }

    private fun canvasBitmap() = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)

    private fun paintBackground(canvas: Canvas) {
        canvas.drawColor(Color.parseColor("#071018"))
    }

    private fun drawHeart(canvas: Canvas, heart: Bitmap?, top: Float, size: Int) {
        if (heart == null) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent() }
            canvas.drawCircle(WIDTH / 2f, top + size / 2f, size / 2f, paint)
            return
        }
        val left = (WIDTH - size) / 2f
        canvas.drawBitmap(heart, null, RectF(left, top, left + size, top + size), Paint(Paint.FILTER_BITMAP_FLAG))
    }

    private fun drawMark(canvas: Canvas, heart: Bitmap?, left: Float, top: Float, size: Int) {
        heart?.let {
            canvas.drawBitmap(it, null, RectF(left, top, left + size, top + size), Paint(Paint.FILTER_BITMAP_FLAG))
        }
        val paint = titlePaint(26f, Color.WHITE).apply { textAlign = Paint.Align.LEFT }
        canvas.drawText("HEALTHFIT", left + size + 16f, top + size * 0.68f, paint)
    }

    private fun drawCover(canvas: Canvas, photo: Bitmap) {
        val scale = max(WIDTH.toFloat() / photo.width, HEIGHT.toFloat() / photo.height)
        val w = photo.width * scale
        val h = photo.height * scale
        val left = (WIDTH - w) / 2f
        val top = (HEIGHT - h) / 2f
        canvas.drawBitmap(
            photo,
            null,
            RectF(left, top, left + w, top + h),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
    }

    private fun drawCentered(canvas: Canvas, text: String, paint: TextPaint, top: Float): Float {
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, WIDTH - 96)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setIncludePad(false)
            .build()
        canvas.save()
        canvas.translate(48f, top)
        layout.draw(canvas)
        canvas.restore()
        return top + layout.height
    }

    private fun titlePaint(size: Float, color: Int) = textPaint(size, color, bold = true)

    private fun bodyPaint(size: Float, color: Int) = textPaint(size, color, bold = false)

    private fun textPaint(size: Float, color: Int, bold: Boolean) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        this.color = color
        textAlign = Paint.Align.LEFT
        typeface = if (bold) Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD) else Typeface.SANS_SERIF
    }

    private fun accent() = Color.parseColor("#3DDC3A")

    private fun muted() = Color.parseColor("#B7C0C8")

    private fun label(month: YearMonth): String {
        val locale = Locale.forLanguageTag("pt-BR")
        val formatted = month.atDay(1).format(DateTimeFormatter.ofPattern("MMMM 'de' yyyy", locale))
        return formatted.replaceFirstChar { char ->
            if (char.isLowerCase()) char.titlecase(locale) else char.toString()
        }
    }

    private fun dayLabelFromKey(dayKey: String): String {
        val parsed = runCatching {
            java.time.LocalDate.parse(dayKey)
        }.getOrNull() ?: return dayKey
        return parsed.format(java.time.format.DateTimeFormatter.ofPattern("d 'de' MMMM", Locale.forLanguageTag("pt-BR")))
    }

    private fun dayLabel(millis: Long): String {
        val cal = Calendar.getInstance()
        cal.timeInMillis = millis
        val fmt = java.text.SimpleDateFormat("d 'de' MMMM", Locale.forLanguageTag("pt-BR"))
        return fmt.format(cal.time)
    }

    private fun count(value: Int, one: String, many: String): String =
        if (value == 1) "1 $one" else "$value $many"

    private fun decodePhoto(path: String): Bitmap? {
        if (!File(path).exists()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / sample > 1600 || bounds.outHeight / sample > 1600) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(path, options)
    }

    private fun <T> sample(items: List<T>, limit: Int): List<T> {
        if (items.size <= limit || limit <= 0) return items
        if (limit == 1) return listOf(items[items.size / 2])
        return (0 until limit).map { index ->
            val position = index.toDouble() * (items.size - 1) / (limit - 1)
            items[position.roundToInt()]
        }
    }
}
