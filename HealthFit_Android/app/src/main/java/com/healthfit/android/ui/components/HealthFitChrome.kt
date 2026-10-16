package com.healthfit.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.min

val GreenOrange = Brush.horizontalGradient(
    listOf(Color(0xFF3DDC4A), Color(0xFFFF9A3C)),
)

/** Relógio central (MM:SS / H:MM:SS) com anel de progresso — cardio, meditação e estudo. */
@Composable
fun SessionClockDial(
    totalSeconds: Int,
    caption: String,
    accent: Color = HealthFitColors.Accent,
    progress: Float = (totalSeconds % 60) / 60f,
    paused: Boolean = false,
    size: Dp = 200.dp,
    modifier: Modifier = Modifier,
) {
    val clamped = progress.coerceIn(0f, 1f)
    val timeColor = if (paused) HealthFitColors.TextSecondary else Color.White
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(size), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val stroke = 14.dp.toPx()
                val diameter = min(this.size.width, this.size.height) - stroke
                val topLeft = Offset(
                    (this.size.width - diameter) / 2f,
                    (this.size.height - diameter) / 2f,
                )
                val arcSize = Size(diameter, diameter)
                drawArc(
                    color = Color.White.copy(alpha = 0.10f),
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round),
                )
                if (clamped > 0f) {
                    drawArc(
                        color = if (paused) accent.copy(alpha = 0.45f) else accent,
                        startAngle = -90f,
                        sweepAngle = 360f * clamped,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = Stroke(width = stroke, cap = StrokeCap.Round),
                    )
                }
                // Marcadores tipo relógio (12 ticks).
                val cx = this.size.width / 2f
                val cy = this.size.height / 2f
                val outer = diameter / 2f
                for (i in 0 until 12) {
                    val angle = Math.toRadians((-90.0 + i * 30.0))
                    val major = i % 3 == 0
                    val inner = outer - if (major) stroke * 0.85f else stroke * 0.45f
                    val cos = kotlin.math.cos(angle).toFloat()
                    val sin = kotlin.math.sin(angle).toFloat()
                    drawLine(
                        color = Color.White.copy(alpha = if (major) 0.35f else 0.18f),
                        start = Offset(cx + cos * inner, cy + sin * inner),
                        end = Offset(cx + cos * outer, cy + sin * outer),
                        strokeWidth = if (major) 3f else 2f,
                        cap = StrokeCap.Round,
                    )
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    formatSessionClock(totalSeconds),
                    color = timeColor,
                    fontSize = if (totalSeconds >= 3600) 36.sp else 44.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    textAlign = TextAlign.Center,
                )
                Text(
                    caption,
                    color = HealthFitColors.TextSecondary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

fun formatSessionClock(totalSeconds: Int): String {
    val s = totalSeconds.coerceAtLeast(0)
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return if (h > 0) {
        "%d:%02d:%02d".format(h, m, sec)
    } else {
        "%02d:%02d".format(m, sec)
    }
}

@Composable
fun HealthFitTabBar(
    items: List<TabSpec>,
    selectedRoute: String?,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(32.dp))
            .background(Color(0xF01A1E22))
            .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(32.dp))
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEach { item ->
            val selected = item.route == selectedRoute
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelect(item.route) }
                    .padding(vertical = 2.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Fixed slot so the red unread badge sits fully inside (not clipped by tab clip/offset).
                Box(
                    modifier = Modifier.size(40.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    if (selected) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(HealthFitColors.Accent.copy(alpha = 0.22f)),
                        )
                    }
                    Icon(
                        imageVector = item.icon,
                        contentDescription = item.label,
                        tint = if (selected) HealthFitColors.Accent else Color(0xFF9AA3AB),
                        modifier = Modifier.size(22.dp),
                    )
                    if (item.badge > 0) {
                        val label = if (item.badge > 99) "99+" else item.badge.toString()
                        Box(
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .defaultMinSize(minWidth = 18.dp, minHeight = 18.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFFF3B30))
                                .padding(horizontal = if (label.length > 1) 5.dp else 0.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = label,
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                textAlign = TextAlign.Center,
                                maxLines = 1,
                                lineHeight = 11.sp,
                            )
                        }
                    }
                }
                Text(
                    text = item.label,
                    color = if (selected) HealthFitColors.Accent else Color(0xFF9AA3AB),
                    fontSize = 10.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

data class TabSpec(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val badge: Int = 0,
)

@Composable
fun HeroCard(
    title: String,
    subtitle: String,
    brush: Brush,
    modifier: Modifier = Modifier,
    height: Dp = 168.dp,
    imageRes: Int? = null,
    eyebrow: String? = null,
    eyebrowColor: Color = HealthFitColors.Accent,
    footer: @Composable (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(22.dp))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        if (imageRes != null) {
            Image(
                painter = painterResource(imageRes),
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                Modifier
                    .matchParentSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.78f)),
                        ),
                    ),
            )
        } else {
            Box(Modifier.matchParentSize().background(brush))
        }
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(16.dp),
        ) {
            eyebrow?.let {
                Text(
                    text = it,
                    color = eyebrowColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.6.sp,
                )
                Spacer(Modifier.height(4.dp))
            }
            Text(text = title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(
                text = subtitle,
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 2.dp),
            )
            footer?.invoke()
        }
    }
}

