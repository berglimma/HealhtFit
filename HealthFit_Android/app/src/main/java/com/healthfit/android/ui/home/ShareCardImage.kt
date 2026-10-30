package com.healthfit.android.ui.home

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import com.healthfit.android.R
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

object ShareCardImage {
    private const val MaxOutputSide = 1920

    fun render(context: Context, session: FinishedWorkout): Bitmap {
        val width = 1080
        val height = 1920
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.parseColor("#0E1113"))
        val cover = BitmapFactory.decodeResource(context.resources, session.coverRes)
        if (cover != null) {
            // Capa do card: preenche a área sem esticar (center-crop).
            drawBitmapAspectFill(canvas, cover, RectF(0f, 0f, width.toFloat(), 1180f))
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
        val source = decodeOrientedBitmap(context, uri)
        val stamped = stampBitmap(context, source, session)
        if (stamped !== source) source.recycle()
        return stamped
    }

    /**
     * Mantém proporção e orientação da foto (retrato ou paisagem).
     * Não estica para 9:16 — o canvas segue o aspecto da imagem.
     */
    fun stampBitmap(context: Context, source: Bitmap, session: FinishedWorkout): Bitmap {
        val (width, height) = outputSizePreservingAspect(source.width, source.height)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.parseColor("#0E1113"))
        // Aspect-fit: foto inteira, sem distorção (barras só se arredondamento exigir).
        drawBitmapAspectFit(canvas, source, RectF(0f, 0f, width.toFloat(), height.toFloat()))
        val shade = Paint().apply {
            shader = LinearGradient(
                0f, height * 0.42f, 0f, height.toFloat(),
                Color.TRANSPARENT,
                Color.parseColor("#F20E1113"),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, height * 0.42f, width.toFloat(), height.toFloat(), shade)
        val scale = min(width, height) / 1080f
        val pad = (64f * scale).coerceAtLeast(28f)
        val logoSize = (72f * scale).roundToInt().coerceAtLeast(40)
        val brandTop = (height * 0.08f).toInt().coerceAtLeast(pad.toInt())
        val logo = BitmapFactory.decodeResource(context.resources, R.drawable.brandheart)
        if (logo != null) {
            canvas.drawBitmap(
                logo,
                null,
                Rect(pad.toInt(), brandTop, pad.toInt() + logoSize, brandTop + logoSize),
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
            logo.recycle()
        }
        val brandSize = (40f * scale).coerceAtLeast(22f)
        canvas.drawText(
            "HealthFit",
            pad + logoSize + 16f * scale,
            brandTop + logoSize * 0.72f,
            text(brandSize, Color.WHITE, true),
        )
        val titlePaint = text((52f * scale).coerceAtLeast(28f), Color.WHITE, true)
        val titleLines = wrappedLines(session.title, titlePaint, (width - pad * 2).toInt()).take(2)
        val stats = session.shareStats()
        val lineStep = titlePaint.textSize * 1.2f
        var y = height - pad - titleLines.size * lineStep - 52f * scale - 88f * scale
        titleLines.forEach { line ->
            canvas.drawText(line, pad, y, titlePaint)
            y += lineStep
        }
        canvas.drawText(
            session.methodLabel(),
            pad,
            y,
            text((30f * scale).coerceAtLeast(18f), Color.parseColor("#D5DDE3"), true),
        )
        y += 70f * scale
        drawStats(canvas, stats, pad, y, width - pad * 2, scale)
        return bitmap
    }

    /** Decodifica a foto aplicando rotação EXIF (evita paisagem “deitada” errada). */
    fun decodeOrientedBitmap(context: Context, uri: Uri): Bitmap {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            return ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.isMutableRequired = false
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val decoded = context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: error("Não foi possível ler a foto.")
        val orientation = context.contentResolver.openInputStream(uri)?.use { stream ->
            ExifInterface(stream).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
        return applyExifOrientation(decoded, orientation)
    }

    private fun applyExifOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (oriented !== bitmap) bitmap.recycle()
        return oriented
    }

    private fun outputSizePreservingAspect(srcW: Int, srcH: Int): Pair<Int, Int> {
        val longest = max(srcW, srcH).coerceAtLeast(1)
        val scale = min(1f, MaxOutputSide.toFloat() / longest)
        val w = (srcW * scale).roundToInt().coerceAtLeast(1)
        val h = (srcH * scale).roundToInt().coerceAtLeast(1)
        return w to h
    }

    private fun drawBitmapAspectFit(canvas: Canvas, bitmap: Bitmap, dest: RectF) {
        val scale = min(dest.width() / bitmap.width, dest.height() / bitmap.height)
        val w = bitmap.width * scale
        val h = bitmap.height * scale
        val left = dest.centerX() - w / 2f
        val top = dest.centerY() - h / 2f
        canvas.drawBitmap(
            bitmap,
            null,
            RectF(left, top, left + w, top + h),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
    }

    private fun drawBitmapAspectFill(canvas: Canvas, bitmap: Bitmap, dest: RectF) {
        val scale = max(dest.width() / bitmap.width, dest.height() / bitmap.height)
        val w = bitmap.width * scale
        val h = bitmap.height * scale
        val left = dest.centerX() - w / 2f
        val top = dest.centerY() - h / 2f
        canvas.save()
        canvas.clipRect(dest)
        canvas.drawBitmap(
            bitmap,
            null,
            RectF(left, top, left + w, top + h),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
        canvas.restore()
    }

    private fun drawStats(
        canvas: Canvas,
        stats: List<ShareStat>,
        left: Float,
        baseline: Float,
        width: Float,
        scale: Float = 1f,
    ) {
        if (stats.isEmpty()) return
        val slot = width / stats.size
        val valuePaint = text((40f * scale).coerceAtLeast(22f), Color.WHITE, true)
        val labelPaint = text((22f * scale).coerceAtLeast(14f), Color.parseColor("#C8FFFFFF"), true)
        val divider = Paint().apply { color = Color.parseColor("#47FFFFFF") }
        stats.forEachIndexed { index, stat ->
            val x = left + slot * index
            canvas.drawText(stat.value, x, baseline, valuePaint)
            canvas.drawText(stat.label, x, baseline + 34f * scale, labelPaint)
            if (index > 0) {
                canvas.drawRect(
                    x - 16f * scale,
                    baseline - 36f * scale,
                    x - 14f * scale,
                    baseline + 40f * scale,
                    divider,
                )
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
