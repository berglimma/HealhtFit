package com.healthfit.android.ui.pulse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.core.pulse.PulseFollowStatus
import com.healthfit.core.pulse.PulseLimits
import com.healthfit.core.pulse.PulsePerson
import com.healthfit.core.pulse.PulseStory
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun PulseTermsGate(onAccept: () -> Unit, onCancel: () -> Unit) {
    var confirmedAge by remember { mutableStateOf(false) }
    var scrolled by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    LaunchedEffect(scroll.value, scroll.maxValue) {
        if (scroll.maxValue > 0 && scroll.value >= scroll.maxValue - 80) scrolled = true
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .padding(20.dp),
    ) {
        Text("HealthFit Pulse", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(PulseLimits.TAGLINE, color = HealthFitColors.Accent, modifier = Modifier.padding(top = 6.dp))
        Text(
            "Versão ${PulseLimits.TERMS_VERSION}. Role até o fim, declare ter 18+ e aceite para entrar.",
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 8.dp, bottom = 12.dp),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(scroll)
                .clip(RoundedCornerShape(16.dp))
                .background(HealthFitColors.CardBackground)
                .padding(16.dp),
        ) {
            Text(PULSE_TERMS_PT, color = Color(0xFFD5DDE3), fontSize = 13.sp, lineHeight = 18.sp)
        }
        if (!scrolled) {
            Text(
                "Role até o fim para habilitar o aceite",
                color = HealthFitColors.Accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
        Text(
            "Declaro ter ${PulseLimits.UGC_MINIMUM_AGE} anos ou mais",
            color = if (confirmedAge) HealthFitColors.Accent else Color.White,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 12.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(if (confirmedAge) HealthFitColors.Accent.copy(alpha = 0.2f) else HealthFitColors.CardBackground)
                .clickable { confirmedAge = !confirmedAge }
                .padding(12.dp)
                .fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        GradientButton(
            text = "Li e aceito",
            onClick = { if (scrolled && confirmedAge) onAccept() },
        )
        Text(
            "Agora não",
            color = Color(0xFFB7C0C8),
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .padding(12.dp)
                .clickable(onClick = onCancel),
        )
    }
}

@Composable
fun PulseCommunitiesTab(store: PulseStore) {
    Text("Comunidades", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
    Text(
        "Toque para ativar ou sair. O feed mostra só as comunidades ATIVO.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
    )
    PulseLimits.THEMATIC_COMMUNITIES.forEach { key ->
        val active = key in store.joinedCommunities
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(if (active) HealthFitColors.Accent else HealthFitColors.CardBackground)
                .clickable { store.toggleCommunity(key) }
                .padding(14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(PulseLimits.communityTitle(key), color = if (active) Color.Black else Color.White, fontWeight = FontWeight.Bold)
            Text(if (active) "ATIVO" else "Entrar", color = if (active) Color.Black else HealthFitColors.Accent, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun PulsePeopleTab(
    store: PulseStore,
    authorId: String,
    authorName: String,
    authorEmail: String,
    authorCountryCode: String,
) {
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<PulsePerson>>(emptyList()) }
    var bio by remember { mutableStateOf(store.ownBio) }
    val incoming = store.incomingFollows(authorId)
    Text("Pessoas", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
    Text("Sua bio", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp))
    OutlinedTextField(
        bio,
        { if (it.length <= PulseLimits.MAX_BIO) bio = it },
        label = { Text("Bio (${bio.length}/${PulseLimits.MAX_BIO})") },
        colors = peopleFieldColors(),
        modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
    )
    Text(
        "Salvar bio",
        color = Color.Black,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(HealthFitColors.Accent)
            .clickable { scope.launch { store.saveBio(authorName, authorEmail, authorCountryCode, bio) } }
            .padding(horizontal = 14.dp, vertical = 10.dp),
    )
    if (incoming.isNotEmpty()) {
        Text("Pedidos para seguir você", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        incoming.forEach { follow ->
            val name = follow.fromName.ifBlank { follow.fromUserId.take(8) }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(HealthFitColors.CardBackground)
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(name, color = Color.White, fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Aceitar",
                        color = Color.Black,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(HealthFitColors.Accent)
                            .clickable { scope.launch { store.acceptFollow(follow.fromUserId, authorId) } }
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                    Text(
                        "Recusar",
                        color = Color.White,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color(0xFF3A4148))
                            .clickable { scope.launch { store.declineFollow(follow.fromUserId, authorId) } }
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        }
    }
    OutlinedTextField(
        query,
        {
            query = it
            scope.launch { results = store.searchPeople(it, authorId) }
        },
        label = { Text("Buscar todos os usuários…") },
        colors = peopleFieldColors(),
        modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
    )
    Text(
        "Resultados da sua região primeiro; depois outros países.",
        color = Color(0xFFB7C0C8),
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 6.dp, bottom = 8.dp),
    )
    val grouped = results.groupBy { it.countryCode.equals(authorCountryCode, true) }
    val nearby = grouped[true].orEmpty()
    val worldwide = grouped[false].orEmpty()
    if (nearby.isNotEmpty()) {
        Text("Na sua região", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
        nearby.forEach { person -> PersonCard(store, person, authorId, authorName) }
    }
    if (worldwide.isNotEmpty()) {
        Text("Outros países", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 10.dp))
        worldwide.forEach { person -> PersonCard(store, person, authorId, authorName) }
    }
    if (query.isNotBlank() && results.isEmpty()) {
        Text("Ninguém encontrado.", color = Color(0xFFB7C0C8), modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun PersonCard(store: PulseStore, person: PulsePerson, authorId: String, authorName: String) {
    val scope = rememberCoroutineScope()
    val status = store.followStatus(authorId, person.id)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF1A4A6A)),
                contentAlignment = Alignment.Center,
            ) {
                if (person.photoURL != null) {
                    AsyncImage(person.photoURL, person.displayName, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                } else {
                    Text(person.displayName.take(1).uppercase(), color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
            Column(modifier = Modifier.padding(start = 10.dp).weight(1f)) {
                Text(person.displayName, color = Color.White, fontWeight = FontWeight.Bold)
                Text(
                    listOf(person.countryCode, person.regionLabel).filter { it.isNotBlank() }.joinToString(" · "),
                    color = Color(0xFFB7C0C8),
                    fontSize = 12.sp,
                )
                Text(person.bio.ifBlank { "Sem bio ainda" }, color = Color(0xFFD5DDE3), fontSize = 12.sp, maxLines = 2)
            }
        }
        val label = when (status) {
            PulseFollowStatus.None -> "Seguir"
            PulseFollowStatus.Requested -> "Solicitado"
            PulseFollowStatus.Following -> "Seguindo"
            PulseFollowStatus.Incoming -> "Aceitar"
        }
        Text(
            label,
            color = if (status == PulseFollowStatus.Following) HealthFitColors.Accent else Color.Black,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .padding(top = 10.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(if (status == PulseFollowStatus.Following) Color(0x333DDC4A) else HealthFitColors.Accent)
                .clickable {
                    scope.launch {
                        when (status) {
                            PulseFollowStatus.None -> store.requestFollow(authorId, person.id, authorName)
                            PulseFollowStatus.Requested -> store.cancelFollow(authorId, person.id)
                            PulseFollowStatus.Incoming -> store.acceptFollow(person.id, authorId)
                            PulseFollowStatus.Following -> Unit
                        }
                    }
                }
                .padding(horizontal = 12.dp, vertical = 8.dp),
        )
    }
}

@Composable
fun PulseStorySession(
    store: PulseStore,
    stories: List<PulseStory>,
    startIndex: Int,
    authorId: String,
    onClose: () -> Unit,
) {
    if (stories.isEmpty()) return
    var index by remember { mutableIntStateOf(startIndex.coerceIn(0, stories.lastIndex)) }
    var paused by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    val story = stories.getOrNull(index) ?: return
    LaunchedEffect(story.id) {
        store.markStoryViewed(story.id)
        progress = 0f
    }
    LaunchedEffect(story.id, paused) {
        if (paused) return@LaunchedEffect
        val start = System.currentTimeMillis() - (progress * PulseLimits.STORY_VIEW_MS).toLong()
        while (isActive && !paused) {
            val elapsed = System.currentTimeMillis() - start
            progress = (elapsed / PulseLimits.STORY_VIEW_MS.toFloat()).coerceIn(0f, 1f)
            if (progress >= 1f) {
                if (index < stories.lastIndex) index++ else onClose()
                break
            }
            delay(50)
        }
    }
    val media = store.mediaFile(story.mediaFileName) ?: story.remoteMediaURL
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .pointerInput(story.id) {
                    detectTapGestures(
                        onLongPress = { paused = true },
                        onPress = {
                            try {
                                awaitRelease()
                            } finally {
                                paused = false
                            }
                        },
                        onTap = { offset ->
                            if (offset.x < size.width / 3f) {
                                if (index > 0) index-- else onClose()
                            } else {
                                if (index < stories.lastIndex) index++ else onClose()
                            }
                        },
                    )
                },
        ) {
            if (media != null) {
                AsyncImage(media, story.authorName, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                stories.forEachIndexed { i, _ ->
                    LinearProgressIndicator(
                        progress = {
                            when {
                                i < index -> 1f
                                i == index -> progress
                                else -> 0f
                            }
                        },
                        modifier = Modifier.weight(1f).height(3.dp).clip(RoundedCornerShape(2.dp)),
                        color = Color.White,
                        trackColor = Color.White.copy(alpha = 0.25f),
                    )
                }
            }
            Text(
                story.authorName,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, top = 28.dp),
            )
            if (story.authorId == authorId) {
                Text(
                    "Apagar",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(16.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color(0x99FF4D4D))
                        .clickable {
                            kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
                                store.deleteOwnStory(story.id, authorId)
                                onClose()
                            }
                        }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            story.textOverlays.firstOrNull()?.let { overlay ->
                Text(
                    overlay.text,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp,
                    modifier = Modifier.align(Alignment.Center).padding(horizontal = 24.dp),
                )
            }
        }
    }
}

@Composable
private fun peopleFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    focusedBorderColor = HealthFitColors.Accent,
    unfocusedBorderColor = Color(0xFF3A4148),
    cursorColor = HealthFitColors.Accent,
)

private const val PULSE_TERMS_PT = """
TERMOS DE USO — HEALTHFIT PULSE
Versão: pulse-terms-v4-2026-09

O Pulse é o espaço social do HealthFit: feed de posts (foto ou vídeo curto de até 30s), stories (12h), legendas, comunidades, busca de pessoas, pedidos de seguir, curtidas, comentários, denúncia, ocultação e bloqueio.

Posts expiram em cerca de 24 horas. Stories expiram em cerca de 12 horas.

O Pulse NÃO é aconselhamento médico, nutricional ou de treino. Consulte profissionais habilitados.

ELEGIBILIDADE: o Pulse exige 18 anos ou mais. Menores não devem acessar nem publicar. Declaração falsa de idade pode resultar em bloqueio.

Você conserva os direitos sobre o que publica e concede à HealthFit licença para hospedar, moderar e exibir o conteúdo na operação do Pulse.

É proibido: nudez/exploração sexual, ódio, assédio, violência gratuita, drogas ilícitas, spam, fraude, doxxing, contas falsas e material médico enganoso.

Você pode denunciar, ocultar e bloquear. A HealthFit pode remover conteúdo e restringir o Pulse.

Ao tocar em “Li e aceito”, você confirma que leu estes Termos e declara ter 18 anos ou mais.
"""
