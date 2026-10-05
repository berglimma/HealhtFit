package com.healthfit.android.ui.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.healthfit.core.auth.AuthRepository
import com.healthfit.designsystem.HealthFitCard
import com.healthfit.designsystem.HealthFitColors
import com.healthfit.designsystem.HealthFitPrimaryButton
import kotlinx.coroutines.launch

@Composable
fun AuthScreen(authRepository: AuthRepository) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isRegister by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "HealthFit",
            style = MaterialTheme.typography.headlineLarge,
            color = HealthFitColors.Accent,
        )
        Text(
            text = "Seu personal trainer inteligente",
            style = MaterialTheme.typography.bodyMedium,
            color = HealthFitColors.TextSecondary,
            modifier = Modifier.padding(top = 6.dp, bottom = 24.dp),
        )

        HealthFitCard {
            Text(
                text = if (isRegister) "Criar conta" else "Entrar",
                style = MaterialTheme.typography.titleMedium,
                color = HealthFitColors.TextPrimary,
            )
            Spacer(Modifier.height(12.dp))
            val fieldColors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = HealthFitColors.Accent,
                unfocusedBorderColor = HealthFitColors.TextSecondary.copy(alpha = 0.4f),
                focusedTextColor = HealthFitColors.TextPrimary,
                unfocusedTextColor = HealthFitColors.TextPrimary,
                cursorColor = HealthFitColors.Accent,
            )
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("E-mail") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                colors = fieldColors,
            )
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Senha") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                colors = fieldColors,
            )
            error?.let {
                Text(
                    text = it,
                    color = HealthFitColors.Danger,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            Spacer(Modifier.height(16.dp))
            HealthFitPrimaryButton(
                text = if (loading) "…" else if (isRegister) "Cadastrar" else "Entrar",
                enabled = !loading && email.isNotBlank() && password.length >= 6,
                onClick = {
                    loading = true
                    error = null
                    scope.launch {
                        val result = if (isRegister) {
                            authRepository.signUpWithEmail(email, password)
                        } else {
                            authRepository.signInWithEmail(email, password)
                        }
                        loading = false
                        result.onFailure { e -> error = e.message ?: "Falha na autenticação" }
                    }
                },
            )
            TextButton(onClick = { isRegister = !isRegister }) {
                Text(
                    text = if (isRegister) "Já tenho conta" else "Criar conta",
                    color = HealthFitColors.Accent,
                )
            }
        }
    }
}
