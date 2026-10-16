package com.healthfit.android.ui.kite

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Sos
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import com.healthfit.android.R
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

@Composable
fun KiteSpotBuddySetupCard(
    enabled: Boolean,
    onToggle: (Boolean) -> Unit,
    onShowConsent: () -> Unit,
) {
    androidx.compose.foundation.layout.Column(Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(168.dp)
                .clip(RoundedCornerShape(18.dp))
                .clickable {
                    if (enabled) onToggle(false) else onShowConsent()
                },
        ) {
            Image(
                painter = painterResource(R.drawable.kitespotbuddycover),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color.Black.copy(alpha = 0.15f),
                                Color.Black.copy(alpha = 0.55f),
                                Color.Black.copy(alpha = 0.88f),
                            ),
                        ),
                    ),
            )
            Icon(
                imageVector = if (enabled) Icons.Filled.CheckCircle else Icons.Filled.MyLocation,
                contentDescription = null,
                tint = if (enabled) HealthFitColors.Accent else Color.White.copy(alpha = 0.85f),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(14.dp)
                    .size(28.dp),
            )
            androidx.compose.foundation.layout.Column(
                Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text(
                    text = "Kite Spot Buddy",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                )
                Text(
                    text = KiteSpotBuddyPrivacy.shortLabel,
                    color = Color.White.copy(alpha = 0.9f),
                    fontSize = 12.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Row(
                    Modifier.padding(top = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    MetaChip(Icons.Filled.Group, "Amigos no spot")
                    MetaChip(Icons.Filled.Map, "Radar até 2 km")
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(HealthFitColors.CardBackground)
                .padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (enabled) "Ativo nesta sessão" else "Ativar nesta sessão",
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = enabled,
                onCheckedChange = { checked ->
                    if (checked) onShowConsent() else onToggle(false)
                },
                colors = SwitchDefaults.colors(
                    checkedTrackColor = HealthFitColors.Accent,
                    checkedThumbColor = Color.White,
                ),
            )
        }
    }
}

@Composable
private fun MetaChip(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = Color.Cyan, modifier = Modifier.size(14.dp))
        Text(text, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp))
    }
}

@Composable
fun KiteSpotBuddyConsentSheet(
    onAccept: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        Icon(Icons.Filled.Air, null, tint = HealthFitColors.Accent, modifier = Modifier.size(40.dp).align(Alignment.CenterHorizontally))
        Text(
            "Kite Spot Buddy",
            color = Color.White,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .padding(top = 16.dp)
                .align(Alignment.CenterHorizontally),
        )
        Text(
            KiteSpotBuddyPrivacy.clearNotice,
            color = HealthFitColors.TextSecondary,
            fontSize = 15.sp,
            modifier = Modifier.padding(top = 16.dp),
        )
        Text(
            "Somente kitesurf · somente durante a sessão · opt-in separado do Duo.",
            color = Color.Cyan,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 16.dp),
        )
        Spacer(Modifier.height(28.dp))
        GradientButton("Li e concordo — ativar Spot Buddy", onClick = onAccept)
        Text(
            "Agora não",
            color = HealthFitColors.TextSecondary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 14.dp)
                .fillMaxWidth()
                .clickable(onClick = onCancel)
                .padding(vertical = 12.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
fun KiteSpotBuddyHelpConfirmSheet(
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color(0xFF2A1515))
            .padding(16.dp),
    ) {
        Text("Confirmar pedido de ajuda?", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(
            "Amigos com Spot Buddy ativo no radar (até 2 km) recebem um alerta com sua distância aproximada.",
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        Spacer(Modifier.height(14.dp))
        Text(
            "Enviar pedido de ajuda",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFFB3261E))
                .clickable(onClick = onConfirm)
                .padding(vertical = 14.dp),
        )
        Text(
            "Cancelar",
            color = HealthFitColors.TextSecondary,
            fontWeight = FontWeight.SemiBold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onCancel)
                .padding(vertical = 12.dp),
        )
    }
}

