package com.healthfit.android.workout

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.healthfit.android.MainActivity
import com.healthfit.android.R
import com.healthfit.core.workout.WorkoutWearContract

object WorkoutLockPublisher {
    fun publish(context: Context, snapshot: WorkoutLockSnapshot) {
        WorkoutLockSession.publish(snapshot)
        val app = context.applicationContext
        runCatching {
            ContextCompat.startForegroundService(app, Intent(app, WorkoutLockService::class.java))
        }
    }

    fun clear(context: Context) {
        WorkoutLockSession.clear()
        val app = context.applicationContext
        val stop = Intent(app, WorkoutLockService::class.java).setAction(WorkoutLockService.ACTION_STOP)
        // Prefer stopService: startForegroundService from Compose onDispose can kill the app on Samsung/Android 12+.
        val stopped = runCatching { app.stopService(stop) }.getOrDefault(false)
        if (!stopped) {
            runCatching { ContextCompat.startForegroundService(app, stop) }
        }
    }
}

class WorkoutLockService : Service() {
    private var chronoKey = ""
    private var chronoBase = 0L
    private var chronoRunning = true
    private var chronoCountDown = false
    private var timerStartEpoch = 0L
    private var restEndEpoch = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel()
        val stopping = intent?.action == ACTION_STOP
        val snapshot = if (stopping) null else WorkoutLockSession.state.value

        // Android kills the app if startForeground isn't called promptly after startForegroundService.
        val notification = snapshot?.let {
            rememberClock(it)
            buildNotification(it)
        } ?: placeholderNotification()
        promoteForeground(notification)

        if (stopping || snapshot == null) {
            syncWatch(null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        syncWatch(snapshot)
        return START_STICKY
    }

    private fun promoteForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun rememberClock(snapshot: WorkoutLockSnapshot) {
        val countdown = snapshot.resting && snapshot.restRemainingSeconds > 0
        val key = "${snapshot.workoutTitle}|${snapshot.exerciseName}|${snapshot.resting}|$countdown|${snapshot.paused}"
        if (key == chronoKey) return
        chronoKey = key
        chronoCountDown = countdown
        chronoRunning = !snapshot.paused && (!snapshot.resting || countdown)
        chronoBase = when {
            countdown -> SystemClock.elapsedRealtime() + snapshot.restRemainingSeconds * 1000L
            else -> SystemClock.elapsedRealtime() - snapshot.elapsedSeconds * 1000L
        }
        timerStartEpoch = System.currentTimeMillis() - snapshot.elapsedSeconds * 1000L
        restEndEpoch = if (countdown) System.currentTimeMillis() + snapshot.restRemainingSeconds * 1000L else 0L
    }

    private fun buildNotification(snapshot: WorkoutLockSnapshot): Notification {
        val isStudy = snapshot.kind == WorkoutWearContract.KIND_MEDITATION &&
            (snapshot.workoutTitle.contains("Estudo", ignoreCase = true) ||
                snapshot.setsLabel.contains("estudo", ignoreCase = true))
        val phase = when {
            snapshot.paused -> "HealthFit · Pausado"
            isStudy -> "HealthFit · Estudo"
            snapshot.resting -> "HealthFit · Pausa"
            snapshot.kind == WorkoutWearContract.KIND_MEDITATION -> "HealthFit · Meditação"
            else -> "HealthFit · Exercício"
        }
        val phaseColor = when {
            snapshot.paused -> 0xFFFFD60A.toInt()
            isStudy -> 0xFF7B8CFF.toInt()
            snapshot.resting -> 0xFFFF8C33.toInt()
            else -> 0xFF3DDC3A.toInt()
        }
        val views = RemoteViews(packageName, R.layout.notification_workout_lock).apply {
            setTextViewText(R.id.lock_phase, phase)
            setTextColor(R.id.lock_phase, phaseColor)
            setTextViewText(R.id.lock_exercise, snapshot.exerciseName)
            setTextViewText(R.id.lock_title, snapshot.workoutTitle)
            setTextViewText(
                R.id.lock_sets,
                when {
                    isStudy && snapshot.restRemainingSeconds > 0 -> "estudo restante"
                    snapshot.resting && snapshot.restRemainingSeconds > 0 -> "restante"
                    else -> snapshot.setsLabel
                },
            )
            setChronometer(R.id.lock_clock, chronoBase, null, chronoRunning)
            setChronometerCountDown(R.id.lock_clock, chronoCountDown)
            if (snapshot.resting || snapshot.paused) setTextColor(R.id.lock_clock, phaseColor)
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_heart)
            .setContentTitle(snapshot.exerciseName)
            .setContentText(snapshot.setsLabel)
            .setSubText(phase)
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(open)
            .build()
    }

    private fun placeholderNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_heart)
            .setContentTitle("HealthFit")
            .setContentText("Encerrando treino…")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL, "Treino na tela bloqueada", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Exercício em andamento na tela bloqueada e no relógio"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun syncWatch(snapshot: WorkoutLockSnapshot?) {
        PhoneWorkoutSync.publishPhoneState(
            context = this,
            active = snapshot != null,
            title = snapshot?.workoutTitle.orEmpty(),
            exercise = snapshot?.exerciseName.orEmpty(),
            sets = snapshot?.setsLabel.orEmpty(),
            resting = snapshot?.resting == true && snapshot.paused != true,
            paused = snapshot?.paused == true,
            elapsedSeconds = snapshot?.elapsedSeconds ?: 0,
            timerStartEpoch = if (snapshot == null) 0L else timerStartEpoch,
            restEndEpoch = if (snapshot == null) 0L else restEndEpoch,
            kind = snapshot?.kind ?: WorkoutWearContract.KIND_STRENGTH,
        )
    }

    companion object {
        const val ACTION_STOP = "com.healthfit.android.workout.STOP"
        private const val CHANNEL = "healthfit_workout_lock"
        private const val NOTIFICATION_ID = 4101
    }
}
