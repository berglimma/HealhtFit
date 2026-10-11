package com.healthfit.wear

import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Text
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

data class SpotBuddyPeer(
    val id: String,
    val displayName: String,
    val distanceMeters: Double,
    val bearingDegrees: Double,
    val needsHelp: Boolean = false,
)

/**
 * Estado do Spot Buddy no relógio. Ainda sem transporte: amigos vêm do celular
 * quando o recurso for ligado; por padrão a lista fica vazia.
 */
object SpotBuddyState {
    private val _enabled = MutableStateFlow(true)
    val enabled: StateFlow<Boolean> = _enabled

    private val _peers = MutableStateFlow<List<SpotBuddyPeer>>(emptyList())
    val peers: StateFlow<List<SpotBuddyPeer>> = _peers

    private val _needsHelp = MutableStateFlow(false)
    val needsHelp: StateFlow<Boolean> = _needsHelp

    private val _incomingHelp = MutableStateFlow<SpotBuddyPeer?>(null)
    val incomingHelp: StateFlow<SpotBuddyPeer?> = _incomingHelp

    fun setEnabled(value: Boolean) { _enabled.value = value }
    fun setPeers(list: List<SpotBuddyPeer>) { _peers.value = list }
    fun requestHelp() { _needsHelp.value = true }
    fun cancelHelp() { _needsHelp.value = false }
    fun dismissIncomingHelp() { _incomingHelp.value = null }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SpotBuddyScreen() {
    val enabled by SpotBuddyState.enabled.collectAsState()
    val peers by SpotBuddyState.peers.collectAsState()
    val needsHelp by SpotBuddyState.needsHelp.collectAsState()
    val context = LocalContext.current

    fun buzz() {
        (context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? Vibrator)
            ?.vibrate(VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text("Kitesurf · Spot Buddy", color = WearColors.Cyan, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        if (enabled) {
            Text(
                if (peers.isEmpty()) "Nenhum amigo no spot"
                else "${peers.size} amigo${if (peers.size == 1) "" else "s"} no spot",
                color = WearColors.TextSecondary,
                fontSize = 10.sp,
            )
        }

        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Radar(peers = peers, enabled = enabled, needsHelp = needsHelp)
        }

        if (needsHelp) {
            Text("SOS enviado", color = WearColors.Orange, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Text(
                "Amigos no Spot receberam seu alerta.",
                color = WearColors.TextSecondary,
                fontSize = 9.sp,
                textAlign = TextAlign.Center,
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (needsHelp) WearColors.Elevated else WearColors.Danger,
                    RoundedCornerShape(50),
                )
                .combinedClickable(
                    onClick = {},
                    onLongClick = {
                        buzz()
                        if (needsHelp) SpotBuddyState.cancelHelp() else SpotBuddyState.requestHelp()
                    },
                )
                .padding(vertical = 6.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                if (needsHelp) "Cancelar SOS" else "SOS (segure)",
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun Radar(peers: List<SpotBuddyPeer>, enabled: Boolean, needsHelp: Boolean) {
    val maxMeters = (peers.maxOfOrNull { it.distanceMeters } ?: 200.0).coerceAtLeast(100.0)
    Box(contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(84.dp)) {
            val radius = min(size.width, size.height) / 2f
            val center = Offset(size.width / 2f, size.height / 2f)
            listOf(1f, 0.66f, 0.33f).forEachIndexed { i, scale ->
                drawCircle(
                    color = Color.White.copy(alpha = 0.12f - i * 0.03f),
                    radius = radius * scale,
                    center = center,
                    style = Stroke(width = 1.dp.toPx()),
                )
            }
            drawLine(Color.White.copy(alpha = 0.08f), Offset(center.x, 0f), Offset(center.x, size.height), 1.dp.toPx())
            drawLine(Color.White.copy(alpha = 0.08f), Offset(0f, center.y), Offset(size.width, center.y), 1.dp.toPx())
            drawCircle(Color.White, radius = 2.5.dp.toPx(), center = center)
            if (enabled) {
                peers.take(6).forEach { peer ->
                    val frac = (peer.distanceMeters / maxMeters).coerceIn(0.1, 1.0).toFloat()
                    val rad = Math.toRadians(peer.bearingDegrees - 90.0)
                    val p = Offset(
                        center.x + cos(rad).toFloat() * radius * 0.85f * frac,
                        center.y + sin(rad).toFloat() * radius * 0.85f * frac,
                    )
                    drawCircle(
                        color = if (peer.needsHelp) Color(0xFFFF9F0A) else Color(0xFF30D158),
                        radius = 4.dp.toPx(),
                        center = p,
                    )
                }
            }
            if (needsHelp) {
                drawCircle(Color(0xFFFF9F0A).copy(alpha = 0.6f), radius = radius, center = center, style = Stroke(2.dp.toPx()))
            }
        }
        Text("N", color = WearColors.TextSecondary, fontSize = 8.sp, modifier = Modifier.align(Alignment.TopCenter))
        if (!enabled) {
            Text(
                "Ative no celular",
                color = WearColors.TextSecondary,
                fontSize = 9.sp,
                textAlign = TextAlign.Center,
            )
        }
    }
}
