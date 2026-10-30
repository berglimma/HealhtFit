package com.healthfit.android.ui.auth

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.healthfit.android.R
import com.healthfit.android.core.AppLanguage
import com.healthfit.android.core.AppLanguageStore
import com.healthfit.core.auth.AuthRepository
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal fun Context.findActivity(): Activity? {
    var ctx: Context = this
    while (ctx is ContextWrapper) {
        if (ctx is Activity) return ctx
        ctx = ctx.baseContext
    }
    return null
}

@Composable
internal fun PulsingHeartIcon(size: Int = 72) {
    val pulse = rememberInfiniteTransition(label = "heart")
    val scale by pulse.animateFloat(
        initialValue = 1f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(tween(1050), RepeatMode.Reverse),
        label = "heartScale",
    )
    val glow by pulse.animateFloat(
        initialValue = 0.12f,
        targetValue = 0.28f,
        animationSpec = infiniteRepeatable(tween(1050), RepeatMode.Reverse),
        label = "heartGlow",
    )
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size((size * 1.34f).dp)) {
        Box(
            Modifier
                .size((size * 1.22f).dp)
                .scale(0.95f + (scale - 1f) * 2f)
                .clip(CircleShape)
                .background(HealthFitColors.Accent.copy(alpha = glow)),
        )
        Box(
            Modifier
                .size((size * 1.08f).dp)
                .border(
                    width = 2.dp,
                    color = HealthFitColors.Accent.copy(alpha = glow + 0.22f),
                    shape = CircleShape,
                ),
        )
        Image(
            painter = painterResource(R.drawable.brandheart),
            contentDescription = null,
            modifier = Modifier
                .size((size * 0.9f).dp)
                .scale(scale),
        )
    }
}

@Composable
internal fun LoginLanguageChip() {
    val context = LocalContext.current
    val selected by AppLanguageStore.language.collectAsState()
    var expanded by remember { mutableStateOf(false) }
    Box(contentAlignment = Alignment.Center) {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(HealthFitColors.CardBackground)
                .border(1.dp, HealthFitColors.Accent.copy(alpha = 0.35f), RoundedCornerShape(50))
                .clickable { expanded = true }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(selected.flag, fontSize = 16.sp)
            Text(selected.nativeName, color = HealthFitColors.TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Icon(
                Icons.Filled.UnfoldMore,
                contentDescription = stringResource(R.string.settings_language),
                tint = HealthFitColors.TextSecondary,
                modifier = Modifier.size(14.dp),
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            AppLanguage.entries.forEach { language ->
                DropdownMenuItem(
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(language.menuLabel, modifier = Modifier.weight(1f))
                            if (language == selected) {
                                Icon(Icons.Filled.Check, contentDescription = null, tint = HealthFitColors.Accent)
                            }
                        }
                    },
                    onClick = {
                        AppLanguageStore.set(context, language)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
internal fun AuthWhiteField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    placeholderAlpha: Float = 1f,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        cursorBrush = SolidColor(HealthFitColors.Accent),
        textStyle = TextStyle(
            color = Color.Black,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .shadow(4.dp, RoundedCornerShape(14.dp), ambientColor = Color.Black.copy(alpha = 0.08f))
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.2.dp, Color.Black.copy(alpha = 0.15f), RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) {
                    Text(
                        placeholder,
                        color = HealthFitColors.Accent.copy(alpha = placeholderAlpha),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp,
                    )
                }
                inner()
            }
        },
    )
}

@Composable
internal fun AuthGradientButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
    showArrow: Boolean = true,
) {
    val shape = RoundedCornerShape(12.dp)
    val brush = if (enabled) {
        Brush.linearGradient(listOf(HealthFitColors.Accent, HealthFitColors.AccentSecondary))
    } else {
        Brush.linearGradient(listOf(Color.Gray.copy(alpha = 0.4f), Color.Gray.copy(alpha = 0.4f)))
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(if (enabled) 12.dp else 0.dp, shape, ambientColor = HealthFitColors.Accent.copy(alpha = 0.45f))
            .clip(shape)
            .background(brush)
            .clickable(enabled = enabled, onClick = onClick)
            .border(1.dp, Color.White.copy(alpha = 0.15f), shape)
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        if (showArrow) {
            Spacer(Modifier.width(8.dp))
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
internal fun SocialLoginRow(
    authRepository: AuthRepository,
    loading: Boolean,
    onLoading: (Boolean) -> Unit,
    onError: (String?) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val googleFailed = stringResource(R.string.auth_failed)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
        scope.launch {
            val account = runCatching { task.getResult(ApiException::class.java) }.getOrNull()
            val token = account?.idToken
            if (token.isNullOrBlank()) {
                onLoading(false)
                if (result.resultCode != Activity.RESULT_CANCELED) onError(googleFailed)
                return@launch
            }
            val signed = authRepository.signInWithGoogleIdToken(token)
            onLoading(false)
            signed.onFailure { onError(it.message ?: googleFailed) }
        }
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SocialIconCard(enabled = !loading) {
                val activity = context.findActivity() ?: return@SocialIconCard
                val webClientId = webClientId(context)
                if (webClientId.isNullOrBlank()) {
                    onError(googleFailed)
                    return@SocialIconCard
                }
                onError(null)
                onLoading(true)
                val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                    .requestIdToken(webClientId)
                    .requestEmail()
                    .build()
                val client = GoogleSignIn.getClient(activity, options)
                client.signOut()
                launcher.launch(client.signInIntent)
            }
            AppleIconCard()
        }
        Spacer(Modifier.height(8.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
        ) {
            Box(Modifier.weight(1f).height(1.dp).background(HealthFitColors.TextSecondary.copy(alpha = 0.35f)))
            Text(
                stringResource(R.string.auth_or),
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            Box(Modifier.weight(1f).height(1.dp).background(HealthFitColors.TextSecondary.copy(alpha = 0.35f)))
        }
    }
}

private fun webClientId(context: Context): String? {
    val id = context.resources.getIdentifier("default_web_client_id", "string", context.packageName)
    if (id == 0) return null
    return context.getString(id).ifBlank { null }
}

@Composable
private fun SocialIconCard(enabled: Boolean, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(64.dp)
            .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = HealthFitColors.Accent.copy(alpha = 0.25f))
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .border(1.2.dp, HealthFitColors.Accent.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick),
    ) {
        Text("G", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 22.sp)
    }
}

@Composable
private fun AppleIconCard() {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(64.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.Black),
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_logo_apple),
            contentDescription = stringResource(R.string.auth_continue_apple),
            tint = Color.White,
            modifier = Modifier.size(28.dp),
        )
    }
}

