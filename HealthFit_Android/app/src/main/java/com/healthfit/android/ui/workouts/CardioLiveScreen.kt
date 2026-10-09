package com.healthfit.android.ui.workouts

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.workout.WorkoutPresence
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlinx.coroutines.delay

fun cardioUsesLiveMap(title: String): Boolean = title in setOf(
    "Corrida",
    "Caminhada",
    "Bicicleta pedal",
    "Mountain bike",
    "Surf",
    "Kitesurf",
    "Remo",
)

@Composable
fun CardioLiveScreen(
    title: String,
    detail: String,
    onClose: (elapsedSeconds: Int, distanceKm: Double, paceLabel: String) -> Unit,
) {
    val context = LocalContext.current
    val showMap = cardioUsesLiveMap(title)
    val cycling = title.contains("bike", ignoreCase = true) || title.contains("Bicicleta pedal")
    var elapsed by remember { mutableIntStateOf(0) }
    var paused by remember { mutableStateOf(false) }
    var is3D by remember { mutableStateOf(false) }
    var locationOn by remember { mutableStateOf(hasLocationPermission(context)) }
    val route = remember { mutableStateListOf<Location>() }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        locationOn = granted
    }

    LaunchedEffect(paused) {
        while (!paused) {
            delay(1000)
            elapsed += 1
        }
    }
    LaunchedEffect(showMap) {
        if (showMap && !locationOn) permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
    }
    DisposableEffect(locationOn, showMap, paused) {
        if (!showMap || !locationOn || paused) return@DisposableEffect onDispose { }
        val manager = context.getSystemService(LocationManager::class.java)
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val last = route.lastOrNull()
                val gap = last?.distanceTo(location) ?: 0f
                when {
                    last == null -> route.add(location)
                    gap > 250f -> {
                        route.clear()
                        route.add(location)
                    }
                    gap >= 3f -> route.add(location)
                }
            }
            override fun onProviderDisabled(provider: String) = Unit
            override fun onProviderEnabled(provider: String) = Unit
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
        providers.forEach { provider ->
            runCatching {
                manager.getLastKnownLocation(provider)?.let { last ->
                    if (route.isEmpty()) route.add(last)
                }
                manager.requestLocationUpdates(provider, 1000L, 2f, listener)
            }
        }
        onDispose { runCatching { manager.removeUpdates(listener) } }
    }

    val distanceMeters = remember(route.size) { routeDistance(route) }
    val distanceKm = distanceMeters / 1000.0
    val paceSeconds = if (distanceKm >= 0.02) (elapsed / distanceKm).roundToInt() else null
    val paceLabel = paceSeconds?.let { formatPace(it) } ?: "—"
    val speedKmh = if (elapsed > 0) distanceKm / (elapsed / 3600.0) else 0.0
    val kcal = (kcalPerMinute(title) * intensityFactor(detail) * (elapsed / 60.0)).roundToInt()
    val steps = (distanceMeters / 0.75).roundToInt()
    val lockSets = when {
        paused -> "Pausado"
        showMap && cycling -> "%.2f km · %.1f km/h".format(distanceKm, speedKmh)
        showMap -> "%.2f km · %s /km".format(distanceKm, paceLabel)
        else -> detail
    }
    WorkoutPresence(
        workoutTitle = detail,
        exerciseName = title,
        setsLabel = lockSets,
        elapsedSeconds = elapsed,
        resting = paused,
    )

    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                "Minimizar",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable { onClose(elapsed, distanceKm, paceLabel) },
            )
            Spacer(Modifier.weight(1f))
            Text(
                "Encerrar",
                color = Color(0xFFE85D4C),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable { onClose(elapsed, distanceKm, paceLabel) },
            )
        }
        Text(title, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp))
        if (showMap) {
            Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MapModeChip("2D", !is3D) { is3D = false }
                MapModeChip("3D", is3D) { is3D = true }
            }
            if (is3D) {
                Text(
                    if (route.size >= 2) "3D: percurso no terreno" else "3D: vista inclinada do local",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            RouteMap(
                points = route,
                is3D = is3D,
                showUser = locationOn,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth()
                    .height(if (is3D) 300.dp else 260.dp),
            )
            if (!locationOn) {
                Text(
                    "O mapa precisa da localização para gravar a rota e o ritmo.",
                    color = HealthFitColors.AccentSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp),
                )
            } else if (route.size < 2) {
                Text(
                    "Aguardando pontos GPS da sessão.",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
        ) {
        Text(
            "%02d:%02d".format(elapsed / 60, elapsed % 60),
            color = if (paused) HealthFitColors.TextSecondary else Color.White,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            textAlign = TextAlign.Center,
        )
        Text(
            if (paused) "Treino pausado" else "Tempo em tempo real",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(
            detail,
            color = HealthFitColors.Accent,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 10.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(HealthFitColors.Accent.copy(alpha = 0.15f))
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
        Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MetricTile("—", "BPM", Modifier.weight(1f))
            MetricTile("$kcal", "kcal", Modifier.weight(1f))
            if (cycling) MetricTile("%.1f".format(speedKmh), "km/h", Modifier.weight(1f))
            else MetricTile(paceLabel, "Ritmo", Modifier.weight(1f))
        }
        if (showMap) {
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (cycling) MetricTile("%.1f".format(speedKmh), "km/h", Modifier.weight(1f))
                else MetricTile("$steps", "Passos", Modifier.weight(1f))
                MetricTile("%.2f".format(distanceKm), "km", Modifier.weight(1f))
                MetricTile("%02d:%02d".format(elapsed / 60, elapsed % 60), "Tempo", Modifier.weight(1f))
            }
        }
        Spacer(Modifier.height(14.dp))
        GradientButton(
            text = if (paused) "Retomar" else "Pausar",
            onClick = { paused = !paused },
            icon = if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
        )
        Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun MapModeChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 22.dp, vertical = 8.dp),
    )
}

