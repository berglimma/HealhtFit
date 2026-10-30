package com.healthfit.android.ui.pulse

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.exifinterface.media.ExifInterface
import com.healthfit.core.directory.DirectorySearch
import com.healthfit.core.pulse.PulseCloud
import com.healthfit.core.pulse.PulseComment
import com.healthfit.core.pulse.PulseFollow
import com.healthfit.core.pulse.PulseFollowStatus
import com.healthfit.core.pulse.PulseLimits
import com.healthfit.core.pulse.PulseMediaKind
import com.healthfit.core.pulse.PulsePerson
import com.healthfit.core.pulse.PulsePost
import com.healthfit.core.pulse.PulseReaction
import com.healthfit.core.pulse.PulseStory
import com.healthfit.core.pulse.PulseStoryTextOverlay
import com.healthfit.core.pulse.PulseWorkoutMeta
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.math.max
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class PulseStore(private val context: Context) {
    var posts by mutableStateOf<List<PulsePost>>(emptyList())
        private set
    var stories by mutableStateOf<List<PulseStory>>(emptyList())
        private set
    var follows by mutableStateOf<List<PulseFollow>>(emptyList())
        private set
    var people by mutableStateOf<List<PulsePerson>>(emptyList())
        private set
    var blockedUserIds by mutableStateOf<Set<String>>(emptySet())
        private set
    var joinedCommunities by mutableStateOf(PulseLimits.DEFAULT_COMMUNITIES)
        private set
    var ownBio by mutableStateOf("")
    var publishing by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)

    private val prefs = context.getSharedPreferences("pulse.local.v1", Context.MODE_PRIVATE)

    init {
        loadLocal()
        pruneExpired()
    }

    fun hasAcceptedTerms(): Boolean =
        prefs.getBoolean("${KEY_TERMS}${PulseLimits.TERMS_VERSION}", false)

    fun acceptTerms() {
        prefs.edit().putBoolean("${KEY_TERMS}${PulseLimits.TERMS_VERSION}", true).apply()
    }

    fun mediaFile(name: String?): File? {
        name ?: return null
        val file = File(mediaDir(), name)
        return file.takeIf { it.exists() }
    }

    fun visiblePosts(community: String?): List<PulsePost> {
        val now = System.currentTimeMillis()
        return posts
            .filter { it.expiresAtMillis > now && !it.isHidden }
            .filter { it.authorId !in blockedUserIds }
            .filter { post ->
                when (community) {
                    null, "todos" -> joinedCommunities.contains(post.community) ||
                        (post.community.startsWith("cardio.") && "cardio" in joinedCommunities)
                    "cardio" -> post.community == "cardio" || post.community.startsWith("cardio.")
                    else -> post.community == community
                }
            }
            .sortedByDescending { it.createdAtMillis }
    }

    fun weeklyHighlight(): PulsePost? {
        val weekAgo = System.currentTimeMillis() - 7L * 24L * 60L * 60L * 1000L
        return visiblePosts("todos")
            .filter { it.createdAtMillis >= weekAgo }
            .maxByOrNull { it.engagementScore }
    }

    fun lightRanking(): List<Pair<String, Int>> {
        val scores = linkedMapOf<String, Int>()
        for (post in visiblePosts("todos").take(40)) {
            scores[post.authorName] = (scores[post.authorName] ?: 0) + post.engagementScore
        }
        return scores.entries.sortedByDescending { it.value }.take(5).map { it.key to it.value }
    }

    fun activeStories(): List<PulseStory> {
        val now = System.currentTimeMillis()
        return stories.filter { it.expiresAtMillis > now }.sortedByDescending { it.createdAtMillis }
    }

    suspend fun refreshFromCloud(
        authorId: String,
        displayName: String,
        email: String,
        countryCode: String,
    ) {
        if (!PulseCloud.isReady()) return
        withContext(Dispatchers.IO) {
            runCatching {
                PulseCloud.upsertOwnProfile(displayName, email, countryCode, ownBio)
            }
        }
        val cloudFollows = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.fetchFollows(authorId) }.getOrDefault(emptyList())
        }
        if (cloudFollows.isNotEmpty()) {
            follows = mergeFollows(follows, cloudFollows)
            persistSocial()
        }
        val cloudPosts = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.fetchActivePosts() }.getOrDefault(emptyList())
        }
        val cloudStories = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.fetchActiveStories() }.getOrDefault(emptyList())
        }
        val cloudPeople = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.fetchProfiles() }.getOrDefault(emptyList())
        }
        val cloudBlocks = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.fetchBlocks() }.getOrDefault(emptySet())
        }
        posts = mergePosts(posts, cloudPosts)
        stories = mergeStories(stories, cloudStories)
        if (cloudPeople.isNotEmpty()) people = mergePeople(people, cloudPeople)
        if (cloudBlocks.isNotEmpty()) blockedUserIds = blockedUserIds + cloudBlocks
        persist()
        persistSocial()
        pruneExpired()
        val toHydrate = posts.filter { it.authorId !in blockedUserIds }.take(12)
        for (post in toHydrate) {
            val comments = withContext(Dispatchers.IO) {
                runCatching { PulseCloud.fetchComments(post.id) }.getOrDefault(emptyList())
            }
            val reactions = withContext(Dispatchers.IO) {
                runCatching { PulseCloud.fetchReactions(post.id) }.getOrDefault(emptyList())
            }
            if (comments.isNotEmpty() || reactions.isNotEmpty()) {
                posts = posts.map {
                    if (it.id != post.id) it
                    else it.copy(
                        comments = if (comments.isNotEmpty()) mergeComments(it.comments, comments) else it.comments,
                        reactions = if (reactions.isNotEmpty()) mergeReactions(it.reactions, reactions) else it.reactions,
                    )
                }
            }
        }
        persist()
    }

    suspend fun addPhotoPost(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        caption: String,
        imageUri: Uri,
        community: String,
        workoutMeta: PulseWorkoutMeta?,
    ): PulsePost {
        val jpeg = withContext(Dispatchers.IO) { jpegFromUri(imageUri) }
        val id = newId()
        val fileName = "$id.jpg"
        withContext(Dispatchers.IO) { File(mediaDir(), fileName).writeBytes(jpeg) }
        return insertPost(
            id = id,
            kind = PulseMediaKind.Photo,
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = authorCountryCode,
            caption = caption,
            community = community,
            workoutMeta = workoutMeta,
            mediaFileName = fileName,
            mediaBytes = jpeg,
            contentType = "image/jpeg",
            fileExtension = "jpg",
        )
    }

    suspend fun addVideoPost(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        caption: String,
        videoUri: Uri,
        community: String,
        workoutMeta: PulseWorkoutMeta?,
        maxSeconds: Double = PulseLimits.MAX_VIDEO_SECONDS,
    ): PulsePost {
        val seconds = withContext(Dispatchers.IO) { videoDurationSeconds(videoUri) }
        if (seconds > maxSeconds) {
            error("O vídeo pode ter no máximo ${maxSeconds.toInt()} segundos.")
        }
        val ext = if (context.contentResolver.getType(videoUri)?.contains("quicktime") == true) "mov" else "mp4"
        val id = newId()
        val fileName = "$id.$ext"
        val dest = File(mediaDir(), fileName)
        val bytes = withContext(Dispatchers.IO) {
            context.contentResolver.openInputStream(videoUri).use { input ->
                requireNotNull(input) { "Não foi possível ler o vídeo." }
                dest.outputStream().use { input.copyTo(it) }
            }
            if (dest.length() > 40L * 1024L * 1024L) {
                dest.delete()
                error("O vídeo ficou grande demais para o Pulse.")
            }
            dest.readBytes()
        }
        val contentType = if (ext == "mov") "video/quicktime" else "video/mp4"
        return insertPost(
            id = id,
            kind = PulseMediaKind.Video,
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = authorCountryCode,
            caption = caption,
            community = community,
            workoutMeta = workoutMeta,
            mediaFileName = fileName,
            mediaBytes = bytes,
            contentType = contentType,
            fileExtension = ext,
        )
    }

    suspend fun addStory(
        authorId: String,
        authorName: String,
        imageUri: Uri,
        overlayText: String,
    ): PulseStory {
        val jpeg = withContext(Dispatchers.IO) { jpegFromUri(imageUri) }
        val id = newId()
        val fileName = "story-$id.jpg"
        withContext(Dispatchers.IO) { File(mediaDir(), fileName).writeBytes(jpeg) }
        val now = System.currentTimeMillis()
        val overlays = overlayText.trim().takeIf { it.isNotEmpty() }?.let {
            listOf(
                PulseStoryTextOverlay(
                    id = newId(),
                    text = it.take(120),
                ),
            )
        }.orEmpty()
        val story = PulseStory(
            id = id,
            authorId = authorId,
            authorName = authorName,
            mediaFileName = fileName,
            createdAtMillis = now,
            expiresAtMillis = now + PulseLimits.STORY_LIFETIME_MS,
            textOverlays = overlays,
        )
        stories = listOf(story) + stories
        persist()
        val remote = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.upsertStory(story, jpeg) }.getOrNull()
        }
        if (remote != null) {
            stories = stories.map { if (it.id == id) it.copy(remoteMediaURL = remote) else it }
            persist()
        }
        return story
    }

    suspend fun publishWorkoutCard(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        title: String,
        caption: String,
        previewJpeg: ByteArray?,
        durationSeconds: Int?,
        community: String,
    ): PulsePost {
        val id = newId()
        val fileName = previewJpeg?.let { bytes ->
            val name = "workout-$id.jpg"
            withContext(Dispatchers.IO) { File(mediaDir(), name).writeBytes(bytes) }
            name
        }
        return insertPost(
            id = id,
            kind = PulseMediaKind.WorkoutCard,
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = authorCountryCode,
            caption = caption.ifBlank { "$title. ${PulseLimits.TAGLINE}" },
            community = community,
            workoutMeta = PulseWorkoutMeta(modality = title, durationSeconds = durationSeconds),
            mediaFileName = fileName,
            mediaBytes = previewJpeg,
            contentType = "image/jpeg",
            fileExtension = "jpg",
        )
    }

    fun clearError() {
        errorMessage = null
    }

    fun toggleCommunity(key: String) {
        val next = joinedCommunities.toMutableSet()
        if (!next.add(key)) {
            if (next.size > 1) next.remove(key)
        }
        joinedCommunities = next
        persistSocial()
    }

    fun markStoryViewed(id: String) {
        stories = stories.map { if (it.id == id) it.copy(isViewed = true) else it }
        persist()
    }

    suspend fun toggleHeart(postId: String, userId: String, userName: String) {
        val post = posts.firstOrNull { it.id == postId } ?: return
        val existing = post.reactions.firstOrNull { it.userId == userId && it.isHeart }
        val next = if (existing == null) {
            post.reactions + PulseReaction(id = newId(), userId = userId, userName = userName, kind = "heart")
        } else {
            post.reactions.filterNot { it.id == existing.id }
        }
        posts = posts.map { if (it.id == postId) it.copy(reactions = next) else it }
        persist()
        withContext(Dispatchers.IO) {
            runCatching {
                if (existing == null) PulseCloud.setReaction(postId, "❤️")
                else PulseCloud.clearReaction(postId)
            }
        }
    }

    suspend fun addComment(postId: String, authorId: String, authorName: String, text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val comment = PulseComment(
            id = newId(),
            authorId = authorId,
            authorName = authorName,
            text = trimmed.take(PulseLimits.MAX_COMMENT),
        )
        posts = posts.map {
            if (it.id == postId) it.copy(comments = it.comments + comment) else it
        }
        persist()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.addComment(postId, comment) } }
    }

    suspend fun deleteComment(postId: String, commentId: String, authorId: String) {
        posts = posts.map {
            if (it.id != postId) it
            else it.copy(comments = it.comments.filterNot { c -> c.id == commentId && c.authorId == authorId })
        }
        persist()
        withContext(Dispatchers.IO) {
            runCatching { PulseCloud.deleteComment(postId, commentId, authorId) }
        }
    }

    suspend fun deleteOwnPost(postId: String, userId: String) {
        val post = posts.firstOrNull { it.id == postId && it.authorId == userId } ?: return
        mediaFile(post.mediaFileName)?.delete()
        posts = posts.filterNot { it.id == postId }
        persist()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.deletePost(postId) } }
    }

    suspend fun deleteOwnStory(storyId: String, userId: String) {
        val story = stories.firstOrNull { it.id == storyId && it.authorId == userId } ?: return
        mediaFile(story.mediaFileName)?.delete()
        stories = stories.filterNot { it.id == storyId }
        persist()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.deleteStory(storyId) } }
    }

    fun hidePost(postId: String) {
        posts = posts.map { if (it.id == postId) it.copy(isHidden = true) else it }
        persist()
    }

    suspend fun reportPost(postId: String) {
        posts = posts.map {
            if (it.id != postId) it
            else {
                val count = it.reportCount + 1
                it.copy(reportCount = count, isHidden = count >= 3 || it.isHidden)
            }
        }
        persist()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.reportPost(postId) } }
    }

    suspend fun blockUser(userId: String) {
        blockedUserIds = blockedUserIds + userId
        follows = follows.filterNot { it.fromUserId == userId || it.toUserId == userId }
        persistSocial()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.upsertBlock(userId) } }
    }

    fun followStatus(fromUserId: String, toUserId: String): PulseFollowStatus {
        follows.firstOrNull { it.fromUserId == fromUserId && it.toUserId == toUserId }?.let { return it.status }
        if (follows.any { it.fromUserId == toUserId && it.toUserId == fromUserId && it.status == PulseFollowStatus.Requested }) {
            return PulseFollowStatus.Incoming
        }
        return PulseFollowStatus.None
    }

    fun incomingFollows(userId: String): List<PulseFollow> =
        follows.filter { it.toUserId == userId && it.status == PulseFollowStatus.Requested }

    suspend fun requestFollow(fromUserId: String, toUserId: String, fromName: String) {
        if (fromUserId == toUserId) return
        val existing = follows.firstOrNull { it.fromUserId == fromUserId && it.toUserId == toUserId }
        follows = if (existing == null) {
            follows + PulseFollow(
                id = "${fromUserId}_$toUserId",
                fromUserId = fromUserId,
                toUserId = toUserId,
                status = PulseFollowStatus.Requested,
                fromName = fromName,
            )
        } else {
            follows.map {
                if (it.id == existing.id) it.copy(status = PulseFollowStatus.Requested) else it
            }
        }
        persistSocial()
        withContext(Dispatchers.IO) {
            runCatching {
                PulseCloud.upsertFollow(fromUserId, toUserId, PulseFollowStatus.Requested, fromName)
            }
        }
    }

    suspend fun cancelFollow(fromUserId: String, toUserId: String) {
        follows = follows.filterNot { it.fromUserId == fromUserId && it.toUserId == toUserId }
        persistSocial()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.deleteFollow(fromUserId, toUserId) } }
    }

    suspend fun acceptFollow(requesterId: String, userId: String) {
        follows = follows.map {
            if (it.fromUserId == requesterId && it.toUserId == userId) {
                it.copy(status = PulseFollowStatus.Following)
            } else it
        }
        persistSocial()
        withContext(Dispatchers.IO) {
            runCatching {
                PulseCloud.upsertFollow(requesterId, userId, PulseFollowStatus.Following, null)
            }
        }
    }

    suspend fun declineFollow(requesterId: String, userId: String) {
        follows = follows.filterNot { it.fromUserId == requesterId && it.toUserId == userId }
        persistSocial()
        withContext(Dispatchers.IO) { runCatching { PulseCloud.deleteFollow(requesterId, userId) } }
    }

    suspend fun saveBio(displayName: String, email: String, countryCode: String, bio: String) {
        ownBio = bio.take(PulseLimits.MAX_BIO)
        persistSocial()
        withContext(Dispatchers.IO) {
            runCatching { PulseCloud.upsertOwnProfile(displayName, email, countryCode, ownBio) }
        }
    }

    suspend fun searchPeople(query: String, excludingUserId: String): List<PulsePerson> {
        val local = people.filter {
            it.id != excludingUserId && it.id !in blockedUserIds &&
                listOf(it.displayName, it.city, it.state, it.bio).joinToString(" ")
                    .contains(query, ignoreCase = true)
        }
        val pulse = withContext(Dispatchers.IO) {
            runCatching { PulseCloud.searchPeople(query, excludingUserId) }.getOrDefault(emptyList())
        }
        val directory = withContext(Dispatchers.IO) {
            runCatching { DirectorySearch.searchPeople(query, excludingUserId, 40) }.getOrDefault(emptyList())
        }.map {
            PulsePerson(
                id = it.uid,
                displayName = it.shownName,
                emailHint = it.email,
                countryCode = it.countryCode ?: "BR",
                photoURL = it.photoUrl,
            )
        }
        val byId = linkedMapOf<String, PulsePerson>()
        for (person in local + pulse + directory) {
            if (person.id == excludingUserId || person.id in blockedUserIds) continue
            val existing = byId[person.id]
            byId[person.id] = existing?.copy(
                photoURL = existing.photoURL ?: person.photoURL,
                bio = existing.bio.ifBlank { person.bio },
            ) ?: person
        }
        people = mergePeople(people, byId.values.toList())
        persistSocial()
        return byId.values.toList()
    }

    fun withPublishing(block: suspend () -> Unit): suspend () -> Unit = {
        publishing = true
        try {
            block()
        } finally {
            publishing = false
        }
    }

    private suspend fun insertPost(
        id: String,
        kind: PulseMediaKind,
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        caption: String,
        community: String,
        workoutMeta: PulseWorkoutMeta?,
        mediaFileName: String?,
        mediaBytes: ByteArray?,
        contentType: String,
        fileExtension: String,
    ): PulsePost {
        val now = System.currentTimeMillis()
        val post = PulsePost(
            id = id,
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = authorCountryCode.ifBlank { "BR" },
            caption = caption.take(PulseLimits.MAX_CAPTION),
            mediaKind = kind,
            mediaFileName = mediaFileName,
            community = community,
            workoutMeta = workoutMeta,
            createdAtMillis = now,
            expiresAtMillis = now + PulseLimits.POST_LIFETIME_MS,
        )
        if (community !in joinedCommunities) {
            joinedCommunities = joinedCommunities + community
            persistSocial()
        }
        posts = listOf(post) + posts
        persist()
        val remote = withContext(Dispatchers.IO) {
            runCatching {
                PulseCloud.upsertPost(post, mediaBytes, contentType, fileExtension)
            }.getOrNull()
        }
        if (remote != null) {
            posts = posts.map { if (it.id == post.id) it.copy(remoteMediaURL = remote) else it }
            persist()
        }
        return post.copy(remoteMediaURL = remote)
    }

    private fun loadLocal() {
        posts = decodePosts(prefs.getString(KEY_POSTS, null))
        stories = decodeStories(prefs.getString(KEY_STORIES, null))
        follows = decodeFollows(prefs.getString(KEY_FOLLOWS, null))
        people = decodePeople(prefs.getString(KEY_PEOPLE, null))
        blockedUserIds = prefs.getStringSet(KEY_BLOCKED, emptySet())?.toSet().orEmpty()
        ownBio = prefs.getString(KEY_BIO, "") ?: ""
        val savedCommunities = prefs.getStringSet(KEY_COMMUNITIES, null)
        if (!savedCommunities.isNullOrEmpty()) joinedCommunities = savedCommunities
    }

    private fun persist() {
        prefs.edit()
            .putString(KEY_POSTS, encodePosts(posts))
            .putString(KEY_STORIES, encodeStories(stories))
            .apply()
    }

    private fun persistSocial() {
        prefs.edit()
            .putString(KEY_FOLLOWS, encodeFollows(follows))
            .putString(KEY_PEOPLE, encodePeople(people))
            .putStringSet(KEY_BLOCKED, blockedUserIds)
            .putStringSet(KEY_COMMUNITIES, joinedCommunities)
            .putString(KEY_BIO, ownBio)
            .apply()
    }

    private fun pruneExpired() {
        val now = System.currentTimeMillis()
        val livePosts = posts.filter { it.expiresAtMillis > now }
        val liveStories = stories.filter { it.expiresAtMillis > now }
        val removed = (posts - livePosts.toSet()) + emptyList()
        val removedNames = posts.filter { it.expiresAtMillis <= now }.mapNotNull { it.mediaFileName } +
            stories.filter { it.expiresAtMillis <= now }.mapNotNull { it.mediaFileName }
        for (name in removedNames) {
            mediaFile(name)?.delete()
        }
        if (livePosts.size != posts.size || liveStories.size != stories.size) {
            posts = livePosts
            stories = liveStories
            persist()
        }
        @Suppress("UNUSED_VARIABLE")
        val unused = removed
    }

    private fun mergePosts(local: List<PulsePost>, cloud: List<PulsePost>): List<PulsePost> {
        val byId = linkedMapOf<String, PulsePost>()
        for (post in local) byId[post.id] = post
        for (remote in cloud) {
            val existing = byId[remote.id]
            byId[remote.id] = if (existing == null) {
                remote
            } else {
                existing.copy(
                    remoteMediaURL = remote.remoteMediaURL ?: existing.remoteMediaURL,
                    caption = remote.caption,
                    community = remote.community,
                    isHidden = remote.isHidden,
                )
            }
        }
        return byId.values.sortedByDescending { it.createdAtMillis }
    }

    private fun mergeFollows(local: List<PulseFollow>, cloud: List<PulseFollow>): List<PulseFollow> {
        val byKey = linkedMapOf<String, PulseFollow>()
        for (item in local) byKey["${item.fromUserId}_${item.toUserId}"] = item
        for (remote in cloud) {
            byKey["${remote.fromUserId}_${remote.toUserId}"] = remote
        }
        return byKey.values.toList()
    }

    private fun mergePeople(local: List<PulsePerson>, cloud: List<PulsePerson>): List<PulsePerson> {
        val byId = linkedMapOf<String, PulsePerson>()
        for (person in local) byId[person.id] = person
        for (remote in cloud) {
            val existing = byId[remote.id]
            byId[remote.id] = existing?.copy(
                displayName = remote.displayName.ifBlank { existing.displayName },
                bio = remote.bio.ifBlank { existing.bio },
                photoURL = remote.photoURL ?: existing.photoURL,
                city = remote.city.ifBlank { existing.city },
                state = remote.state.ifBlank { existing.state },
            ) ?: remote
        }
        return byId.values.toList()
    }

    private fun mergeComments(local: List<PulseComment>, cloud: List<PulseComment>): List<PulseComment> {
        val byId = linkedMapOf<String, PulseComment>()
        for (item in local) byId[item.id] = item
        for (item in cloud) byId[item.id] = item
        return byId.values.sortedBy { it.createdAtMillis }
    }

    private fun mergeReactions(local: List<PulseReaction>, cloud: List<PulseReaction>): List<PulseReaction> {
        val byUser = linkedMapOf<String, PulseReaction>()
        for (item in local) byUser[item.userId + item.kind] = item
        for (item in cloud) byUser[item.userId + item.kind] = item
        return byUser.values.toList()
    }

    private fun mergeStories(local: List<PulseStory>, cloud: List<PulseStory>): List<PulseStory> {
        val byId = linkedMapOf<String, PulseStory>()
        for (story in local) byId[story.id] = story
        for (remote in cloud) {
            val existing = byId[remote.id]
            byId[remote.id] = if (existing == null) {
                remote
            } else {
                existing.copy(remoteMediaURL = remote.remoteMediaURL ?: existing.remoteMediaURL)
            }
        }
        return byId.values.sortedByDescending { it.createdAtMillis }
    }

    private fun mediaDir(): File = File(context.filesDir, "PulseExperimentalMedia").apply { mkdirs() }

    private fun jpegFromUri(uri: Uri): ByteArray {
        val bitmap = decodeBitmap(uri) ?: error("Não foi possível ler a foto.")
        val scaled = downsample(bitmap, 1600)
        val out = ByteArrayOutputStream()
        var quality = 85
        do {
            out.reset()
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
            quality -= 8
        } while (out.size() > 7 * 1024 * 1024 && quality >= 50)
        if (scaled !== bitmap) bitmap.recycle()
        return out.toByteArray()
    }

    private fun decodeBitmap(uri: Uri): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val sample = sampleSize(max(bounds.outWidth, bounds.outHeight), 1600)
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        val rotation = resolver.openInputStream(uri)?.use { input ->
            when (ExifInterface(input).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        if (rotation == 0f) return bitmap
        val matrix = android.graphics.Matrix().apply { postRotate(rotation) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true).also {
            if (it !== bitmap) bitmap.recycle()
        }
    }

    private fun downsample(bitmap: Bitmap, maxSide: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxSide) return bitmap
        val scale = maxSide.toFloat() / longest
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        )
    }

    private fun sampleSize(longest: Int, maxSide: Int): Int {
        var sample = 1
        var size = longest
        while (size / 2 >= maxSide) {
            sample *= 2
            size /= 2
        }
        return sample.coerceAtLeast(1)
    }

    private fun videoDurationSeconds(uri: Uri): Double {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val ms = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            ms / 1000.0
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun newId(): String = UUID.randomUUID().toString().uppercase()

    private fun encodePosts(items: List<PulsePost>): String {
        val array = JSONArray()
        for (post in items) {
            val obj = JSONObject()
                .put("id", post.id)
                .put("authorId", post.authorId)
                .put("authorName", post.authorName)
                .put("authorCountryCode", post.authorCountryCode)
                .put("caption", post.caption)
                .put("mediaKind", post.mediaKind.raw)
                .put("community", post.community)
                .put("createdAtMillis", post.createdAtMillis)
                .put("expiresAtMillis", post.expiresAtMillis)
                .put("isHidden", post.isHidden)
            post.mediaFileName?.let { obj.put("mediaFileName", it) }
            post.remoteMediaURL?.let { obj.put("remoteMediaURL", it) }
            obj.put("reportCount", post.reportCount)
            val comments = JSONArray()
            for (comment in post.comments) {
                comments.put(
                    JSONObject()
                        .put("id", comment.id)
                        .put("authorId", comment.authorId)
                        .put("authorName", comment.authorName)
                        .put("text", comment.text)
                        .put("createdAtMillis", comment.createdAtMillis),
                )
            }
            obj.put("comments", comments)
            val reactions = JSONArray()
            for (reaction in post.reactions) {
                reactions.put(
                    JSONObject()
                        .put("id", reaction.id)
                        .put("userId", reaction.userId)
                        .put("userName", reaction.userName)
                        .put("kind", reaction.kind)
                        .put("createdAtMillis", reaction.createdAtMillis),
                )
            }
            obj.put("reactions", reactions)
            post.workoutMeta?.let {
                obj.put(
                    "workoutMeta",
                    JSONObject()
                        .put("modality", it.modality ?: "")
                        .put("durationSeconds", it.durationSeconds ?: 0)
                        .put("intensity", it.intensity ?: 0)
                        .put("duoTeamName", it.duoTeamName ?: ""),
                )
            }
            array.put(obj)
        }
        return array.toString()
    }

    private fun encodeStories(items: List<PulseStory>): String {
        val array = JSONArray()
        for (story in items) {
            val overlays = JSONArray()
            for (overlay in story.textOverlays) {
                overlays.put(
                    JSONObject()
                        .put("id", overlay.id)
                        .put("text", overlay.text)
                        .put("fontStyle", overlay.fontStyle)
                        .put("isBold", overlay.isBold)
                        .put("colorHex", overlay.colorHex)
                        .put("x", overlay.x)
                        .put("y", overlay.y)
                        .put("scale", overlay.scale),
                )
            }
            array.put(
                JSONObject()
                    .put("id", story.id)
                    .put("authorId", story.authorId)
                    .put("authorName", story.authorName)
                    .put("mediaFileName", story.mediaFileName)
                    .put("remoteMediaURL", story.remoteMediaURL)
                    .put("createdAtMillis", story.createdAtMillis)
                    .put("expiresAtMillis", story.expiresAtMillis)
                    .put("textOverlays", overlays)
                    .put("isViewed", story.isViewed),
            )
        }
        return array.toString()
    }

    private fun decodePosts(raw: String?): List<PulsePost> {
        raw ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    val metaObj = o.optJSONObject("workoutMeta")
                    add(
                        PulsePost(
                            id = o.getString("id"),
                            authorId = o.getString("authorId"),
                            authorName = o.getString("authorName"),
                            authorCountryCode = o.optString("authorCountryCode", "BR"),
                            caption = o.optString("caption"),
                            mediaKind = PulseMediaKind.fromRaw(o.optString("mediaKind")),
                            mediaFileName = o.optString("mediaFileName").takeIf { it.isNotBlank() },
                            remoteMediaURL = o.optString("remoteMediaURL").takeIf { it.isNotBlank() },
                            community = o.optString("community", "musculacao"),
                            workoutMeta = metaObj?.let {
                                PulseWorkoutMeta(
                                    modality = it.optString("modality").takeIf { v -> v.isNotBlank() },
                                    durationSeconds = it.optInt("durationSeconds").takeIf { v -> v > 0 },
                                    intensity = it.optInt("intensity").takeIf { v -> v > 0 },
                                    duoTeamName = it.optString("duoTeamName").takeIf { v -> v.isNotBlank() },
                                )
                            },
                            createdAtMillis = o.optLong("createdAtMillis"),
                            expiresAtMillis = o.optLong("expiresAtMillis"),
                            isHidden = o.optBoolean("isHidden"),
                            reportCount = o.optInt("reportCount"),
                            comments = decodeComments(o.optJSONArray("comments")),
                            reactions = decodeReactions(o.optJSONArray("reactions")),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun decodeStories(raw: String?): List<PulseStory> {
        raw ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    val overlaysJson = o.optJSONArray("textOverlays") ?: JSONArray()
                    val overlays = buildList {
                        for (j in 0 until overlaysJson.length()) {
                            val ov = overlaysJson.getJSONObject(j)
                            add(
                                PulseStoryTextOverlay(
                                    id = ov.optString("id", newId()),
                                    text = ov.optString("text"),
                                    fontStyle = ov.optString("fontStyle", "modern"),
                                    isBold = ov.optBoolean("isBold", true),
                                    colorHex = ov.optString("colorHex", "#FFFFFF"),
                                    x = ov.optDouble("x", 0.5),
                                    y = ov.optDouble("y", 0.45),
                                    scale = ov.optDouble("scale", 1.0),
                                ),
                            )
                        }
                    }
                    add(
                        PulseStory(
                            id = o.getString("id"),
                            authorId = o.getString("authorId"),
                            authorName = o.getString("authorName"),
                            mediaFileName = o.optString("mediaFileName").takeIf { it.isNotBlank() },
                            remoteMediaURL = o.optString("remoteMediaURL").takeIf { it.isNotBlank() },
                            createdAtMillis = o.optLong("createdAtMillis"),
                            expiresAtMillis = o.optLong("expiresAtMillis"),
                            textOverlays = overlays,
                            isViewed = o.optBoolean("isViewed"),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun decodeComments(array: JSONArray?): List<PulseComment> {
        array ?: return emptyList()
        return buildList {
            for (i in 0 until array.length()) {
                val o = array.getJSONObject(i)
                add(
                    PulseComment(
                        id = o.optString("id", newId()),
                        authorId = o.optString("authorId"),
                        authorName = o.optString("authorName"),
                        text = o.optString("text"),
                        createdAtMillis = o.optLong("createdAtMillis"),
                    ),
                )
            }
        }
    }

    private fun decodeReactions(array: JSONArray?): List<PulseReaction> {
        array ?: return emptyList()
        return buildList {
            for (i in 0 until array.length()) {
                val o = array.getJSONObject(i)
                add(
                    PulseReaction(
                        id = o.optString("id", newId()),
                        userId = o.optString("userId"),
                        userName = o.optString("userName"),
                        kind = o.optString("kind", "heart"),
                        createdAtMillis = o.optLong("createdAtMillis"),
                    ),
                )
            }
        }
    }

    private fun encodeFollows(items: List<PulseFollow>): String {
        val array = JSONArray()
        for (item in items) {
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("fromUserId", item.fromUserId)
                    .put("toUserId", item.toUserId)
                    .put("status", item.status.raw)
                    .put("createdAtMillis", item.createdAtMillis)
                    .put("notifyPosts", item.notifyPosts)
                    .put("fromName", item.fromName),
            )
        }
        return array.toString()
    }

    private fun decodeFollows(raw: String?): List<PulseFollow> {
        raw ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    add(
                        PulseFollow(
                            id = o.optString("id"),
                            fromUserId = o.optString("fromUserId"),
                            toUserId = o.optString("toUserId"),
                            status = PulseFollowStatus.entries.firstOrNull { it.raw == o.optString("status") }
                                ?: PulseFollowStatus.fromCloud(o.optString("status")),
                            createdAtMillis = o.optLong("createdAtMillis"),
                            notifyPosts = o.optBoolean("notifyPosts", true),
                            fromName = o.optString("fromName"),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun encodePeople(items: List<PulsePerson>): String {
        val array = JSONArray()
        for (person in items) {
            array.put(
                JSONObject()
                    .put("id", person.id)
                    .put("displayName", person.displayName)
                    .put("emailHint", person.emailHint)
                    .put("countryCode", person.countryCode)
                    .put("state", person.state)
                    .put("city", person.city)
                    .put("bio", person.bio)
                    .put("communityFocus", person.communityFocus)
                    .put("photoURL", person.photoURL ?: ""),
            )
        }
        return array.toString()
    }

    private fun decodePeople(raw: String?): List<PulsePerson> {
        raw ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    add(
                        PulsePerson(
                            id = o.optString("id"),
                            displayName = o.optString("displayName"),
                            emailHint = o.optString("emailHint"),
                            countryCode = o.optString("countryCode", "BR"),
                            state = o.optString("state"),
                            city = o.optString("city"),
                            bio = o.optString("bio"),
                            communityFocus = o.optString("communityFocus", "musculacao"),
                            photoURL = o.optString("photoURL").takeIf { it.isNotBlank() },
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    companion object {
        private const val KEY_POSTS = "posts"
        private const val KEY_STORIES = "stories"
        private const val KEY_FOLLOWS = "follows"
        private const val KEY_PEOPLE = "people"
        private const val KEY_BLOCKED = "blocked"
        private const val KEY_COMMUNITIES = "communities"
        private const val KEY_BIO = "bio"
        private const val KEY_TERMS = "terms."
    }
}
