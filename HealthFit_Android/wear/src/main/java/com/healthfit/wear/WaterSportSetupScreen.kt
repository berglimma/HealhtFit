package com.healthfit.wear

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.wear.compose.material.ChipDefaults

/** Setup Surf / Kitesurf: prancha (surf) ou modo + prancha (kite), depois "Iniciar". */
@Composable
fun WaterSportSetupScreen(
    activity: WatchCatalog.CardioActivity,
    onStart: (modeName: String, boardName: String) -> Unit,
) {
    val modeOptions = if (activity.isKitesurf) WatchCatalog.kiteRidingModes else WatchCatalog.surfBoards
    val boardOptions = if (activity.isKitesurf) WatchCatalog.kiteBoards else emptyList()
    var selectedMode by remember { mutableStateOf(modeOptions.first()) }
    var selectedBoard by remember { mutableStateOf<WatchCatalog.WaterRideOption?>(boardOptions.firstOrNull()) }

    WearList(activity.name) {
        item {
            SmallNote(
                if (activity.isKitesurf) {
                    "Mesmas funções do Surf: saltos, sensores, sync, pausar e encerrar."
                } else {
                    "Sessão livre com saltos opcionais e sync com o celular."
                },
                WearColors.TextSecondary,
            )
        }
        item { SectionLabel(if (activity.isKitesurf) "Modo de velejo" else "Tipo de prancha") }
        items(modeOptions.size) { i ->
            val option = modeOptions[i]
            OptionChip(option, selected = selectedMode.id == option.id) { selectedMode = option }
        }
        if (boardOptions.isNotEmpty()) {
            item { SectionLabel("Prancha") }
            items(boardOptions.size) { i ->
                val option = boardOptions[i]
                OptionChip(option, selected = selectedBoard?.id == option.id) { selectedBoard = option }
            }
        }
        item {
            HFChip(
                label = if (activity.isKitesurf) "Iniciar Kitesurf" else "Iniciar Surf",
                onClick = { onStart(selectedMode.name, selectedBoard?.name.orEmpty()) },
                colors = ChipDefaults.chipColors(
                    backgroundColor = WearColors.Cyan,
                    contentColor = androidx.compose.ui.graphics.Color.Black,
                    secondaryContentColor = androidx.compose.ui.graphics.Color.Black,
                ),
            )
        }
        item {
            SmallNote(
                "Sessão livre · sensores de salto iguais ao Surf · métricas no celular pareado.",
                WearColors.TextSecondary,
            )
        }
    }
}

@Composable
private fun OptionChip(option: WatchCatalog.WaterRideOption, selected: Boolean, onClick: () -> Unit) {
    HFChip(
        label = (if (selected) "✓ " else "") + option.name,
        secondary = option.detail,
        onClick = onClick,
        colors = ChipDefaults.chipColors(
            backgroundColor = if (selected) WearColors.Elevated else WearColors.Card,
            contentColor = if (selected) WearColors.Cyan else WearColors.TextPrimary,
            secondaryContentColor = WearColors.TextSecondary,
        ),
    )
}
