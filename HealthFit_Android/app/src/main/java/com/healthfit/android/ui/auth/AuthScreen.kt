package com.healthfit.android.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.core.auth.AuthRepository
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.launch

private enum class AuthPage { Login, Register, Forgot }

@Composable
fun AuthScreen(authRepository: AuthRepository) {
    var page by remember { mutableStateOf(AuthPage.Login) }
    when (page) {
        AuthPage.Login -> LoginPane(
            authRepository = authRepository,
            onCreateAccount = { page = AuthPage.Register },
            onForgotPassword = { page = AuthPage.Forgot },
        )
        AuthPage.Register -> RegisterPane(
            authRepository = authRepository,
            onBack = { page = AuthPage.Login },
        )
        AuthPage.Forgot -> ForgotPasswordPane(
            authRepository = authRepository,
            onBack = { page = AuthPage.Login },
        )
    }
}

@Composable
private fun LoginPane(
    authRepository: AuthRepository,
    onCreateAccount: () -> Unit,
    onForgotPassword: () -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val failed = stringResource(R.string.auth_failed)
    val canSubmit = email.isNotBlank() && password.length >= 6 && !loading

    Box(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .imePadding(),
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(24.dp))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    PulsingHeartIcon(72)
                    Text(
                        "HealthFit",
                        color = HealthFitColors.TextPrimary,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.SansSerif,
                    )
                    Text(
                        stringResource(R.string.tagline),
                        color = HealthFitColors.TextSecondary,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(top = 4.dp, bottom = 28.dp),
                    )
                }

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    SocialLoginRow(
                        authRepository = authRepository,
                        loading = loading,
                        onLoading = { loading = it },
                        onError = { error = it },
                    )
                    Spacer(Modifier.height(16.dp))
                    LoginLanguageChip()
                    Spacer(Modifier.height(16.dp))

                    Column(Modifier.fillMaxWidth()) {
                        Text(
                            stringResource(R.string.auth_email),
                            color = HealthFitColors.TextSecondary,
                            fontWeight = FontWeight.Medium,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(bottom = 6.dp),
                        )
                        AuthWhiteField(
                            value = email,
                            onValueChange = { email = it },
                            placeholder = stringResource(R.string.auth_email_placeholder),
                            keyboardType = KeyboardType.Email,
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                    Column(Modifier.fillMaxWidth()) {
                        Text(
                            stringResource(R.string.auth_password),
                            color = HealthFitColors.TextSecondary,
                            fontWeight = FontWeight.Medium,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(bottom = 6.dp),
                        )
                        AuthWhiteField(
                            value = password,
                            onValueChange = { password = it },
                            placeholder = stringResource(R.string.auth_password_placeholder),
                            placeholderAlpha = 0.55f,
                            keyboardType = KeyboardType.Password,
                            isPassword = true,
                        )
                    }
                    Text(
                        stringResource(R.string.auth_forgot_password),
                        color = HealthFitColors.Accent,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 12.dp)
                            .clickable(onClick = onForgotPassword),
                    )
                    error?.let {
                        Text(
                            it,
                            color = HealthFitColors.Danger,
                            fontSize = 12.sp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp),
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                    AuthGradientButton(
                        text = stringResource(R.string.auth_sign_in),
                        enabled = canSubmit,
                        onClick = {
                            loading = true
                            error = null
                            scope.launch {
                                val result = authRepository.signInWithEmail(email, password)
                                loading = false
                                result.onFailure { e -> error = e.message ?: failed }
                            }
                        },
                    )
                    Spacer(Modifier.height(12.dp))
                    CreateAccountCard(onClick = onCreateAccount)
                }
                Spacer(Modifier.height(24.dp))
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HealthFitColors.Background)
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                LegalLinksRow()
            }
        }

        if (loading) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = HealthFitColors.Accent)
            }
        }
    }
}

