package com.healthfit.android.ui.navigation

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.healthfit.android.R
import com.healthfit.android.ui.auth.AuthScreen
import com.healthfit.android.ui.home.HomeScreen
import com.healthfit.android.ui.profile.ProfileScreen
import com.healthfit.android.ui.workouts.WorkoutsScreen
import com.healthfit.core.auth.AuthRepository
import com.healthfit.core.billing.BillingGateway
import com.healthfit.core.health.HealthConnectGateway
import com.healthfit.core.workout.WorkoutRepository
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitColors

private enum class MainTab(val route: String, val labelRes: Int, val icon: ImageVector) {
    Home("home", R.string.tab_home, Icons.Filled.Home),
    Workouts("workouts", R.string.tab_workouts, Icons.Filled.FitnessCenter),
    Nutrition("nutrition", R.string.tab_nutrition, Icons.Filled.Restaurant),
    Assistant("assistant", R.string.tab_assistant, Icons.Filled.Chat),
    Profile("profile", R.string.tab_profile, Icons.Filled.Person),
}

@Composable
fun HealthFitRoot(
    authRepository: AuthRepository,
    workoutRepository: WorkoutRepository,
    healthConnectGateway: HealthConnectGateway,
    billingGateway: BillingGateway,
) {
    val user by authRepository.currentUser.collectAsState(initial = null)
    if (user == null) {
        AuthScreen(authRepository = authRepository)
        return
    }

    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val current = backStack?.destination?.route
    val billingConnected by billingGateway.connected.collectAsState()

    Scaffold(
        containerColor = HealthFitColors.Background,
        bottomBar = {
            NavigationBar(containerColor = HealthFitColors.CardBackground) {
                MainTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = current == tab.route,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.labelRes)) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = HealthFitColors.Accent,
                            selectedTextColor = HealthFitColors.Accent,
                            indicatorColor = HealthFitColors.Accent.copy(alpha = 0.18f),
                            unselectedIconColor = HealthFitColors.TextSecondary,
                            unselectedTextColor = HealthFitColors.TextSecondary,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = MainTab.Home.route,
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            composable(MainTab.Home.route) {
                HomeScreen(
                    userName = user?.displayName?.ifBlank { user?.email }.orEmpty(),
                    healthAvailable = healthConnectGateway.isAvailable(),
                    billingConnected = billingConnected,
                )
            }
            composable(MainTab.Workouts.route) {
                WorkoutsScreen(workoutRepository = workoutRepository)
            }
            composable(MainTab.Nutrition.route) {
                PlaceholderPhaseScreen(
                    title = "Nutrição",
                    body = "Fase 2 — cardápio, lista de compras e foto de refeição (paridade com iOS).",
                )
            }
            composable(MainTab.Assistant.route) {
                PlaceholderPhaseScreen(
                    title = "Dúvidas",
                    body = "Fase 3 — IAssistente e motores de engajamento.",
                )
            }
            composable(MainTab.Profile.route) {
                ProfileScreen(
                    profile = user!!,
                    onSignOut = { authRepository.signOut() },
                    healthAvailable = healthConnectGateway.isAvailable(),
                )
            }
        }
    }
}

@Composable
fun PlaceholderPhaseScreen(title: String, body: String) {
    Column(modifier = Modifier.padding(16.dp)) {
        HealthFitCard {
            Text(
                text = title,
                color = HealthFitColors.TextPrimary,
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                text = body,
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
