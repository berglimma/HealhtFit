package com.healthfit.android.ui.tennis

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.designsystem.HealthFitColors

@Composable
fun TennisSetupSection(
    setup: TennisSessionSetup,
    onSetupChange: (TennisSessionSetup) -> Unit,
) {
    Text("Setup Tênis", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 18.dp))

    Text("Tipo de sessão", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    TennisSessionType.entries.chunked(2).forEach { row ->
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { type ->
                Chip(
                    label = type.title,
                    selected = setup.sessionType == type,
                    modifier = Modifier.weight(1f),
                ) { onSetupChange(setup.copy(sessionType = type)) }
            }
            if (row.size == 1) Spacer(Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
    }
    Text(setup.sessionType.detail, color = HealthFitColors.TextSecondary, fontSize = 12.sp)

    Text("Formato", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        TennisMatchFormat.entries.forEach { format ->
            Chip(format.title, setup.matchFormat == format) { onSetupChange(setup.copy(matchFormat = format)) }
        }
    }

    Text("Superfície", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    TennisCourtSurface.entries.forEach { surface ->
        val selected = setup.surface == surface
        Column(
            Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(if (selected) Color(0xFF243028) else HealthFitColors.CardBackground)
                .border(1.dp, if (selected) HealthFitColors.Accent else Color.Transparent, RoundedCornerShape(14.dp))
                .clickable { onSetupChange(setup.copy(surface = surface)) }
                .padding(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(surface.title, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text(
                    if (surface.isOutdoor) "Outdoor · GPS" else "Indoor",
                    color = if (surface.isOutdoor) HealthFitColors.Accent else HealthFitColors.TextSecondary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Text(surface.detail, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
        }
    }

    Text("Nível e mão", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        TennisSkillLevel.entries.forEach { level ->
            Chip(level.title, setup.skillLevel == level, Modifier.weight(1f)) {
                onSetupChange(setup.copy(skillLevel = level))
            }
        }
    }
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        TennisHandedness.entries.forEach { hand ->
            Chip(hand.title, setup.handedness == hand) { onSetupChange(setup.copy(handedness = hand)) }
        }
    }

    Text("Metas", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    MetaStepper(
        label = "Sets",
        valueLabel = if (setup.targetSets == 0) "Livre" else "${setup.targetSets} set(s)",
        onMinus = { onSetupChange(setup.copy(targetSets = (setup.targetSets - 1).coerceAtLeast(0))) },
        onPlus = { onSetupChange(setup.copy(targetSets = (setup.targetSets + 1).coerceAtMost(5))) },
    )
    Spacer(Modifier.height(8.dp))
    MetaStepper(
        label = "Duração",
        valueLabel = if (setup.targetMinutes == 0) "Livre" else "${setup.targetMinutes} min",
        onMinus = { onSetupChange(setup.copy(targetMinutes = (setup.targetMinutes - 15).coerceAtLeast(0))) },
        onPlus = { onSetupChange(setup.copy(targetMinutes = (setup.targetMinutes + 15).coerceAtMost(180))) },
    )
    Spacer(Modifier.height(8.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text("Meta de zona alta", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(
                "Alvo ~${setup.skillLevel.highZoneGoalPercent}% do tempo em FC elevada",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
            )
        }
        Switch(
            checked = setup.useZoneGoal,
            onCheckedChange = { onSetupChange(setup.copy(useZoneGoal = it)) },
            colors = SwitchDefaults.colors(checkedTrackColor = HealthFitColors.Accent),
        )
    }

    Text("Quadra", color = HealthFitColors.TextSecondary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    BasicTextField(
        value = setup.courtName,
        onValueChange = { onSetupChange(setup.copy(courtName = it)) },
        singleLine = true,
        textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
        cursorBrush = SolidColor(HealthFitColors.Accent),
        decorationBox = { inner ->
            BoxField {
                if (setup.courtName.isBlank()) {
                    Text("Nome da quadra (opcional)", color = HealthFitColors.TextSecondary)
                }
                inner()
            }
        },
    )
    Text(
        "No treino: placar manual (sets/games), picos de movimento e GPS se a superfície for outdoor.",
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 12.dp),
    )
}

@Composable
private fun Chip(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
    )
}

@Composable
private fun MetaStepper(label: String, valueLabel: String, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Text("−", color = HealthFitColors.Accent, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.clickable(onClick = onMinus).padding(horizontal = 12.dp))
        Text(valueLabel, color = Color.White, fontWeight = FontWeight.SemiBold)
        Text("+", color = HealthFitColors.Accent, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.clickable(onClick = onPlus).padding(horizontal = 12.dp))
    }
}

@Composable
private fun BoxField(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) { content() }
}
