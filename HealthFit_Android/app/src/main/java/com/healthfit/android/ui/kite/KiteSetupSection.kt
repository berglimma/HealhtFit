package com.healthfit.android.ui.kite

import android.Manifest
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MyLocation
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.healthfit.designsystem.HealthFitColors
import java.util.Locale
import kotlinx.coroutines.launch

@Composable
fun KiteSetupSection(
    setup: KiteSessionSetup,
    onSetupChange: (KiteSessionSetup) -> Unit,
    onRequestConsent: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var boardSearch by remember { mutableStateOf("") }
    var useGps by remember { mutableStateOf(setup.spot.hasCoordinates) }
    var wind by remember { mutableStateOf<WindTideSnapshot?>(null) }
    var loadingWind by remember { mutableStateOf(false) }
    var windError by remember { mutableStateOf<String?>(null) }
    var locationStatus by remember { mutableStateOf("") }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) refreshLocation(context, useGps) { spot, status ->
            locationStatus = status
            onSetupChange(setup.copy(spot = spot))
            if (spot.hasCoordinates) {
                scope.launch { loadWind(spot) { s, e, l -> wind = s; windError = e; loadingWind = l } }
            }
        } else {
            locationStatus = "Permissão de localização negada"
        }
    }

    fun requestWind(force: Boolean = false) {
        val spot = setup.spot
        if (!spot.hasCoordinates) {
            refreshLocation(context, true) { newSpot, status ->
                locationStatus = status
                useGps = true
                onSetupChange(setup.copy(spot = newSpot))
                if (newSpot.hasCoordinates) {
                    scope.launch {
                        loadWind(newSpot) { s, e, l ->
                            wind = s
                            windError = e
                            loadingWind = l
                            s?.let {
                                onSetupChange(
                                    setup.copy(
                                        spot = newSpot,
                                        windSummary = "${it.windSpeedKmh.toInt()} km/h ${it.windLabel}",
                                        tideSummary = it.estimatedTideLabel,
                                    ),
                                )
                            }
                        }
                    }
                } else if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            }
            return
        }
        if (!force && wind != null) return
        scope.launch {
            loadWind(spot) { s, e, l ->
                wind = s
                windError = e
                loadingWind = l
                s?.let {
                    onSetupChange(
                        setup.copy(
                            windSummary = "${it.windSpeedKmh.toInt()} km/h ${it.windLabel}",
                            tideSummary = it.estimatedTideLabel,
                        ),
                    )
                }
            }
        }
    }

    LaunchedEffect(Unit) {
        if (KiteSpotBuddyPreferences.isEnabledForNextSession(context) && KiteSpotBuddyPreferences.hasConsent(context)) {
            onSetupChange(setup.copy(spotBuddyEnabled = true))
        }
        requestWind()
    }

    Text("Setup Kitesurf", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 18.dp))

    Text("1. Tipo de equipamento (kite)", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    DetailOptionGrid(
        items = KiteEquipmentType.entries.map { it.title to it.detail },
        selected = setup.equipment.title,
    ) { title ->
        onSetupChange(setup.copy(equipment = KiteEquipmentType.entries.first { it.title == title }))
    }

    Text("2. Modo de velejo", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    KiteRidingMode.entries.forEach { mode ->
        SelectRow(
            title = mode.title,
            detail = mode.detail,
            selected = setup.ridingMode == mode,
        ) { onSetupChange(setup.copy(ridingMode = mode)) }
        Spacer(Modifier.height(8.dp))
    }

    Text("3. Tipo de prancha", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp, bottom = 8.dp))
    SearchField(boardSearch, "Buscar prancha…") { boardSearch = it }
    Spacer(Modifier.height(8.dp))
    WaterBoard.kiteBoards
        .filter { boardSearch.isBlank() || it.title.contains(boardSearch, true) || it.detail.contains(boardSearch, true) }
        .forEach { board ->
            SelectRow(board.title, board.detail, setup.board == board) {
                onSetupChange(setup.copy(board = board))
            }
            Spacer(Modifier.height(8.dp))
        }

    Text("4. SPOT de partida", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp, bottom = 8.dp))
    SearchField(setup.spot.name, "Nome do local / praia / spot") {
        onSetupChange(setup.copy(spot = setup.spot.copy(name = it)))
    }
    Spacer(Modifier.height(8.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(HealthFitColors.CardBackground)
            .clickable {
                useGps = !useGps
                if (useGps) {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                    } else {
                        refreshLocation(context, true) { spot, status ->
                            locationStatus = status
                            onSetupChange(setup.copy(spot = spot))
                            requestWind(force = true)
                        }
                    }
                }
            }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Sincronizar partida com GPS (mapa)",
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        if (useGps) Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent)
    }
    if (setup.spot.hasCoordinates) {
        Text(
            "GPS: %.5f, %.5f".format(setup.spot.latitude, setup.spot.longitude),
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
    } else if (locationStatus.isNotBlank()) {
        Text(locationStatus, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                } else {
                    refreshLocation(context, true) { spot, status ->
                        locationStatus = status
                        useGps = true
                        onSetupChange(setup.copy(spot = spot))
                        requestWind(force = true)
                    }
                }
            }
            .padding(vertical = 6.dp),
    ) {
        Icon(Icons.Filled.MyLocation, null, tint = HealthFitColors.Accent, modifier = Modifier.padding(end = 6.dp))
        Text("Atualizar localização", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }

    Spacer(Modifier.height(14.dp))
    WindTideConditionsCard(
        snapshot = wind,
        loading = loadingWind,
        error = windError,
        isKitesurf = true,
        onRefresh = { requestWind(force = true) },
    )

    Spacer(Modifier.height(16.dp))
    KiteSpotBuddySetupCard(
        enabled = setup.spotBuddyEnabled,
        onToggle = {
            onSetupChange(setup.copy(spotBuddyEnabled = it))
            KiteSpotBuddyPreferences.setEnabledForNextSession(context, it)
        },
        onShowConsent = {
            if (KiteSpotBuddyPreferences.hasConsent(context)) {
                onSetupChange(setup.copy(spotBuddyEnabled = true))
                KiteSpotBuddyPreferences.setEnabledForNextSession(context, true)
            } else {
                onRequestConsent()
            }
        },
    )
    Text(
        "No treino: altura de saltos via sensores do watch + celular, pontos no mapa e Spot Buddy.",
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 12.dp),
    )
}