@Composable
fun KiteSpotBuddyIncomingBanner(
    peer: KiteSpotBuddyPeer,
    onOpen: () -> Unit,
    onDismiss: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xE0B3261E))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Warning, null, tint = Color.White)
        Column(Modifier.padding(start = 8.dp).weight(1f)) {
            Text("${peer.displayName} pediu ajuda", color = Color.White, fontWeight = FontWeight.Bold)
            Text("A ~${formatDistance(peer.distanceMeters)} de você", color = Color.White.copy(alpha = 0.85f), fontSize = 12.sp)
        }
        Text(
            "Entendi",
            color = Color.Black,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .clickable(onClick = onOpen)
                .padding(horizontal = 12.dp, vertical = 8.dp),
        )
        Text(
            "Ignorar",
            color = Color.White,
            modifier = Modifier
                .padding(start = 8.dp)
                .clickable(onClick = onDismiss)
                .padding(8.dp),
        )
    }
}

@Composable
fun KiteSpotBuddyEntryCard(
    peers: List<KiteSpotBuddyPeer>,
    needsHelp: Boolean,
    onOpenMap: () -> Unit,
    onRequestHelp: () -> Unit,
    onCancelHelp: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Kite Spot Buddy", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text(
                "${peers.size} no alcance",
                color = Color.Cyan,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
        if (needsHelp) {
            Text(
                "Pedido de ajuda enviado",
                color = Color(0xFFFF8A80),
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
        Text(
            if (peers.isEmpty()) "Nenhum amigo no spot (radar 2 km)" else peers.joinToString(" · ") {
                "${it.displayName} · ${formatDistance(it.distanceMeters)}"
            },
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
        MiniRadar(peers, Modifier
            .padding(top = 10.dp)
            .fillMaxWidth()
            .height(120.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFF0E2438)))
        Row(
            Modifier.padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "Abrir mapa",
                color = Color.Black,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(HealthFitColors.Accent)
                    .clickable(onClick = onOpenMap)
                    .padding(vertical = 12.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            Text(
                if (needsHelp) "Estou bem — cancelar ajuda" else "SOS",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = if (needsHelp) 12.sp else 14.sp,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (needsHelp) Color(0xFF2E7D32) else Color(0xFFB3261E))
                    .clickable { if (needsHelp) onCancelHelp() else onRequestHelp() }
                    .padding(vertical = 12.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}

@Composable
fun KiteSpotBuddyLiveMapScreen(
    myLat: Double?,
    myLon: Double?,
    onBack: () -> Unit,
    onRequestHelp: () -> Unit,
    onCancelHelp: () -> Unit,
) {
    val service = remember { KiteSpotBuddyService.shared }
    val peers by service.peers.collectAsState()
    val needsHelp by service.needsHelp.collectAsState()
    val incoming by service.incomingHelp.collectAsState()
    var confirmSos by remember { mutableStateOf(false) }

    val center = if (myLat != null && myLon != null) LatLng(myLat, myLon) else LatLng(-27.595, -48.548)
    val camera = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(center, 14.5f)
    }

    Box(Modifier.fillMaxSize().background(HealthFitColors.Background)) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = camera,
            properties = MapProperties(mapType = MapType.SATELLITE, isMyLocationEnabled = myLat != null),
            uiSettings = MapUiSettings(zoomControlsEnabled = false, myLocationButtonEnabled = true),
        ) {
            if (myLat != null && myLon != null) {
                Marker(state = MarkerState(LatLng(myLat, myLon)), title = "Você")
            }
            peers.forEach { peer ->
                Marker(
                    state = MarkerState(LatLng(peer.latitude, peer.longitude)),
                    title = peer.displayName,
                    snippet = formatDistance(peer.distanceMeters) + if (peer.needsHelp) " · AJUDA" else "",
                )
            }
        }

        Column(
            Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopCenter),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color(0xE01A1E22))
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "Fechar",
                    tint = Color.White,
                    modifier = Modifier
                        .clip(CircleShape)
                        .clickable(onClick = onBack)
                        .padding(4.dp),
                )
                Column(Modifier.padding(start = 10.dp).weight(1f)) {
                    Text("Kite Spot Buddy", color = Color.White, fontWeight = FontWeight.Bold)
                    Text("${peers.size} amigos · radar 2 km", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
                }
            }
            incoming?.let { help ->
                Row(
                    Modifier
                        .padding(top = 8.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color(0xE0B3261E))
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Warning, null, tint = Color.White)
                    Column(Modifier.padding(start = 8.dp).weight(1f)) {
                        Text("${help.displayName} pediu ajuda", color = Color.White, fontWeight = FontWeight.Bold)
                        Text(formatDistance(help.distanceMeters), color = Color.White.copy(alpha = 0.85f), fontSize = 12.sp)
                    }
                    Text(
                        "Ir",
                        color = Color.Black,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White)
                            .clickable {
                                camera.position = CameraPosition.fromLatLngZoom(
                                    LatLng(help.latitude, help.longitude),
                                    16f,
                                )
                                service.dismissIncomingHelp()
                            }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    )
                    Text(
                        "Ignorar",
                        color = Color.White,
                        modifier = Modifier
                            .padding(start = 8.dp)
                            .clickable { service.dismissIncomingHelp() }
                            .padding(8.dp),
                    )
                }
            }
        }

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(16.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Color(0xF01A1E22))
                .padding(14.dp),
        ) {
            peers.take(4).forEach { peer ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clickable {
                            camera.position = CameraPosition.fromLatLngZoom(
                                LatLng(peer.latitude, peer.longitude),
                                16f,
                            )
                        },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(if (peer.needsHelp) Color(0xFFFF3B30) else Color.Cyan),
                    )
                    Text(
                        peer.displayName,
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 8.dp).weight(1f),
                    )
                    Text(formatDistance(peer.distanceMeters), color = HealthFitColors.TextSecondary, fontSize = 12.sp)
                    peer.bearingDegrees?.let {
                        Text(" · ${it.toInt()}°", color = Color.Cyan, fontSize = 12.sp)
                    }
                }
            }
            if (peers.isEmpty()) {
                Text("Nenhum amigo no alcance", color = HealthFitColors.TextSecondary, fontSize = 13.sp)
            }
            Spacer(Modifier.height(10.dp))
            if (confirmSos) {
                Text("Enviar pedido de ajuda aos amigos no spot?", color = Color.White, fontWeight = FontWeight.SemiBold)
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Enviar pedido de ajuda",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color(0xFFB3261E))
                            .clickable {
                                onRequestHelp()
                                confirmSos = false
                            }
                            .padding(vertical = 12.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    Text(
                        "Cancelar",
                        color = Color.White,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(HealthFitColors.CardBackground)
                            .clickable { confirmSos = false }
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                    )
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (needsHelp) Color(0xFF2E7D32) else Color(0xFFB3261E))
                            .clickable {
                                if (needsHelp) onCancelHelp() else confirmSos = true
                            }
                            .padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            if (needsHelp) Icons.Filled.CheckCircle else Icons.Filled.Sos,
                            null,
                            tint = Color.White,
                            modifier = Modifier.size(18.dp),
                        )
                        Text(
                            if (needsHelp) "Estou bem" else "Ajuda",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(start = 6.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MiniRadar(peers: List<KiteSpotBuddyPeer>, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val r = min(size.width, size.height) * 0.42f
        drawCircle(Color.Cyan.copy(alpha = 0.15f), radius = r, center = Offset(cx, cy))
        drawCircle(Color.Cyan.copy(alpha = 0.35f), radius = r, center = Offset(cx, cy), style = Stroke(1.5f))
        drawCircle(Color.Cyan.copy(alpha = 0.25f), radius = r * 0.66f, center = Offset(cx, cy), style = Stroke(1f))
        drawCircle(Color.Cyan.copy(alpha = 0.25f), radius = r * 0.33f, center = Offset(cx, cy), style = Stroke(1f))
        drawCircle(Color.Cyan, radius = 5f, center = Offset(cx, cy))
        peers.take(8).forEach { peer ->
            val bearing = peer.bearingDegrees ?: 0.0
            val ratio = (peer.distanceMeters / KiteSpotBuddyGeo.maxRadarMeters).coerceIn(0.0, 1.0)
            val rad = Math.toRadians(bearing - 90.0)
            val px = cx + cos(rad).toFloat() * (r * ratio.toFloat())
            val py = cy + sin(rad).toFloat() * (r * ratio.toFloat())
            drawCircle(
                if (peer.needsHelp) Color(0xFFFF3B30) else Color.White,
                radius = 6f,
                center = Offset(px, py),
            )
        }
    }
}

private fun formatDistance(meters: Double): String =
    if (meters < 1000) "${meters.toInt()} m" else "%.1f km".format(meters / 1000.0)
