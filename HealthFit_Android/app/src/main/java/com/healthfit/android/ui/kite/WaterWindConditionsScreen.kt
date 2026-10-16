package com.healthfit.android.ui.kite

import android.Manifest
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.launch

/**
 * Pre-start sheet (iOS WaterWindConditionsView parity): review Open-Meteo wind/tide
 * before starting Surf or Kitesurf.
 */
@Composable
fun WaterWindConditionsScreen(
    isKitesurf: Boolean,
    preferredSpot: WaterSpotInfo,
    startButtonTitle: String,
    onStart: (WindTideSnapshot?) -> Unit,
    onCancel: () -> Unit,
) {
    BackHandler(onBack = onCancel)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var snapshot by remember { mutableStateOf<WindTideSnapshot?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var label by remember { mutableStateOf(preferredSpot.name.ifBlank { "Localizando…" }) }

    fun load(forceLat: Double? = null, forceLon: Double? = null, forceLabel: String? = null) {
        val lat = forceLat ?: preferredSpot.latitude
        val lon = forceLon ?: preferredSpot.longitude
        if (lat == null || lon == null) {
            error = "Ative o GPS no setup para ler vento e maré no spot."
            return
        }
        loading = true
        error = null
        scope.launch {
            val result = OpenMeteoWindService.fetch(lat, lon, forceLabel ?: preferredSpot.name.ifBlank { "Spot" })
            loading = false
            result.onSuccess {
                snapshot = it
                label = it.locationLabel
            }.onFailure {
                error = it.message ?: "Falha ao buscar vento e maré"
            }
        }
    }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            resolveGps(context) { spot ->
                label = spot.name.ifBlank { "GPS" }
                load(spot.latitude, spot.longitude, spot.name)
            }
        } else {
            error = "Permissão de localização negada"
        }
    }

    LaunchedEffect(preferredSpot.latitude, preferredSpot.longitude) {
        if (preferredSpot.hasCoordinates) {
            load()
        } else if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        ) {
            resolveGps(context) { spot ->
                label = spot.name.ifBlank { "GPS" }
                load(spot.latitude, spot.longitude, spot.name)
            }
        } else {
            permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(top = 10.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Fechar",
                color = HealthFitColors.TextSecondary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onCancel),
            )
            Spacer(Modifier.weight(1f))
            Text(
                if (isKitesurf) "Vento e maré — Kitesurf" else "Vento e maré — Surf",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp,
            )
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.size(48.dp))
        }

        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(HealthFitColors.CardBackground)
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.Air,
                contentDescription = null,
                tint = HealthFitColors.Accent,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(HealthFitColors.Accent.copy(alpha = 0.2f))
                    .padding(12.dp),
            )
            Column(Modifier.padding(start = 12.dp)) {
                Text(
                    if (isKitesurf) "Vento e maré — Kitesurf" else "Vento e maré — Surf",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Open-Meteo (vento + Marine): altura real estimada com sua localização.",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        Text(label, color = Color.White, fontWeight = FontWeight.SemiBold)
        snapshot?.beachSportMessage(isKitesurf)?.let {
            Text(
                it,
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        Text(
            "Condições atualizadas. Revise e inicie quando estiver pronto.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
        )

        WindTideConditionsCard(
            snapshot = snapshot,
            loading = loading,
            error = error,
            isKitesurf = isKitesurf,
            onRefresh = {
                if (preferredSpot.hasCoordinates) load(forceLat = preferredSpot.latitude, forceLon = preferredSpot.longitude)
                else if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                    == PackageManager.PERMISSION_GRANTED
                ) {
                    resolveGps(context) { spot -> load(spot.latitude, spot.longitude, spot.name) }
                } else {
                    permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            },
        )

        Spacer(Modifier.height(18.dp))
        GradientButton(
            text = startButtonTitle,
            onClick = { onStart(snapshot) },
            icon = Icons.Filled.PlayArrow,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Iniciar mesmo sem atualizar",
            color = HealthFitColors.TextSecondary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .clickable { onStart(snapshot) }
                .padding(vertical = 14.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
    }
}

private fun resolveGps(context: android.content.Context, onResult: (WaterSpotInfo) -> Unit) {
    val manager = context.getSystemService(LocationManager::class.java) ?: return
    val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
    val loc = providers.firstNotNullOfOrNull { p ->
        runCatching { manager.getLastKnownLocation(p) }.getOrNull()
    }
    if (loc != null) {
        onResult(WaterSpotInfo(name = "Spot GPS", latitude = loc.latitude, longitude = loc.longitude))
    } else {
        // Florianópolis fallback (same as iOS)
        onResult(WaterSpotInfo(name = "Florianópolis", latitude = -27.5954, longitude = -48.5480))
    }
}
