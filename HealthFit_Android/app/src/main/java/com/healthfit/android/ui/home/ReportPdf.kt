package com.healthfit.android.ui.home

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

object ReportPdf {
    fun write(context: Context, report: ProgressReport): File {
        val dir = File(context.cacheDir, "reports").apply { mkdirs() }
        val prefix = if (report.kind == ReportKind.Weekly) "HealthFit-Semanal" else "HealthFit-Mensal"
        val file = File(dir, "$prefix.pdf")
        val document = PdfDocument()
        val pageWidth = 595
        val pageHeight = 842
        val margin = 40f
        val lines = mutableListOf<PdfRow>()
        lines += PdfRow.Title(report.title)
        lines += PdfRow.Meta(report.period)
        lines += PdfRow.Score(report.score, report.message)
        lines += PdfRow.Gap
        report.stats.chunked(2).forEach { pair ->
            lines += PdfRow.Stats(pair)
        }
        report.sections.forEach { section ->
            lines += PdfRow.Gap
            lines += PdfRow.Heading(section.title)
            section.lines.forEach { line ->
                lines += PdfRow.Body(line.title, line.detail)
            }
        }
        lines += PdfRow.Gap
        lines += PdfRow.Footer("HealthFit · relatório gerado no aparelho")

        var pageNumber = 1
        var page = document.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
        var canvas = page.canvas
        drawBackdrop(canvas, pageWidth, pageHeight)
        var y = 36f
        y = drawBrandBar(canvas, pageWidth, y)
        lines.forEach { row ->
            val height = row.height()
            if (y + height > pageHeight - 36f) {
                document.finishPage(page)
                pageNumber += 1
                page = document.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
                canvas = page.canvas
                drawBackdrop(canvas, pageWidth, pageHeight)
                y = drawBrandBar(canvas, pageWidth, 36f)
            }
            y = row.draw(canvas, margin, y, pageWidth - margin)
        }
        document.finishPage(page)
        FileOutputStream(file).use { document.writeTo(it) }
        document.close()
        return file
    }

    fun share(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, file.nameWithoutExtension.replace('-', ' '))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(send, "Compartilhar relatório")
        if (context !is Activity) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
    }

    private fun drawBackdrop(canvas: Canvas, width: Int, height: Int) {
        canvas.drawColor(Color.WHITE)
        val edge = Paint().apply { color = Color.parseColor("#F4F7F4") }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), edge)
    }

    private fun drawBrandBar(canvas: Canvas, width: Int, top: Float): Float {
        val bar = Paint().apply { color = Color.parseColor("#143D24") }
        canvas.drawRect(0f, 0f, width.toFloat(), 28f, bar)
        val brand = textPaint(11f, Color.WHITE, bold = true)
        canvas.drawText("HEALTHFIT", 40f, 18f, brand)
        return top.coerceAtLeast(44f)
    }

    private fun textPaint(size: Float, color: Int, bold: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        this.color = color
        typeface = if (bold) Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD) else Typeface.SANS_SERIF
    }

    private sealed class PdfRow {
        abstract fun height(): Float
        abstract fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float

        data class Title(val text: String) : PdfRow() {
            override fun height() = 32f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                canvas.drawText(text, left, top + 22f, textPaint(22f, Color.parseColor("#111418"), true))
                return top + height()
            }
        }

        data class Meta(val text: String) : PdfRow() {
            override fun height() = 22f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                canvas.drawText(text, left, top + 14f, textPaint(11f, Color.parseColor("#5C656C")))
                return top + height()
            }
        }

        data class Score(val score: Int, val message: String) : PdfRow() {
            override fun height() = 78f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                val card = Paint().apply { color = Color.WHITE }
                canvas.drawRoundRect(left, top, right, top + 70f, 12f, 12f, card)
                canvas.drawText("$score", left + 16f, top + 36f, textPaint(28f, Color.parseColor("#1FAE3A"), true))
                canvas.drawText("pontos", left + 16f, top + 54f, textPaint(11f, Color.parseColor("#5C656C")))
                val messagePaint = textPaint(12f, Color.parseColor("#111418"))
                canvas.drawText(message.take(64), left + 110f, top + 40f, messagePaint)
                return top + height()
            }
        }

        data class Stats(val pair: List<ReportStat>) : PdfRow() {
            override fun height() = 52f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                val gap = 8f
                val width = (right - left - gap) / 2f
                pair.forEachIndexed { index, stat ->
                    val x = left + index * (width + gap)
                    val card = Paint().apply { color = Color.WHITE }
                    canvas.drawRoundRect(x, top, x + width, top + 44f, 10f, 10f, card)
                    canvas.drawText(stat.value, x + 12f, top + 22f, textPaint(14f, Color.parseColor("#111418"), true))
                    canvas.drawText(stat.label, x + 12f, top + 36f, textPaint(10f, Color.parseColor("#5C656C")))
                }
                return top + height()
            }
        }

        data class Heading(val text: String) : PdfRow() {
            override fun height() = 26f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                canvas.drawText(text, left, top + 18f, textPaint(14f, Color.parseColor("#143D24"), true))
                return top + height()
            }
        }

        data class Body(val title: String, val detail: String) : PdfRow() {
            override fun height() = 34f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                canvas.drawText(title, left, top + 14f, textPaint(12f, Color.parseColor("#111418"), true))
                canvas.drawText(detail.take(78), left, top + 28f, textPaint(10f, Color.parseColor("#5C656C")))
                return top + height()
            }
        }

        data object Gap : PdfRow() {
            override fun height() = 10f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float) = top + height()
        }

        data class Footer(val text: String) : PdfRow() {
            override fun height() = 24f
            override fun draw(canvas: Canvas, left: Float, top: Float, right: Float): Float {
                canvas.drawText(text, left, top + 16f, textPaint(10f, Color.parseColor("#8E989F")))
                return top + height()
            }
        }
    }
}
