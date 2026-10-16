package com.healthfit.android.ui.kite

import android.content.Context
import android.location.Location
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

object KiteSpotBuddyPreferences {
    private const val PREFS = "kite_spot_buddy"
    private const val CONSENT = "consent_v1"
    private const val ENABLED = "enabled_next"

    fun hasConsent(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(CONSENT, false)

    fun grantConsent(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(CONSENT, true).apply()
    }

    fun isEnabledForNextSession(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ENABLED, false)

    fun setEnabledForNextSession(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ENABLED, enabled).apply()
    }
}

object KiteSpotBuddyPrivacy {
    const val shortLabel = "Compartilhar posição na sessão com amigos da equipe (somente kitesurf)."
    val clearNotice = """
O Kite Spot Buddy compartilha sua posição aproximada apenas durante uma sessão ativa de kitesurf, e somente com amigos da sua equipe que também estiverem com o recurso ativo na mesma sessão.

• Não substitui o Duo: o chat e ranking de equipe continuam sem mapa em tempo real.
• Você pode desativar a qualquer momento ou encerrar a sessão para apagar sua posição.
• Dados compartilhados: nome, foto (se houver), distância e direção aproximadas.
• Alarme de ajuda: avisa colegas próximos; confirme antes de enviar e use “Estou bem” para cancelar.
""".trimIndent()
}

data class KiteSpotBuddyPeer(
    val uid: String,
    val displayName: String,
    val photoURL: String? = null,
    val latitude: Double,
    val longitude: Double,
    val distanceMeters: Double,
    val bearingDegrees: Double?,
    val needsHelp: Boolean,
)

object KiteSpotBuddyGeo {
    val maxRadarMeters = 2_000.0

    fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val result = FloatArray(1)
        Location.distanceBetween(lat1, lon1, lat2, lon2, result)
        return result[0].toDouble()
    }

    fun bearingDegrees(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val φ1 = Math.toRadians(lat1)
        val φ2 = Math.toRadians(lat2)
        val Δλ = Math.toRadians(lon2 - lon1)
        val y = sin(Δλ) * cos(φ2)
        val x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        val deg = Math.toDegrees(atan2(y, x))
        return (deg + 360.0) % 360.0
    }
}

/**
 * Presence + peer radar for Kite Spot Buddy (Firestore `kiteSpotPresence`, same as iOS).
 */
class KiteSpotBuddyService {
    private val scope = CoroutineScope(Dispatchers.Main.immediate + Job())
    private var listener: ListenerRegistration? = null
    private var heartbeat: Job? = null
    private var sessionId: String? = null
    private var displayName: String = "Kiter"
    private var myLat: Double? = null
    private var myLon: Double? = null

    private val _peers = MutableStateFlow<List<KiteSpotBuddyPeer>>(emptyList())
    val peers: StateFlow<List<KiteSpotBuddyPeer>> = _peers.asStateFlow()

    private val _needsHelp = MutableStateFlow(false)
    val needsHelp: StateFlow<Boolean> = _needsHelp.asStateFlow()

    private val _incomingHelp = MutableStateFlow<KiteSpotBuddyPeer?>(null)
    val incomingHelp: StateFlow<KiteSpotBuddyPeer?> = _incomingHelp.asStateFlow()

    private val _active = MutableStateFlow(false)
    val active: StateFlow<Boolean> = _active.asStateFlow()

    fun start(sessionId: String, displayName: String) {
        stop()
        if (!firebaseAvailable()) return
        this.sessionId = sessionId
        this.displayName = displayName
        _active.value = true
        _needsHelp.value = false
        listen()
        heartbeat = scope.launch {
            while (isActive && _active.value) {
                upsert()
                delay(20_000)
            }
        }
    }

    fun updateLocation(latitude: Double, longitude: Double) {
        myLat = latitude
        myLon = longitude
        recomputePeers(lastDocs)
    }

    fun requestHelp() {
        _needsHelp.value = true
        scope.launch { upsert(forceHelp = true) }
    }

    fun cancelHelp() {
        _needsHelp.value = false
        scope.launch { upsert(forceHelp = true) }
    }

    fun dismissIncomingHelp() {
        _incomingHelp.value = null
    }

