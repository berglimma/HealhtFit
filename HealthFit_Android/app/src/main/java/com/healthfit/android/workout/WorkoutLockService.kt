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
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.healthfit.android.MainActivity
import com.healthfit.android.R
import com.healthfit.core.workout.WorkoutWearContract

object WorkoutLockPublisher {
    fun publish(context: Context, snapshot: WorkoutLockSnapshot) {
        WorkoutLockSession.publish(snapshot)
        val app = context.applicationContext
        ContextCompat.startForegroundService(app, Intent(app, WorkoutLockService::class.java))
    }

    fun clear(context: Context) {
        WorkoutLockSession.clear()
        val app = context.applicationContext
        app.startService(Intent(app, WorkoutLockService::class.java).setAction(WorkoutLockService.ACTION_STOP))
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
        if (intent?.action == ACTION_STOP) {
            syncWatch(null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val snapshot = WorkoutLockSession.state.value ?: return START_NOT_STICKY
        rememberClock(snapshot)
        val notification = buildNotification(snapshot)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        syncWatch(snapshot)
        return START_STICKY
    }

    private fun rememberClock(snapshot: WorkoutLockSnapshot) {
        val countdown = snapshot.resting && snapshot.restRemainingSeconds > 0
        val key = "${snapshot.workoutTitle}|${snapshot.exerciseName}|${snapshot.resting}|$countdown"
        if (key == chronoKey) return
        chronoKey = key
        chronoCountDown = countdown
        chronoRunning = !snapshot.resting || countdown
        chronoBase = when {
            countdown -> SystemClock.elapsedRealtime() + snapshot.restRemainingSeconds * 1000L
            else -> SystemClock.elapsedRealtime() - snapshot.elapsedSeconds * 1000L
        }
        timerStartEpoch = System.currentTimeMillis() - snapshot.elapsedSeconds * 1000L
        restEndEpoch = if (countdown) System.currentTimeMillis() + snapshot.restRemainingSeconds * 1000L else 0L
    }

    private fun buildNotification(snapshot: WorkoutLockSnapshot): Notification {
        ensureChannel()
        val phase = if (snapshot.resting) "HealthFit · Pausa" else "HealthFit · Exercício"
        val views = RemoteViews(packageName, R.layout.notification_workout_lock).apply {
            setTextViewText(R.id.lock_phase, phase)
            setTextColor(R.id.lock_phase, if (snapshot.resting) 0xFFFF8C33.toInt() else 0xFF3DDC3A.toInt())
            setTextViewText(R.id.lock_exercise, snapshot.exerciseName)
            setTextViewText(R.id.lock_title, snapshot.workoutTitle)
            setTextViewText(R.id.lock_sets, if (snapshot.resting && snapshot.restRemainingSeconds > 0) "restante" else snapshot.setsLabel)
            setChronometer(R.id.lock_clock, chronoBase, null, chronoRunning)
            setChronometerCountDown(R.id.lock_clock, chronoCountDown)
            if (snapshot.resting) setTextColor(R.id.lock_clock, 0xFFFF8C33.toInt())
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
        runCatching {
            val request = PutDataMapRequest.create(WorkoutWearContract.PATH).apply {
                dataMap.putBoolean(WorkoutWearContract.ACTIVE, snapshot != null)
                dataMap.putString(WorkoutWearContract.TITLE, snapshot?.workoutTitle.orEmpty())
                dataMap.putString(WorkoutWearContract.EXERCISE, snapshot?.exerciseName.orEmpty())
                dataMap.putString(WorkoutWearContract.SETS, snapshot?.setsLabel.orEmpty())
                dataMap.putBoolean(WorkoutWearContract.RESTING, snapshot?.resting == true)
                dataMap.putInt(WorkoutWearContract.ELAPSED, snapshot?.elapsedSeconds ?: 0)
                dataMap.putLong(WorkoutWearContract.TIMER_START, if (snapshot == null) 0L else timerStartEpoch)
                dataMap.putLong(WorkoutWearContract.REST_END, if (snapshot == null) 0L else restEndEpoch)
                dataMap.putLong(WorkoutWearContract.UPDATED, System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(this).putDataItem(request)
        }
    }

    companion object {
        const val ACTION_STOP = "com.healthfit.android.workout.STOP"
        private const val CHANNEL = "healthfit_workout_lock"
        private const val NOTIFICATION_ID = 4101
    }
}
