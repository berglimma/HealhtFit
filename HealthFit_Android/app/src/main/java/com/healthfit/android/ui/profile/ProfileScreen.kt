package com.healthfit.android.ui.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.healthfit.core.model.UserProfile
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitColors

@Composable
fun ProfileScreen(
    profile: UserProfile,
    onSignOut: () -> Unit,
    healthAvailable: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Perfil", color = HealthFitColors.TextPrimary, style = MaterialTheme.typography.headlineMedium)
        HealthFitCard {
            Text(
                profile.displayName.ifBlank { "Atleta HealthFit" },
                color = HealthFitColors.TextPrimary,
                style = MaterialTheme.typography.titleMedium,
            )
            Text(profile.email, color = HealthFitColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
            Text(
                "UID: ${profile.uid.take(8)}…",
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
        HealthFitCard {
            Text("Health Connect", color = HealthFitColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            Text(
                if (healthAvailable) "SDK disponível neste dispositivo."
                else "Instale o app Health Connect (Android 14+ / Play Store).",
                color = HealthFitColors.TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
        TextButton(onClick = onSignOut) {
            Text("Sair", color = HealthFitColors.Danger)
        }
    }
}
