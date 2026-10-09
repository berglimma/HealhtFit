package com.healthfit.android.ui.assistant

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.designsystem.HealthFitColors

private data class ChatLine(val fromUser: Boolean, val text: String)

@Composable
fun AssistantScreen(
    name: String,
    wellness: DailyWellness,
    athlete: AthleteProfile,
) {
    val context = LocalContext.current
    val messages = remember {
        mutableStateListOf(ChatLine(false, AssistantEngine.welcome(name, wellness, athlete)))
    }
    var draft by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            AssistantNotifications.activate(context, wellness, name)
            Toast.makeText(context, "Notificações do IAssistente ativas", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, "As notificações ficam desligadas até você permitir", Toast.LENGTH_SHORT).show()
        }
    }

    fun enableNotifications() {
        val needsPermission = Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        if (needsPermission) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        else {
            AssistantNotifications.activate(context, wellness, name)
            Toast.makeText(context, "Lembretes de água, treino, suplemento e check-in ativos", Toast.LENGTH_SHORT).show()
        }
    }

    LaunchedEffect(Unit) { enableNotifications() }
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.lastIndex)
    }

    fun send(text: String) {
        val clean = text.trim()
        if (clean.isEmpty()) return
        messages += ChatLine(true, clean)
        messages += ChatLine(false, AssistantEngine.reply(clean, wellness, athlete, name))
        draft = ""
    }

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            Column(Modifier.weight(1f)) {
                Text("IAssistente", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.ExtraBold)
                Text("Treino, nutrição e o seu dia", color = HealthFitColors.TextSecondary, fontSize = 13.sp)
            }
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .border(1.dp, HealthFitColors.Accent, CircleShape)
                    .clickable { enableNotifications() },
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
                    .clickable {
                        messages.clear()
                        messages += ChatLine(false, AssistantEngine.welcome(name, wellness, athlete))
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Refresh, contentDescription = "Reiniciar", tint = HealthFitColors.Accent)
            }
        }
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).padding(top = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(messages) { line ->
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
        }
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 8.dp),
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
                        .clickable { send(suggestion) }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }
        Text(AssistantEngine.Disclaimer, color = Color(0xFF8E989F), fontSize = 11.sp)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp, bottom = 8.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(HealthFitColors.CardBackground)
                .padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicTextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.weight(1f).padding(vertical = 8.dp),
                textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
                decorationBox = { inner ->
                    if (draft.isEmpty()) Text("Conte como você está se sentindo...", color = Color(0xFF8E989F))
                    inner()
                },
            )
            Spacer(Modifier.size(8.dp))
            Icon(
                Icons.Filled.Send,
                contentDescription = "Enviar",
                tint = HealthFitColors.Accent,
                modifier = Modifier.clickable { send(draft) },
            )
        }
    }
}
