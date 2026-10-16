package com.healthfit.android.ui.workouts

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Looper
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
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
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.SessionClockDial
import com.healthfit.android.ui.kite.KiteSpotBuddyEntryCard
import com.healthfit.android.ui.kite.KiteSpotBuddyHelpConfirmSheet
import com.healthfit.android.ui.kite.KiteSpotBuddyIncomingBanner
import com.healthfit.android.ui.kite.KiteSpotBuddyLiveMapScreen
import com.healthfit.android.ui.kite.KiteSpotBuddyService
import com.healthfit.android.workout.PhoneWorkoutSync
import com.healthfit.android.workout.WearRemoteAction
import com.healthfit.android.workout.WorkoutPresence
import com.healthfit.core.workout.WorkoutWearContract
import com.healthfit.designsystem.HealthFitColors
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlinx.coroutines.delay

fun cardioUsesLiveMap(title: String, detail: String = ""): Boolean {
    if (title.equals("Tênis", ignoreCase = true) || title.equals("Tenis", ignoreCase = true)) {
        // Outdoor surfaces only (iOS: surface.isOutdoor).
        return !detail.contains("indoor", ignoreCase = true) && !detail.contains("Carpete", ignoreCase = true)
    }
    return title in setOf(
        "Corrida",
        "Caminhada",
        "Bicicleta pedal",
        "Mountain bike",
        "Surf",
        "Kitesurf",
        "Remo",
    )
}

fun usesCardioLiveScreen(title: String, detail: String = ""): Boolean =
    cardioUsesLiveMap(title, detail) ||
        title.equals("Tênis", ignoreCase = true) ||
        title.equals("Tenis", ignoreCase = true)

