package com.healthfit.wear

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Sensores locais do relógio durante sessões solo: batimentos, kcal (estimativa),
 * acelerômetro/saltos, altímetro (pressão) e GPS (rota/distância).
 */
object WatchSensorHub : SensorEventListener, LocationListener {
    private val main = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var sensorManager: SensorManager? = null
    private var locationManager: LocationManager? = null
    private var running = false
    private var paused = false

    private var kind = SessionKind.Strength
    private var isWater = false
    private var usesGps = false
    private var speedLabelMode = true

    private var lastCaloriesAt = 0L
    private var lastAccelPublish = 0L
    private var freeFallStart = 0L
    private var basePressure = 0f
    private var lastLocation: Location? = null

    private val calorieTicker = object : Runnable {
        override fun run() {
            if (!running) return
            tickCalories()
            main.postDelayed(this, 1000L)
        }
    }

    fun start(ctx: Context, session: ActiveSession) {
        stop()
        val app = ctx.applicationContext
        context = app
        kind = session.kind
        isWater = session.isWaterSport
        usesGps = session.kind == SessionKind.Cardio && shouldUseGps(session)
        speedLabelMode = !(session.title == "Corrida" || session.title == "Caminhada")
        paused = false
        running = true
        lastCaloriesAt = System.currentTimeMillis()
        basePressure = 0f
        freeFallStart = 0L
        lastLocation = null

        val sm = app.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = sm

        if (hasPermission(app, Manifest.permission.BODY_SENSORS)) {
            sm.getDefaultSensor(Sensor.TYPE_HEART_RATE)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }
        if (isWater) {
            sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            sm.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }
        if (usesGps) startGps(app)
        main.postDelayed(calorieTicker, 1000L)
    }

    fun setPaused(value: Boolean) {
        paused = value
        lastCaloriesAt = System.currentTimeMillis()
    }

    fun stop() {
        if (!running && sensorManager == null) return
        running = false
        main.removeCallbacks(calorieTicker)
        sensorManager?.unregisterListener(this)
        try {
            locationManager?.removeUpdates(this)
        } catch (_: SecurityException) {
        }
        sensorManager = null
        locationManager = null
        lastLocation = null
    }

    private fun shouldUseGps(session: ActiveSession): Boolean = session.isWaterSport || session.title in OUTDOOR

    @Suppress("MissingPermission")
    private fun startGps(app: Context) {
        if (!hasPermission(app, Manifest.permission.ACCESS_FINE_LOCATION)) {
            LocalWatchSession.updateMetrics { it.copy(syncStatus = "GPS Watch sem permissão") }
            return
        }
        val lm = app.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        locationManager = lm
        if (!lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) return
        lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 1f, this, Looper.getMainLooper())
        LocalWatchSession.updateMetrics { it.copy(syncStatus = "GPS Watch ativo") }
    }

    private fun hasPermission(ctx: Context, permission: String) =
        ContextCompat.checkSelfPermission(ctx, permission) == PackageManager.PERMISSION_GRANTED

    private fun tickCalories() {
        val now = System.currentTimeMillis()
        val dtMin = (now - lastCaloriesAt) / 60_000.0
        lastCaloriesAt = now
        if (paused) return
        LocalWatchSession.updateMetrics { s ->
            val perMinute = if (s.heartRate > 40) {
                ((-55.0969 + 0.6309 * s.heartRate + 0.1988 * 70 + 0.2017 * 30) / 4.184).coerceAtLeast(1.0)
            } else {
                val met = when {
                    s.kind == SessionKind.Meditation -> 1.3
                    s.kind == SessionKind.Strength -> 5.0
                    s.isSwimming -> 8.0
                    s.isWaterSport -> 6.0
                    else -> 8.0
                }
                met * 3.5 * 70 / 200.0
            }
            s.copy(calories = s.calories + perMinute * dtMin)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!running) return
        when (event.sensor.type) {
            Sensor.TYPE_HEART_RATE -> {
                val bpm = event.values[0].toInt()
                if (bpm > 0) LocalWatchSession.updateMetrics { it.copy(heartRate = bpm) }
            }
            Sensor.TYPE_ACCELEROMETER -> handleAccel(event)
            Sensor.TYPE_PRESSURE -> {
                val p = event.values[0]
                if (basePressure == 0f) basePressure = p
                val alt = 44330.0 * (1.0 - (p / basePressure).toDouble().pow(1.0 / 5.255))
                LocalWatchSession.updateMetrics { it.copy(relativeAltM = alt) }
            }
        }
    }

    private fun handleAccel(event: SensorEvent) {
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val mag = sqrt(x * x + y * y + z * z)
        val now = System.currentTimeMillis()
        if (now - lastAccelPublish > 500L) {
            lastAccelPublish = now
            LocalWatchSession.updateMetrics { it.copy(liveAccelG = (mag / SensorManager.GRAVITY_EARTH).toDouble()) }
        }
        if (paused) return
        // Queda livre (≈0 g) seguida de impacto = salto; altura = g·t²/8.
        if (mag < FREE_FALL_THRESHOLD) {
            if (freeFallStart == 0L) freeFallStart = now
        } else if (freeFallStart != 0L) {
            val flightMs = now - freeFallStart
            freeFallStart = 0L
            if (flightMs in MIN_FLIGHT_MS..MAX_FLIGHT_MS) {
                val t = flightMs / 1000.0
                val height = SensorManager.GRAVITY_EARTH * t * t / 8.0
                LocalWatchSession.markJump(heightM = height, auto = true)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onLocationChanged(location: Location) {
        if (!running || paused) return
        val prev = lastLocation
        lastLocation = location
        val delta = prev?.distanceTo(location)?.toDouble() ?: 0.0
        val speedMs = if (location.hasSpeed()) location.speed.toDouble() else 0.0
        LocalWatchSession.updateMetrics { s ->
            s.copy(
                gpsPointCount = s.gpsPointCount + 1,
                distanceMeters = s.distanceMeters + delta,
                paceOrSpeedLabel = speedLabel(speedMs),
                syncStatus = "GPS · ${s.gpsPointCount + 1} pts",
            )
        }
    }

    private fun speedLabel(speedMs: Double): String {
        if (speedLabelMode) return "%.1f km/h".format(speedMs * 3.6)
        if (speedMs < 0.3) return "--'--\"/km"
        val secPerKm = (1000.0 / speedMs).toInt()
        return "%d'%02d\"/km".format(secPerKm / 60, secPerKm % 60)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) = Unit
    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit

    private val OUTDOOR = setOf("Corrida", "Caminhada", "Mountain bike", "Bicicleta pedal")
    private const val FREE_FALL_THRESHOLD = 3.0f
    private const val MIN_FLIGHT_MS = 250L
    private const val MAX_FLIGHT_MS = 6_000L
}
