package com.healthfit.core.coach

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.healthfit.core.firebase.FirebaseProject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * READ-ONLY Coach graph against production Firestore (same paths as iOS).
 *
 * Flow: `users/{uid}/coachMemberships` → `coachLinks/{id}` →
 * `assignedWorkouts` (isActive) + `mealPlan/current`.
 *
 * Never writes. Invite accept / chat / publish stay behind [CoachCloudGates.WRITES_HARD_DISABLED].
 */
object CoachCloudRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _state = MutableStateFlow(CoachCloudState())
    val state: StateFlow<CoachCloudState> = _state.asStateFlow()

    private var sessionJob: Job? = null
    private val registrations = mutableListOf<ListenerRegistration>()
    private var startedForUid: String? = null

    fun start(uid: String) {
        if (uid.isBlank() || uid == "offline-local") {
            stop()
            _state.value = CoachCloudState(
                firebaseReady = AppConfigAndroid.isFirebaseReady(),
                statusMessage = "Entre com a mesma conta do iOS para ver vínculos Coach.",
            )
            return
        }
        if (startedForUid == uid && sessionJob?.isActive == true) return
        stop()
        startedForUid = uid
        sessionJob = scope.launch {
            val firebaseReady = AppConfigAndroid.isFirebaseReady()
            if (!firebaseReady) {
                _state.value = CoachCloudState(
                    firebaseReady = false,
                    uid = uid,
                    statusMessage = "Firebase não configurado (google-services.json).",
                )
                return@launch
            }
            val config = AppConfigAndroid.fetch()
            val readEnabled = config.coachCloudReadEnabled
            val writeEnabled = CoachCloudGates.effectiveWriteEnabled(config.coachCloudWriteEnabled)
            _state.value = CoachCloudState(
                firebaseReady = true,
                readEnabled = readEnabled,
                writeEnabled = writeEnabled,
                uid = uid,
                statusMessage = if (!readEnabled) {
                    "Leitura Coach desligada em appConfig/android."
                } else {
                    "Sincronizando vínculos…"
                },
            )
            if (!readEnabled) return@launch
            attachMembershipListener(uid)
        }
    }

    fun stop() {
        sessionJob?.cancel()
        sessionJob = null
        startedForUid = null
        clearListeners()
        _state.value = CoachCloudState()
    }

    private fun clearListeners() {
        registrations.forEach { runCatching { it.remove() } }
        registrations.clear()
    }

    private fun attachMembershipListener(uid: String) {
        val db = FirebaseFirestore.getInstance()
        val reg = db.collection(FirebaseProject.coachMemberships(uid))
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    _state.update {
                        it.copy(statusMessage = "Sem permissão ou rede para Coach (${error.code}).")
                    }
                    return@addSnapshotListener
                }
                val linkIds = snap?.documents?.map { it.id }.orEmpty()
                if (linkIds.isEmpty()) {
                    clearChildListenersKeepMembership()
                    _state.update {
                        it.copy(
                            links = emptyList(),
                            assignedByLink = emptyMap(),
                            mealPlanByLink = emptyMap(),
                            statusMessage = "Nenhum vínculo Coach na nuvem.",
                        )
                    }
                    return@addSnapshotListener
                }
                replaceLinkListeners(linkIds)
            }
        registrations += reg
    }

    /** Remove link/assignment/meal listeners but keep the membership registration (index 0). */
    private fun clearChildListenersKeepMembership() {
        if (registrations.size <= 1) return
        registrations.drop(1).forEach { runCatching { it.remove() } }
        while (registrations.size > 1) registrations.removeAt(registrations.lastIndex)
    }

    private fun replaceLinkListeners(linkIds: List<String>) {
        clearChildListenersKeepMembership()
        val db = FirebaseFirestore.getInstance()
        linkIds.forEach { linkId ->
            registrations += db.document(FirebaseProject.coachLink(linkId))
                .addSnapshotListener { snap, _ ->
                    val data = snap?.data
                    val parsed = data?.let { parseLink(linkId, it) }
                    _state.update { current ->
                        val without = current.links.filterNot { it.id == linkId }
                        val links = if (parsed != null) {
                            (without + parsed).sortedBy { it.coachName.lowercase() }
                        } else {
                            without
                        }
                        current.copy(
                            links = links,
                            statusMessage = null,
                        )
                    }
                }
            registrations += db.collection(FirebaseProject.assignedWorkouts(linkId))
                .whereEqualTo("isActive", true)
                .addSnapshotListener { snap, _ ->
                    val items = snap?.documents.orEmpty().mapNotNull { doc ->
                        parseAssigned(doc.id, doc.data.orEmpty())
                    }
                    _state.update { current ->
                        current.copy(
                            assignedByLink = current.assignedByLink + (linkId to items),
                        )
                    }
                }
            registrations += db.document(FirebaseProject.mealPlanCurrent(linkId))
                .addSnapshotListener { snap, _ ->
                    val data = snap?.data
                    val plan = if (data == null) {
                        null
                    } else {
                        CoachMealPlanSnapshot(
                            linkId = linkId,
                            coachUid = data["coachUid"] as? String,
                            coachName = data["coachName"] as? String,
                            hasWeeklyPlan = data["weeklyPlan"] != null,
                        )
                    }
                    _state.update { current ->
                        val map = current.mealPlanByLink.toMutableMap()
                        if (plan == null) map.remove(linkId) else map[linkId] = plan
                        current.copy(mealPlanByLink = map)
                    }
                }
        }
    }

    private fun parseLink(id: String, data: Map<String, Any>): CoachLinkSnapshot? {
        val coachUid = data["coachUid"] as? String ?: return null
        val studentUid = data["studentUid"] as? String ?: return null
        val profession = data["profession"] as? String ?: return null
        val status = data["status"] as? String ?: return null
        @Suppress("UNCHECKED_CAST")
        val members = (data["memberUids"] as? List<*>)?.mapNotNull { it as? String }.orEmpty()
        return CoachLinkSnapshot(
            id = id,
            coachUid = coachUid,
            coachName = data["coachName"] as? String ?: "Profissional",
            coachPhotoURL = data["coachPhotoURL"] as? String,
            studentUid = studentUid,
            studentName = data["studentName"] as? String ?: "Aluno",
            studentPhotoURL = data["studentPhotoURL"] as? String,
            profession = profession,
            status = status,
            memberUids = members,
        )
    }

    private fun parseAssigned(id: String, data: Map<String, Any>): CoachAssignedWorkoutSnapshot? {
        val linkId = data["linkId"] as? String ?: return null
        val coachUid = data["coachUid"] as? String ?: return null
        val studentUid = data["studentUid"] as? String ?: return null
        @Suppress("UNCHECKED_CAST")
        val sheet = data["sheet"] as? Map<String, Any>
        val title = (sheet?.get("title") as? String)
            ?: (data["title"] as? String)
            ?: "Ficha prescrita"
        return CoachAssignedWorkoutSnapshot(
            id = id,
            linkId = linkId,
            coachUid = coachUid,
            coachName = data["coachName"] as? String ?: "Personal",
            studentUid = studentUid,
            sheetTitle = title,
            isActive = data["isActive"] as? Boolean ?: true,
        )
    }
}
