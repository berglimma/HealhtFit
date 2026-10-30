package com.healthfit.core.auth

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.UserProfileChangeRequest
import com.healthfit.core.model.UserProfile
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

interface AuthRepository {
    val currentUser: Flow<UserProfile?>
    suspend fun signInWithEmail(email: String, password: String): Result<UserProfile>
    suspend fun signUpWithEmail(
        email: String,
        password: String,
        displayName: String = "",
    ): Result<UserProfile>
    suspend fun signInWithGoogleIdToken(idToken: String): Result<UserProfile>
    suspend fun sendPasswordReset(email: String): Result<Unit>
    fun signOut()

    /** Deletes the Firebase user and the same cloud documents iOS removes. Local wipe is the caller's job. */
    suspend fun deleteAccount(password: String?): Result<Unit>
}

class FirebaseAuthRepository(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
) : AuthRepository {

    override val currentUser: Flow<UserProfile?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser?.toProfile()) }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    override suspend fun signInWithEmail(email: String, password: String): Result<UserProfile> = runCatching {
        val result = auth.signInWithEmailAndPassword(email.trim(), password).await()
        result.user?.toProfile() ?: error("Usuário nulo após login")
    }

    override suspend fun signUpWithEmail(
        email: String,
        password: String,
        displayName: String,
    ): Result<UserProfile> = runCatching {
        val result = auth.createUserWithEmailAndPassword(email.trim(), password).await()
        val user = result.user ?: error("Usuário nulo após cadastro")
        val name = displayName.trim()
        if (name.isNotEmpty()) {
            user.updateProfile(
                UserProfileChangeRequest.Builder().setDisplayName(name).build(),
            ).await()
        }
        user.toProfile().copy(displayName = name.ifEmpty { user.displayName.orEmpty() })
    }

    override suspend fun signInWithGoogleIdToken(idToken: String): Result<UserProfile> = runCatching {
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        val result = auth.signInWithCredential(credential).await()
        result.user?.toProfile() ?: error("Usuário nulo após Google")
    }

    override suspend fun sendPasswordReset(email: String): Result<Unit> = runCatching {
        auth.sendPasswordResetEmail(email.trim()).await()
        Unit
    }

    override fun signOut() {
        auth.signOut()
    }

    override suspend fun deleteAccount(password: String?): Result<Unit> =
        AccountDeletion.deleteCurrentAccount(password)
}

private fun FirebaseUser.toProfile() = UserProfile(
    uid = uid,
    displayName = displayName.orEmpty(),
    email = email.orEmpty(),
)
