package com.healthfit.android.ui.profile

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import coil.compose.AsyncImage
import java.io.File
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors

@Composable
fun CoachEntryCard(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(220.dp)
            .clip(RoundedCornerShape(22.dp))
            .clickable(onClick = onClick),
    ) {
        Image(
            painter = painterResource(R.drawable.cardiocovercaminhada),
            contentDescription = null,
            modifier = Modifier.matchParentSize(),
            contentScale = ContentScale.Crop,
        )
        Box(
            Modifier
                .matchParentSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.05f), Color.Black.copy(alpha = 0.78f)),
                    ),
                ),
        )
        Column(Modifier.align(Alignment.BottomStart).padding(16.dp)) {
            Text("PAINEL PROFISSIONAL", color = HealthFitColors.Accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Text("HealthFit Coach", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            Text("1 aluno vinculado · fichas, dietas e chat", color = Color.White.copy(alpha = 0.92f), fontSize = 13.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                Chip("1 aluno")
                Chip("CREF 000000-RJ")
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.padding(top = 10.dp)) {
                Mini(Icons.Filled.Groups, "Alunos")
                Mini(Icons.Filled.FitnessCenter, "Prescrever")
                Mini(Icons.Filled.Chat, "Chat")
            }
        }
    }
}

@Composable
fun CoachHubScreen(onBack: () -> Unit, onOpen: (String) -> Unit, sent: Boolean = false) {
    HubColumn(onBack, "HealthFit Coach") {
        if (sent) {
            Text("Ficha enviada ao aluno.", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold)
        }
        Text("Fichas, dietas e chat do aluno vinculado.", color = Color(0xFFB7C0C8))
        Action("Alunos", "1 aluno ativo") { onOpen("coach-alunos") }
        Action("Prescrever", "Enviar ficha ou dieta") { onOpen("coach-prescribe") }
        Action("Chat", "Conversar com o aluno") { onOpen("coach-chat") }
        Action("Fichas", "Treino — Peito + Tríceps") { onOpen("coach-fichas") }
    }
}

@Composable
fun CoachStudentsScreen(onBack: () -> Unit, onOpenSheet: () -> Unit) {
    HubColumn(onBack, "Alunos") {
        DarkCard(onClick = onOpenSheet) {
            Text("Aluno vinculado", color = Color.White, fontWeight = FontWeight.Bold)
            Text("Ficha ativa: Treino — Peito + Tríceps", color = Color(0xFFB7C0C8), fontSize = 13.sp)
            Text("Toque para abrir a ficha", color = HealthFitColors.Accent, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

@Composable
fun CoachPrescribeScreen(onBack: () -> Unit, onSent: () -> Unit) {
    var name by remember { mutableStateOf("Treino — Peito + Tríceps") }
    HubColumn(onBack, "Prescrever") {
        OutlinedTextField(
            name,
            { name = it },
            label = { Text("Nome da ficha") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = HealthFitColors.Accent,
                unfocusedBorderColor = Color(0xFF3A4148),
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        GradientButton("Enviar ao aluno", onClick = onSent)
    }
}

@Composable
fun CoachChatScreen(onBack: () -> Unit) {
    val messages = remember { mutableStateListOf("Berg: Ficha de peito enviada.") }
    var draft by remember { mutableStateOf("") }
    HubColumn(onBack, "Chat") {
        messages.forEach { line ->
            Text(line, color = Color.White, modifier = Modifier.padding(vertical = 4.dp))
        }
        OutlinedTextField(
            draft,
            { draft = it },
            label = { Text("Mensagem") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedBorderColor = HealthFitColors.Accent,
                unfocusedBorderColor = Color(0xFF3A4148),
            ),
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        Spacer(Modifier.height(8.dp))
        GradientButton("Enviar", {
            if (draft.isNotBlank()) {
                messages.add("Você: ${draft.trim()}")
                draft = ""
            }
        })
    }
}

@Composable
fun CoachSheetScreen(onBack: () -> Unit) {
    val moves = listOf("Supino reto", "Supino inclinado", "Crucifixo", "Tríceps pulley", "Tríceps testa")
    HubColumn(onBack, "Treino — Peito + Tríceps") {
        Text("Prescrita por Berg Limma · 13 exercícios · ~73 min", color = Color(0xFFB7C0C8))
        moves.forEach { move ->
            DarkCard(modifier = Modifier.padding(top = 8.dp)) {
                Text(move, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("4 séries · GIF no treino", color = Color(0xFF8E989F), fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun ProfileCover(
    coverFile: File?,
    avatarFile: File?,
    name: String,
    email: String,
    onChangeCover: () -> Unit,
    onChangeAvatar: () -> Unit,
    onClearCover: () -> Unit,
    onClearAvatar: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(168.dp)
            .clip(RoundedCornerShape(18.dp))
            .clickable(onClick = onChangeCover),
    ) {
        if (coverFile != null) {
            AsyncImage(
                model = coverFile,
                contentDescription = "Foto de fundo",
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Image(
                painter = painterResource(R.drawable.cardiocovercaminhada),
                contentDescription = "Foto de fundo",
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
        }
        Text(
            if (coverFile == null) "Toque para foto de fundo" else "Alterar fundo",
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(10.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.45f))
                .padding(horizontal = 10.dp, vertical = 6.dp),
        )
        if (coverFile != null) {
            Text(
                "✕",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.45f))
                    .clickable(onClick = onClearCover)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 10.dp, bottom = 8.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF1F6B32))
                    .clickable(onClick = onChangeAvatar),
                contentAlignment = Alignment.Center,
            ) {
                if (avatarFile != null) {
                    AsyncImage(
                        model = avatarFile,
                        contentDescription = "Foto do perfil",
                        modifier = Modifier.matchParentSize(),
                        contentScale = ContentScale.Crop,
                    )
                } else {
                    Text(
                        name.firstOrNull()?.uppercase().orEmpty(),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 28.sp,
                    )
                }
            }
            Text(
                if (avatarFile == null) "Foto" else "Remover",
                color = if (avatarFile == null) HealthFitColors.Accent else Color(0xFFFF6B6B),
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .clickable(onClick = if (avatarFile == null) onChangeAvatar else onClearAvatar),
            )
        }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(name, color = Color.White, fontWeight = FontWeight.Bold)
            Text(email, color = Color(0xFFB7C0C8), fontSize = 12.sp)
            Text("🇧🇷 Brasil", color = Color(0xFFB7C0C8), fontSize = 12.sp)
            Text("Toque no avatar ou no fundo para a galeria", color = HealthFitColors.Accent, fontSize = 12.sp)
        }
    }
}

@Composable
private fun HubColumn(onBack: () -> Unit, title: String, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Text(title, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 10.dp))
        content()
    }
}

@Composable
private fun Action(title: String, subtitle: String, onClick: () -> Unit) {
    DarkCard(onClick = onClick, modifier = Modifier.padding(top = 10.dp)) {
        Text(title, color = Color.White, fontWeight = FontWeight.Bold)
        Text(subtitle, color = Color(0xFFB7C0C8), fontSize = 13.sp)
    }
}

@Composable
private fun Chip(text: String) {
    Text(
        text,
        color = Color.White,
        fontSize = 12.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.16f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun Mini(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.height(14.dp))
        Text(" $label", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
    }
}
