package com.healthfit.android.ui.pulse

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import coil.compose.AsyncImage
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.components.HealthFitTabBar
import com.healthfit.android.ui.components.TabSpec
import com.healthfit.android.ui.home.ConstancyStore
import com.healthfit.android.ui.home.SharePublisher
import com.healthfit.android.ui.home.toastShare
import com.healthfit.core.pulse.PulseLimits
import com.healthfit.core.pulse.PulseMediaKind
import com.healthfit.core.pulse.PulsePost
import com.healthfit.core.pulse.PulseStory
import com.healthfit.core.pulse.PulseWorkoutMeta
import com.healthfit.designsystem.HealthFitColors
import java.io.File
import kotlinx.coroutines.launch

@Composable
fun PulseScreen(
    onClose: () -> Unit,
    authorId: String,
    authorName: String,
    authorCountryCode: String = "BR",
    authorEmail: String = "",
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember { PulseStore(context) }
    var tab by remember { mutableIntStateOf(0) }
    var composer by remember { mutableStateOf<String?>(null) }
    var communityFilter by remember { mutableStateOf("todos") }
    var viewingStories by remember { mutableStateOf<List<PulseStory>?>(null) }
    var viewingIndex by remember { mutableIntStateOf(0) }
    var sharePost by remember { mutableStateOf<PulsePost?>(null) }
    var acceptedTerms by remember { mutableStateOf(store.hasAcceptedTerms()) }
    LaunchedEffect(authorId) {
        store.refreshFromCloud(authorId, authorName, authorEmail, authorCountryCode)
    }
    if (!acceptedTerms) {
        PulseTermsGate(
            onAccept = {
                store.acceptTerms()
                acceptedTerms = true
            },
            onCancel = onClose,
        )
        return
    }
    fun openStories(stories: List<PulseStory>, index: Int) {
        viewingStories = stories
        viewingIndex = index
    }
    Column(modifier = Modifier.fillMaxSize()) {
        PulseTopBar(
            onClose = onClose,
            onCompose = {
                tab = 1
                composer = "post"
            },
            onSearch = { tab = 3 },
        )
        Text(
            PulseLimits.TAGLINE,
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
                    publishing = store.publishing,
                    onCancel = { composer = null },
                    onPublish = { photo, video, caption, community, meta ->
                        scope.launch {
                            store.publishing = true
                            runCatching {
                                when {
                                    video != null -> store.addVideoPost(
                                        authorId, authorName, authorCountryCode, caption, video, community, meta,
                                    )
                                    photo != null -> store.addPhotoPost(
                                        authorId, authorName, authorCountryCode, caption, photo, community, meta,
                                    )
                                    else -> error("Escolha uma foto ou um vídeo de até 30 segundos.")
                                }
                            }.onSuccess {
                                composer = null
                                tab = 0
                                sharePost = it
                            }.onFailure {
                                store.errorMessage = it.message ?: "Não foi possível publicar o post."
                            }
                            store.publishing = false
                        }
                    },
                )
                composer == "story" -> StoryComposer(
                    publishing = store.publishing,
                    onCancel = { composer = null },
                    onPublish = { photo, text ->
                        scope.launch {
                            store.publishing = true
                            runCatching {
                                store.addStory(authorId, authorName, photo, text)
                            }.onSuccess { story ->
                                composer = null
                                tab = 0
                                openStories(listOf(story), 0)
                            }.onFailure {
                                store.errorMessage = it.message ?: "Não foi possível publicar o story."
                            }
                            store.publishing = false
                        }
                    },
                )
                tab == 0 -> FeedTab(
                    store = store,
                    authorId = authorId,
                    authorName = authorName,
                    communityFilter = communityFilter,
                    onFilter = { communityFilter = it },
                    onStory = {
                        val mine = store.activeStories().firstOrNull { it.authorId == authorId }
                        if (mine == null) composer = "story" else openStories(store.activeStories(), store.activeStories().indexOf(mine).coerceAtLeast(0))
                    },
                    onOpenStory = { story ->
                        val all = store.activeStories()
                        openStories(all, all.indexOfFirst { it.id == story.id }.coerceAtLeast(0))
                    },
                    onPublishWorkout = {
                        scope.launch { publishLastWorkout(context, store, authorId, authorName, authorCountryCode) }
                    },
                )
                tab == 1 -> PostHub(
                    onCreatePost = { composer = "post" },
                    onCreateStory = { composer = "story" },
                )
                tab == 2 -> PulseCommunitiesTab(store)
                else -> PulsePeopleTab(
                    store = store,
                    authorId = authorId,
                    authorName = authorName,
                    authorEmail = authorEmail,
                    authorCountryCode = authorCountryCode,
                )
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
                composer = null
                tab = listOf("feed", "post", "comunidade", "pessoas").indexOf(route)
            },
        )
    }
    viewingStories?.let { session ->
        PulseStorySession(
            store = store,
            stories = session,
            startIndex = viewingIndex,
            authorId = authorId,
            onClose = { viewingStories = null },
        )
    }
    store.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { store.clearError() },
            confirmButton = {
                TextButton(onClick = { store.clearError() }) { Text("OK") }
            },
            title = { Text("Pulse") },
            text = { Text(message) },
        )
    }
    sharePost?.let { post ->
        AlertDialog(
            onDismissRequest = { sharePost = null },
            title = { Text("Publicado no Pulse") },
            text = { Text("O post já está no feed (24h). Quer postar também no Instagram ou no WhatsApp?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        shareOutside(context, store, post, SharePublisher.Target.InstagramStories)
                        sharePost = null
                    },
                ) { Text("Instagram") }
            },
            dismissButton = {
                Row {
                    TextButton(
                        onClick = {
                            shareOutside(context, store, post, SharePublisher.Target.WhatsAppStatus)
                            sharePost = null
                        },
                    ) { Text("WhatsApp") }
                    TextButton(onClick = { sharePost = null }) { Text("Agora não") }
                }
            },
        )
    }
}

