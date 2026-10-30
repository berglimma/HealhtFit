package com.healthfit.android

import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import com.google.android.gms.maps.MapsInitializer
import com.healthfit.android.core.AppLanguageStore
import com.healthfit.android.core.withAppLocale
import com.healthfit.android.ui.navigation.HealthFitRoot
import com.healthfit.designsystem.HealthFitColors
import com.healthfit.designsystem.HealthFitTheme

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MapsInitializer.initialize(applicationContext, MapsInitializer.Renderer.LEGACY, null)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(0xFF0E1113.toInt()),
            navigationBarStyle = SystemBarStyle.dark(0xFF0E1113.toInt()),
        )
        // Reagenda lembretes ao abrir qualquer tela — não depende do IAssistente.
        runCatching { com.healthfit.android.ui.assistant.AssistantNotifications.rescheduleFromStorage(this) }
        val app = application as HealthFitApp
        setContent {
            val language by AppLanguageStore.language.collectAsState()
            val activityContext = LocalContext.current
            val localizedContext = remember(language, activityContext) {
                activityContext.withAppLocale(language)
            }
            val localizedConfig = remember(language, localizedContext) {
                Configuration(localizedContext.resources.configuration)
            }
            CompositionLocalProvider(
                LocalContext provides localizedContext,
                LocalConfiguration provides localizedConfig,
                LocalActivityResultRegistryOwner provides this@MainActivity,
                LocalLifecycleOwner provides this@MainActivity,
                LocalViewModelStoreOwner provides this@MainActivity,
            ) {
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
}
