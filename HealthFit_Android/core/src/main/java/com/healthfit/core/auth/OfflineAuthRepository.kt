package com.healthfit.core.auth

import com.healthfit.core.model.UserProfile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Used when `google-services.json` is absent (fresh clone / CI).
 * Lets the UI shell run without touching Firebase.
 */
class OfflineAuthRepository : AuthRepository {
    private val user = MutableStateFlow<UserProfile?>(
        UserProfile(
            uid = "offline-local",
            displayName = "Berg Limma",
            email = "berg@healthfit.app",
        ),
    )
    override val currentUser: Flow<UserProfile?> = user.asStateFlow()

    override suspend fun signInWithEmail(email: String, password: String): Result<UserProfile> {
        val profile = UserProfile(
            uid = "offline-local",
            displayName = email.substringBefore('@'),
            email = email.trim(),
        )
        user.value = profile
        return Result.success(profile)
    }

    override suspend fun signUpWithEmail(email: String, password: String): Result<UserProfile> =
        signInWithEmail(email, password)

    override fun signOut() {
        user.value = null
    }
}
