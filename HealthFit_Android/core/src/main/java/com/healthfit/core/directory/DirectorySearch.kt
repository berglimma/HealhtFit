package com.healthfit.core.directory

import com.google.firebase.firestore.FirebaseFirestore
import com.healthfit.core.coach.AppConfigAndroid
import kotlinx.coroutines.tasks.await
import java.text.Normalizer

/**
 * Read-only search against the same Firestore collections iOS already uses.
 * Does not write, patch, or create documents — iOS production data stays untouched.
 *
 * - Pessoas e alunos: `userDirectory` (ProfileFirestoreService.searchUsers)
 * - Personal e nutricionista: `coachProfiles` where `isDirectoryVisible == true`
 */
object DirectorySearch {
    suspend fun searchPeople(
        query: String,
        excludingUid: String? = null,
        limit: Int = 25,
    ): List<DirectoryPerson> {
        val needle = searchable(query)
        if (needle.isEmpty()) return emptyList()
        val db = firestoreOrNull() ?: return emptyList()
        val snap = db.collection("userDirectory")
            .limit(300)
            .get()
            .await()
        val matches = snap.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            val uid = (data["uid"] as? String)?.takeIf { it.isNotBlank() } ?: doc.id
            if (excludingUid != null && uid == excludingUid) return@mapNotNull null
            val name = data["name"] as? String ?: ""
            val displayName = data["displayName"] as? String ?: ""
            val email = data["email"] as? String ?: ""
            val haystacks = listOf(
                name,
                displayName,
                email,
                data["nameLower"] as? String ?: "",
                data["displayNameLower"] as? String ?: "",
                data["emailLower"] as? String ?: "",
            ).map(::searchable)
            if (haystacks.none { it.contains(needle) }) return@mapNotNull null
            DirectoryPerson(
                uid = uid,
                name = name,
                displayName = displayName,
                email = email,
                countryCode = data["countryCode"] as? String,
                photoUrl = (data["photoURL"] as? String)?.takeIf { it.isNotBlank() },
                hasPersonalTrainer = data["hasPersonalTrainer"] as? Boolean ?: false,
            )
        }
        return matches
            .sortedBy { it.shownName.lowercase() }
            .take(limit)
    }

    suspend fun searchProfessionals(
        name: String,
        profession: ProfessionFilter,
        city: String = "",
        stateCode: String = "",
    ): List<DirectoryProfessional> {
        val db = firestoreOrNull() ?: return emptyList()
        val needle = name.trim()
        val limit = if (needle.isNotEmpty()) 120L else 80L
        val snap = db.collection("coachProfiles")
            .whereEqualTo("isDirectoryVisible", true)
            .limit(limit)
            .get()
            .await()
        val preferState = stateCode.trim().uppercase()
        val preferCity = city.trim()
        val nameNeedle = searchable(needle)
        return snap.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            val professions = professionNames(data["professions"])
            if (profession == ProfessionFilter.Personal && "personal" !in professions) return@mapNotNull null
            if (profession == ProfessionFilter.Nutritionist && "nutritionist" !in professions) return@mapNotNull null
            val displayName = data["displayName"] as? String ?: ""
            if (nameNeedle.isNotEmpty() && !searchable(displayName).contains(nameNeedle)) return@mapNotNull null
            DirectoryProfessional(
                uid = (data["uid"] as? String)?.takeIf { it.isNotBlank() } ?: doc.id,
                displayName = displayName,
                city = data["city"] as? String ?: "",
                stateCode = data["stateCode"] as? String ?: "",
                bio = data["bio"] as? String ?: "",
                photoUrl = (data["photoURL"] as? String)?.takeIf { it.isNotBlank() },
                professions = professions,
                cref = data["cref"] as? String,
                crn = data["crn"] as? String,
            )
        }.sortedWith(
            compareByDescending<DirectoryProfessional> {
                localityScore(it, preferState, preferCity)
            }.thenBy { it.displayName.lowercase() },
        )
    }

    private fun firestoreOrNull(): FirebaseFirestore? {
        if (!AppConfigAndroid.isFirebaseReady()) return null
        return runCatching { FirebaseFirestore.getInstance() }.getOrNull()
    }

    private fun professionNames(raw: Any?): Set<String> {
        val list = raw as? List<*> ?: return emptySet()
        return list.mapNotNull { item ->
            when (item) {
                is String -> item
                is Map<*, *> -> (item["rawValue"] as? String) ?: (item["_0"] as? String)
                else -> null
            }
        }.map { it.lowercase() }.toSet()
    }

    /** 3 = mesma cidade+UF, 2 = mesma UF ou cidade, 1 = sem local, 0 = outra região. */
    private fun localityScore(profile: DirectoryProfessional, preferState: String, preferCity: String): Int {
        if (preferState.isEmpty() && preferCity.isEmpty()) return 0
        val state = profile.stateCode.trim().uppercase()
        val city = profile.city.trim()
        val sameState = preferState.isNotEmpty() && state.isNotEmpty() && state == preferState
        val sameCity = preferCity.isNotEmpty() && city.isNotEmpty() &&
            searchable(city).contains(searchable(preferCity))
        if (sameState && sameCity) return 3
        if (sameState || sameCity) return 2
        if (state.isEmpty() && city.isEmpty()) return 1
        return 0
    }

    private fun searchable(text: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""
        val normalized = Normalizer.normalize(trimmed, Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")
        return normalized.lowercase()
    }
}

enum class ProfessionFilter {
    Personal,
    Nutritionist,
}

data class DirectoryPerson(
    val uid: String,
    val name: String,
    val displayName: String,
    val email: String,
    val countryCode: String?,
    val photoUrl: String?,
    val hasPersonalTrainer: Boolean,
) {
    val shownName: String
        get() = displayName.trim().ifEmpty { name.trim() }.ifEmpty { email.substringBefore("@") }
}

data class DirectoryProfessional(
    val uid: String,
    val displayName: String,
    val city: String,
    val stateCode: String,
    val bio: String,
    val photoUrl: String?,
    val professions: Set<String>,
    val cref: String?,
    val crn: String?,
) {
    val roleLabel: String
        get() = when {
            "personal" in professions && "nutritionist" in professions -> "Personal e nutricionista"
            "nutritionist" in professions -> "Nutricionista"
            else -> "Personal trainer"
        }

    val placeLabel: String
        get() = listOf(city.trim(), stateCode.trim()).filter { it.isNotEmpty() }.joinToString(" · ")
}
