package com.healthfit.android.ui.home

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay

private data class WelcomeSlide(val label: String, val icon: ImageVector)

@Composable
fun WelcomeLoadingScreen(name: String, onFinished: () -> Unit) {
    val first = name.substringBefore(' ').ifBlank { "Berg" }
    val slides = listOf(
        WelcomeSlide("Treino", Icons.Filled.FitnessCenter),
        WelcomeSlide("Cardio", Icons.AutoMirrored.Filled.DirectionsRun),
        WelcomeSlide("Meditação", Icons.Filled.SelfImprovement),
    )
    var slide by remember { mutableIntStateOf(0) }
    var progress by remember { mutableFloatStateOf(0f) }
    val bounce = rememberInfiniteTransition(label = "welcome")
    val scale by bounce.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(tween(700, easing = LinearEasing), RepeatMode.Reverse),
        label = "icon",
    )

    LaunchedEffect(Unit) {
        val start = System.nanoTime()
        while (progress < 1f) {
            val elapsed = (System.nanoTime() - start) / 1_000_000_000.0
            progress = (elapsed / 5.0).toFloat().coerceIn(0f, 1f)
            slide = ((elapsed / (5.0 / slides.size)).toInt()).coerceIn(0, slides.lastIndex)
            delay(40)
        }
        onFinished()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(420.dp)
                .background(
                    Brush.radialGradient(
                        listOf(HealthFitColors.Accent.copy(alpha = 0.22f), Color.Transparent),
                    ),
                ),
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp, vertical = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))
            Box(contentAlignment = Alignment.Center, modifier = Modifier.scale(scale)) {
                Box(
                    modifier = Modifier
                        .size(128.dp)
                        .clip(CircleShape)
                        .background(HealthFitColors.Accent.copy(alpha = 0.16f)),
                )
                Canvas(Modifier.size(128.dp)) {
                    drawCircle(
                        color = HealthFitColors.Accent.copy(alpha = 0.55f),
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3.dp.toPx()),
                    )
                }
                Icon(slides[slide].icon, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(52.dp))
            }
            Text(slides[slide].label, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 12.dp)) {
                slides.indices.forEach { index ->
                    Box(
                        modifier = Modifier
                            .size(width = if (index == slide) 18.dp else 8.dp, height = 8.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (index == slide) HealthFitColors.Accent else Color.White.copy(alpha = 0.28f)),
                    )
                }
            }
            Spacer(Modifier.height(36.dp))
            Text(
                "Bora treinar, $first!",
                color = Color.White,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                "Cada treino te aproxima do objetivo. Hoje é dia de evoluir!",
                color = Color(0xFFB7C0C8),
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 14.dp),
            )
            Text(
                "Sono e água em dia — ótimo cuidado. Agora escolha o próximo passo.",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 14.dp),
            )
            Spacer(Modifier.weight(1f))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(4.dp)),
                color = HealthFitColors.Accent,
                trackColor = Color.White.copy(alpha = 0.12f),
                strokeCap = StrokeCap.Round,
            )
            Text("Carregando...", color = Color(0xFFB7C0C8), fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp, bottom = 12.dp))
        }
    }
}
