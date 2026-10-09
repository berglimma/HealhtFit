package com.healthfit.android.ui.home

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.healthfit.android.R
import java.io.File
import java.io.FileOutputStream

object ShareCardImage {
    fun render(context: Context, session: FinishedWorkout): Bitmap {
        val width = 1080
        val height = 1920
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.parseColor("#0E1113"))
        val cover = BitmapFactory.decodeResource(context.resources, session.coverRes)
        if (cover != null) {
            canvas.drawBitmap(cover, null, Rect(0, 0, width, 1180), Paint(Paint.ANTI_ALIAS_FLAG))
        }
        val shade = Paint().apply {
            shader = LinearGradient(
                0f, 700f, 0f, 1180f,
                Color.TRANSPARENT,
                Color.parseColor("#0E1113"),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 700f, width.toFloat(), 1180f, shade)
        val title = text(64f, Color.WHITE, true)
        val body = text(36f, Color.parseColor("#D5DDE3"))
        val accent = text(34f, Color.parseColor("#3DDC3A"), true)
        canvas.drawText("HEALTHFIT", 72f, 1280f, accent)
        wrap(canvas, session.title, title, 72f, 1380f, width - 144)
        canvas.drawText(session.durationMinutes, 72f, 1680f, text(72f, Color.WHITE, true))
        val kcal = session.calories?.let { " · $it kcal" }.orEmpty()
        canvas.drawText(session.whenLabel + kcal, 72f, 1760f, body)
        canvas.drawText(session.motivation, 72f, 1840f, body)
        return bitmap
    }

    fun stampPhoto(context: Context, uri: Uri, session: FinishedWorkout): Bitmap {
        val source = context.contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
            ?: error("Não foi possível ler a foto.")
        val stamped = stampBitmap(context, source, session)
        if (stamped != source) source.recycle()
        return stamped
    }

    fun stampBitmap(context: Context, source: Bitmap, session: FinishedWorkout): Bitmap {
        val width = 1080
        val height = 1920
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawBitmap(source, null, Rect(0, 0, width, height), Paint(Paint.ANTI_ALIAS_FLAG))
        val shade = Paint().apply {
            shader = LinearGradient(
                0f, height * 0.42f, 0f, height.toFloat(),
                Color.TRANSPARENT,
                Color.parseColor("#F20E1113"),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, height * 0.42f, width.toFloat(), height.toFloat(), shade)
        val logoSize = 72
        val brandTop = (height * 0.10f).toInt()
        val logo = BitmapFactory.decodeResource(context.resources, R.drawable.brandheart)
        if (logo != null) {
            canvas.drawBitmap(
                logo,
                null,
                Rect(64, brandTop, 64 + logoSize, brandTop + logoSize),
                Paint(Paint.ANTI_ALIAS_FLAG),
            )
            logo.recycle()
        }
        canvas.drawText("HealthFit", 156f, brandTop + 50f, text(40f, Color.WHITE, true))
        val titlePaint = text(52f, Color.WHITE, true)
        val titleLines = wrappedLines(session.title, titlePaint, width - 144).take(2)
        val stats = session.shareStats()
        var y = height - 120f - titleLines.size * 64f - 52f - 88f
        titleLines.forEach { line ->
            canvas.drawText(line, 64f, y, titlePaint)
            y += 64f
        }
        canvas.drawText(session.methodLabel(), 64f, y, text(30f, Color.parseColor("#D5DDE3"), true))
        y += 70f
        drawStats(canvas, stats, 64f, y, width - 128f)
        return bitmap
    }

    private fun drawStats(canvas: Canvas, stats: List<ShareStat>, left: Float, baseline: Float, width: Float) {
        if (stats.isEmpty()) return
        val slot = width / stats.size
        val valuePaint = text(40f, Color.WHITE, true)
        val labelPaint = text(22f, Color.parseColor("#C8FFFFFF"), true)
        val divider = Paint().apply { color = Color.parseColor("#47FFFFFF") }
        stats.forEachIndexed { index, stat ->
            val x = left + slot * index
            canvas.drawText(stat.value, x, baseline, valuePaint)
            canvas.drawText(stat.label, x, baseline + 34f, labelPaint)
            if (index > 0) {
                canvas.drawRect(x - 16f, baseline - 36f, x - 14f, baseline + 40f, divider)
            }
        }
    }

    fun saveToGallery(context: Context, bitmap: Bitmap, displayName: String) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "$displayName.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/HealthFit")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("A galeria não aceitou o card.")
        resolver.openOutputStream(uri).use { stream ->
            requireNotNull(stream)
            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, stream)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }

    fun writeTemp(context: Context, bitmap: Bitmap, name: String): File {
        val dir = File(context.cacheDir, "cards").apply { mkdirs() }
        val file = File(dir, "$name.jpg")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) }
        return file
    }

    private fun text(size: Float, color: Int, bold: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        this.color = color
        typeface = if (bold) Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD) else Typeface.SANS_SERIF
    }

    private fun wrap(canvas: Canvas, text: String, paint: Paint, x: Float, startY: Float, maxWidth: Int) {
        var y = startY
        wrappedLines(text, paint, maxWidth).forEach { line ->
            canvas.drawText(line, x, y, paint)
            y += paint.textSize * 1.15f
        }
    }

    private fun wrappedLines(text: String, paint: Paint, maxWidth: Int): List<String> {
        val lines = mutableListOf<String>()
        var line = ""
        text.split(" ").forEach { word ->
            val trial = if (line.isEmpty()) word else "$line $word"
            if (paint.measureText(trial) > maxWidth && line.isNotEmpty()) {
                lines += line
                line = word
            } else {
                line = trial
            }
        }
        if (line.isNotEmpty()) lines += line
        return lines
    }
}