private suspend fun publishLastWorkout(
    context: android.content.Context,
    store: PulseStore,
    authorId: String,
    authorName: String,
    country: String,
) {
    val last = ConstancyStore.loadSessions(context).maxByOrNull { it.endedAtMillis }
    if (last == null) {
        store.errorMessage = "Nenhum treino recente para publicar."
        return
    }
    val jpeg = last.photoPath?.let { path -> File(path).takeIf { it.exists() }?.readBytes() }
    val community = when {
        last.kind.contains("cardio", true) || last.title.contains("kite", true) -> "cardio"
        else -> "musculacao"
    }
    runCatching {
        store.publishWorkoutCard(
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = country,
            title = last.title,
            caption = "${last.title}. ${PulseLimits.TAGLINE}",
            previewJpeg = jpeg,
            durationSeconds = null,
            community = community,
        )
    }.onFailure {
        store.errorMessage = it.message ?: "Não foi possível publicar o treino."
    }
}

private fun shareOutside(
    context: android.content.Context,
    store: PulseStore,
    post: PulsePost,
    target: SharePublisher.Target,
) {
    val file = store.mediaFile(post.mediaFileName) ?: return
    val mime = if (post.mediaKind == PulseMediaKind.Video) "video/mp4" else "image/jpeg"
    toastShare(context) { SharePublisher.post(context, file, mime, target) }
}

