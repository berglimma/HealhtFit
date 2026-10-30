package com.healthfit.core.pulse

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.SetOptions
import com.google.firebase.storage.FirebaseStorage
import com.healthfit.core.coach.AppConfigAndroid
import java.util.Date
import java.util.UUID
import kotlinx.coroutines.tasks.await

/**
 * Same Pulse backend as iOS `PulseFirestoreService`:
 * Firestore `pulsePosts` / `pulseStories` + Storage `pulse/{uid}/{id}.{ext}`.
 */
object PulseCloud {
    private const val POSTS = "pulsePosts"
    private const val STORIES = "pulseStories"
    private const val PROFILES = "pulseProfiles"
    private const val FOLLOWS = "pulseFollows"
    private const val BLOCKS = "pulseBlocks"
    private const val REPORTS = "pulseReports"

    fun isReady(): Boolean = AppConfigAndroid.isFirebaseReady() &&
        FirebaseAuth.getInstance().currentUser != null

    fun currentUid(): String? = FirebaseAuth.getInstance().currentUser?.uid?.takeIf { it.isNotBlank() }

    suspend fun upsertPost(post: PulsePost, media: ByteArray?, contentType: String, fileExtension: String): String? {
        val uid = currentUid() ?: return null
        if (post.authorId != uid) return null
        var remote = post.remoteMediaURL
        if (media != null) {
            remote = upload(uid, post.id, media, contentType, fileExtension) ?: remote
        }
        val payload = postPayload(post, uid, remote)
        FirebaseFirestore.getInstance().collection(POSTS).document(post.id)
            .set(payload, SetOptions.merge())
            .await()
        return remote
    }

    suspend fun upsertStory(story: PulseStory, imageJpeg: ByteArray?): String? {
        val uid = currentUid() ?: return null
        if (story.authorId != uid) return null
        var remote = story.remoteMediaURL
        if (imageJpeg != null) {
            remote = upload(uid, story.id, imageJpeg, "image/jpeg", "jpg") ?: remote
        }
        val data = hashMapOf<String, Any>(
            "id" to story.id,
            "authorId" to uid,
            "authorName" to story.authorName,
            "createdAt" to Timestamp(Date(story.createdAtMillis)),
            "expiresAt" to Timestamp(Date(story.expiresAtMillis)),
            "source" to PulseLimits.CLOUD_SOURCE,
            "updatedAt" to FieldValue.serverTimestamp(),
        )
        remote?.let { data["remoteMediaURL"] = it }
        if (story.textOverlays.isNotEmpty()) {
            data["textOverlays"] = story.textOverlays.map { overlay ->
                mapOf(
                    "id" to overlay.id,
                    "text" to overlay.text,
                    "fontStyle" to overlay.fontStyle,
                    "isBold" to overlay.isBold,
                    "colorHex" to overlay.colorHex,
                    "x" to overlay.x,
                    "y" to overlay.y,
                    "scale" to overlay.scale,
                )
            }
        }
        FirebaseFirestore.getInstance().collection(STORIES).document(story.id)
            .set(data, SetOptions.merge())
            .await()
        return remote
    }

    suspend fun fetchActivePosts(limit: Int = 40): List<PulsePost> {
        if (!isReady()) return emptyList()
        val snap = FirebaseFirestore.getInstance().collection(POSTS)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get()
            .await()
        val now = System.currentTimeMillis()
        return snap.documents.mapNotNull { decodePost(it.data, it.id) }
            .filter { it.expiresAtMillis > now && !it.isHidden }
            .sortedByDescending { it.createdAtMillis }
    }

    suspend fun fetchActiveStories(limit: Int = 40): List<PulseStory> {
        if (!isReady()) return emptyList()
        val snap = FirebaseFirestore.getInstance().collection(STORIES)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get()
            .await()
        val now = System.currentTimeMillis()
        return snap.documents.mapNotNull { decodeStory(it.data, it.id) }
            .filter { it.expiresAtMillis > now }
            .sortedByDescending { it.createdAtMillis }
    }