    fun stop() {
        heartbeat?.cancel()
        heartbeat = null
        listener?.remove()
        listener = null
        if (firebaseAvailable()) {
            val uid = runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull()
            if (uid != null) {
                scope.launch {
                    runCatching {
                        withContext(Dispatchers.IO) {
                            FirebaseFirestore.getInstance().collection(COLLECTION).document(uid).delete().await()
                        }
                    }
                }
            }
        }
        _active.value = false
        _peers.value = emptyList()
        _needsHelp.value = false
        _incomingHelp.value = null
        sessionId = null
        lastDocs = emptyList()
    }

    private var lastDocs: List<Map<String, Any?>> = emptyList()

    private fun listen() {
        if (!firebaseAvailable()) return
        runCatching {
            listener = FirebaseFirestore.getInstance()
                .collection(COLLECTION)
                .whereEqualTo("visible", true)
                .addSnapshotListener { snap, _ ->
                    val docs = snap?.documents?.map { it.data.orEmpty() + ("uid" to (it.getString("uid") ?: it.id)) }
                        ?: emptyList()
                    lastDocs = docs
                    recomputePeers(docs)
                }
        }
    }

    private fun recomputePeers(docs: List<Map<String, Any?>>) {
        val me = runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull()
        val lat = myLat
        val lon = myLon
        if (lat == null || lon == null) {
            _peers.value = emptyList()
            return
        }
        val now = System.currentTimeMillis()
        val list = docs.mapNotNull { data ->
            val uid = data["uid"] as? String ?: return@mapNotNull null
            if (uid == me) return@mapNotNull null
            val expires = (data["expiresAt"] as? com.google.firebase.Timestamp)?.toDate()?.time ?: Long.MAX_VALUE
            if (expires < now) return@mapNotNull null
            val pLat = (data["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val pLon = (data["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val dist = KiteSpotBuddyGeo.distanceMeters(lat, lon, pLat, pLon)
            if (dist > KiteSpotBuddyGeo.maxRadarMeters) return@mapNotNull null
            KiteSpotBuddyPeer(
                uid = uid,
                displayName = (data["displayName"] as? String)?.ifBlank { "Amigo" } ?: "Amigo",
                photoURL = data["photoURL"] as? String,
                latitude = pLat,
                longitude = pLon,
                distanceMeters = dist,
                bearingDegrees = KiteSpotBuddyGeo.bearingDegrees(lat, lon, pLat, pLon),
                needsHelp = data["needsHelp"] as? Boolean ?: false,
            )
        }.sortedBy { it.distanceMeters }
        _peers.value = list
        val help = list.firstOrNull { it.needsHelp }
        if (help != null && _incomingHelp.value?.uid != help.uid) {
            _incomingHelp.value = help
        }
    }

    private suspend fun upsert(forceHelp: Boolean = false) {
        if (!firebaseAvailable()) return
        val uid = runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull() ?: return
        val lat = myLat ?: return
        val lon = myLon ?: return
        val sid = sessionId ?: return
        val help = _needsHelp.value
        runCatching {
            withContext(Dispatchers.IO) {
                val expires = com.google.firebase.Timestamp(
                    java.util.Date(System.currentTimeMillis() + 30 * 60_000L),
                )
                val payload = hashMapOf<String, Any>(
                    "uid" to uid,
                    "displayName" to displayName.take(80),
                    "latitude" to lat,
                    "longitude" to lon,
                    "sessionId" to sid,
                    "visible" to true,
                    "isKitesurf" to true,
                    "needsHelp" to help,
                    "updatedAt" to FieldValue.serverTimestamp(),
                    "expiresAt" to expires,
                )
                if (help || forceHelp) {
                    if (help) payload["helpRequestedAt"] = FieldValue.serverTimestamp()
                }
                FirebaseFirestore.getInstance().collection(COLLECTION).document(uid)
                    .set(payload, SetOptions.merge())
                    .await()
            }
        }
    }

    companion object {
        private const val COLLECTION = "kiteSpotPresence"
        val shared = KiteSpotBuddyService()

        fun firebaseAvailable(): Boolean =
            runCatching { FirebaseApp.getInstance() }.isSuccess
    }
}
