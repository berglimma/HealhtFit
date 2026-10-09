package com.healthfit.wear

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import com.healthfit.core.workout.WorkoutWearContract

class WorkoutWearListener : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        events.forEach { event ->
            if (event.dataItem.uri.path != WorkoutWearContract.PATH) return@forEach
            if (event.type == DataEvent.TYPE_DELETED) {
                WorkoutWearSession.clear()
                cancelOngoing()
                return@forEach
            }
            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            WorkoutWearSession.apply(map)
            if (map.getBoolean(WorkoutWearContract.ACTIVE)) {
                showOngoing()
                startActivity(
                    Intent(this, MainActivity::class.java).addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    ),
                )
            } else {
                cancelOngoing()
            }
        }
    }

    private fun showOngoing() {
        val workout = WorkoutWearSession.state.value ?: return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL, "Treino", NotificationManager.IMPORTANCE_HIGH).apply {
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val phase = if (workout.resting) "Pausa" else "Exercício"
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_heart)
            .setContentTitle(workout.exercise)
            .setContentText("$phase · ${workout.sets}")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open)
        OngoingActivity.Builder(applicationContext, NOTIFICATION_ID, builder)
            .setStaticIcon(R.drawable.ic_stat_heart)
            .setTouchIntent(open)
            .setStatus(Status.Builder().addTemplate(workout.exercise).build())
            .build()
            .apply(applicationContext)
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun cancelOngoing() {
        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }

    companion object {
        private const val CHANNEL = "healthfit_wear_workout"
        private const val NOTIFICATION_ID = 4102
    }
}
