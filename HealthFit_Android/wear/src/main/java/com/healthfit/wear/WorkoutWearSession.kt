package com.healthfit.wear

import com.google.android.gms.wearable.DataMap
import com.healthfit.core.workout.WorkoutWearContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class WearWorkout(
    val title: String,
    val exercise: String,
    val sets: String,
    val resting: Boolean,
    val paused: Boolean = false,
    val elapsedSeconds: Int,
    val timerStartEpoch: Long,
    val restEndEpoch: Long,
) {
    fun clock(now: Long = System.currentTimeMillis()): String {
        val seconds = when {
            resting && restEndEpoch > now -> ((restEndEpoch - now) / 1000L).toInt()
            resting -> elapsedSeconds
            timerStartEpoch > 0L -> ((now - timerStartEpoch) / 1000L).toInt()
            else -> elapsedSeconds
        }.coerceAtLeast(0)
        return "%02d:%02d".format(seconds / 60, seconds % 60)
    }
}

object WorkoutWearSession {
    private val mutable = MutableStateFlow<WearWorkout?>(null)
    val state: StateFlow<WearWorkout?> = mutable

    fun apply(map: DataMap) {
        if (!map.getBoolean(WorkoutWearContract.ACTIVE)) {
            mutable.value = null
            LocalWatchSession.applyPhoneWorkout(null)
            return
        }
        mutable.value = WearWorkout(
            title = map.getString(WorkoutWearContract.TITLE).orEmpty(),
            exercise = map.getString(WorkoutWearContract.EXERCISE).orEmpty(),
            sets = map.getString(WorkoutWearContract.SETS).orEmpty(),
            resting = map.getBoolean(WorkoutWearContract.RESTING),
            paused = map.getBoolean(WorkoutWearContract.PAUSED) ||
                map.getString(WorkoutWearContract.SETS).equals("Pausado", ignoreCase = true),
            elapsedSeconds = map.getInt(WorkoutWearContract.ELAPSED),
            timerStartEpoch = map.getLong(WorkoutWearContract.TIMER_START),
            restEndEpoch = map.getLong(WorkoutWearContract.REST_END),
        )
        LocalWatchSession.applyPhoneWorkout(mutable.value)
    }

    fun clear() {
        mutable.value = null
        LocalWatchSession.applyPhoneWorkout(null)
    }
}