@Composable
private fun PulseTopBar(onClose: () -> Unit, onCompose: () -> Unit, onSearch: () -> Unit = {}) {
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
            CircleIcon(Icons.Filled.Search, onSearch)
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
    store: PulseStore,
    authorId: String,
    authorName: String,
    communityFilter: String,
    onFilter: (String) -> Unit,
    onStory: () -> Unit,
    onOpenStory: (PulseStory) -> Unit,
    onPublishWorkout: () -> Unit,
) {
    val stories = store.activeStories()
    val mine = stories.firstOrNull { it.authorId == authorId }
    val others = stories.filter { it.authorId != authorId }
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StoryRing(
            label = if (mine == null) "Seu story" else "Você",
            image = store.mediaFile(mine?.mediaFileName) ?: mine?.remoteMediaURL,
            empty = mine == null,
            viewed = mine?.isViewed == true,
            onClick = onStory,
        )
        others.forEach { story ->
            StoryRing(
                label = story.authorName.substringBefore(' ').ifBlank { story.authorName },
                image = store.mediaFile(story.mediaFileName) ?: story.remoteMediaURL,
                empty = false,
                viewed = story.isViewed,
                onClick = { onOpenStory(story) },
            )
        }
    }
    Spacer(Modifier.height(14.dp))
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Text("Desafio do dia", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        Text(PulseLimits.dailyChallenge(authorId), color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
    }
    Spacer(Modifier.height(12.dp))
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilterPill("Todos", communityFilter == "todos") { onFilter("todos") }
        store.joinedCommunities.forEach { key ->
            FilterPill(PulseLimits.communityTitle(key), communityFilter == key) { onFilter(key) }
        }
    }
    store.weeklyHighlight()?.let { highlight ->
        Spacer(Modifier.height(12.dp))
        Text("Destaque da semana", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
        Text("${highlight.authorName} · ${highlight.engagementScore} pts", color = Color.White, modifier = Modifier.padding(top = 4.dp))
    }
    val ranking = store.lightRanking()
    if (ranking.isNotEmpty()) {
        Spacer(Modifier.height(8.dp))
        Text("Ranking leve", color = Color(0xFFB7C0C8), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        ranking.forEachIndexed { index, pair ->
            Text("${index + 1}. ${pair.first} · ${pair.second}", color = Color.White, fontSize = 13.sp)
        }
    }
    val posts = store.visiblePosts(communityFilter)
    posts.forEach { post ->
        Spacer(Modifier.height(12.dp))
        PostCard(store = store, post = post, authorId = authorId, authorName = authorName)
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
        Text("Seu feed está quieto", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
        Text(
            "Publique um post ou um story para aparecer aqui — iguais ao iPhone, com 24h / 12h e sync na nuvem.",
            color = Color(0xFFD5DDE3),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        Spacer(Modifier.height(14.dp))
        GradientButton(text = "Publicar treino", onClick = onPublishWorkout)
    }
}

@Composable
private fun StoryRing(
    label: String,
    image: Any?,
    empty: Boolean,
    viewed: Boolean = false,
    onClick: () -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable(onClick = onClick)) {
        Box(
            modifier = Modifier
                .size(58.dp)
                .clip(CircleShape)
                .background(
                    if (viewed) Brush.linearGradient(listOf(Color(0xFF3A4148), Color(0xFF3A4148)))
                    else Brush.linearGradient(listOf(Color(0xFF1A4A6A), Color(0xFF3DDC3A))),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (image != null && !empty) {
                AsyncImage(
                    model = image,
                    contentDescription = label,
                    modifier = Modifier
                        .size(52.dp)
                        .clip(CircleShape),
                    contentScale = ContentScale.Crop,
                )
            } else {
                Text("+", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
            }
        }
        Text(label, color = Color(0xFFB7C0C8), fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun PostCard(store: PulseStore, post: PulsePost, authorId: String, authorName: String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val media = store.mediaFile(post.mediaFileName) ?: post.remoteMediaURL
    var menu by remember { mutableStateOf(false) }
    var comment by remember { mutableStateOf("") }
    val liked = post.hasHeartFrom(authorId)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(HealthFitColors.CardBackground)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(post.communityTitle(), color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                Text(post.authorName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            Box {
                Icon(
                    Icons.Filled.MoreHoriz,
                    contentDescription = "Mais",
                    tint = Color(0xFFB7C0C8),
                    modifier = Modifier.clickable { menu = true }.padding(6.dp),
                )
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    if (post.authorId == authorId) {
                        DropdownMenuItem(text = { Text("Excluir") }, onClick = {
                            menu = false
                            scope.launch { store.deleteOwnPost(post.id, authorId) }
                        })
                    }
                    DropdownMenuItem(text = { Text("Compartilhar no Instagram") }, onClick = {
                        menu = false
                        shareOutside(context, store, post, SharePublisher.Target.InstagramStories)
                    })
                    DropdownMenuItem(text = { Text("Denunciar") }, onClick = {
                        menu = false
                        scope.launch { store.reportPost(post.id) }
                    })
                    DropdownMenuItem(text = { Text("Ocultar") }, onClick = {
                        menu = false
                        store.hidePost(post.id)
                    })
                    if (post.authorId != authorId) {
                        DropdownMenuItem(text = { Text("Bloquear") }, onClick = {
                            menu = false
                            scope.launch { store.blockUser(post.authorId) }
                        })
                    }
                }
            }
        }
        post.workoutMeta?.detailLine()?.takeIf { it.isNotBlank() }?.let {
            Text(it, color = Color(0xFFB7C0C8), fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
        }
        if (media != null) {
            Box(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .height(210.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .clickable {
                        if (post.mediaKind == PulseMediaKind.Video) {
                            val uri = when (media) {
                                is File -> FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", media)
                                is String -> Uri.parse(media)
                                else -> null
                            }
                            if (uri != null) {
                                runCatching {
                                    context.startActivity(
                                        Intent(Intent.ACTION_VIEW).apply {
                                            setDataAndType(uri, "video/*")
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        },
                                    )
                                }
                            }
                        }
                    },
            ) {
                if (post.mediaKind == PulseMediaKind.Video) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color(0xFF101418)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Filled.PlayArrow, contentDescription = "Vídeo", tint = Color.White, modifier = Modifier.size(48.dp))
                    }
                } else {
                    AsyncImage(
                        model = media,
                        contentDescription = post.caption,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }
        }
        if (post.caption.isNotBlank()) {
            Text(post.caption, color = Color(0xFFD5DDE3), modifier = Modifier.padding(top = 8.dp))
        }
        Row(
            modifier = Modifier.padding(top = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.clickable { scope.launch { store.toggleHeart(post.id, authorId, authorName) } },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    if (liked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                    contentDescription = "Curtir",
                    tint = HealthFitColors.Accent,
                    modifier = Modifier.size(20.dp),
                )
                Text(" ${post.heartCount}", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
            Text("${post.comments.size} comentário(s)", color = Color(0xFFB7C0C8), fontSize = 13.sp)
        }
        if (post.reactions.any { it.isHeart }) {
            Text(
                "Ver quem curtiu · ${post.heartCount}",
                color = HealthFitColors.Accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp),
            )
            post.reactions.filter { it.isHeart }.take(4).forEach { reaction ->
                Text(reaction.userName.ifBlank { "Atleta" }, color = Color(0xFFD5DDE3), fontSize = 12.sp)
            }
        }
        post.comments.forEach { item ->
            Row(
                modifier = Modifier.padding(top = 6.dp).fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(item.authorName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    Text(item.text, color = Color(0xFFD5DDE3), fontSize = 12.sp)
                }
                if (item.authorId == authorId) {
                    Text(
                        "Excluir",
                        color = Color(0xFFFF8A8A),
                        fontSize = 11.sp,
                        modifier = Modifier.clickable {
                            scope.launch { store.deleteComment(post.id, item.id, authorId) }
                        },
                    )
                }
            }
        }
        OutlinedTextField(
            comment,
            { if (it.length <= PulseLimits.MAX_COMMENT) comment = it },
            label = { Text("Comente ou @marque…") },
            colors = composerFieldColors(),
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        if (comment.isNotBlank()) {
            Text(
                "Enviar",
                color = Color.Black,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(HealthFitColors.Accent)
                    .clickable {
                        val text = comment
                        comment = ""
                        scope.launch { store.addComment(post.id, authorId, authorName, text) }
                    }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun PostHub(onCreatePost: () -> Unit, onCreateStory: () -> Unit) {
    Text("Postar", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
    Text(
        "Foto ou vídeo curto no feed (24h). Stories ficam 12h no topo, como no iPhone.",
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
            "Toque no círculo “Seu story” ou publique aqui com foto e texto.",
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
    publishing: Boolean,
    onCancel: () -> Unit,
    onPublish: (photo: Uri?, video: Uri?, caption: String, community: String, meta: PulseWorkoutMeta?) -> Unit,
) {
    val context = LocalContext.current
    var mediaUri by remember { mutableStateOf<Uri?>(null) }
    var mediaIsVideo by remember { mutableStateOf(false) }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    var community by remember { mutableStateOf("musculacao") }
    var modality by remember { mutableStateOf("") }
    var minutes by remember { mutableStateOf("") }
    var intensity by remember { mutableStateOf("") }
    var duo by remember { mutableStateOf("") }
    var caption by remember { mutableStateOf("") }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        mediaUri = uri
        mediaIsVideo = context.contentResolver.getType(uri)?.startsWith("video") == true
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) {
            mediaUri = cameraUri
            mediaIsVideo = false
        }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = pulseCameraUri(context)
            cameraUri = uri
            camera.launch(uri)
        }
    }
    val fieldColors = composerFieldColors()
    Text("Cancelar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onCancel))
    Text("Novo post", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
    Text("Mídia", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ChoiceChip("Câmera", Icons.Filled.CameraAlt, false) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
            if (granted) {
                val uri = pulseCameraUri(context)
                cameraUri = uri
                camera.launch(uri)
            } else {
                cameraPermission.launch(Manifest.permission.CAMERA)
            }
        }
        ChoiceChip("Galeria", Icons.Filled.PhotoLibrary, mediaUri != null) {
            gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
        }
    }
    mediaUri?.let { uri ->
        if (mediaIsVideo) {
            Box(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF101418)),
                contentAlignment = Alignment.Center,
            ) {
                Text("Vídeo selecionado (máx. 30s)", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        } else {
            AsyncImage(
                model = uri,
                contentDescription = null,
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop,
            )
        }
    }
    Text("Comunidade", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterPill("Musculação", community == "musculacao") { community = "musculacao" }
        FilterPill("Cardio", community == "cardio") { community = "cardio" }
        FilterPill("Kite", community == "kite") { community = "kite" }
        FilterPill("Nutrição", community == "nutricao") { community = "nutricao" }
    }
    Text("Detalhes do treino (opcional)", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp))
    OutlinedTextField(modality, { modality = it }, label = { Text("Modalidade") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    OutlinedTextField(minutes, { minutes = it }, label = { Text("Duração (minutos)") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    OutlinedTextField(intensity, { intensity = it.filter { ch -> ch.isDigit() }.take(2) }, label = { Text("Intensidade (1–10)") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    OutlinedTextField(duo, { duo = it }, label = { Text("Dupla / equipe") }, colors = fieldColors, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
    Text("Legenda (${caption.length}/${PulseLimits.MAX_CAPTION})", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 14.dp))
    OutlinedTextField(
        caption,
        { if (it.length <= PulseLimits.MAX_CAPTION) caption = it },
        label = { Text(PulseLimits.TAGLINE) },
        colors = fieldColors,
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 12.dp),
    )
    GradientButton(
        text = if (publishing) "Publicando…" else "Publicar",
        onClick = {
            if (publishing) return@GradientButton
            val minutesInt = minutes.toIntOrNull()
            val intensityInt = intensity.toIntOrNull()?.coerceIn(1, 10)
            val meta = PulseWorkoutMeta(
                modality = modality.trim().ifBlank { null },
                durationSeconds = minutesInt?.times(60),
                intensity = intensityInt,
                duoTeamName = duo.trim().ifBlank { null },
            ).takeIf { it.detailLine().isNotBlank() }
            onPublish(
                mediaUri.takeUnless { mediaIsVideo },
                mediaUri.takeIf { mediaIsVideo },
                caption,
                community,
                meta,
            )
        },
        icon = Icons.Filled.Add,
    )
}

@Composable
private fun StoryComposer(
    publishing: Boolean,
    onCancel: () -> Unit,
    onPublish: (Uri, String) -> Unit,
) {
    val context = LocalContext.current
    var photo by remember { mutableStateOf<Uri?>(null) }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    var text by remember { mutableStateOf("") }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) photo = uri
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) photo = cameraUri
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = pulseCameraUri(context)
            cameraUri = uri
            camera.launch(uri)
        }
    }
    Text("Cancelar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onCancel))
    Text("Seu story", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
    Text("Foto (obrigatória)", color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 12.dp, bottom = 8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ChoiceChip("Câmera", Icons.Filled.CameraAlt, false) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
            if (granted) {
                val uri = pulseCameraUri(context)
                cameraUri = uri
                camera.launch(uri)
            } else {
                cameraPermission.launch(Manifest.permission.CAMERA)
            }
        }
        ChoiceChip("Galeria", Icons.Filled.PhotoLibrary, photo != null) {
            gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }
    photo?.let { uri ->
        AsyncImage(
            model = uri,
            contentDescription = null,
            modifier = Modifier
                .padding(top = 10.dp)
                .fillMaxWidth()
                .height(220.dp)
                .clip(RoundedCornerShape(12.dp)),
            contentScale = ContentScale.Crop,
        )
    }
    OutlinedTextField(
        text,
        { text = it },
        label = { Text("Texto do story (opcional)") },
        colors = composerFieldColors(),
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 12.dp),
    )
    GradientButton(
        text = if (publishing) "Publicando…" else "Publicar story",
        onClick = {
            if (publishing) return@GradientButton
            val image = photo
            if (image == null) {
                Toast.makeText(context, "Escolha uma foto para o story.", Toast.LENGTH_SHORT).show()
            } else {
                onPublish(image, text)
            }
        },
        icon = Icons.Filled.CameraAlt,
    )
}

@Composable
private fun StoryViewer(store: PulseStore, story: PulseStory, onClose: () -> Unit) {
    val media = store.mediaFile(story.mediaFileName) ?: story.remoteMediaURL
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .clickable(onClick = onClose),
        ) {
            if (media != null) {
                AsyncImage(
                    model = media,
                    contentDescription = story.authorName,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
            story.textOverlays.firstOrNull()?.let { overlay ->
                Text(
                    overlay.text,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 24.dp),
                )
            }
            Text(
                story.authorName,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(24.dp),
            )
            Icon(
                Icons.Filled.Close,
                contentDescription = "Fechar",
                tint = Color.White,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(20.dp)
                    .size(28.dp),
            )
        }
    }
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
        "Ative um tema para ele aparecer no Feed e nos posts.",
        color = Color(0xFFB7C0C8),
        modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ActivePill("Musculação")
        ActivePill("Cardio")
    }
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

@Composable
private fun composerFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    focusedBorderColor = HealthFitColors.Accent,
    unfocusedBorderColor = Color(0xFF3A4148),
    cursorColor = HealthFitColors.Accent,
)

private fun pulseCameraUri(context: android.content.Context): Uri {
    val dir = File(context.cacheDir, "pulse_camera").apply { mkdirs() }
    val file = File(dir, "pulse_${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}
