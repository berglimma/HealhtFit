package com.healthfit.android.workout

import android.os.SystemClock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class WorkoutLockSnapshot(
    val workoutTitle: String,
    val exerciseName: String,
    val setsLabel: String,
    val elapsedSeconds: Int,
    val resting: Boolean,
    val restRemainingSeconds: Int = 0,
    val publishedAt: Long = SystemClock.elapsedRealtime(),
) {
    fun displaySeconds(now: Long = SystemClock.elapsedRealtime()): Int {
        if (resting) return elapsedSeconds
        val extra = ((now - publishedAt) / 1000L).toInt()
        return elapsedSeconds + extra.coerceAtLeast(0)
    }

    fun clock(now: Long = SystemClock.elapsedRealtime()): String {
        val seconds = displaySeconds(now).coerceAtLeast(0)
        return "%02d:%02d".format(seconds / 60, seconds % 60)
    }
}

object WorkoutLockSession {
    private val mutable = MutableStateFlow<WorkoutLockSnapshot?>(null)
    val state: StateFlow<WorkoutLockSnapshot?> = mutable

    fun publish(snapshot: WorkoutLockSnapshot) {
        mutable.value = snapshot
    }

    fun clear() {
        mutable.value = null
    }
}