    suspend fun upsertOwnProfile(
        displayName: String,
        emailHint: String,
        countryCode: String,
        bio: String = "",
        state: String = "",
        city: String = "",
        communityFocus: String = "musculacao",
    ) {
        val uid = currentUid() ?: return
        val data = hashMapOf<String, Any>(
            "id" to uid,
            "displayName" to displayName.take(80).ifBlank { "HealthFit" },
            "emailHint" to emailHint,
            "countryCode" to countryCode.ifBlank { "BR" },
            "state" to state.take(80),
            "city" to city.take(80),
            "bio" to bio.take(PulseLimits.MAX_BIO),
            "communityFocus" to communityFocus,
            "notifyOnPosts" to true,
            "updatedAt" to FieldValue.serverTimestamp(),
            "source" to PulseLimits.CLOUD_SOURCE,
        )
        FirebaseFirestore.getInstance().collection(PROFILES).document(uid)
            .set(data, SetOptions.merge())
            .await()
    }

    suspend fun deletePost(postId: String) {
        val uid = currentUid() ?: return
        val ref = FirebaseFirestore.getInstance().collection(POSTS).document(postId)
        val snap = ref.get().await()
        if (snap.getString("authorId") != uid) return
        ref.delete().await()
        val storage = FirebaseStorage.getInstance()
        for (ext in listOf("jpg", "mp4", "mov")) {
            runCatching { storage.reference.child("pulse/$uid/$postId.$ext").delete().await() }
        }
    }

    suspend fun deleteStory(storyId: String) {
        val uid = currentUid() ?: return
        val ref = FirebaseFirestore.getInstance().collection(STORIES).document(storyId)
        val snap = ref.get().await()
        if (snap.getString("authorId") != uid) return
        ref.delete().await()
        runCatching {
            FirebaseStorage.getInstance().reference.child("pulse/$uid/$storyId.jpg").delete().await()
        }
    }

    suspend fun setReaction(postId: String, emoji: String) {
        val uid = currentUid() ?: return
        val trimmed = emoji.trim().take(16)
        if (trimmed.isEmpty()) return
        FirebaseFirestore.getInstance().collection(POSTS).document(postId)
            .collection("reactions").document(uid)
            .set(
                mapOf(
                    "userId" to uid,
                    "emoji" to trimmed,
                    "createdAt" to FieldValue.serverTimestamp(),
                    "updatedAt" to FieldValue.serverTimestamp(),
                ),
                SetOptions.merge(),
            )
            .await()
    }

    suspend fun clearReaction(postId: String) {
        val uid = currentUid() ?: return
        FirebaseFirestore.getInstance().collection(POSTS).document(postId)
            .collection("reactions").document(uid)
            .delete()
            .await()
    }

