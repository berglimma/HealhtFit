package com.healthfit.core.workout

/** Payload shared by the phone lock-screen session and the Wear OS app. */
object WorkoutWearContract {
    const val PATH = "/healthfit/workout"
    const val ACTIVE = "active"
    const val TITLE = "title"
    const val EXERCISE = "exercise"
    const val SETS = "sets"
    const val RESTING = "resting"
    const val ELAPSED = "elapsed"
    const val TIMER_START = "timerStart"
    const val REST_END = "restEnd"
    const val UPDATED = "updated"
}
