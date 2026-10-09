package com.healthfit.wear

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.healthfit.core.workout.WorkoutWearContract
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        setContent { WearRoot() }
    }
}

@Composable
private fun WearRoot() {
    val context = LocalContext.current
    val workout by WorkoutWearSession.state.collectAsState()
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        Wearable.getDataClient(context).dataItems.addOnSuccessListener { buffer ->
            buffer.use { items ->
                items.forEach { item ->
                    if (item.uri.path == WorkoutWearContract.PATH) {
                        WorkoutWearSession.apply(DataMapItem.fromDataItem(item).dataMap)
                    }
                }
            }
        }
    }
    LaunchedEffect(workout) {
        while (true) {
            now = System.currentTimeMillis()
            delay(1000)
        }
    }
    DisposableEffect(workout != null) {
        val activity = context.findActivity()
        if (workout != null) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }
    MaterialTheme {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(HealthFitColors.Background)
                .padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("HealthFit", color = HealthFitColors.Accent, textAlign = TextAlign.Center)
            val current = workout
            if (current == null) {
                Text(
                    "Aguardando treino do celular",
                    color = HealthFitColors.TextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp),
                )
            } else {
                Text(
                    if (current.resting) "Pausa" else "Exercício",
                    color = if (current.resting) HealthFitColors.AccentSecondary else HealthFitColors.Accent,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 6.dp),
                )
                Text(
                    current.exercise,
                    color = androidx.compose.ui.graphics.Color.White,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    current.clock(now),
                    color = androidx.compose.ui.graphics.Color.White,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    current.sets,
                    color = HealthFitColors.TextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp),
                )
                if (current.title.isNotBlank()) {
                    Text(
                        current.title,
                        color = HealthFitColors.TextSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }
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
