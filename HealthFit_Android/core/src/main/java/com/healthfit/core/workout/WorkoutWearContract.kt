package com.healthfit.core.workout

/** Payload and control paths shared by phone and Wear OS. */
object WorkoutWearContract {
    const val PATH = "/healthfit/workout"
    const val CONTROL_PATH = "/healthfit/workout/control"

    const val ACTIVE = "active"
    const val TITLE = "title"
    const val EXERCISE = "exercise"
    const val SETS = "sets"
    const val RESTING = "resting"
    const val PAUSED = "paused"
    const val ELAPSED = "elapsed"
    const val TIMER_START = "timerStart"
    const val REST_END = "restEnd"
    const val KIND = "kind"
    const val SOURCE = "source"
    const val UPDATED = "updated"
    const val ACTION = "action"

    const val SOURCE_PHONE = "phone"
    const val SOURCE_WATCH = "watch"

    const val KIND_STRENGTH = "strength"
    const val KIND_CARDIO = "cardio"
    const val KIND_MEDITATION = "meditation"

    const val ACTION_START = "start"
    const val ACTION_PAUSE = "pause"
    const val ACTION_RESUME = "resume"
    const val ACTION_STOP = "stop"

    /** TCP bridge port for emulator phone↔watch when Wearable nodes are empty. */
    const val EMULATOR_BRIDGE_PORT = 19887
}
