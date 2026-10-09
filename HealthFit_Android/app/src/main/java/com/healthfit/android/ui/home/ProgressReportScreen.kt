package com.healthfit.android.ui.home

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ProgressReportScreen(
    report: ProgressReport,
    onClose: () -> Unit,
) {
    BackHandler(onBack = onClose)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var generating by remember { mutableStateOf(false) }
    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Fechar",
                tint = Color.White,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2A3138))
                    .clickable(onClick = onClose)
                    .padding(8.dp),
            )
            Text(
                report.title,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(start = 12.dp),
            )
        }
        Spacer(Modifier.height(18.dp))
        DarkCard {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                ScoreRing(report.score)
                Text(report.period, color = Color(0xFFB7C0C8), fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 10.dp))
                Text(report.message, color = Color.White, fontSize = 14.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
            }
        }
        Spacer(Modifier.height(12.dp))
        report.stats.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { stat ->
                    DarkCard(modifier = Modifier.weight(1f)) {
                        Text(stat.value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        Text(stat.label, color = Color(0xFF8E989F), fontSize = 12.sp)
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
        }
        report.sections.forEach { section ->
            Text(section.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.padding(top = 10.dp, bottom = 8.dp))
            section.lines.forEach { line ->
                DarkCard(modifier = Modifier.padding(bottom = 8.dp)) {
                    Text(line.title, color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text(line.detail, color = Color(0xFFB7C0C8), fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        GradientButton(
            text = if (generating) "Gerando PDF…" else "Gerar PDF do relatório",
            onClick = {
                if (generating) return@GradientButton
                generating = true
                scope.launch {
                    val shared = runCatching {
                        val file = withContext(Dispatchers.IO) { ReportPdf.write(context, report) }
                        withContext(Dispatchers.Main) { ReportPdf.share(context, file) }
                    }
                    generating = false
                    if (shared.isFailure) {
                        Toast.makeText(context, "Não foi possível gerar o PDF", Toast.LENGTH_SHORT).show()
                    }
                }
            },
            icon = Icons.Filled.Description,
        )
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun ScoreRing(score: Int) {
    val fraction = (score / 100f).coerceIn(0f, 1f)
    val color = when {
        score >= 80 -> HealthFitColors.Accent
        score >= 50 -> HealthFitColors.AccentSecondary
        else -> Color(0xFFFF9A3C)
    }
    Box(Modifier.size(120.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.matchParentSize()) {
            val stroke = Stroke(width = 10.dp.toPx(), cap = StrokeCap.Round)
            drawArc(
                color = Color.White.copy(alpha = 0.1f),
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                style = stroke,
                topLeft = Offset(8.dp.toPx(), 8.dp.toPx()),
                size = Size(size.width - 16.dp.toPx(), size.height - 16.dp.toPx()),
            )
            drawArc(
                color = color,
                startAngle = -90f,
                sweepAngle = 360f * fraction,
                useCenter = false,
                style = stroke,
                topLeft = Offset(8.dp.toPx(), 8.dp.toPx()),
                size = Size(size.width - 16.dp.toPx(), size.height - 16.dp.toPx()),
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("$score", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 32.sp)
            Text("pontos", color = Color(0xFF8E989F), fontSize = 11.sp)
        }
    }
}
