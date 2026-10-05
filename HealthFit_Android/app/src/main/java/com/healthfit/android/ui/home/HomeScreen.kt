package com.healthfit.android.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthfit.android.R
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitColors

@Composable
fun HomeScreen(
    userName: String,
    healthAvailable: Boolean,
    billingConnected: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = stringResource(R.string.phase_badge),
            color = HealthFitColors.AccentSecondary,
            style = MaterialTheme.typography.labelLarge,
        )
        Text(
            text = if (userName.isBlank()) "Olá" else "Olá, ${userName.substringBefore('@')}",
            color = HealthFitColors.TextPrimary,
            style = MaterialTheme.typography.headlineMedium,
        )

        HealthFitCard {
            Text("Início", color = HealthFitColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            Text(
                "Shell Android com as mesmas 5 abas do iOS (Início · Treinos · Nutrição · Dúvidas · Perfil) e cards no estilo HealthFit.",
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatusChip(
                title = "Health Connect",
                ok = healthAvailable,
                modifier = Modifier.weight(1f),
            )
            StatusChip(
                title = "Play Billing",
                ok = billingConnected,
                modifier = Modifier.weight(1f),
            )
        }

        HealthFitCard {
            Text("Paridade fiel", color = HealthFitColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            Text(
                "Backend Firebase compartilhado com o iOS. Nenhuma regra/Function foi publicada a partir deste módulo. Writes de treino na nuvem ficam off até o schema ser validado.",
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun StatusChip(title: String, ok: Boolean, modifier: Modifier = Modifier) {
    HealthFitCard(modifier = modifier) {
        Text(title, color = HealthFitColors.TextSecondary, style = MaterialTheme.typography.labelSmall)
        Text(
            text = if (ok) "Pronto" else "Indisponível",
            color = if (ok) HealthFitColors.Accent else HealthFitColors.AccentSecondary,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}
