package com.healthfit.android.ui.assistant

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private data class ChatLine(
    val fromUser: Boolean,
    val text: String,
    val id: String = java.util.UUID.randomUUID().toString(),
)

@Composable
fun AssistantScreen(
    name: String,
    wellness: DailyWellness,
    athlete: AthleteProfile,
    userId: String?,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val density = LocalDensity.current
    val imeVisible = WindowInsets.ime.getBottom(density) > 0
    val focusRequester = remember { FocusRequester() }
    var inputFocused by remember { mutableStateOf(false) }

    val snapshot = remember(userId) { AssistantRoutineStore.load(context, userId) }
    val profile = remember(snapshot) { AssistantRoutineProfileEngine.buildProfile(snapshot) }
    val weeklyCount = remember(snapshot) { AssistantRoutineProfileEngine.weeklyWorkoutCount(snapshot) }
    val hasWorkoutAlert = weeklyCount == 0

    val messages = remember {
        mutableStateListOf(
            ChatLine(false, AssistantEngine.welcome(name, wellness, athlete, profile, hasWorkoutAlert)),
        )
    }
    var draft by remember { mutableStateOf("") }
    var isTyping by remember { mutableStateOf(false) }
    var replyJob by remember { mutableStateOf<Job?>(null) }
    val listState = rememberLazyListState()
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            AssistantNotifications.activate(context, wellness, name, userId)
            Toast.makeText(context, "Notificações do IAssistente ativas", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, "As notificações ficam desligadas até você permitir", Toast.LENGTH_SHORT).show()
        }
    }

    fun dismissKeyboard() {
        focusManager.clearFocus(force = true)
        keyboard?.hide()
        inputFocused = false
    }

    fun enableNotifications() {
        val needsPermission = Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        if (needsPermission) {
            permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            AssistantNotifications.activate(context, wellness, name, userId)
            Toast.makeText(context, "Lembretes de água, treino, suplemento e check-in ativos", Toast.LENGTH_SHORT).show()
        }
    }

    fun appendProactiveInsights() {
        if (isTyping) return
        val fresh = AssistantRoutineStore.load(context, userId)
        val built = AssistantRoutineProfileEngine.buildProfile(fresh)
        val week = AssistantRoutineProfileEngine.weeklyWorkoutCount(fresh)
        AssistantRoutineProfileEngine.missedWindowMessageIfNeeded(name, built, fresh, wellness)?.let { text ->
            if (messages.none { !it.fromUser && it.text == text }) {
                messages += ChatLine(false, text)
                AssistantRoutineStore.markInsightDelivered(context, userId, AssistantRoutineStore.dayKey())
            }
            return
        }
        AssistantRoutineProfileEngine.personalizedAnalysisMessageIfNeeded(
            athleteName = name,
            profile = built,
            snapshot = fresh,
            wellness = wellness,
            weeklyWorkoutCount = week,
        )?.let { text ->
            if (messages.none { !it.fromUser && it.text == text }) {
                messages += ChatLine(false, text)
                AssistantRoutineStore.markAnalysisDelivered(context, userId, AssistantRoutineStore.dayKey())
            }
        }
    }

    LaunchedEffect(Unit) {
        AssistantRoutineStore.markAppOpened(context, userId)
        enableNotifications()
        appendProactiveInsights()
    }

    suspend fun scrollChatToEnd() {
        val target = if (isTyping) messages.size else messages.lastIndex.coerceAtLeast(0)
        if (messages.isNotEmpty() || isTyping) {
            listState.animateScrollToItem(target)
        }
    }

    LaunchedEffect(messages.size, isTyping, imeVisible, inputFocused) {
        scrollChatToEnd()
    }

    // When keyboard opens or field gains focus, jump to the latest message.
    LaunchedEffect(imeVisible, inputFocused) {
        if (imeVisible || inputFocused) {
            delay(80)
            scrollChatToEnd()
        } else {
            inputFocused = false
            delay(50)
            scrollChatToEnd()
        }
    }

    fun send(text: String) {
        val clean = text.trim()
        if (clean.isEmpty() || isTyping) return
        messages += ChatLine(true, clean)
        draft = ""
        dismissKeyboard()
        val feeling = AssistantRoutineStore.classifyFeeling(clean)
        if (feeling != "neutral") {
            AssistantRoutineStore.recordMood(context, userId, kind = "chat", feeling = feeling)
        }
        isTyping = true
        replyJob?.cancel()
        replyJob = scope.launch {
            delay(AssistantEngine.ReplyDelayMs)
            val snap = AssistantRoutineStore.load(context, userId)
            val built = AssistantRoutineProfileEngine.buildProfile(snap)
            val week = AssistantRoutineProfileEngine.weeklyWorkoutCount(snap)
            val last = snap.sessions.maxOfOrNull { it.endedAtMillis }
            val hours = last?.let { (System.currentTimeMillis() - it) / 3_600_000.0 }
            messages += ChatLine(
                false,
                AssistantEngine.reply(clean, wellness, athlete, name, built, week, hours),
            )
            isTyping = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
            .padding(horizontal = 16.dp),
    ) {
        AnimatedVisibility(visible = !imeVisible, enter = fadeIn(), exit = fadeOut()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
            ) {
                Column(Modifier.weight(1f)) {
                    Text("IAssistente", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.ExtraBold)
                    Text("Treino, nutrição e o seu dia", color = HealthFitColors.TextSecondary, fontSize = 13.sp)
                }
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .border(1.dp, HealthFitColors.Accent, CircleShape)
                        .clickable(enabled = !isTyping) { enableNotifications() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Notifications, contentDescription = "Notificações", tint = HealthFitColors.Accent)
                }
                Spacer(Modifier.size(8.dp))
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .border(1.dp, HealthFitColors.Accent, CircleShape)
                        .clickable(enabled = !isTyping) {
                            dismissKeyboard()
                            replyJob?.cancel()
                            isTyping = false
                            val fresh = AssistantRoutineStore.load(context, userId)
                            val built = AssistantRoutineProfileEngine.buildProfile(fresh)
                            val week = AssistantRoutineProfileEngine.weeklyWorkoutCount(fresh)
                            messages.clear()
                            messages += ChatLine(
                                false,
                                AssistantEngine.welcome(name, wellness, athlete, built, week == 0),
                            )
                            appendProactiveInsights()
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Refresh, contentDescription = "Reiniciar", tint = HealthFitColors.Accent)
                }
            }
        }

        if (imeVisible) {
            Text(
                "IAssistente",
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
            )
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .pointerInput(Unit) {
                    detectTapGestures(onTap = { dismissKeyboard() })
                },
            contentPadding = PaddingValues(top = 8.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(messages, key = { it.id }) { line ->
                val mine = line.fromUser
                Box(Modifier.fillMaxWidth(), contentAlignment = if (mine) Alignment.CenterEnd else Alignment.CenterStart) {
                    Text(
                        line.text,
                        color = if (mine) Color.Black else Color.White,
                        fontSize = 14.sp,
                        modifier = Modifier
                            .fillMaxWidth(if (mine) 0.86f else 1f)
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (mine) HealthFitColors.Accent else HealthFitColors.CardBackground)
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                    )
                }
            }
            if (isTyping) {
                item(key = "typing") {
                    TypingIndicatorBubble()
                }
            }
        }

        AnimatedVisibility(visible = !imeVisible) {
            Column {
                Row(
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AssistantEngine.suggestions.forEach { suggestion ->
                        Text(
                            suggestion,
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier
                                .clip(RoundedCornerShape(18.dp))
                                .background(Color(0xFF1E4A32))
                                .clickable(enabled = !isTyping) {
                                    dismissKeyboard()
                                    send(suggestion)
                                }
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                        )
                    }
                }
                Text(
                    AssistantEngine.Disclaimer,
                    color = Color(0xFF8E989F),
                    fontSize = 11.sp,
                    modifier = Modifier.padding(bottom = 4.dp),
                )
            }
        }

        // Composer always sits just above the keyboard via imePadding.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp, bottom = if (imeVisible) 8.dp else 8.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(HealthFitColors.CardBackground)
                .border(
                    width = if (inputFocused || imeVisible) 1.dp else 0.dp,
                    color = if (inputFocused || imeVisible) HealthFitColors.Accent.copy(alpha = 0.55f) else Color.Transparent,
                    shape = RoundedCornerShape(24.dp),
                )
                .padding(horizontal = 14.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicTextField(
                value = draft,
                onValueChange = { if (!isTyping) draft = it },
                enabled = !isTyping,
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 40.dp, max = 120.dp)
                    .padding(vertical = 10.dp)
                    .focusRequester(focusRequester)
                    .onFocusChanged { state ->
                        inputFocused = state.isFocused
                        if (state.isFocused) {
                            scope.launch {
                                delay(120)
                                val target = if (isTyping) messages.size else messages.lastIndex.coerceAtLeast(0)
                                if (messages.isNotEmpty() || isTyping) {
                                    listState.animateScrollToItem(target)
                                }
                            }
                        }
                    },
                textStyle = TextStyle(color = Color.White, fontSize = 15.sp, lineHeight = 20.sp),
                cursorBrush = SolidColor(HealthFitColors.Accent),
                maxLines = 5,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { send(draft) }),
                decorationBox = { inner ->
                    Box(contentAlignment = Alignment.CenterStart) {
                        if (draft.isEmpty()) {
                            Text(
                                "Conte como você está se sentindo...",
                                color = Color(0xFF8E989F),
                                fontSize = 15.sp,
                            )
                        }
                        inner()
                    }
                },
            )
            Spacer(Modifier.size(8.dp))
            Icon(
                Icons.AutoMirrored.Filled.Send,
                contentDescription = "Enviar",
                tint = if (isTyping || draft.isBlank()) {
                    HealthFitColors.Accent.copy(alpha = 0.4f)
                } else {
                    HealthFitColors.Accent
                },
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable(
                        enabled = !isTyping && draft.isNotBlank(),
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                    ) { send(draft) }
                    .padding(8.dp),
            )
        }
    }
}

@Composable
private fun TypingIndicatorBubble() {
    val transition = rememberInfiniteTransition(label = "typing")
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("escrevendo", color = Color(0xFF8E989F), fontSize = 12.sp)
        Spacer(Modifier.size(4.dp))
        repeat(3) { index ->
            val offset by transition.animateFloat(
                initialValue = 0f,
                targetValue = -4f,
                animationSpec = infiniteRepeatable(
                    animation = tween(durationMillis = 360, delayMillis = index * 160, easing = LinearEasing),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "dot$index",
            )
            Box(
                modifier = Modifier
                    .offset(y = offset.dp)
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF8E989F)),
            )
        }
    }
}
