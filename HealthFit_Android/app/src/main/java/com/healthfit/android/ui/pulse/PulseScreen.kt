package com.healthfit.android.ui.pulse

import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.HealthFitTabBar
import com.healthfit.android.ui.components.HeroCard
import com.healthfit.android.ui.components.TabSpec
import com.healthfit.designsystem.HealthFitColors

private data class LocalPost(val caption: String, val community: String, val modality: String)

@Composable
fun PulseScreen(onClose: () -> Unit) {
    var tab by remember { mutableIntStateOf(0) }
    var composer by remember { mutableStateOf<String?>(null) }
    val posts = remember { mutableStateListOf<LocalPost>() }
    var storyCaption by remember { mutableStateOf<String?>(null) }
    Column(modifier = Modifier.fillMaxSize()) {
        PulseTopBar(
            onClose = onClose,
            onCompose = {
                tab = 1
                composer = "post"
            },
        )
        Text(
            "Sozinho você treina. Junto, você permanece.",
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 8.dp),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            when {
                composer == "post" -> PostComposer(
                    onCancel = { composer = null },
                    onPublish = { caption, community, modality ->
                        posts.add(0, LocalPost(caption, community, modality))
                        composer = null
                        tab = 0
                    },
                )
                composer == "story" -> StoryComposer(
                    onCancel = { composer = null },
                    onPublish = { text ->
                        storyCaption = text
                        composer = null
                        tab = 0
                    },
                )
                tab == 0 -> FeedTab(posts, storyCaption) { composer = "story" }
                tab == 1 -> PostHub(
                    onCreatePost = { composer = "post" },
                    onCreateStory = { composer = "story" },
                )
                tab == 2 -> CommunitiesTab()
                else -> EmptyPulse("Pessoas", "Busque atletas e profissionais para seguir no Pulse.")
            }
            Spacer(Modifier.height(12.dp))
        }
        HealthFitTabBar(
            items = listOf(
                TabSpec("feed", "Feed", Icons.Filled.Favorite),
                TabSpec("post", "Postar", Icons.Filled.Add),
                TabSpec("comunidade", "Comunidade", Icons.Filled.Groups),
                TabSpec("pessoas", "Pessoas", Icons.Filled.Search),
            ),
            selectedRoute = listOf("feed", "post", "comunidade", "pessoas")[tab],
            onSelect = { route ->
                composer = if (route == "post") "post" else null
                tab = listOf("feed", "post", "comunidade", "pessoas").indexOf(route)
            },
        )
    }
}

@Composable
private fun PulseTopBar(onClose: () -> Unit, onCompose: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            "Fechar",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .border(1.dp, Color(0xFF3A4148), RoundedCornerShape(20.dp))
                .clickable(onClick = onClose)
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Favorite, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
            Text(" Pulse", color = Color.White, fontWeight = FontWeight.Bold)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircleIcon(Icons.Filled.Search)
            CircleIcon(Icons.Filled.Add, onCompose)
            CircleIcon(Icons.Filled.MoreHoriz)
        }
    }
}