@Composable
fun SurfSetupSection(
    setup: SurfSessionSetup,
    onSetupChange: (SurfSessionSetup) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var boardSearch by remember { mutableStateOf("") }
    var useGps by remember { mutableStateOf(setup.spot.hasCoordinates) }
    var wind by remember { mutableStateOf<WindTideSnapshot?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var locationStatus by remember { mutableStateOf("") }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            refreshLocation(context, true) { spot, status ->
                locationStatus = status
                onSetupChange(setup.copy(spot = spot.copy(name = setup.spot.name.ifBlank { spot.name })))
                if (spot.hasCoordinates) {
                    scope.launch {
                        loadWind(spot) { s, e, l ->
                            wind = s; error = e; loading = l
                            s?.let {
                                onSetupChange(
                                    setup.copy(
                                        spot = spot.copy(name = setup.spot.name.ifBlank { spot.name }),
                                        windSummary = "${it.windSpeedKmh.toInt()} km/h ${it.windLabel}",
                                        tideSummary = it.estimatedTideLabel,
                                    ),
                                )
                            }
                        }
                    }
                }
            }
        } else {
            locationStatus = "Permissão de localização negada"
        }
    }

    fun requestWind(force: Boolean = false) {
        val spot = setup.spot
        if (!spot.hasCoordinates) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                return
            }
            refreshLocation(context, true) { newSpot, status ->
                locationStatus = status
                useGps = true
                val merged = newSpot.copy(name = setup.spot.name.ifBlank { newSpot.name })
                onSetupChange(setup.copy(spot = merged))
                if (merged.hasCoordinates) {
                    scope.launch {
                        loadWind(merged) { s, e, l ->
                            wind = s; error = e; loading = l
                            s?.let {
                                onSetupChange(
                                    setup.copy(
                                        spot = merged,
                                        windSummary = "${it.windSpeedKmh.toInt()} km/h ${it.windLabel}",
                                        tideSummary = it.estimatedTideLabel,
                                    ),
                                )
                            }
                        }
                    }
                }
            }
            return
        }
        if (!force && wind != null) return
        scope.launch {
            loadWind(spot) { s, e, l ->
                wind = s; error = e; loading = l
                s?.let {
                    onSetupChange(
                        setup.copy(
                            windSummary = "${it.windSpeedKmh.toInt()} km/h ${it.windLabel}",
                            tideSummary = it.estimatedTideLabel,
                        ),
                    )
                }
            }
        }
    }

    LaunchedEffect(Unit) { requestWind() }

    Text("Setup Surf", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 18.dp))
    Text("Tipo de prancha", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    SearchField(boardSearch, "Buscar prancha…") { boardSearch = it }
    Spacer(Modifier.height(8.dp))
    WaterBoard.surfBoards
        .filter { boardSearch.isBlank() || it.title.contains(boardSearch, true) || it.detail.contains(boardSearch, true) }
        .forEach { board ->
            SelectRow(board.title, board.detail, setup.board == board) {
                onSetupChange(setup.copy(board = board))
            }
            Spacer(Modifier.height(8.dp))
        }

    Text("SPOT de partida", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp, bottom = 8.dp))
    SearchField(setup.spot.name, "Nome do local / praia / spot") {
        onSetupChange(setup.copy(spot = setup.spot.copy(name = it)))
    }
    Spacer(Modifier.height(8.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(HealthFitColors.CardBackground)
            .clickable {
                useGps = !useGps
                if (useGps) {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                    } else {
                        requestWind(force = true)
                    }
                }
            }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Sincronizar partida com GPS (mapa)",
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        if (useGps) Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent)
    }
    if (setup.spot.hasCoordinates) {
        Text(
            "GPS: %.5f, %.5f".format(setup.spot.latitude, setup.spot.longitude),
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
    } else if (locationStatus.isNotBlank()) {
        Text(locationStatus, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable { requestWind(force = true) }
            .padding(vertical = 6.dp),
    ) {
        Icon(Icons.Filled.MyLocation, null, tint = HealthFitColors.Accent, modifier = Modifier.padding(end = 6.dp))
        Text("Atualizar localização", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }

    Spacer(Modifier.height(14.dp))
    WindTideConditionsCard(
        snapshot = wind,
        loading = loading,
        error = error,
        isKitesurf = false,
        onRefresh = { requestWind(force = true) },
    )
}

@Composable
private fun DetailOptionGrid(items: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { (title, detail) ->
                    val on = title == selected
                    Column(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (on) HealthFitColors.Accent.copy(alpha = 0.2f) else HealthFitColors.CardBackground)
                            .border(if (on) 1.5.dp else 0.dp, if (on) HealthFitColors.Accent else Color.Transparent, RoundedCornerShape(12.dp))
                            .clickable { onSelect(title) }
                            .padding(10.dp),
                    ) {
                        Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        Text(detail, color = HealthFitColors.TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun SelectRow(title: String, detail: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) HealthFitColors.Accent.copy(alpha = 0.12f) else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Text(detail, color = HealthFitColors.TextSecondary, fontSize = 11.sp)
        }
        if (selected) Icon(Icons.Filled.CheckCircle, null, tint = HealthFitColors.Accent)
    }
}

@Composable
private fun SearchField(value: String, hint: String, onChange: (String) -> Unit) {
    BasicTextField(
        value = value,
        onValueChange = onChange,
        singleLine = true,
        textStyle = TextStyle(color = Color.White, fontSize = 14.sp),
        cursorBrush = SolidColor(HealthFitColors.Accent),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(HealthFitColors.CardBackground)
            .padding(12.dp),
        decorationBox = { inner ->
            if (value.isEmpty()) Text(hint, color = HealthFitColors.TextSecondary, fontSize = 14.sp)
            inner()
        },
    )
}

private suspend fun loadWind(
    spot: WaterSpotInfo,
    emit: (WindTideSnapshot?, String?, Boolean) -> Unit,
) {
    val lat = spot.latitude ?: return
    val lon = spot.longitude ?: return
    emit(null, null, true)
    val label = spot.name.ifBlank { "Localização GPS" }
    val result = OpenMeteoWindService.fetch(lat, lon, label)
    result.fold(
        onSuccess = { emit(it, null, false) },
        onFailure = { emit(null, it.message ?: "Falha ao buscar vento e maré", false) },
    )
}

private fun refreshLocation(
    context: android.content.Context,
    enabled: Boolean,
    onResult: (WaterSpotInfo, String) -> Unit,
) {
    if (!enabled) {
        onResult(WaterSpotInfo(), "GPS desligado")
        return
    }
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        != PackageManager.PERMISSION_GRANTED
    ) {
        onResult(WaterSpotInfo(), "Aguardando permissão de localização…")
        return
    }
    val manager = context.getSystemService(LocationManager::class.java)
    val location: Location? = manager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
        ?: manager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
    if (location == null) {
        onResult(WaterSpotInfo(), "Buscando GPS…")
        return
    }
    val name = runCatching {
        if (!Geocoder.isPresent()) return@runCatching null
        @Suppress("DEPRECATION")
        Geocoder(context, Locale("pt", "BR"))
            .getFromLocation(location.latitude, location.longitude, 1)
            ?.firstOrNull()
            ?.let { it.subLocality ?: it.locality ?: it.featureName }
    }.getOrNull()
    onResult(
        WaterSpotInfo(
            name = name.orEmpty(),
            latitude = location.latitude,
            longitude = location.longitude,
        ),
        "Localização atualizada",
    )
}
