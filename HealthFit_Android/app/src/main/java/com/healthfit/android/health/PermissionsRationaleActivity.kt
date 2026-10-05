package com.healthfit.android.health

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthfit.android.R
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitTheme

/** Required by Health Connect when the user opens the permission rationale deep link. */
class PermissionsRationaleActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HealthFitTheme {
                HealthFitCard(modifier = Modifier.padding(24.dp)) {
                    Text(stringResource(R.string.health_connect_rationale))
                }
            }
        }
    }
}