@Composable
fun CardioLiveScreen(
    title: String,
    detail: String,
    onClose: (elapsedSeconds: Int, distanceKm: Double, paceLabel: String) -> Unit,
    spotBuddyEnabled: Boolean = false,
) {
    val context = LocalContext.current
    val showMap = cardioUsesLiveMap(title, detail)
    val isKitesurf = title.equals("Kitesurf", ignoreCase = true)
    val isTennis = title.equals("Tênis", ignoreCase = true) || title.equals("Tenis", ignoreCase = true)
    val firebaseReady = remember(context) { FirebaseApp.getApps(context).isNotEmpty() }
    // Spot Buddy needs Firebase; without google-services.json the session must still open.
    val buddyOn = spotBuddyEnabled && isKitesurf && firebaseReady
    val cycling = title.contains("bike", ignoreCase = true) || title.contains("Bicicleta pedal")
    var elapsed by remember { mutableIntStateOf(0) }
    var paused by remember { mutableStateOf(false) }
    var is3D by remember { mutableStateOf(false) }
    var locationOn by remember { mutableStateOf(hasLocationPermission(context)) }
    var showSpotMap by remember { mutableStateOf(false) }
    var confirmSos by remember { mutableStateOf(false) }
    var mySets by remember { mutableIntStateOf(0) }
    var oppSets by remember { mutableIntStateOf(0) }
    var myGames by remember { mutableIntStateOf(0) }
    var oppGames by remember { mutableIntStateOf(0) }
    var bursts by remember { mutableIntStateOf(0) }
    val route = remember { mutableStateListOf<Location>() }
    val buddy = remember { KiteSpotBuddyService.shared }
    val peers by buddy.peers.collectAsState()
    val needsHelp by buddy.needsHelp.collectAsState()
    val incomingHelp by buddy.incomingHelp.collectAsState()
    val mapsKeyOk = remember(context) { hasMapsApiKey(context) }
    val permission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        locationOn = result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    }

    DisposableEffect(buddyOn) {
        if (buddyOn) {
            val name = runCatching {
                FirebaseAuth.getInstance().currentUser?.displayName?.takeIf { it.isNotBlank() }
            }.getOrNull() ?: "Kiter"
            runCatching {
                buddy.start(sessionId = "kite-${System.currentTimeMillis()}", displayName = name)
            }
        }
        onDispose { if (buddyOn) runCatching { buddy.stop() } }
    }

    LaunchedEffect(paused) {
        while (!paused) {
            delay(1000)
            elapsed += 1
        }
    }
    LaunchedEffect(showMap) {
        if (showMap && !locationOn) {
            permission.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
            )
        }
    }
    DisposableEffect(locationOn, showMap, paused) {
        if (!showMap || !locationOn || paused) return@DisposableEffect onDispose { }
        val fused = LocationServices.getFusedLocationProviderClient(context)
        fun ingest(location: Location) {
            val last = route.lastOrNull()
            val gap = last?.distanceTo(location) ?: 0f
            when {
                last == null -> route.add(location)
                gap > 250f -> {
                    route.clear()
                    route.add(location)
                }
                gap >= 2f -> route.add(location)
            }
            if (buddyOn) buddy.updateLocation(location.latitude, location.longitude)
        }
        runCatching {
            fused.lastLocation.addOnSuccessListener { last ->
                if (last != null && route.isEmpty()) ingest(last)
            }
        }
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
            .setMinUpdateDistanceMeters(2f)
            .setMinUpdateIntervalMillis(800L)
            .build()
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let(::ingest)
            }
        }
        val fusedOk = runCatching {
            fused.requestLocationUpdates(request, callback, Looper.getMainLooper())
            true
        }.getOrDefault(false)
        val manager = context.getSystemService(LocationManager::class.java)
        val legacyListener = android.location.LocationListener { loc -> ingest(loc) }
        if (!fusedOk) {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .filter { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
                .forEach { provider ->
                    runCatching {
                        manager.getLastKnownLocation(provider)?.let { if (route.isEmpty()) ingest(it) }
                        manager.requestLocationUpdates(provider, 1000L, 2f, legacyListener, Looper.getMainLooper())
                    }
                }
        }
        onDispose {
            runCatching { fused.removeLocationUpdates(callback) }
            if (!fusedOk) runCatching { manager.removeUpdates(legacyListener) }
        }
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
    val stopFromWatch by rememberUpdatedState {
        onClose(elapsed, distanceKm, paceLabel)
    }
    LaunchedEffect(Unit) {
        PhoneWorkoutSync.remoteActions.collect { action ->
            when (action) {
                WearRemoteAction.Pause -> paused = true
                WearRemoteAction.Resume -> paused = false
                WearRemoteAction.Stop -> stopFromWatch()
            }
        }
    }
    WorkoutPresence(
        workoutTitle = detail,
        exerciseName = title,
        setsLabel = lockSets,
        elapsedSeconds = elapsed,
        resting = false,
        paused = paused,
        kind = WorkoutWearContract.KIND_CARDIO,
    )

    if (showSpotMap && buddyOn) {
        val last = route.lastOrNull()
        KiteSpotBuddyLiveMapScreen(
            myLat = last?.latitude,
            myLon = last?.longitude,
            onBack = { showSpotMap = false },
            onRequestHelp = { buddy.requestHelp() },
            onCancelHelp = { buddy.cancelHelp() },
        )
        return
    }

    // Scaffold já reserva a tab bar — não somar 88.dp (isso escondia o cronômetro sob área preta).
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState())
            .padding(bottom = 16.dp),
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
            RouteMap(
                points = route,
                is3D = is3D,
                showUser = locationOn && mapsKeyOk,
                mapsKeyOk = mapsKeyOk,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth()
                    .height(if (is3D) 220.dp else 180.dp),
            )
            val mapHint = when {
                !mapsKeyOk ->
                    "Mapa sem API key — adicione MAPS_API_KEY em local.properties e reinstale."
                !locationOn ->
                    "Ative a localização para gravar a rota e o ritmo."
                route.isEmpty() ->
                    "Buscando GPS… saia para área aberta se demorar."
                route.size < 2 ->
                    "Localização ok · aguardando movimento para traçar a rota."
                else -> null
            }
            if (mapHint != null) {
                Text(
                    mapHint,
                    color = if (!mapsKeyOk || !locationOn) HealthFitColors.AccentSecondary else HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }
        Column(
            Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            SessionClockDial(
                totalSeconds = elapsed,
                caption = if (paused) "Pausado" else "tempo real",
                accent = HealthFitColors.Accent,
                progress = (elapsed % 60) / 60f,
                paused = paused,
                size = if (showMap) 160.dp else 200.dp,
                modifier = Modifier.padding(top = 10.dp),
            )
            Text(
                detail,
                color = HealthFitColors.Accent,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 4.dp)
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
            if (isTennis) {
                Spacer(Modifier.height(14.dp))
                TennisScoreBoard(
                    mySets = mySets,
                    oppSets = oppSets,
                    myGames = myGames,
                    oppGames = oppGames,
                    bursts = bursts,
                    onMySets = { mySets = it.coerceIn(0, 5) },
                    onOppSets = { oppSets = it.coerceIn(0, 5) },
                    onMyGames = { myGames = it.coerceIn(0, 99) },
                    onOppGames = { oppGames = it.coerceIn(0, 99) },
                    onBurst = { bursts += 1 },
                )
            }
            if (buddyOn) {
                Spacer(Modifier.height(14.dp))
                incomingHelp?.let { help ->
                    KiteSpotBuddyIncomingBanner(
                        peer = help,
                        onOpen = {
                            showSpotMap = true
                            buddy.dismissIncomingHelp()
                        },
                        onDismiss = { buddy.dismissIncomingHelp() },
                    )
                    Spacer(Modifier.height(10.dp))
                }
                if (confirmSos) {
                    KiteSpotBuddyHelpConfirmSheet(
                        onConfirm = {
                            buddy.requestHelp()
                            confirmSos = false
                        },
                        onCancel = { confirmSos = false },
                    )
                } else {
                    KiteSpotBuddyEntryCard(
                        peers = peers,
                        needsHelp = needsHelp,
                        onOpenMap = { showSpotMap = true },
                        onRequestHelp = { confirmSos = true },
                        onCancelHelp = { buddy.cancelHelp() },
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
            GradientButton(
                text = if (paused) "Retomar" else "Pausar",
                onClick = { paused = !paused },
                icon = if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun TennisScoreBoard(
    mySets: Int,
    oppSets: Int,
    myGames: Int,
    oppGames: Int,
    bursts: Int,
    onMySets: (Int) -> Unit,
    onOppSets: (Int) -> Unit,
    onMyGames: (Int) -> Unit,
    onOppGames: (Int) -> Unit,
    onBurst: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Text("Placar", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TennisScoreColumn("Você", mySets, myGames, onMySets, onMyGames, Modifier.weight(1f))
            TennisScoreColumn("Adv.", oppSets, oppGames, onOppSets, onOppGames, Modifier.weight(1f))
        }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MetricTile("$bursts", "Picos", Modifier.weight(1f))
            MetricTile("$mySets–$oppSets", "Sets", Modifier.weight(1f))
            MetricTile("$myGames–$oppGames", "Games", Modifier.weight(1f))
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "Marcar pico",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(HealthFitColors.Accent.copy(alpha = 0.15f))
                .clickable(onClick = onBurst)
                .padding(vertical = 12.dp),
        )
    }
}

@Composable
private fun TennisScoreColumn(
    label: String,
    sets: Int,
    games: Int,
    onSets: (Int) -> Unit,
    onGames: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF141A1E))
            .padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, color = HealthFitColors.TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Text("Sets", color = HealthFitColors.TextSecondary, fontSize = 11.sp)
        StepperRow(sets, onSets)
        Spacer(Modifier.height(8.dp))
        Text("Games", color = HealthFitColors.TextSecondary, fontSize = 11.sp)
        StepperRow(games, onGames)
    }
}

@Composable
private fun StepperRow(value: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("−", color = HealthFitColors.Accent, fontSize = 22.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable { onChange(value - 1) }.padding(horizontal = 10.dp))
        Text("$value", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
        Text("+", color = HealthFitColors.Accent, fontSize = 22.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable { onChange(value + 1) }.padding(horizontal = 10.dp))
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
private fun RouteMap(
    points: List<Location>,
    is3D: Boolean,
    showUser: Boolean,
    mapsKeyOk: Boolean,
    modifier: Modifier = Modifier,
) {
    val fallback = LatLng(-23.5505, -46.6333) // São Paulo — evita câmera em (0,0) no oceano
    val latest = points.lastOrNull()
    val camera = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            latest?.let { LatLng(it.latitude, it.longitude) } ?: fallback,
            if (latest != null) 17f else 11f,
        )
    }
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
    Box(modifier) {
        if (!mapsKeyOk) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(16.dp))
                    .background(HealthFitColors.CardBackground)
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "Mapa indisponível\nConfigure MAPS_API_KEY",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        } else {
            GoogleMap(
                modifier = Modifier
                    .fillMaxSize()
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
                latest?.let { here ->
                    Marker(
                        state = MarkerState(LatLng(here.latitude, here.longitude)),
                        title = "Você",
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
    ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

private fun hasMapsApiKey(context: android.content.Context): Boolean = runCatching {
    val info = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
    val key = info.metaData?.getString("com.google.android.geo.API_KEY").orEmpty().trim()
    key.isNotEmpty() &&
        !key.contains("YOUR_", ignoreCase = true) &&
        !key.contains("REPLACE", ignoreCase = true) &&
        key != "null"
}.getOrDefault(false)

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
    title.contains("Escada") || title.contains("Escalada") || title.contains("Natação") ||
        title.contains("Tênis") || title.contains("Tenis", ignoreCase = true) -> 11.0
    title.contains("Corrida") || title.contains("Mountain") || title == "Remo" || title == "Surf" -> 10.0
    title.contains("Esteira") || title.contains("Polichinelo") || title.contains("pedal") -> 9.0
    title.contains("Caminhada") -> 6.0
    else -> 8.0
}
