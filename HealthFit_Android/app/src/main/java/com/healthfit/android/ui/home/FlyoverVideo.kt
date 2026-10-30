package com.healthfit.android.ui.home

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

object FlyoverVideo {
    private const val TAG = "HealthFitVideo"
    fun render(context: Context, title: String, athlete: String, minutes: String): File {
        val width = 720
        val height = 1280
        val frameRate = 24
        val frameCount = 72
        val dir = File(context.cacheDir, "flyover").apply { mkdirs() }
        val file = File(dir, "HealthFit-Flyover.mp4")
        if (file.exists()) file.delete()
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val color = pickColor(encoder)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, color)
            setInteger(MediaFormat.KEY_BIT_RATE, 2_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var track = -1
        var started = false
        val bufferInfo = MediaCodec.BufferInfo()
        val timeout = 10_000L
        repeat(frameCount) { index ->
            val bitmap = frame(width, height, index / (frameCount - 1f), title, athlete, minutes)
            val yuv = toYuv(bitmap, width, height, color)
            bitmap.recycle()
            val inIndex = encoder.dequeueInputBuffer(timeout)
            if (inIndex >= 0) {
                val input = encoder.getInputBuffer(inIndex) ?: return@repeat
                input.clear()
                input.put(yuv)
                val time = index * 1_000_000L / frameRate
                encoder.queueInputBuffer(inIndex, 0, yuv.size, time, 0)
            }
            track = drain(encoder, muxer, bufferInfo, track, started).also { started = it.second }.first
        }
        val inIndex = encoder.dequeueInputBuffer(timeout)
        if (inIndex >= 0) {
            encoder.queueInputBuffer(inIndex, 0, 0, frameCount * 1_000_000L / frameRate, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }
        var eos = false
        var waits = 0
        while (!eos && waits < 40) {
            val out = encoder.dequeueOutputBuffer(bufferInfo, timeout)
            when {
                out == MediaCodec.INFO_TRY_AGAIN_LATER -> waits += 1
                out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!started) {
                        track = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        started = true
                    }
                }
                out >= 0 -> {
                    val encoded = encoder.getOutputBuffer(out)
                    if (encoded != null && bufferInfo.size > 0 && started) {
                        encoded.position(bufferInfo.offset)
                        encoded.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(track, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(out, false)
                    eos = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                }
                else -> waits += 1
            }
        }
        encoder.stop()
        encoder.release()
        if (started) muxer.stop()
        muxer.release()
        if (!file.exists() || file.length() == 0L) error("O vídeo do flyover ficou vazio.")
        return file
    }

    fun share(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Flyover HealthFit")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, "Compartilhar flyover")
        if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
    }

    fun saveToGallery(context: Context, file: File) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "HealthFit-Flyover.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/HealthFit")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("A galeria não aceitou o vídeo.")
        resolver.openOutputStream(uri).use { output ->
            requireNotNull(output)
            file.inputStream().use { it.copyTo(output) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }

    internal fun encodeHeldFrames(file: File, slides: List<Pair<Bitmap, Int>>, fps: Int) {
        if (file.exists()) file.delete()
        if (slides.isEmpty()) error("Sem quadros para o vídeo.")
        val names = listOf("c2.qti.avc.encoder", "c2.android.avc.encoder", "OMX.google.h264.encoder")
        var last: Throwable? = null
        try {
            for (name in names) {
                val encoder = runCatching { MediaCodec.createByCodecName(name) }.getOrNull() ?: continue
                try {
                    if (file.exists()) file.delete()
                    encodeWith(encoder, file, slides, fps)
                    if (file.exists() && file.length() > 0L) return
                    last = IllegalStateException("O vídeo da retrospectiva ficou vazio.")
                } catch (error: Throwable) {
                    last = error
                    Log.e(TAG, "Falha ao montar o vídeo com $name", error)
                }
            }
            throw last ?: IllegalStateException("Este aparelho não gera vídeo.")
        } finally {
            slides.forEach { (bitmap, _) -> if (!bitmap.isRecycled) bitmap.recycle() }
        }
    }

    private fun encodeWith(encoder: MediaCodec, file: File, slides: List<Pair<Bitmap, Int>>, fps: Int) {
        val first = slides.first().first
        val width = first.width
        val height = first.height
        val color = pickColor(encoder)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, color)
            setInteger(MediaFormat.KEY_BIT_RATE, 2_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, width * height * 3 / 2)
        }
        var muxer: MediaMuxer? = null
        var track = -1
        var started = false
        val bufferInfo = MediaCodec.BufferInfo()
        val timeout = 10_000L
        var frameIndex = 0
        try {
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val output = muxer
            slides.forEach { (bitmap, frames) ->
                val planes = yuvPlanes(bitmap, width, height)
                repeat(frames.coerceAtLeast(1)) {
                    val inIndex = encoder.dequeueInputBuffer(timeout)
                    if (inIndex < 0) error("O codificador de vídeo não aceitou o quadro.")
                    val input = encoder.getInputBuffer(inIndex) ?: error("Buffer de vídeo indisponível.")
                    val image = encoder.getInputImage(inIndex)
                    val size = if (image != null) {
                        writePlanes(planes, image)
                        val frameBytes = width * height * 3 / 2
                        if (input.capacity() >= frameBytes) frameBytes else input.capacity()
                    } else {
                        val yuv = planes.toSemiPlanar()
                        if (input.capacity() < yuv.size) error("Buffer de vídeo menor que o quadro.")
                        input.clear()
                        input.put(yuv)
                        yuv.size
                    }
                    val time = frameIndex * 1_000_000L / fps
                    encoder.queueInputBuffer(inIndex, 0, size, time, 0)
                    frameIndex += 1
                    val drained = drain(encoder, output, bufferInfo, track, started)
                    track = drained.first
                    started = drained.second
                }
            }
            val endIndex = encoder.dequeueInputBuffer(timeout)
            if (endIndex >= 0) {
                encoder.queueInputBuffer(
                    endIndex,
                    0,
                    0,
                    frameIndex * 1_000_000L / fps,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
            }
            var eos = false
            var waits = 0
            while (!eos && waits < 80) {
                val out = encoder.dequeueOutputBuffer(bufferInfo, timeout)
                when {
                    out == MediaCodec.INFO_TRY_AGAIN_LATER -> waits += 1
                    out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (!started) {
                            track = output.addTrack(encoder.outputFormat)
                            output.start()
                            started = true
                        }
                    }
                    out >= 0 -> {
                        val encoded = encoder.getOutputBuffer(out)
                        if (encoded != null && bufferInfo.size > 0 && started) {
                            encoded.position(bufferInfo.offset)
                            encoded.limit(bufferInfo.offset + bufferInfo.size)
                            output.writeSampleData(track, encoded, bufferInfo)
                        }
                        encoder.releaseOutputBuffer(out, false)
                        eos = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    }
                    else -> waits += 1
                }
            }
        } finally {
            runCatching { encoder.stop() }
            runCatching { encoder.release() }
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
        }
        if (!file.exists() || file.length() == 0L) error("O vídeo da retrospectiva ficou vazio.")
    }

    private class YuvPlanes(
        val width: Int,
        val height: Int,
        val y: ByteArray,
        val u: ByteArray,
        val v: ByteArray,
    ) {
        fun toSemiPlanar(): ByteArray {
            val ySize = width * height
            val out = ByteArray(ySize + u.size * 2)
            y.copyInto(out)
            interleaved(uThenV = true).copyInto(out, ySize)
            return out
        }

        fun interleaved(uThenV: Boolean): ByteArray {
            val cached = if (uThenV) uv else vu
            if (cached != null) return cached
            val out = ByteArray(u.size * 2)
            var index = 0
            for (i in u.indices) {
                out[index++] = if (uThenV) u[i] else v[i]
                out[index++] = if (uThenV) v[i] else u[i]
            }
            if (uThenV) uv = out else vu = out
            return out
        }

        private var uv: ByteArray? = null
        private var vu: ByteArray? = null
    }

    private fun yuvPlanes(bitmap: Bitmap, width: Int, height: Int): YuvPlanes {
        val argb = IntArray(width * height)
        bitmap.getPixels(argb, 0, width, 0, 0, width, height)
        val chromaWidth = width / 2
        val chromaHeight = height / 2
        val y = ByteArray(width * height)
        val u = ByteArray(chromaWidth * chromaHeight)
        val v = ByteArray(chromaWidth * chromaHeight)
        var yIndex = 0
        for (row in 0 until height) {
            for (col in 0 until width) {
                val pixel = argb[yIndex]
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF
                y[yIndex] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).coerceIn(0, 255).toByte()
                yIndex += 1
                if (row % 2 == 0 && col % 2 == 0) {
                    val chroma = (row / 2) * chromaWidth + col / 2
                    u[chroma] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).coerceIn(0, 255).toByte()
                    v[chroma] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).coerceIn(0, 255).toByte()
                }
            }
        }
        return YuvPlanes(width, height, y, u, v)
    }

    private fun writePlanes(planes: YuvPlanes, image: Image) {
        val crop = image.cropRect
        val width = min(planes.width, crop.width())
        val height = min(planes.height, crop.height())
        copyPlane(image.planes[0], planes.y, width, height, planes.width)
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        if (uPlane.pixelStride == 2 && vPlane.pixelStride == 2 &&
            uPlane.rowStride == planes.width && vPlane.rowStride == planes.width
        ) {
            val uBuffer = uPlane.buffer
            val vBuffer = vPlane.buffer
            val uFirst = uBuffer.position() <= vBuffer.position()
            val packed = planes.interleaved(uThenV = uFirst)
            val buffer = if (uFirst) uBuffer else vBuffer
            val copy = buffer.duplicate()
            copy.position(buffer.position())
            copy.put(packed, 0, min(packed.size, copy.remaining()))
            return
        }
        copyPlane(uPlane, planes.u, width / 2, height / 2, planes.width / 2)
        copyPlane(vPlane, planes.v, width / 2, height / 2, planes.width / 2)
    }

    private fun copyPlane(plane: Image.Plane, src: ByteArray, width: Int, height: Int, srcStride: Int) {
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val base = buffer.position()
        if (pixelStride == 1 && rowStride == width && srcStride == width) {
            val copy = buffer.duplicate()
            copy.position(base)
            copy.put(src, 0, width * height)
            return
        }
        if (pixelStride == 1) {
            val copy = buffer.duplicate()
            for (row in 0 until height) {
                copy.position(base + row * rowStride)
                copy.put(src, row * srcStride, width)
            }
            return
        }
        for (row in 0 until height) {
            val rowStart = base + row * rowStride
            val srcRow = row * srcStride
            for (col in 0 until width) {
                val index = rowStart + col * pixelStride
                if (index < buffer.limit()) buffer.put(index, src[srcRow + col])
            }
        }
    }

    private fun pickColor(encoder: MediaCodec): Int {
        val formats = encoder.codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).colorFormats
        return when {
            formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
            formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar) ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
            else -> error("Este aparelho não gera vídeo flyover.")
        }
    }

    private fun drain(
        encoder: MediaCodec,
        muxer: MediaMuxer,
        info: MediaCodec.BufferInfo,
        track: Int,
        started: Boolean,
    ): Pair<Int, Boolean> {
        var currentTrack = track
        var muxing = started
        while (true) {
            val out = encoder.dequeueOutputBuffer(info, 0)
            when {
                out == MediaCodec.INFO_TRY_AGAIN_LATER -> return currentTrack to muxing
                out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxing) {
                        currentTrack = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxing = true
                    }
                }
                out >= 0 -> {
                    val encoded = encoder.getOutputBuffer(out)
                    if (encoded != null && info.size > 0 && muxing) {
                        encoded.position(info.offset)
                        encoded.limit(info.offset + info.size)
                        muxer.writeSampleData(currentTrack, encoded, info)
                    }
                    encoder.releaseOutputBuffer(out, false)
                }
                else -> return currentTrack to muxing
            }
        }
    }

    private fun frame(width: Int, height: Int, progress: Float, title: String, athlete: String, minutes: String): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.parseColor("#071018"))
        val grid = Paint().apply { color = Color.parseColor("#143044"); strokeWidth = 2f }
        var y = 180f
        while (y < 980f) {
            canvas.drawLine(40f, y, width - 40f, y + 30f, grid)
            y += 70f
        }
        val path = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#3DDC3A")
            style = Paint.Style.STROKE
            strokeWidth = 10f
            strokeCap = Paint.Cap.ROUND
        }
        val points = route(width, height)
        val visible = (points.size * progress).toInt().coerceAtLeast(2)
        for (index in 1 until visible) {
            canvas.drawLine(points[index - 1].first, points[index - 1].second, points[index].first, points[index].second, path)
        }
        val marker = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val head = points[(visible - 1).coerceAtMost(points.lastIndex)]
        canvas.drawCircle(head.first, head.second, 16f, marker)
        canvas.drawText("HEALTHFIT  ·  FLYOVER", 48f, 120f, label(28f, Color.parseColor("#3DDC3A"), true))
        canvas.drawText(title.take(28), 48f, 1060f, label(42f, Color.WHITE, true))
        canvas.drawText(athlete, 48f, 1120f, label(28f, Color.parseColor("#D5DDE3")))
        canvas.drawText(minutes, 48f, 1200f, label(56f, Color.WHITE, true))
        canvas.drawText("Sobrevoo do percurso", 48f, 1260f, label(24f, Color.parseColor("#8E989F")))
        return bitmap
    }

    private fun route(width: Int, height: Int): List<Pair<Float, Float>> {
        val points = ArrayList<Pair<Float, Float>>(80)
        for (step in 0 until 80) {
            val t = step / 79f
            val x = 80f + t * (width - 160f)
            val y = 620f + sin(t * 6.2) * 180f + cos(t * 2.4) * 40f
            points += x to y.toFloat()
        }
        return points
    }

    private fun label(size: Float, color: Int, bold: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        this.color = color
        typeface = if (bold) Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD) else Typeface.SANS_SERIF
    }

    private fun toYuv(bitmap: Bitmap, width: Int, height: Int, color: Int): ByteArray {
        val argb = IntArray(width * height)
        bitmap.getPixels(argb, 0, width, 0, 0, width, height)
        val ySize = width * height
        val uvSize = ySize / 4
        val semi = color == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        val out = ByteArray(ySize + uvSize * 2)
        var yIndex = 0
        var uIndex = ySize
        var vIndex = if (semi) ySize else ySize + uvSize
        for (row in 0 until height) {
            for (col in 0 until width) {
                val pixel = argb[row * width + col]
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                out[yIndex++] = y.coerceIn(0, 255).toByte()
                if (row % 2 == 0 && col % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    if (semi) {
                        out[uIndex++] = u.coerceIn(0, 255).toByte()
                        out[uIndex++] = v.coerceIn(0, 255).toByte()
                    } else {
                        out[uIndex++] = u.coerceIn(0, 255).toByte()
                        out[vIndex++] = v.coerceIn(0, 255).toByte()
                    }
                }
            }
        }
        return out
    }
}
