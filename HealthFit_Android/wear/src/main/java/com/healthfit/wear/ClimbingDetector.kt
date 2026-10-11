package com.healthfit.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Monitora o acelerômetro procurando o padrão de escalada (braço elevado com
 * movimento moderado sustentado). Ao fim da janela dispara [onDetected].
 * Mensagens espelham WatchWorkoutManager.swift.
 */
class ClimbingDetector(
    context: Context,
    private val onStatus: (String) -> Unit,
    private val onDetected: () -> Unit,
) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var running = false
    private var signalSince = 0L
    private var lastSample = 0L
    private val gravity = FloatArray(3)
    private var gravityReady = false

    fun start() {
        if (running) return
        val sensor = accelerometer
        if (sensor == null) {
            onStatus("Sensores indisponíveis")
            return
        }
        signalSince = 0L
        lastSample = 0L
        gravityReady = false
        running = true
        onStatus("Monitorando movimento")
        sensorManager.registerListener(this, sensor, SAMPLE_PERIOD_US)
    }

    fun stop() {
        if (!running) return
        running = false
        sensorManager.unregisterListener(this)
        signalSince = 0L
        onStatus("")
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!running) return
        val now = System.currentTimeMillis()
        // Filtro passa-baixa isola gravidade; resto é aceleração do usuário.
        val alpha = 0.9f
        if (!gravityReady) {
            for (i in 0..2) gravity[i] = event.values[i]
            gravityReady = true
            return
        }
        for (i in 0..2) gravity[i] = alpha * gravity[i] + (1 - alpha) * event.values[i]
        if (now - lastSample < SAMPLE_INTERVAL_MS) return
        lastSample = now

        val ux = event.values[0] - gravity[0]
        val uy = event.values[1] - gravity[1]
        val uz = event.values[2] - gravity[2]
        val accelG = sqrt(ux * ux + uy * uy + uz * uz) / SensorManager.GRAVITY_EARTH
        val gravityZ = gravity[2] / SensorManager.GRAVITY_EARTH

        val armRaised = abs(gravityZ) < 0.55f
        val climbingLike = armRaised && accelG > 0.10f && accelG < 1.2f

        if (!climbingLike) {
            signalSince = 0L
            onStatus("Monitorando movimento")
            return
        }
        if (signalSince == 0L) {
            signalSince = now
            return
        }
        val sustained = (now - signalSince) / 1000.0
        if (sustained < WINDOW_SECONDS) {
            onStatus("Possível escalada… %.0fs".format(WINDOW_SECONDS - sustained))
            return
        }
        stop()
        onDetected()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    companion object {
        const val WINDOW_SECONDS = 90.0
        private const val SAMPLE_INTERVAL_MS = 200L
        private const val SAMPLE_PERIOD_US = 50_000
    }
}