@Composable
private fun CircleIcon(icon: ImageVector, onClick: () -> Unit = {}) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .border(1.dp, Color(0xFF3A4148), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun FeedTab(
    posts: List<LocalPost>,
    storyCaption: String?,
    onStory: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable(onClick = onStory)) {
        Box(
            modifier = Modifier
                .size(54.dp)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(Color(0xFF1A4A6A), Color(0xFF3DDC3A)))),
            contentAlignment = Alignment.Center,
        ) {
            Text(if (storyCaption == null) "+" else "B", color = Color.White, fontWeight = FontWeight.Bold)
        }
        Text(
            if (storyCaption == null) "  Seu story" else "  $storyCaption",
            color = Color(0xFFB7C0C8),
            fontSize = 12.sp,
        )
    }
    Spacer(Modifier.height(14.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Favorite, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(16.dp))
            Text("  Desafio do dia", color = Color.White, fontWeight = FontWeight.Bold)
        }
        Text(
            "Suba escadas por 5 minutos contínuos. ✨",
            color = Color(0xFFD5DDE3),
            modifier = Modifier.padding(top = 8.dp, start = 24.dp),
        )
    }
    Spacer(Modifier.height(12.dp))
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilterPill("✨ Todos", selected = true)
        FilterPill("Musculação  ATIVO", selected = false)
        FilterPill("Cardio  ATIVO", selected = false)
    }
    Spacer(Modifier.height(12.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(16.dp),
    ) {
        Text("Destaque da semana", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(
            "Publique algo esta semana para aparecer aqui.",
            color = Color(0xFFB7C0C8),
            modifier = Modifier.padding(top = 6.dp),
        )
    }
    posts.forEach { post ->
        Spacer(Modifier.height(12.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .padding(16.dp),
        ) {
            Text(post.community, color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text(post.modality.ifBlank { "Treino" }, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            if (post.caption.isNotBlank()) {
                Text(post.caption, color = Color(0xFFD5DDE3), modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
    if (posts.isNotEmpty()) return
    Spacer(Modifier.height(12.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(54.dp)
                .clip(CircleShape)
                .border(2.dp, HealthFitColors.Accent, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Favorite, contentDescription = null, tint = HealthFitColors.Accent)
        }
        Text("Seu feed está quieto", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp, modifier = Modifier.padding(top = 12.dp))
        Text(
            "Compartilhar “Cardio — Kitesurf · Big Air” no Pulse?",
            color = Color(0xFFD5DDE3),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        Spacer(Modifier.height(12.dp))
        HeroCard(
            title = "Berg Limma fechou o kitesurf",
            subtitle = "0,26 km · 4 min · treino com maestria",
            brush = Brush.linearGradient(listOf(Color(0xFF123044), Color(0xFF1A4030))),
            height = 120.dp,
            eyebrow = "HealthFit",
        )
        Spacer(Modifier.height(14.dp))
        GradientButton(text = "Publicar treino", onClick = {})
    }
}

@Composable
private fun PostHub(onCreatePost: () -> Unit, onCreateStory: () -> Unit) {
    Text("Postar", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
    Text(
        "Crie um card com foto para aparecer no feed do Pulse (24h).",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
    )
    GradientButton(text = "Criar post para o feed", onClick = onCreatePost, icon = Icons.Filled.Add)
    Spacer(Modifier.height(12.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Text("Stories continuam no topo do Feed", color = Color.White, fontWeight = FontWeight.SemiBold)
        Text(
            "Toque no círculo “Seu story” no Feed para publicar stories com música e texto.",
            color = Color(0xFFB7C0C8),
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 10.dp),
        )
        Text(
            "Criar story",
            color = Color.Black,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(HealthFitColors.Accent)
                .clickable(onClick = onCreateStory)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        )
    }
}

@Composable
private fun PostComposer(
    onCancel: () -> Unit,
    onPublish: (caption: String, community: String, modality: String) -> Unit,
) {
    var media by remember { mutableStateOf<String?>(null) }
    var music by remember { mutableStateOf("Nenhuma") }
    var community by remember { mutableStateOf("Musculação") }
    var modality by remember { mutableStateOf("") }
    var minutes by remember { mutableStateOf("") }
    var duo by remember { mutableStateOf("") }
    var intensityOn by remember { mutableStateOf(false) }
    var intensity by remember { mutableIntStateOf(7) }
    var caption by remember { mutableStateOf("") }
    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedTextColor = Color.White,
        unfocusedTextColor = Color.White,
        focusedBorderColor = HealthFitColors.Accent,
        unfocusedBorderColor = Color(0xFF3A4148),
        cursorColor = HealthFitColors.Accent,
    )
    Text("Cancelar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onCancel))
    Text("Novo post", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
    Text("Mídia", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ChoiceChip("Câmera", Icons.Filled.CameraAlt, media == "Câmera") { media = "Câmera" }
        ChoiceChip("Galeria", Icons.Filled.PhotoLibrary, media == "Galeria") { media = "Galeria" }
    }
    if (media != null) {
        Image(
            painter = painterResource(if (media == "Câmera") R.drawable.cardiocovercorrida else R.drawable.workoutprogrammale),
            contentDescription = null,
            modifier = Modifier
                .padding(top = 10.dp)
                .fillMaxWidth()
                .height(160.dp)
                .clip(RoundedCornerShape(12.dp)),
            contentScale = ContentScale.Crop,
        )
    }
    Text("Música (opcional)", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Nenhuma", "Treino", "Foco", "Energia").forEach { option ->
            FilterPill(option, music == option) { music = option }
        }
    }
    Text("Comunidade", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Musculação", "Cardio", "Corrida").forEach { option ->
            FilterPill(option, community == option) { community = option }
        }
    }
    Text("Só comunidades ATIVO aparecem aqui.", color = Color(0xFF8E989F), fontSize = 12.sp)
    Text("Detalhes do treino (opcional)", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp))
    OutlinedTextField(modality, { modality = it }, label = { Text("Modalidade") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    OutlinedTextField(minutes, { minutes = it }, label = { Text("Duração (minutos)") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    OutlinedTextField(duo, { duo = it }, label = { Text("Dupla / equipe") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
        Text("Incluir intensidade", color = Color.White, modifier = Modifier.weight(1f))
        Text(
            if (intensityOn) "$intensity/10" else "Não",
            color = HealthFitColors.Accent,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable {
                intensityOn = !intensityOn
            },
        )
    }
    if (intensityOn) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            listOf(5, 7, 8, 10).forEach { value ->
                FilterPill("$value", intensity == value) { intensity = value }
            }
        }
    }
    Text("Legenda (${caption.length}/180)", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp))
    OutlinedTextField(
        caption,
        { if (it.length <= 180) caption = it },
        label = { Text("Sozinho você treina. Junto, você permanece.") },
        colors = fieldColors,
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
    )
    Text("Digite @ para marcar quem você segue.", color = Color(0xFF8E989F), fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp, bottom = 12.dp))
    GradientButton(
        text = "Publicar",
        onClick = {
            val detail = listOf(modality, minutes.takeIf { it.isNotBlank() }?.let { "$it min" }, duo)
                .filter { !it.isNullOrBlank() }
                .joinToString(" · ")
            onPublish(caption, community, detail.ifBlank { modality })
        },
        icon = Icons.Filled.Add,
    )
}

@Composable
private fun StoryComposer(onCancel: () -> Unit, onPublish: (String) -> Unit) {
    var text by remember { mutableStateOf("") }
    var music by remember { mutableStateOf("Nenhuma") }
    Text("Cancelar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onCancel))
    Text("Seu story", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
    Text("Música", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("Nenhuma", "Treino", "Foco").forEach { option ->
            FilterPill(option, music == option) { music = option }
        }
    }
    OutlinedTextField(
        text,
        { text = it },
        label = { Text("Texto do story") },
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = HealthFitColors.Accent,
            unfocusedBorderColor = Color(0xFF3A4148),
            cursorColor = HealthFitColors.Accent,
        ),
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 12.dp),
    )
    GradientButton(
        text = "Publicar story",
        onClick = { onPublish(text.ifBlank { "Story" } + if (music == "Nenhuma") "" else " · $music") },
        icon = Icons.Filled.MusicNote,
    )
}

@Composable
private fun ChoiceChip(label: String, icon: ImageVector, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) Color.Black else HealthFitColors.Accent, modifier = Modifier.size(16.dp))
        Text(" $label", color = if (selected) Color.Black else Color.White, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun CommunitiesTab() {
    Text("Comunidades", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
    Text(
        "Ative um tema para ele aparecer no Feed (ao lado de Todos) e nos posts como ATIVO.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
    )
    Text("Ativas agora", color = Color.White, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ActivePill("Musculação")
        ActivePill("Cardio")
        ActivePill("Corrida")
    }
    Spacer(Modifier.height(14.dp))
    Text("Posts nas comunidades ATIVO", color = Color.White, fontWeight = FontWeight.Bold)
    Text(
        "Ainda não há posts nas suas comunidades ativas.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
    )
    HeroCard(
        title = "Musculação",
        subtitle = "ATIVO no Feed e nos posts · toque para sair",
        brush = Brush.linearGradient(listOf(Color(0xFF102018), Color(0xFF1A4030))),
        eyebrow = "ATIVO",
        height = 150.dp,
    )
    Spacer(Modifier.height(10.dp))
    HeroCard(
        title = "Cardio",
        subtitle = "ATIVO no Feed e nos posts · toque para sair",
        brush = Brush.linearGradient(listOf(Color(0xFF1A2840), Color(0xFF3A2418))),
        eyebrow = "ATIVO",
        height = 150.dp,
    )
}

@Composable
private fun EmptyPulse(title: String, body: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(20.dp),
    ) {
        Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
        Text(body, color = Color(0xFFB7C0C8), modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun FilterPill(text: String, selected: Boolean, onClick: () -> Unit = {}) {
    val brush = if (selected) {
        Brush.horizontalGradient(listOf(Color(0xFF3DDC4A), Color(0xFFFF9A3C)))
    } else {
        Brush.horizontalGradient(listOf(Color(0xFF1C2126), Color(0xFF1C2126)))
    }
    Text(
        text,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(brush)
            .border(1.dp, Color(0xFF3A4148), RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

@Composable
private fun ActivePill(text: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF3DDC4A), Color(0xFFFF9A3C))))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.FitnessCenter, contentDescription = null, tint = Color.Black, modifier = Modifier.size(14.dp))
        Text(" $text  ATIVO", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 12.sp)
    }
}