@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        color = Color(0xFFB7C0C8),
        fontSize = 15.sp,
        fontWeight = FontWeight.Medium,
        modifier = modifier,
    )
}

@Composable
fun PillChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        color = if (selected) Color.Black else Color.White,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (selected) Color(0xFF3A4148) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

@Composable
fun ChipRow(
    labels: List<String>,
    selected: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .horizontalScroll(rememberScrollState())
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFF1A1F24))
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        labels.forEachIndexed { index, label ->
            PillChip(
                text = label,
                selected = index == selected,
                onClick = { onSelect(index) },
            )
        }
    }
}

@Composable
fun GradientButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(GreenOrange)
            .clickable(onClick = onClick)
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
        }
        Text(text, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

@Composable
fun DarkCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(14.dp),
    ) {
        content()
    }
}

@Composable
fun BiotypeSection(
    selected: com.healthfit.android.ui.home.BodyType,
    modifier: Modifier = Modifier,
    onSelect: (com.healthfit.android.ui.home.BodyType) -> Unit,
) {
    val types = com.healthfit.android.ui.home.BodyType.entries
    Text("Biotipo", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, modifier = modifier)
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        types.forEach { type ->
            BiotypeCard(
                title = type.title,
                body = type.summary,
                selected = selected == type,
                accent = type.accent,
                modifier = Modifier.weight(1f).clickable { onSelect(type) },
            )
        }
    }
    Spacer(Modifier.height(10.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(selected.accent.copy(alpha = 0.18f))
            .clickable { }
            .padding(12.dp),
    ) {
        Text("Como saber se você é ${selected.title.lowercase()}", color = selected.accent, fontWeight = FontWeight.Bold)
        Text(
            selected.detail,
            color = Color(0xFFD5DDE3),
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun BiotypeCard(
    title: String,
    body: String,
    selected: Boolean,
    accent: Color,
    modifier: Modifier,
) {
    Column(
        modifier = modifier
            .height(168.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) accent else Color(0xFF12161A))
            .border(1.dp, accent, RoundedCornerShape(16.dp))
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, color = if (selected) Color.Black else Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        Text(
            body,
            color = if (selected) Color.Black.copy(alpha = 0.8f) else Color(0xFFB7C0C8),
            fontSize = 10.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}

@Composable
fun MetaRow(icon: ImageVector, text: String, tint: Color = Color.White) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(14.dp))
        Text(
            text = text,
            color = Color.White.copy(alpha = 0.9f),
            fontSize = 12.sp,
            modifier = Modifier.padding(start = 6.dp),
            textAlign = TextAlign.Start,
        )
    }
}
