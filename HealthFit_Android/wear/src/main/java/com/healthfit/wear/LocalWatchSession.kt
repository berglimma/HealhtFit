package com.healthfit.wear

import android.content.Context
import com.healthfit.core.workout.WorkoutWearContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class SessionKind { Strength, Cardio, Meditation }

data class ActiveSession(
    val kind: SessionKind,
    val title: String = "",
    val exerciseName: String = "",
    val isPaused: Boolean = false,
    val isResting: Boolean = false,
    val sessionStartEpoch: Long = 0L,
    val exerciseStartEpoch: Long = 0L,
    val pauseAccumulatedMs: Long = 0L,
    val pauseStartEpoch: Long = 0L,
    val restEndEpoch: Long = 0L,
    val targetSeconds: Int = 0,
    val heartRate: Int = 0,
    val calories: Double = 0.0,
    // meditação
    val meditationTopicName: String = "",
    val meditationColorName: String = "",
    val meditationPrompts: List<String> = emptyList(),
    val meditationPromptIndex: Int = 0,
    // cardio / água
    val isWaterSport: Boolean = false,
    val isKitesurf: Boolean = false,
    val isSwimming: Boolean = false,
    val waterSetupMode: String = "",
    val waterSetupBoard: String = "",
    val jumpCount: Int = 0,
    val maxJumpM: Double = 0.0,
    val lastJumpM: Double = 0.0,
    val liveAccelG: Double = 0.0,
    val relativeAltM: Double = 0.0,
    val gpsPointCount: Int = 0,
    val swimLaps: Int = 0,
    val poolLengthM: Int = 25,
    val usesSegmentedChronometer: Boolean = false,
    val cardioTargetCalories: Int = 0,
    val distanceMeters: Double = 0.0,
    val paceOrSpeedLabel: String = "",
    val waterSensorStatus: String = "",
    val syncStatus: String = "",
    val ejectionStatus: String = "",
    val climbingAutoDetect: Boolean = false,
    val climbingStatus: String = "",
    val phoneReachable: Boolean = false,
    /** true quando a sessão veio do celular (somente leitura no relógio). */
    val fromPhone: Boolean = false,
    val phoneSets: String = "",
) {
    private fun effectiveNow(now: Long): Long = if (isPaused && pauseStartEpoch > 0L) pauseStartEpoch else now

    /** Tempo total ativo da sessão (sem pausas). */
    fun elapsedMs(now: Long = System.currentTimeMillis()): Long =
        (effectiveNow(now) - sessionStartEpoch - pauseAccumulatedMs).coerceAtLeast(0L)

    fun elapsedSeconds(now: Long = System.currentTimeMillis()): Int = (elapsedMs(now) / 1000L).toInt()

    /** Tempo do exercício atual (força). */
    fun exerciseElapsedSeconds(now: Long = System.currentTimeMillis()): Int {
        val base = if (exerciseStartEpoch > 0L) exerciseStartEpoch else sessionStartEpoch
        val pauses = if (base == sessionStartEpoch) pauseAccumulatedMs else 0L
        return ((effectiveNow(now) - base - pauses).coerceAtLeast(0L) / 1000L).toInt()
    }

    fun restRemainingSeconds(now: Long = System.currentTimeMillis()): Int =
        if (!isResting) 0 else ((restEndEpoch - effectiveNow(now)).coerceAtLeast(0L) / 1000L).toInt()

    fun remainingSeconds(now: Long = System.currentTimeMillis()): Int =
        if (targetSeconds <= 0) 0 else (targetSeconds - elapsedSeconds(now)).coerceAtLeast(0)

    /** Progresso 0..1 contra a meta (tempo ou kcal); sem meta usa segmento de 60 s. */
    fun progress(now: Long = System.currentTimeMillis()): Float = when {
        targetSeconds > 0 -> (elapsedSeconds(now).toFloat() / targetSeconds).coerceIn(0f, 1f)
        cardioTargetCalories > 0 -> (calories.toFloat() / cardioTargetCalories).coerceIn(0f, 1f)
        else -> ((elapsedMs(now) % 60_000L) / 60_000f)
    }

    val meditationTotalPrompts: Int get() = meditationPrompts.size
    val currentPrompt: String get() = meditationPrompts.getOrNull(meditationPromptIndex).orEmpty()
}

