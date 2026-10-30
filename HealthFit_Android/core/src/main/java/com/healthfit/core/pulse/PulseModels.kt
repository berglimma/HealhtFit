package com.healthfit.core.pulse

import java.util.Calendar

/**
 * Pulse payload that matches iOS `PulsePost` / `PulseStory` Firestore documents.
 * Collections: `pulsePosts`, `pulseStories`, `pulseProfiles`, `pulseFollows`,
 * `pulseBlocks`, `pulseReports`. Storage: `pulse/{uid}/{id}.jpg|mp4`.
 */
object PulseLimits {
    const val MAX_CAPTION = 350
    const val MAX_COMMENT = 280
    const val MAX_BIO = 100
    const val MAX_STORY_TEXT = 80
    const val MAX_VIDEO_SECONDS = 30.5
    const val STORY_LIFETIME_MS = 12L * 60L * 60L * 1000L
    const val POST_LIFETIME_MS = 24L * 60L * 60L * 1000L
    const val STORY_VIEW_MS = 15_000L
    const val CLOUD_SOURCE = "healthfit-pulse"
    const val TAGLINE = "Sozinho você treina. Junto, você permanece."
    const val TERMS_VERSION = "pulse-terms-v4-2026-09"
    const val UGC_MINIMUM_AGE = 18
    val DEFAULT_COMMUNITIES = setOf("musculacao", "cardio")
    val THEMATIC_COMMUNITIES = listOf("musculacao", "cardio", "kite", "nutricao")

    fun communityTitle(key: String): String = when {
        key == "musculacao" -> "Musculação"
        key == "cardio" -> "Cardio"
        key == "kite" -> "Kite"
        key == "nutricao" -> "Nutrição"
        key.startsWith("cardio.") -> key.removePrefix("cardio.")
        else -> key
    }

    fun dailyChallenge(userId: String): String {
        val cal = Calendar.getInstance()
        val day = cal.get(Calendar.DAY_OF_YEAR)
        val year = cal.get(Calendar.YEAR)
        val hash = (year.toString() + "|" + userId + "|pulse-challenge-v1").fold(0) { acc, c ->
            acc * 31 + c.code
        }
        val index = kotlin.math.abs(hash + day) % CHALLENGES.size
        return CHALLENGES[index]
    }

    private val CHALLENGES = listOf(
        "Complete 20 min de movimento consciente hoje.",
        "Poste um treino com intensidade registrada (1–10).",
        "Hidrate-se: registre 2L e compartilhe no Pulse.",
        "Faça 10 min de mobilidade e conte como se sentiu.",
        "Poste um story de aquecimento antes do treino.",
        "Complete um treino de força focado em pernas.",
        "Faça 5 minutos de respiração antes do treino.",
        "Registre a intensidade real do treino (sem maquiar).",
        "Caminhe 20 minutos ao ar livre.",
        "Faça 3 séries de prancha (20–40s).",
        "Compartilhe uma refeição alinhada ao seu plano.",
        "Convide alguém para um check-in rápido.",
    )
}

enum class PulseMediaKind(val raw: String) {
    Photo("photo"),
    Video("video"),
    WorkoutCard("workoutCard");

    companion object {
        fun fromRaw(value: String?): PulseMediaKind =
            entries.firstOrNull { it.raw == value } ?: Photo
    }
}

enum class PulseFollowStatus(val raw: String) {
    None("none"),
    Requested("requested"),
    Following("following"),
    Incoming("incoming");

    companion object {
        fun fromCloud(value: String?): PulseFollowStatus = when (value) {
            "accepted", "following" -> Following
            "pending", "requested" -> Requested
            else -> None
        }

        fun toCloud(status: PulseFollowStatus): String? = when (status) {
            Requested -> "pending"
            Following -> "accepted"
            else -> null
        }
    }
}

data class PulseWorkoutMeta(
    val modality: String? = null,
    val durationSeconds: Int? = null,
    val intensity: Int? = null,
    val duoTeamName: String? = null,
) {
    fun detailLine(): String = listOfNotNull(
        modality?.takeIf { it.isNotBlank() },
        durationSeconds?.takeIf { it > 0 }?.let { min ->
            val minutes = (min / 60).coerceAtLeast(if (min > 0) 1 else 0)
            if (minutes > 0) "$minutes min" else "${min}s"
        },
        intensity?.let { "Intensidade $it/10" },
        duoTeamName?.takeIf { it.isNotBlank() },
    ).joinToString(" · ")
}

data class PulseStoryTextOverlay(
    val id: String,
    val text: String,
    val fontStyle: String = "modern",
    val isBold: Boolean = true,
    val colorHex: String = "#FFFFFF",
    val x: Double = 0.5,
    val y: Double = 0.45,
    val scale: Double = 1.0,
)

data class PulseComment(
    val id: String,
    val authorId: String,
    val authorName: String,
    val text: String,
    val createdAtMillis: Long = System.currentTimeMillis(),
)

data class PulseReaction(
    val id: String,
    val userId: String,
    val userName: String,
    val kind: String,
    val createdAtMillis: Long = System.currentTimeMillis(),
) {
    val isHeart: Boolean get() = kind == "heart" || kind == "❤️" || kind == "💚"
}

data class PulsePost(
    val id: String,
    val authorId: String,
    val authorName: String,
    val authorCountryCode: String = "BR",
    val caption: String,
    val mediaKind: PulseMediaKind,
    val mediaFileName: String? = null,
    val remoteMediaURL: String? = null,
    val community: String = "musculacao",
    val workoutMeta: PulseWorkoutMeta? = null,
    val createdAtMillis: Long,
    val expiresAtMillis: Long,
    val isHidden: Boolean = false,
    val reportCount: Int = 0,
    val reactions: List<PulseReaction> = emptyList(),
    val comments: List<PulseComment> = emptyList(),
) {
    val isActive: Boolean get() = System.currentTimeMillis() < expiresAtMillis
    val heartCount: Int get() = reactions.count { it.isHeart }
    val engagementScore: Int get() = heartCount * 2 + comments.size

    fun communityTitle(): String = PulseLimits.communityTitle(community)

    fun hasHeartFrom(userId: String): Boolean =
        reactions.any { it.userId == userId && it.isHeart }
}

data class PulseStory(
    val id: String,
    val authorId: String,
    val authorName: String,
    val mediaFileName: String? = null,
    val remoteMediaURL: String? = null,
    val createdAtMillis: Long,
    val expiresAtMillis: Long,
    val textOverlays: List<PulseStoryTextOverlay> = emptyList(),
    val isViewed: Boolean = false,
) {
    val isActive: Boolean get() = System.currentTimeMillis() < expiresAtMillis
}

data class PulsePerson(
    val id: String,
    val displayName: String,
    val emailHint: String = "",
    val countryCode: String = "BR",
    val state: String = "",
    val city: String = "",
    val bio: String = "",
    val communityFocus: String = "musculacao",
    val notifyOnPosts: Boolean = true,
    val photoURL: String? = null,
) {
    val regionLabel: String
        get() = listOf(city, state).map { it.trim() }.filter { it.isNotEmpty() }.joinToString(", ")
}

data class PulseFollow(
    val id: String,
    val fromUserId: String,
    val toUserId: String,
    val status: PulseFollowStatus,
    val createdAtMillis: Long = System.currentTimeMillis(),
    val notifyPosts: Boolean = true,
    val fromName: String = "",
)
