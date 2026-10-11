package com.healthfit.wear

import androidx.compose.runtime.Composable

/**
 * Seletor de duração. Cardio: "Livre" + 5/10/15/20/30/45/60 min.
 * Meditação: 5/10/15/20 min apenas (sem opção livre).
 */
@Composable
fun DurationPickerScreen(
    title: String,
    subtitle: String,
    options: List<WatchCatalog.DurationOption>,
    allowFree: Boolean,
    onPick: (seconds: Int) -> Unit,
) {
    WearList(title) {
        item { SmallNote(subtitle, WearColors.TextSecondary) }
        item { SectionLabel("Duração") }
        if (allowFree) {
            item { HFChip("Livre (sem meta de tempo)", onClick = { onPick(0) }) }
        }
        items(options.size) { i ->
            val option = options[i]
            HFChip(option.label, onClick = { onPick(option.seconds) })
        }
    }
}
