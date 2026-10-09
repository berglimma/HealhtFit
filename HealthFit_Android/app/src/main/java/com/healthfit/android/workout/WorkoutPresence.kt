package com.healthfit.android.workout

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.view.WindowManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat

@Composable
fun WorkoutPresence(
    workoutTitle: String,
    exerciseName: String,
    setsLabel: String,
    elapsedSeconds: Int,
    resting: Boolean,
    restRemainingSeconds: Int = 0,
    enabled: Boolean = true,
) {
    val context = LocalContext.current
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    DisposableEffect(enabled) {
        val activity = context.findActivity()
        if (enabled) {
            activity?.setShowWhenLocked(true)
            activity?.setTurnScreenOn(true)
            activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            activity?.setShowWhenLocked(false)
            activity?.setTurnScreenOn(false)
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            WorkoutLockPublisher.clear(context)
        }
    }
    LaunchedEffect(enabled) {
        if (!enabled) {
            WorkoutLockPublisher.clear(context)
            return@LaunchedEffect
        }
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
    LaunchedEffect(enabled, workoutTitle, exerciseName, setsLabel, resting, restRemainingSeconds, elapsedSeconds / 5) {
        if (!enabled) return@LaunchedEffect
        WorkoutLockPublisher.publish(
            context,
            WorkoutLockSnapshot(
                workoutTitle = workoutTitle,
                exerciseName = exerciseName,
                setsLabel = setsLabel,
                elapsedSeconds = elapsedSeconds,
                resting = resting,
                restRemainingSeconds = restRemainingSeconds,
            ),
        )
    }
}

private fun Context.findActivity(): Activity? {
    var current = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
