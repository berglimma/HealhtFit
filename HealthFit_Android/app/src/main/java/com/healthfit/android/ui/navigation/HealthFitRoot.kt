package com.healthfit.android.ui.navigation

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.healthfit.android.R
import com.healthfit.android.core.AppLanguageStore
import com.healthfit.android.ui.assistant.AssistantEngine
import com.healthfit.android.ui.assistant.AssistantNotifications
import com.healthfit.android.ui.assistant.AssistantScreen
import com.healthfit.android.ui.auth.AuthScreen
import com.healthfit.android.ui.components.HealthFitTabBar
import com.healthfit.android.ui.components.TabSpec
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.android.ui.home.HomeScreen
import com.healthfit.android.ui.home.WelcomeLoadingScreen
import com.healthfit.android.ui.nutrition.NutritionScreen
import com.healthfit.android.ui.profile.ProfileScreen
import com.healthfit.android.ui.pulse.PulseScreen
import com.healthfit.android.ui.workouts.WorkoutsScreen
import com.healthfit.core.auth.AuthRepository
import com.healthfit.core.billing.BillingGateway
import com.healthfit.core.health.HealthConnectGateway
import com.healthfit.core.workout.WorkoutRepository
import com.healthfit.designsystem.HealthFitColors

@Composable
@Suppress("UNUSED_PARAMETER")
fun HealthFitRoot(
    authRepository: AuthRepository,
    workoutRepository: WorkoutRepository,
    healthConnectGateway: HealthConnectGateway,
    billingGateway: BillingGateway,
) {
    val user by authRepository.currentUser.collectAsState(initial = null)
    val appLanguage by AppLanguageStore.language.collectAsState()
    val wellness = remember { DailyWellness() }
    val athlete = remember { com.healthfit.android.ui.home.AthleteProfile() }
    var showWelcome by remember { mutableStateOf(true) }
    val tabs = listOf(
        TabSpec("home", stringResource(R.string.tab_home), Icons.Filled.Home),
        TabSpec("workouts", stringResource(R.string.tab_workouts), Icons.Filled.FitnessCenter),
        TabSpec("nutrition", stringResource(R.string.tab_nutrition), Icons.Filled.Restaurant),
        TabSpec("assistant", stringResource(R.string.tab_assistant), Icons.Filled.Chat, badge = 1),
        TabSpec("profile", stringResource(R.string.tab_profile), Icons.Filled.Person),
    )
    // Recompose tab labels when language preference changes.
    @Suppress("UNUSED_EXPRESSION")
    appLanguage
    if (showWelcome) {
        WelcomeLoadingScreen(
            name = user?.displayName?.ifBlank { "Berg" } ?: "Berg",
            onFinished = { showWelcome = false },
        )
        return
    }
    val signedIn = user
    if (signedIn == null) {
        AuthScreen(authRepository = authRepository)
        return
    }

    val context = LocalContext.current
    val greetingName = signedIn.displayName?.ifBlank { "Berg" } ?: "Berg"
    val notificationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            AssistantNotifications.ensureBackgroundDelivery(
                context = context,
                name = greetingName,
                userId = signedIn.uid,
                requestBatteryExemption = true,
            )
        }
    }
    LaunchedEffect(signedIn.uid) {
        val needsPermission = Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        if (needsPermission) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            // Ativa lembretes em qualquer aba (Início, Treinos, etc.) — IAssistente não precisa estar aberto.
            AssistantNotifications.ensureBackgroundDelivery(
                context = context,
                name = greetingName,
                userId = signedIn.uid,
                requestBatteryExemption = true,
            )
        }
    }

    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val current = backStack?.destination?.route
    val showTabs = current != "pulse"
    val density = LocalDensity.current
    val imeVisible = WindowInsets.ime.getBottom(density) > 0
    // Hide tab bar while typing in IAssistente so the composer stays above the keyboard.
    val showBottomBar = showTabs && !(current == "assistant" && imeVisible)

    Scaffold(
        containerColor = HealthFitColors.Background,
        bottomBar = {
            if (showBottomBar) {
                HealthFitTabBar(
                    items = tabs.map { tab ->
                        if (tab.route == "assistant") {
                            tab.copy(badge = if (current == "assistant") 0 else AssistantEngine.alerts(wellness).size)
                        } else {
                            tab
                        }
                    },
                    selectedRoute = current,
                    onSelect = { route ->
                        navController.navigate(route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = "home",
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            composable("home") {
                HomeScreen(
                    userName = signedIn.displayName?.ifBlank { signedIn.email.substringBefore('@') }.orEmpty(),
                    wellness = wellness,
                    onOpenPulse = { navController.navigate("pulse") },
                )
            }
            composable("workouts") { WorkoutsScreen(userId = signedIn.uid) }
            composable("nutrition") { NutritionScreen(wellness, athlete) }
            composable("assistant") {
                AssistantScreen(
                    name = greetingName,
                    wellness = wellness,
                    athlete = athlete,
                    userId = signedIn.uid,
                )
            }
            composable("profile") {
                ProfileScreen(
                    profile = signedIn,
                    wellness = wellness,
                    athlete = athlete,
                    onSignOut = { authRepository.signOut() },
                )
            }
            composable("pulse") {
                PulseScreen(onClose = { navController.popBackStack() })
            }
        }
    }
}
