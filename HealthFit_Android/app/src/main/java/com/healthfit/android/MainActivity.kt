package com.healthfit.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import com.google.android.gms.maps.MapsInitializer
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.healthfit.android.ui.navigation.HealthFitRoot
import com.healthfit.designsystem.HealthFitColors
import com.healthfit.designsystem.HealthFitTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MapsInitializer.initialize(applicationContext, MapsInitializer.Renderer.LEGACY, null)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(0xFF0E1113.toInt()),
            navigationBarStyle = SystemBarStyle.dark(0xFF0E1113.toInt()),
        )
        val app = application as HealthFitApp
        setContent {
            HealthFitTheme(darkTheme = true) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = HealthFitColors.Background,
                ) {
                    HealthFitRoot(
                        authRepository = app.authRepository,
                        workoutRepository = app.workoutRepository,
                        healthConnectGateway = app.healthConnectGateway,
                        billingGateway = app.billingGateway,
                    )
                }
            }
        }
    }
}