@Composable
internal fun CreateAccountCard(onClick: () -> Unit) {
    val icons = listOf(
        Icons.Filled.FitnessCenter,
        Icons.Filled.DirectionsRun,
        Icons.Filled.SelfImprovement,
        Icons.Filled.Spa,
        Icons.Filled.LocalFireDepartment,
        Icons.Filled.Favorite,
    )
    var index by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(2000)
            index = (index + 1) % icons.size
        }
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(6.dp, RoundedCornerShape(12.dp), ambientColor = HealthFitColors.Accent.copy(alpha = 0.15f))
            .clip(RoundedCornerShape(12.dp))
            .background(HealthFitColors.CardBackground)
            .border(1.dp, HealthFitColors.Accent.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CyclingWorkoutIcon(icons[index])
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                stringResource(R.string.auth_create_account),
                color = HealthFitColors.TextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
            )
            Text(
                stringResource(R.string.auth_create_account_subtitle),
                color = HealthFitColors.TextSecondary,
                fontSize = 11.sp,
                maxLines = 2,
            )
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = HealthFitColors.Accent.copy(alpha = 0.8f),
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
private fun CyclingWorkoutIcon(icon: ImageVector) {
    val pulse = rememberInfiniteTransition(label = "createIcon")
    val scale by pulse.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(550), RepeatMode.Reverse),
        label = "createIconScale",
    )
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(56.dp)) {
        Box(
            Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(HealthFitColors.Accent.copy(alpha = 0.14f))
                .border(1.5.dp, HealthFitColors.Accent.copy(alpha = 0.35f), CircleShape),
        )
        Icon(
            icon,
            contentDescription = null,
            tint = HealthFitColors.Accent,
            modifier = Modifier
                .size(26.dp)
                .scale(scale),
        )
    }
}

@Composable
internal fun LegalLinksRow() {
    val uriHandler = LocalUriHandler.current
    val privacy = stringResource(R.string.privacy_url)
    val terms = stringResource(R.string.terms_url)
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.legal_privacy),
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.clickable { runCatching { uriHandler.openUri(privacy) } },
        )
        Text("  ·  ", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
        Text(
            stringResource(R.string.legal_terms),
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.clickable { runCatching { uriHandler.openUri(terms) } },
        )
    }
}