@Composable
private fun RegisterPane(
    authRepository: AuthRepository,
    onBack: () -> Unit,
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var accepted by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val failed = stringResource(R.string.auth_failed)
    val valid = name.isNotBlank() &&
        email.contains("@") &&
        password.length >= 8 &&
        password == confirm &&
        accepted &&
        !loading

    Box(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .statusBarsPadding()
            .imePadding(),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                stringResource(R.string.auth_close),
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .align(Alignment.Start)
                    .padding(top = 8.dp)
                    .clickable(onClick = onBack),
            )
            Spacer(Modifier.height(20.dp))
            Text(
                stringResource(R.string.auth_register_title),
                color = HealthFitColors.TextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                stringResource(R.string.auth_register_subtitle),
                color = HealthFitColors.TextSecondary,
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
            )
            SocialLoginRow(
                authRepository = authRepository,
                loading = loading,
                onLoading = { loading = it },
                onError = { error = it },
            )
            Spacer(Modifier.height(16.dp))
            AuthWhiteField(name, { name = it }, stringResource(R.string.auth_full_name))
            Spacer(Modifier.height(10.dp))
            AuthWhiteField(email, { email = it }, stringResource(R.string.auth_email), keyboardType = KeyboardType.Email)
            Spacer(Modifier.height(10.dp))
            AuthWhiteField(
                password,
                { password = it },
                stringResource(R.string.auth_password),
                keyboardType = KeyboardType.Password,
                isPassword = true,
            )
            Spacer(Modifier.height(10.dp))
            AuthWhiteField(
                confirm,
                { confirm = it },
                stringResource(R.string.auth_confirm_password),
                keyboardType = KeyboardType.Password,
                isPassword = true,
            )
            RowAcceptTerms(accepted) { accepted = it }
            LegalLinksRow()
            error?.let {
                Text(it, color = HealthFitColors.Danger, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
            }
            Spacer(Modifier.height(16.dp))
            AuthGradientButton(
                text = stringResource(R.string.auth_register),
                enabled = valid,
                showArrow = false,
                onClick = {
                    loading = true
                    error = null
                    scope.launch {
                        val result = authRepository.signUpWithEmail(email, password, name)
                        loading = false
                        result.onFailure { e -> error = e.message ?: failed }
                    }
                },
            )
            Spacer(Modifier.height(32.dp))
        }
        if (loading) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = HealthFitColors.Accent)
            }
        }
    }
}

@Composable
private fun RowAcceptTerms(accepted: Boolean, onChange: (Boolean) -> Unit) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .clickable { onChange(!accepted) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Switch(
            checked = accepted,
            onCheckedChange = onChange,
            colors = androidx.compose.material3.SwitchDefaults.colors(
                checkedTrackColor = HealthFitColors.Accent,
                checkedThumbColor = Color.White,
            ),
        )
        Text(
            stringResource(R.string.auth_accept_terms),
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
            modifier = Modifier.padding(start = 10.dp),
        )
    }
}

@Composable
private fun ForgotPasswordPane(
    authRepository: AuthRepository,
    onBack: () -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var success by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val sent = stringResource(R.string.auth_reset_sent)
    val failed = stringResource(R.string.auth_failed)
    val canSubmit = email.contains("@") && !loading

    Box(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .statusBarsPadding()
            .imePadding(),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                stringResource(R.string.auth_close),
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .align(Alignment.Start)
                    .padding(top = 8.dp)
                    .clickable(onClick = onBack),
            )
            Spacer(Modifier.height(32.dp))
            Text(
                stringResource(R.string.auth_reset_title),
                color = HealthFitColors.TextPrimary,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                stringResource(R.string.auth_reset_subtitle),
                color = HealthFitColors.TextSecondary,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
            )
            AuthWhiteField(email, { email = it }, stringResource(R.string.auth_email), keyboardType = KeyboardType.Email)
            success?.let {
                Text(it, color = Color(0xFF30D158), fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
            }
            error?.let {
                Text(it, color = HealthFitColors.Danger, fontSize = 12.sp, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
            }
            Spacer(Modifier.height(20.dp))
            AuthGradientButton(
                text = stringResource(R.string.auth_reset_send),
                enabled = canSubmit,
                showArrow = false,
                onClick = {
                    loading = true
                    error = null
                    success = null
                    scope.launch {
                        val result = authRepository.sendPasswordReset(email)
                        loading = false
                        result.fold(
                            onSuccess = { success = sent },
                            onFailure = { error = it.message ?: failed },
                        )
                    }
                },
            )
        }
        if (loading) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = HealthFitColors.Accent)
            }
        }
    }
}