    suspend fun fetchReactions(postId: String): List<PulseReaction> {
        if (!isReady()) return emptyList()
        val snap = FirebaseFirestore.getInstance().collection(POSTS).document(postId)
            .collection("reactions")
            .limit(200)
            .get()
            .await()
        return snap.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            val userId = data["userId"] as? String ?: doc.id
            val emoji = data["emoji"] as? String ?: "heart"
            val kind = if (emoji == "💚" || emoji == "heart" || emoji == "❤️") "heart" else emoji
            PulseReaction(
                id = doc.id,
                userId = userId,
                userName = data["userName"] as? String ?: "",
                kind = kind,
                createdAtMillis = millisOf(data["createdAt"]) ?: System.currentTimeMillis(),
            )
        }
    }

    suspend fun addComment(postId: String, comment: PulseComment): Boolean {
        val uid = currentUid() ?: return false
        if (comment.authorId != uid) return false
        val text = comment.text.trim()
        if (text.isEmpty()) return false
        val data = hashMapOf<String, Any>(
            "id" to comment.id,
            "authorId" to uid,
            "authorName" to comment.authorName,
            "text" to text.take(500),
            "createdAt" to Timestamp(Date(comment.createdAtMillis)),
            "updatedAt" to FieldValue.serverTimestamp(),
        )
        return runCatching {
            FirebaseFirestore.getInstance().collection(POSTS).document(postId)
                .collection("comments").document(comment.id)
                .set(data)
                .await()
            true
        }.getOrDefault(false)
    }

    suspend fun deleteComment(postId: String, commentId: String, authorId: String): Boolean {
        val uid = currentUid() ?: return false
        if (authorId != uid) return false
        return runCatching {
            FirebaseFirestore.getInstance().collection(POSTS).document(postId)
                .collection("comments").document(commentId)
                .delete()
                .await()
            true
        }.getOrDefault(false)
    }

    suspend fun fetchComments(postId: String): List<PulseComment> {
        if (!isReady()) return emptyList()
        val snap = FirebaseFirestore.getInstance().collection(POSTS).document(postId)
            .collection("comments")
            .orderBy("createdAt", Query.Direction.ASCENDING)
            .limit(50)
            .get()
            .await()
        return snap.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            val authorId = data["authorId"] as? String ?: return@mapNotNull null
            val authorName = data["authorName"] as? String ?: return@mapNotNull null
            val text = data["text"] as? String ?: return@mapNotNull null
            PulseComment(
                id = (data["id"] as? String)?.takeIf { it.isNotBlank() } ?: doc.id,
                authorId = authorId,
                authorName = authorName,
                text = text,
                createdAtMillis = millisOf(data["createdAt"]) ?: System.currentTimeMillis(),
            )
        }
    }

    suspend fun reportPost(postId: String) {
        val uid = currentUid() ?: return
        FirebaseFirestore.getInstance().collection(REPORTS).document()
            .set(
                hashMapOf(
                    "postId" to postId,
                    "reporterId" to uid,
                    "reason" to "user_report",
                    "createdAt" to FieldValue.serverTimestamp(),
                ),
            )
            .await()
    }

    suspend fun upsertBlock(blockedId: String) {
        val uid = currentUid() ?: return
        if (uid == blockedId) return
        FirebaseFirestore.getInstance().collection(BLOCKS).document("${uid}_$blockedId")
            .set(
                hashMapOf(
                    "blockerId" to uid,
                    "blockedId" to blockedId,
                    "createdAt" to FieldValue.serverTimestamp(),
                    "source" to PulseLimits.CLOUD_SOURCE,
                ),
                SetOptions.merge(),
            )
            .await()
    }

    suspend fun fetchBlocks(): Set<String> {
        val uid = currentUid() ?: return emptySet()
        val snap = FirebaseFirestore.getInstance().collection(BLOCKS)
            .whereEqualTo("blockerId", uid)
            .limit(200)
            .get()
            .await()
        return snap.documents.mapNotNull { it.getString("blockedId") }.toSet()
    }

    suspend fun upsertFollow(fromUserId: String, toUserId: String, status: PulseFollowStatus, fromName: String?) {
        val uid = currentUid() ?: return
        if (fromUserId == toUserId) return
        val cloudStatus = PulseFollowStatus.toCloud(status) ?: return
        val isCreator = fromUserId == uid
        val isTargetAccepting = toUserId == uid && cloudStatus == "accepted"
        if (!isCreator && !isTargetAccepting) return
        val followId = "${fromUserId}_$toUserId"
        val ref = FirebaseFirestore.getInstance().collection(FOLLOWS).document(followId)
        if (isCreator) {
            val data = hashMapOf<String, Any>(
                "fromUserId" to fromUserId,
                "toUserId" to toUserId,
                "status" to cloudStatus,
                "createdAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp(),
                "source" to PulseLimits.CLOUD_SOURCE,
            )
            fromName?.trim()?.takeIf { it.isNotEmpty() }?.let { data["fromName"] = it.take(80) }
            ref.set(data, SetOptions.merge()).await()
        } else {
            ref.update(
                mapOf(
                    "status" to cloudStatus,
                    "updatedAt" to FieldValue.serverTimestamp(),
                ),
            ).await()
        }
    }

    suspend fun deleteFollow(fromUserId: String, toUserId: String) {
        val uid = currentUid() ?: return
        if (fromUserId != uid && toUserId != uid) return
        FirebaseFirestore.getInstance().collection(FOLLOWS)
            .document("${fromUserId}_$toUserId")
            .delete()
            .await()
    }

    suspend fun fetchFollows(userId: String): List<PulseFollow> {
        if (!isReady()) return emptyList()
        val db = FirebaseFirestore.getInstance().collection(FOLLOWS)
        val outgoing = db.whereEqualTo("fromUserId", userId).limit(100).get().await()
        val incoming = db.whereEqualTo("toUserId", userId).limit(100).get().await()
        val seen = mutableSetOf<String>()
        return (outgoing.documents + incoming.documents).mapNotNull { doc ->
            if (!seen.add(doc.id)) return@mapNotNull null
            val data = doc.data ?: return@mapNotNull null
            val from = data["fromUserId"] as? String ?: return@mapNotNull null
            val to = data["toUserId"] as? String ?: return@mapNotNull null
            PulseFollow(
                id = doc.id,
                fromUserId = from,
                toUserId = to,
                status = PulseFollowStatus.fromCloud(data["status"] as? String),
                createdAtMillis = millisOf(data["createdAt"]) ?: System.currentTimeMillis(),
                notifyPosts = data["notifyPosts"] as? Boolean ?: true,
                fromName = data["fromName"] as? String ?: "",
            )
        }
    }

    suspend fun fetchProfiles(limit: Int = 80): List<PulsePerson> {
        if (!isReady()) return emptyList()
        val snap = FirebaseFirestore.getInstance().collection(PROFILES)
            .orderBy("displayName")
            .limit(limit.toLong())
            .get()
            .await()
        return snap.documents.mapNotNull { decodePerson(it.data, it.id) }
    }

    suspend fun searchPeople(query: String, excludingUserId: String?): List<PulsePerson> {
        if (!isReady()) return emptyList()
        val needle = query.trim().lowercase()
        if (needle.isEmpty()) return emptyList()
        val byId = linkedMapOf<String, PulsePerson>()
        runCatching {
            val snap = FirebaseFirestore.getInstance().collection(PROFILES)
                .orderBy("displayName")
                .limit(300)
                .get()
                .await()
            for (doc in snap.documents) {
                val person = decodePerson(doc.data, doc.id) ?: continue
                if (person.id == excludingUserId) continue
                val hay = listOf(person.displayName, person.city, person.state, person.emailHint, person.bio)
                    .joinToString(" ").lowercase()
                if (hay.contains(needle)) byId[person.id] = person
            }
        }
        return byId.values.toList()
    }

    private fun decodePerson(data: Map<String, Any>?, documentId: String): PulsePerson? {
        data ?: return null
        val displayName = data["displayName"] as? String ?: return null
        val photo = data["photoURL"] as? String
        return PulsePerson(
            id = (data["id"] as? String)?.takeIf { it.isNotBlank() } ?: documentId,
            displayName = displayName,
            emailHint = data["emailHint"] as? String ?: "",
            countryCode = data["countryCode"] as? String ?: "BR",
            state = data["state"] as? String ?: "",
            city = data["city"] as? String ?: "",
            bio = data["bio"] as? String ?: "",
            communityFocus = data["communityFocus"] as? String ?: "musculacao",
            notifyOnPosts = data["notifyOnPosts"] as? Boolean ?: true,
            photoURL = photo?.takeIf { it.isNotBlank() },
        )
    }

    private suspend fun upload(
        uid: String,
        fileId: String,
        bytes: ByteArray,
        contentType: String,
        fileExtension: String,
    ): String? = runCatching {
        val ref = FirebaseStorage.getInstance().reference.child("pulse/$uid/$fileId.$fileExtension")
        val meta = com.google.firebase.storage.StorageMetadata.Builder()
            .setContentType(contentType)
            .build()
        ref.putBytes(bytes, meta).await()
        ref.downloadUrl.await().toString()
    }.getOrNull()

    private fun postPayload(post: PulsePost, uid: String, remote: String?): HashMap<String, Any> {
        val data = hashMapOf<String, Any>(
            "id" to post.id,
            "authorId" to uid,
            "authorName" to post.authorName,
            "authorCountryCode" to post.authorCountryCode,
            "caption" to post.caption.take(PulseLimits.MAX_CAPTION),
            "mediaKind" to post.mediaKind.raw,
            "community" to post.community,
            "createdAt" to Timestamp(Date(post.createdAtMillis)),
            "expiresAt" to Timestamp(Date(post.expiresAtMillis)),
            "isHidden" to post.isHidden,
            "reportCount" to 0,
            "source" to PulseLimits.CLOUD_SOURCE,
            "updatedAt" to FieldValue.serverTimestamp(),
        )
        remote?.let { data["remoteMediaURL"] = it }
        post.workoutMeta?.let { meta ->
            val map = mutableMapOf<String, Any>()
            meta.modality?.takeIf { it.isNotBlank() }?.let { map["modality"] = it }
            meta.durationSeconds?.let { map["durationSeconds"] = it }
            meta.intensity?.let { map["intensity"] = it }
            meta.duoTeamName?.takeIf { it.isNotBlank() }?.let { map["duoTeamName"] = it }
            if (map.isNotEmpty()) data["workoutMeta"] = map
        }
        return data
    }

    private fun decodePost(data: Map<String, Any>?, documentId: String): PulsePost? {
        data ?: return null
        val authorId = data["authorId"] as? String ?: return null
        val authorName = data["authorName"] as? String ?: return null
        val caption = data["caption"] as? String ?: return null
        val created = millisOf(data["createdAt"]) ?: System.currentTimeMillis()
        val expires = millisOf(data["expiresAt"]) ?: created + PulseLimits.POST_LIFETIME_MS
        val metaRaw = data["workoutMeta"] as? Map<*, *>
        val meta = metaRaw?.let {
            PulseWorkoutMeta(
                modality = it["modality"] as? String,
                durationSeconds = (it["durationSeconds"] as? Number)?.toInt(),
                intensity = (it["intensity"] as? Number)?.toInt(),
                duoTeamName = it["duoTeamName"] as? String,
            )
        }
        return PulsePost(
            id = (data["id"] as? String)?.takeIf { it.isNotBlank() } ?: documentId,
            authorId = authorId,
            authorName = authorName,
            authorCountryCode = data["authorCountryCode"] as? String ?: "BR",
            caption = caption,
            mediaKind = PulseMediaKind.fromRaw(data["mediaKind"] as? String),
            remoteMediaURL = data["remoteMediaURL"] as? String,
            community = data["community"] as? String ?: "musculacao",
            workoutMeta = meta,
            createdAtMillis = created,
            expiresAtMillis = expires,
            isHidden = data["isHidden"] as? Boolean ?: false,
            reportCount = (data["reportCount"] as? Number)?.toInt() ?: 0,
        )
    }

    private fun decodeStory(data: Map<String, Any>?, documentId: String): PulseStory? {
        data ?: return null
        val authorId = data["authorId"] as? String ?: return null
        val authorName = data["authorName"] as? String ?: return null
        val created = millisOf(data["createdAt"]) ?: System.currentTimeMillis()
        val expires = millisOf(data["expiresAt"]) ?: created + PulseLimits.STORY_LIFETIME_MS
        val overlays = (data["textOverlays"] as? List<*>).orEmpty().mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            val text = map["text"] as? String ?: return@mapNotNull null
            PulseStoryTextOverlay(
                id = map["id"] as? String ?: UUID.randomUUID().toString().uppercase(),
                text = text,
                fontStyle = map["fontStyle"] as? String ?: "modern",
                isBold = map["isBold"] as? Boolean ?: true,
                colorHex = map["colorHex"] as? String ?: "#FFFFFF",
                x = (map["x"] as? Number)?.toDouble() ?: 0.5,
                y = (map["y"] as? Number)?.toDouble() ?: 0.45,
                scale = (map["scale"] as? Number)?.toDouble() ?: 1.0,
            )
        }
        return PulseStory(
            id = (data["id"] as? String)?.takeIf { it.isNotBlank() } ?: documentId,
            authorId = authorId,
            authorName = authorName,
            remoteMediaURL = data["remoteMediaURL"] as? String,
            createdAtMillis = created,
            expiresAtMillis = expires,
            textOverlays = overlays,
        )
    }

    private fun millisOf(value: Any?): Long? = when (value) {
        is Timestamp -> value.toDate().time
        is Date -> value.time
        is Number -> value.toLong()
        else -> null
    }
}
