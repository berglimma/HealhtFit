package com.healthfit.android.workout

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import com.healthfit.core.workout.WorkoutWearContract
import org.json.JSONObject

/** Receives workout state/control from the paired watch. */
class WearSyncListener : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            if (event.type != DataEvent.TYPE_CHANGED) return@forEach
            if (event.dataItem.uri.path != WorkoutWearContract.PATH) return@forEach
            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            PhoneWorkoutSync.applyIncomingDataMap(map)
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WorkoutWearContract.CONTROL_PATH) return
        val json = runCatching {
            JSONObject(String(messageEvent.data, Charsets.UTF_8))
        }.getOrNull() ?: return
        PhoneWorkoutSync.applyIncomingControl(
            action = json.optString(WorkoutWearContract.ACTION),
            source = json.optString(WorkoutWearContract.SOURCE),
        )
    }
}