fun formatDuration(seconds: Int): String {
    val total = seconds.coerceAtLeast(0)
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
}

/**
 * Estado da sessão exibida no relógio. Sessões locais (modo solo) têm prioridade
 * sobre a sessão enviada pelo celular via [WorkoutWearSession].
 */
object LocalWatchSession {
    private val _state = MutableStateFlow<ActiveSession?>(null)
    val state: StateFlow<ActiveSession?> = _state

    private val _climbingAutoDetect = MutableStateFlow(false)
    val climbingAutoDetect: StateFlow<Boolean> = _climbingAutoDetect

    private val _climbingStatus = MutableStateFlow("")
    val climbingStatus: StateFlow<String> = _climbingStatus

    private val _phoneReachable = MutableStateFlow(false)
    val phoneReachable: StateFlow<Boolean> = _phoneReachable

    private val _ejectionStatus = MutableStateFlow("")
    val ejectionStatus: StateFlow<String> = _ejectionStatus

    private val _isEjecting = MutableStateFlow(false)
    val isEjecting: StateFlow<Boolean> = _isEjecting

    private var local: ActiveSession? = null
    private var phone: ActiveSession? = null
    private var appContext: Context? = null
    private var climbingDetector: ClimbingDetector? = null

    val isLocalActive: Boolean get() = local != null

    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        _climbingAutoDetect.value = prefs.getBoolean(KEY_CLIMB, false)
        climbingDetector = ClimbingDetector(
            context = context.applicationContext,
            onStatus = { _climbingStatus.value = it; publish() },
            onDetected = { autoStartClimbing() },
        )
        if (_climbingAutoDetect.value) climbingDetector?.start()
        WatchPhoneSync.start(context.applicationContext)
        refreshPhoneReachable()
    }

    // region begin / stop

    fun beginStrength(program: WatchCatalog.StrengthProgram) {
        val now = System.currentTimeMillis()
        startLocal(
            ActiveSession(
                kind = SessionKind.Strength,
                title = program.title,
                exerciseName = program.firstExercise,
                sessionStartEpoch = now,
                exerciseStartEpoch = now,
                syncStatus = "Watch · batimentos ativos",
            ),
        )
    }

    fun beginCardio(
        activity: WatchCatalog.CardioActivity,
        targetSeconds: Int = 0,
        setupModeName: String = "",
        setupBoardName: String = "",
        targetCalories: Int = 0,
    ) {
        val now = System.currentTimeMillis()
        startLocal(
            ActiveSession(
                kind = SessionKind.Cardio,
                title = activity.name,
                exerciseName = activity.name,
                sessionStartEpoch = now,
                exerciseStartEpoch = now,
                targetSeconds = targetSeconds,
                cardioTargetCalories = targetCalories,
                isWaterSport = activity.isWaterSport,
                isKitesurf = activity.isKitesurf,
                isSwimming = activity.isSwimming,
                waterSetupMode = setupModeName,
                waterSetupBoard = setupBoardName,
                usesSegmentedChronometer = !activity.isWaterSport && !activity.isSwimming,
                waterSensorStatus = if (activity.isWaterSport) "Giroscópio + acelerômetro + altímetro" else "",
                syncStatus = when {
                    activity.isSwimming -> "Natação · voltas automáticas"
                    activity.isWaterSport -> "Cronômetro · GPS ativo"
                    else -> "Watch · batimentos ativos"
                },
            ),
        )
    }

    fun beginMeditation(topic: WatchCatalog.MeditationTopic, targetSeconds: Int) {
        val now = System.currentTimeMillis()
        startLocal(
            ActiveSession(
                kind = SessionKind.Meditation,
                title = topic.name,
                exerciseName = topic.name,
                sessionStartEpoch = now,
                exerciseStartEpoch = now,
                targetSeconds = targetSeconds,
                meditationTopicName = topic.name,
                meditationColorName = topic.colorName,
                meditationPrompts = topic.prompts,
                meditationPromptIndex = 0,
            ),
        )
    }

    private fun startLocal(session: ActiveSession) {
        if (local != null) return
        climbingDetector?.stop()
        _climbingStatus.value = ""
        local = session.copy(syncStatus = "Sincronizando…")
        publish()
        appContext?.let {
            WatchSensorHub.start(it, session)
            WatchPhoneSync.publishSession(local)
        }
        refreshPhoneReachable()
        local = local?.copy(
            syncStatus = if (_phoneReachable.value) "Celular sincronizado" else "Modo solo — bridge/celular",
        )
        publish()
        WatchPhoneSync.publishSession(local)
    }

    private fun autoStartClimbing() {
        val activity = WatchCatalog.cardio("climb") ?: return
        if (local != null) return
        beginCardio(activity)
        _climbingStatus.value = "Sessão de escalada iniciada automaticamente"
        publish()
    }

    fun togglePause(fromRemote: Boolean = false) {
        val phoneSession = if (local == null) phone else null
        if (phoneSession != null) {
            // Control the phone-owned workout from the watch.
            WatchPhoneSync.sendControl(
                if (phoneSession.isPaused) WorkoutWearContract.ACTION_RESUME
                else WorkoutWearContract.ACTION_PAUSE,
            )
            phone = phoneSession.copy(
                isPaused = !phoneSession.isPaused,
                syncStatus = if (phoneSession.isPaused) "Em andamento" else "Pausado",
            )
            publish()
            return
        }
        val s = local ?: return
        val now = System.currentTimeMillis()
        local = if (s.isPaused) {
            val paused = (now - s.pauseStartEpoch).coerceAtLeast(0L)
            s.copy(
                isPaused = false,
                pauseStartEpoch = 0L,
                pauseAccumulatedMs = s.pauseAccumulatedMs + paused,
                restEndEpoch = if (s.isResting) s.restEndEpoch + paused else s.restEndEpoch,
                syncStatus = "Em andamento",
            )
        } else {
            s.copy(isPaused = true, pauseStartEpoch = now, syncStatus = "Pausado")
        }
        WatchSensorHub.setPaused(local?.isPaused == true)
        publish()
        if (!fromRemote) {
            WatchPhoneSync.publishSession(local)
            WatchPhoneSync.sendControl(
                if (local?.isPaused == true) WorkoutWearContract.ACTION_PAUSE
                else WorkoutWearContract.ACTION_RESUME,
            )
        }
    }

    fun stop(fromRemote: Boolean = false) {
        if (local == null && phone != null) {
            if (!fromRemote) WatchPhoneSync.sendControl(WorkoutWearContract.ACTION_STOP)
            phone = null
            publish()
            return
        }
        if (local == null) return
        local = null
        WatchSensorHub.stop()
        publish()
        if (!fromRemote) {
            WatchPhoneSync.publishSession(null)
            WatchPhoneSync.sendControl(WorkoutWearContract.ACTION_STOP)
        }
        if (_climbingAutoDetect.value) climbingDetector?.start()
    }

    // endregion

    // region strength rest / water / swim

    fun startRest(seconds: Int = 90) {
        val s = local ?: return
        if (s.kind != SessionKind.Strength || s.isPaused) return
        local = s.copy(isResting = true, restEndEpoch = System.currentTimeMillis() + seconds * 1000L)
        publish()
    }

    fun endRest() {
        val s = local ?: return
        local = s.copy(isResting = false, restEndEpoch = 0L, exerciseStartEpoch = System.currentTimeMillis())
        publish()
    }

    fun markJump(heightM: Double = 0.0, auto: Boolean = false) {
        val s = local ?: return
        if (!s.isWaterSport || s.isPaused) return
        val h = if (heightM > 0.0) heightM else s.lastJumpM
        local = s.copy(
            jumpCount = s.jumpCount + 1,
            lastJumpM = h,
            maxJumpM = maxOf(s.maxJumpM, h),
            syncStatus = if (auto) "Salto detectado" else "Salto marcado",
        )
        publish()
    }

    fun addSwimLap() {
        val s = local ?: return
        if (!s.isSwimming || s.isPaused) return
        val laps = s.swimLaps + 1
        local = s.copy(swimLaps = laps, distanceMeters = laps * s.poolLengthM.toDouble(), syncStatus = "Voltas enviadas")
        publish()
    }

    /** Atualizações vindas dos sensores (HR, kcal, g, altitude, GPS). */
    fun updateMetrics(transform: (ActiveSession) -> ActiveSession) {
        val s = local ?: return
        local = transform(s)
        publish()
    }

    fun requestPhoneSync() {
        val s = local ?: return
        refreshPhoneReachable()
        local = s.copy(
            syncStatus = if (_phoneReachable.value) "iPhone sincronizado" else "Sem celular — dados ficam no relógio",
        )
        publish()
    }

    /** Chamado a cada segundo pela UI: avança passos de meditação, descanso e metas. */
    fun tick(now: Long = System.currentTimeMillis()) {
        val s = local ?: return
        if (s.isPaused) return
        var next = s
        when (s.kind) {
            SessionKind.Meditation -> {
                if (s.targetSeconds > 0 && s.meditationPrompts.isNotEmpty()) {
                    val step = s.targetSeconds.toDouble() / s.meditationPrompts.size
                    val idx = (s.elapsedSeconds(now) / step).toInt().coerceIn(0, s.meditationPrompts.lastIndex)
                    if (idx != s.meditationPromptIndex) next = next.copy(meditationPromptIndex = idx)
                }
                if (s.targetSeconds > 0 && s.elapsedSeconds(now) >= s.targetSeconds) {
                    stop()
                    return
                }
            }
            SessionKind.Strength -> {
                // descanso acabou: mantém isResting até o usuário confirmar; UI mostra "Hora de voltar!"
            }
            SessionKind.Cardio -> {
                if (s.targetSeconds > 0 && s.elapsedSeconds(now) >= s.targetSeconds &&
                    !s.syncStatus.startsWith("Meta")
                ) {
                    next = next.copy(syncStatus = "Meta ok! Toque Encerrar p/ finalizar")
                }
            }
        }
        if (next !== s) {
            local = next
            publish()
        }
    }

    // endregion

    // region climbing

    fun setClimbingAutoDetect(enabled: Boolean) {
        _climbingAutoDetect.value = enabled
        appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)?.edit()?.putBoolean(KEY_CLIMB, enabled)?.apply()
        if (enabled && local == null) {
            climbingDetector?.start()
        } else {
            climbingDetector?.stop()
            _climbingStatus.value = ""
        }
        publish()
    }

    // endregion

    // region ejection

    fun ejectWater() {
        val ctx = appContext ?: return
        if (_isEjecting.value) return
        _isEjecting.value = true
        WaterEjection.play(
            context = ctx,
            onStatus = { setEjectionStatus(it) },
            onFinished = {
                _isEjecting.value = false
                setEjectionStatus("Água ejetada")
                local?.let { local = it.copy(syncStatus = "Água ejetada do speaker") }
                publish()
            },
        )
    }

    private fun setEjectionStatus(text: String) {
        _ejectionStatus.value = text
        publish()
    }

    // endregion

    // region phone

    fun refreshPhoneReachable() {
        val ctx = appContext ?: return
        com.google.android.gms.wearable.Wearable.getNodeClient(ctx).connectedNodes
            .addOnSuccessListener { nodes ->
                _phoneReachable.value = nodes.isNotEmpty()
                publish()
            }
            .addOnFailureListener {
                _phoneReachable.value = false
                publish()
            }
    }

    /** Mapeia a sessão ativa enviada pelo celular para [ActiveSession]. */
    fun applyPhoneWorkout(workout: WearWorkout?) {
        phone = workout?.let {
            val now = System.currentTimeMillis()
            val start = if (it.timerStartEpoch > 0L) it.timerStartEpoch else now - it.elapsedSeconds * 1000L
            ActiveSession(
                kind = SessionKind.Strength,
                title = it.title,
                exerciseName = it.exercise,
                isPaused = it.paused,
                isResting = it.resting && !it.paused,
                sessionStartEpoch = start,
                exerciseStartEpoch = start,
                restEndEpoch = it.restEndEpoch,
                fromPhone = true,
                phoneSets = it.sets,
                syncStatus = if (it.paused) "Pausado no celular" else "Celular sincronizado",
            )
        }
        publish()
    }

    // endregion

    private fun publish() {
        val base = local ?: phone
        _state.value = base?.copy(
            climbingAutoDetect = _climbingAutoDetect.value,
            climbingStatus = _climbingStatus.value,
            phoneReachable = _phoneReachable.value,
            ejectionStatus = _ejectionStatus.value,
        )
    }

    private const val PREFS = "healthfit_wear"
    private const val KEY_CLIMB = "healthfit.watch.climbingAutoDetect"
}
