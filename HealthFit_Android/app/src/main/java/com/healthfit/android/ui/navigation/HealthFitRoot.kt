package com.healthfit.android.ui.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.healthfit.android.ui.assistant.AssistantEngine
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

private val Tabs = listOf(
    TabSpec("home", "Início", Icons.Filled.Home),
    TabSpec("workouts", "Treinos", Icons.Filled.FitnessCenter),
    TabSpec("nutrition", "Nutrição", Icons.Filled.Restaurant),
    TabSpec("assistant", "IAssistente", Icons.Filled.Chat, badge = 1),
    TabSpec("profile", "Perfil", Icons.Filled.Person),
)

@Composable
@Suppress("UNUSED_PARAMETER")
fun HealthFitRoot(
    authRepository: AuthRepository,
    workoutRepository: WorkoutRepository,
    healthConnectGateway: HealthConnectGateway,
    billingGateway: BillingGateway,
) {
    val user by authRepository.currentUser.collectAsState(initial = null)
    val wellness = remember { DailyWellness() }
    val athlete = remember { com.healthfit.android.ui.home.AthleteProfile() }
    var showWelcome by remember { mutableStateOf(true) }
    if (showWelcome) {
        WelcomeLoadingScreen(
            name = user?.displayName?.ifBlank { "Berg" } ?: "Berg",
            onFinished = { showWelcome = false },
        )
        return
    }
    if (user == null) {
        AuthScreen(authRepository = authRepository)
        return
    }

    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val current = backStack?.destination?.route
    val showTabs = current != "pulse"

    Scaffold(
        containerColor = HealthFitColors.Background,
        bottomBar = {
            if (showTabs) {
                HealthFitTabBar(
                    items = Tabs.map { tab ->
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
                    userName = user?.displayName?.ifBlank { user?.email?.substringBefore('@') }.orEmpty(),
                    wellness = wellness,
                    onOpenPulse = { navController.navigate("pulse") },
                )
            }
            composable("workouts") { WorkoutsScreen() }
            composable("nutrition") { NutritionScreen(wellness, athlete) }
            composable("assistant") {
                AssistantScreen(
                    name = user?.displayName?.ifBlank { "Berg" } ?: "Berg",
                    wellness = wellness,
                    athlete = athlete,
                )
            }
            composable("profile") {
                ProfileScreen(
                    profile = user!!,
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
