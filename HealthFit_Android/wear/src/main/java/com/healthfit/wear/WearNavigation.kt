package com.healthfit.wear

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.currentBackStackEntryAsState
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

object WearRoutes {
    const val HOME = "home"
    const val STRENGTH = "strength"
    const val CARDIO = "cardio"
    const val CARDIO_DURATION = "cardioDuration/{id}"
    const val WATER_SETUP = "waterSetup/{id}"
    const val MEDITATION = "meditation"
    const val MEDITATION_DURATION = "meditationDuration/{id}"
    const val ACTIVE = "active"

    fun cardioDuration(id: String) = "cardioDuration/$id"
    fun waterSetup(id: String) = "waterSetup/$id"
    fun meditationDuration(id: String) = "meditationDuration/$id"
}

@Composable
fun WearNavigation() {
    val navController = rememberSwipeDismissableNavController()
    val session by LocalWatchSession.state.collectAsState()
    val backStack by navController.currentBackStackEntryAsState()
    val route = backStack?.destination?.route
    val hasSession = session != null

    // Sessão ativa (local ou do celular) abre a tela cheia; ao encerrar volta ao início.
    LaunchedEffect(hasSession) {
        if (hasSession) {
            if (navController.currentBackStackEntry?.destination?.route != WearRoutes.ACTIVE) {
                navController.navigate(WearRoutes.ACTIVE) {
                    popUpTo(WearRoutes.HOME)
                    launchSingleTop = true
                }
            }
        } else if (navController.currentBackStackEntry?.destination?.route == WearRoutes.ACTIVE) {
            navController.popBackStack(WearRoutes.HOME, inclusive = false)
        }
    }

    HealthFitWearTheme {
        SwipeDismissableNavHost(
            navController = navController,
            startDestination = WearRoutes.HOME,
            userSwipeEnabled = route != WearRoutes.ACTIVE,
        ) {
            composable(WearRoutes.HOME) {
                HomeScreen(
                    onStrength = { navController.navigate(WearRoutes.STRENGTH) },
                    onCardio = { navController.navigate(WearRoutes.CARDIO) },
                    onMeditation = { navController.navigate(WearRoutes.MEDITATION) },
                )
            }
            composable(WearRoutes.STRENGTH) {
                StrengthListScreen(onStart = { LocalWatchSession.beginStrength(it) })
            }
            composable(WearRoutes.CARDIO) {
                CardioListScreen(
                    onWater = { navController.navigate(WearRoutes.waterSetup(it.id)) },
                    onCardio = { navController.navigate(WearRoutes.cardioDuration(it.id)) },
                )
            }
            composable(
                WearRoutes.CARDIO_DURATION,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val activity = entry.arguments?.getString("id")?.let { WatchCatalog.cardio(it) }
                if (activity != null) {
                    DurationPickerScreen(
                        title = activity.name,
                        subtitle = "Duração alvo (opcional — livre se não escolher)",
                        options = WatchCatalog.DurationOption.values().toList(),
                        allowFree = true,
                        onPick = { LocalWatchSession.beginCardio(activity, targetSeconds = it) },
                    )
                }
            }
            composable(
                WearRoutes.WATER_SETUP,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val activity = entry.arguments?.getString("id")?.let { WatchCatalog.cardio(it) }
                if (activity != null) {
                    WaterSportSetupScreen(activity) { mode, board ->
                        LocalWatchSession.beginCardio(
                            activity,
                            targetSeconds = 0,
                            setupModeName = mode,
                            setupBoardName = board,
                        )
                    }
                }
            }
            composable(WearRoutes.MEDITATION) {
                MeditationListScreen(onTopic = { navController.navigate(WearRoutes.meditationDuration(it.id)) })
            }
            composable(
                WearRoutes.MEDITATION_DURATION,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                val topic = entry.arguments?.getString("id")?.let { WatchCatalog.meditation(it) }
                if (topic != null) {
                    DurationPickerScreen(
                        title = topic.name,
                        subtitle = "Escolha a duração da meditação",
                        options = WatchCatalog.meditationDurations,
                        allowFree = false,
                        onPick = { LocalWatchSession.beginMeditation(topic, it) },
                    )
                }
            }
            composable(WearRoutes.ACTIVE) {
                ActiveWorkoutScreen()
            }
        }
    }
}
