package com.healthfit.wear

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Ejeta água do alto-falante do relógio com 8 pulsos graves (~165 Hz) + vibração.
 * Espelha WatchWaterEjection.swift.
 */
object WaterEjection {
    private const val SAMPLE_RATE = 22_050
    private const val PULSE_SECONDS = 0.12
    private const val GAP_SECONDS = 0.08
    private const val PULSE_COUNT = 8
    private const val FREQUENCY = 165.0

    private val main = Handler(Looper.getMainLooper())
    private var track: AudioTrack? = null
    var isPlaying = false
        private set

    fun play(
        context: Context,
        onStatus: (String) -> Unit = {},
        onFinished: () -> Unit = {},
    ) {
        if (isPlaying) return
        isPlaying = true
        onStatus("Ejetando água do alto-falante…")
        val appContext = context.applicationContext
        vibrate(appContext, click = true)

        val pcm = makeEjectionPcm()
        val durationMs = (pcm.size * 1000L) / SAMPLE_RATE
        try {
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(pcm.size * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            audioTrack.write(pcm, 0, pcm.size)
            audioTrack.setVolume(1.0f)
            track = audioTrack
            audioTrack.play()
            main.postDelayed({ finish(appContext, onFinished) }, max(durationMs + 150L, 1200L))
        } catch (t: Throwable) {
            onStatus("Falha ao ejetar água")
            finish(appContext, onFinished)
        }
    }

    private fun finish(context: Context, onFinished: () -> Unit) {
        try {
            track?.stop()
        } catch (_: IllegalStateException) {
        }
        track?.release()
        track = null
        isPlaying = false
        vibrate(context, click = false)
        onFinished()
    }

    private fun vibrate(context: Context, click: Boolean) {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        vibrator ?: return
        val effect = if (click) {
            VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE)
        } else {
            VibrationEffect.createWaveform(longArrayOf(0, 60, 60, 60), -1)
        }
        vibrator.vibrate(effect)
    }

    /** PCM mono 16 bits: 8 pulsos de ~165 Hz com envelope suave e pausas. */
    private fun makeEjectionPcm(): ShortArray {
        val pulseSamples = (SAMPLE_RATE * PULSE_SECONDS).toInt()
        val gapSamples = (SAMPLE_RATE * GAP_SECONDS).toInt()
        val out = ShortArray(PULSE_COUNT * (pulseSamples + gapSamples))
        var idx = 0
        for (pulse in 0 until PULSE_COUNT) {
            val amp = 28_000 - pulse * 1_200
            for (i in 0 until pulseSamples) {
                val t = i.toDouble() / SAMPLE_RATE
                val env = sin(PI * i / max(pulseSamples - 1, 1))
                val sample = sin(2 * PI * FREQUENCY * t) * amp * env
                out[idx++] = min(Short.MAX_VALUE.toInt(), max(Short.MIN_VALUE.toInt(), sample.roundToInt())).toShort()
            }
            idx += gapSamples
        }
        return out
    }
}