@Composable
private fun MetricTile(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 11.sp)
    }
}

@Composable
private fun RouteMap(points: List<Location>, is3D: Boolean, showUser: Boolean, modifier: Modifier = Modifier) {
    val camera = rememberCameraPositionState {
        val here = points.lastOrNull()
        if (here != null) {
            position = CameraPosition.fromLatLngZoom(LatLng(here.latitude, here.longitude), 17f)
        }
    }
    val latest = points.lastOrNull()
    LaunchedEffect(latest?.latitude, latest?.longitude, is3D) {
        val here = latest ?: return@LaunchedEffect
        val previous = points.getOrNull(points.lastIndex - 1)
        val heading = if (previous != null) bearing(previous, here) else 0f
        camera.animate(
            CameraUpdateFactory.newCameraPosition(
                CameraPosition.Builder()
                    .target(LatLng(here.latitude, here.longitude))
                    .zoom(17f)
                    .tilt(if (is3D) 60f else 0f)
                    .bearing(if (is3D) heading else 0f)
                    .build(),
            ),
        )
    }
    GoogleMap(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp)),
        cameraPositionState = camera,
        properties = MapProperties(
            isMyLocationEnabled = showUser,
            mapType = if (is3D) MapType.HYBRID else MapType.NORMAL,
        ),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            myLocationButtonEnabled = showUser,
            compassEnabled = true,
            tiltGesturesEnabled = true,
        ),
    ) {
        if (points.size >= 2) {
            Polyline(
                points = points.map { LatLng(it.latitude, it.longitude) },
                color = HealthFitColors.Accent,
                width = 14f,
            )
        }
        points.firstOrNull()?.let { start ->
            Marker(
                state = MarkerState(LatLng(start.latitude, start.longitude)),
                title = "Início",
            )
        }
    }
}

private fun bearing(from: Location, to: Location): Float {
    val lat1 = Math.toRadians(from.latitude)
    val lat2 = Math.toRadians(to.latitude)
    val dLon = Math.toRadians(to.longitude - from.longitude)
    val y = sin(dLon) * cos(lat2)
    val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    return ((Math.toDegrees(atan2(y, x)) + 360.0) % 360.0).toFloat()
}

private fun hasLocationPermission(context: android.content.Context): Boolean =
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

private fun routeDistance(points: List<Location>): Double {
    var total = 0.0
    for (index in 1 until points.size) total += haversine(points[index - 1], points[index])
    return total
}

private fun haversine(a: Location, b: Location): Double {
    val r = 6_371_000.0
    val dLat = Math.toRadians(b.latitude - a.latitude)
    val dLon = Math.toRadians(b.longitude - a.longitude)
    val h = sin(dLat / 2).pow(2) + cos(Math.toRadians(a.latitude)) * cos(Math.toRadians(b.latitude)) * sin(dLon / 2).pow(2)
    return 2 * r * asin(sqrt(h))
}

private fun formatPace(secondsPerKm: Int): String {
    val clamped = secondsPerKm.coerceIn(45, 20 * 60)
    return "%d:%02d".format(clamped / 60, clamped % 60)
}

private fun intensityFactor(detail: String): Double = when {
    detail.contains("alta", ignoreCase = true) -> 1.35
    detail.contains("baixa", ignoreCase = true) -> 0.75
    else -> 1.0
}

private fun kcalPerMinute(title: String): Double = when {
    title.contains("Burpee") -> 13.0
    title.contains("Kitesurf") || title.contains("Corda") -> 12.0
    title.contains("Escada") || title.contains("Escalada") || title.contains("Natação") -> 11.0
    title.contains("Corrida") || title.contains("Mountain") || title == "Remo" || title == "Surf" -> 10.0
    title.contains("Esteira") || title.contains("Polichinelo") || title.contains("pedal") -> 9.0
    title.contains("Caminhada") -> 6.0
    else -> 8.0
}
