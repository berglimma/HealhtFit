package com.healthfit.core.auth

import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.CollectionReference
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import com.healthfit.core.coach.AppConfigAndroid
import kotlinx.coroutines.tasks.await

/**
 * Same deletion order as iOS `AuthService.deleteRemoteData`: the signed-in user's
 * own documents only. Does not deploy rules or change documents other clients own,
 * except the Pulse follows/blocks and Duo invites that iOS already removes for this uid.
 */
object AccountDeletion {
    suspend fun deleteCurrentAccount(password: String?): Result<Unit> = runCatching {
        if (!AppConfigAndroid.isFirebaseReady()) {
            error("Firebase não está configurado neste aparelho.")
        }
        val auth = FirebaseAuth.getInstance()
        val user = auth.currentUser ?: error("Nenhuma conta ativa encontrada.")
        val uid = user.uid
        val email = user.email.orEmpty()
        val usesPassword = user.providerData.any { it.providerId == EmailAuthProvider.PROVIDER_ID }
        if (usesPassword) {
            if (password.isNullOrBlank() || email.isBlank()) {
                error("Digite a senha da conta para confirmar a exclusão.")
            }
            val credential = EmailAuthProvider.getCredential(email, password)
            user.reauthenticate(credential).await()
        }
        deleteRemoteData(uid)
        user.delete().await()
    }

    private suspend fun deleteRemoteData(uid: String) {
        val db = FirebaseFirestore.getInstance()
        val user = db.collection("users").document(uid)
        val subcollections = listOf(
            "bodyEvolutionEvaluations",
            "bodyEvolutionMeta",
            "dailyWellness",
            "wellnessMeta",
            "mealPlan",
            "mealPhotoAnalyses",
            "workoutSessions",
            "workoutSheets",
            "duoMemberships",
            "duoPendingInvites",
            "duoNotifications",
            "duoReadCursors",
            "settings",
            "bikeMeta",
            "climbingGear",
            "activeWorkout",
            "coachMemberships",
            "coachInterestMessages",
            "fcmTokens",
        )
        for (name in subcollections) {
            deleteCollection(user.collection(name))
        }
        deleteWhere(db.collection("duoInvites"), "fromUid", uid)
        deleteWhere(db.collection("pulsePosts"), "authorId", uid)
        deleteWhere(db.collection("pulseStories"), "authorId", uid)
        deleteWhere(db.collection("pulseFollows"), "fromUserId", uid)
        deleteWhere(db.collection("pulseFollows"), "toUserId", uid)
        deleteWhere(db.collection("pulseBlocks"), "blockerId", uid)
        runCatching { db.collection("pulseProfiles").document(uid).delete().await() }
        runCatching { db.collection("userDirectory").document(uid).delete().await() }
        runCatching { db.collection("coachProfiles").document(uid).delete().await() }
        runCatching { user.delete().await() }
        val storage = FirebaseStorage.getInstance().reference
        runCatching { storage.child("users/$uid/profile/avatar.jpg").delete().await() }
        runCatching { storage.child("users/$uid/profile/background.jpg").delete().await() }
    }

    private suspend fun deleteCollection(collection: CollectionReference) {
        runCatching {
            val snap = collection.limit(200).get().await()
            for (doc in snap.documents) {
                runCatching { doc.reference.delete().await() }
            }
        }
    }

    private suspend fun deleteWhere(
        collection: CollectionReference,
        field: String,
        uid: String,
    ) {
        runCatching {
            val snap = collection.whereEqualTo(field, uid).limit(80).get().await()
            for (doc in snap.documents) {
                runCatching { doc.reference.delete().await() }
            }
        }
    }
}
