package com.healthfit.android.workout

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.healthfit.core.workout.WorkoutWearContract
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

enum class WearRemoteAction {
    Pause,
    Resume,
    Stop,
}

/** Mirror of a workout that started on the watch. */
data class WatchOwnedWorkout(
    val title: String,
    val exercise: String,
    val kind: String,
    val paused: Boolean,
    val elapsedSeconds: Int,
    val sets: String,
)

/**
 * Bidirectional workout sync hub on the phone.
 * Wearable Data/Message Layer when paired; TCP bridge for emulators.
 */
object PhoneWorkoutSync {
    private const val TAG = "PhoneWorkoutSync"

    private val _remoteActions = MutableSharedFlow<WearRemoteAction>(extraBufferCapacity = 8)
    val remoteActions: SharedFlow<WearRemoteAction> = _remoteActions.asSharedFlow()

    private val _watchOwned = MutableStateFlow<WatchOwnedWorkout?>(null)
    val watchOwned: StateFlow<WatchOwnedWorkout?> = _watchOwned.asStateFlow()

    private val ignoringOwnWrites = AtomicBoolean(false)
    private val lastSource = AtomicReference(WorkoutWearContract.SOURCE_PHONE)
    private var appContext: Context? = null

    private val bridgeExecutor = Executors.newCachedThreadPool()
    private var serverSocket: ServerSocket? = null
    private val bridgeClients = mutableListOf<BufferedWriter>()

    fun start(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        startEmulatorBridge()
        // Also connect as client to host relay (adb reverse tcp:19887) for physical phone ↔ watch emu.
        connectHostRelayClient()
    }

    fun publishPhoneState(
        context: Context,
        active: Boolean,
        title: String = "",
        exercise: String = "",
        sets: String = "",
        resting: Boolean = false,
        paused: Boolean = false,
        elapsedSeconds: Int = 0,
        timerStartEpoch: Long = 0L,
        restEndEpoch: Long = 0L,
        kind: String = WorkoutWearContract.KIND_STRENGTH,
    ) {
        lastSource.set(WorkoutWearContract.SOURCE_PHONE)
        if (!active) {
            _watchOwned.value = null
        }
        val payload = JSONObject()
            .put("type", "state")
            .put(WorkoutWearContract.ACTIVE, active)
            .put(WorkoutWearContract.TITLE, title)
            .put(WorkoutWearContract.EXERCISE, exercise)
            .put(WorkoutWearContract.SETS, sets)
            .put(WorkoutWearContract.RESTING, resting)
            .put(WorkoutWearContract.PAUSED, paused)
            .put(WorkoutWearContract.ELAPSED, elapsedSeconds)
            .put(WorkoutWearContract.TIMER_START, timerStartEpoch)
            .put(WorkoutWearContract.REST_END, restEndEpoch)
            .put(WorkoutWearContract.KIND, kind)
            .put(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_PHONE)
            .put(WorkoutWearContract.UPDATED, System.currentTimeMillis())

        pushWearableData(context, payload)
        broadcastBridge(payload)
    }

    fun sendControlToWatch(context: Context, action: String) {
        val payload = JSONObject()
            .put("type", "control")
            .put(WorkoutWearContract.ACTION, action)
            .put(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_PHONE)
            .put(WorkoutWearContract.UPDATED, System.currentTimeMillis())
        sendWearableMessage(context, payload)
        broadcastBridge(payload)
    }

    fun applyIncomingDataMap(map: DataMap) {
        val source = map.getString(WorkoutWearContract.SOURCE).orEmpty()
        if (source == WorkoutWearContract.SOURCE_PHONE && ignoringOwnWrites.get()) return
        val active = map.getBoolean(WorkoutWearContract.ACTIVE)
        val paused = map.getBoolean(WorkoutWearContract.PAUSED)
        if (source == WorkoutWearContract.SOURCE_WATCH) {
            if (!active) {
                val had = _watchOwned.value != null
                _watchOwned.value = null
                if (had) _remoteActions.tryEmit(WearRemoteAction.Stop)
                return
            }
            val previous = _watchOwned.value
            val next = WatchOwnedWorkout(
                title = map.getString(WorkoutWearContract.TITLE).orEmpty(),
                exercise = map.getString(WorkoutWearContract.EXERCISE).orEmpty(),
                kind = map.getString(WorkoutWearContract.KIND) ?: WorkoutWearContract.KIND_STRENGTH,
                paused = paused,
                elapsedSeconds = map.getInt(WorkoutWearContract.ELAPSED),
                sets = map.getString(WorkoutWearContract.SETS).orEmpty(),
            )
            _watchOwned.value = next
            if (previous != null && previous.paused != paused) {
                _remoteActions.tryEmit(if (paused) WearRemoteAction.Pause else WearRemoteAction.Resume)
            }
            return
        }
        // Phone-originated echoes ignored for UI; watch controls come as messages.
    }

    fun applyIncomingControl(action: String, source: String) {
        if (source == WorkoutWearContract.SOURCE_PHONE) return
        when (action) {
            WorkoutWearContract.ACTION_PAUSE -> _remoteActions.tryEmit(WearRemoteAction.Pause)
            WorkoutWearContract.ACTION_RESUME -> _remoteActions.tryEmit(WearRemoteAction.Resume)
            WorkoutWearContract.ACTION_STOP -> {
                _watchOwned.value = null
                _remoteActions.tryEmit(WearRemoteAction.Stop)
            }
            WorkoutWearContract.ACTION_START -> Unit
        }
    }

    fun applyIncomingJson(line: String) {
        runCatching {
            val json = JSONObject(line)
            when (json.optString("type")) {
                "state" -> {
                    val map = DataMap()
                    map.putBoolean(WorkoutWearContract.ACTIVE, json.optBoolean(WorkoutWearContract.ACTIVE))
                    map.putString(WorkoutWearContract.TITLE, json.optString(WorkoutWearContract.TITLE))
                    map.putString(WorkoutWearContract.EXERCISE, json.optString(WorkoutWearContract.EXERCISE))
                    map.putString(WorkoutWearContract.SETS, json.optString(WorkoutWearContract.SETS))
                    map.putBoolean(WorkoutWearContract.RESTING, json.optBoolean(WorkoutWearContract.RESTING))
                    map.putBoolean(WorkoutWearContract.PAUSED, json.optBoolean(WorkoutWearContract.PAUSED))
                    map.putInt(WorkoutWearContract.ELAPSED, json.optInt(WorkoutWearContract.ELAPSED))
                    map.putLong(WorkoutWearContract.TIMER_START, json.optLong(WorkoutWearContract.TIMER_START))
                    map.putLong(WorkoutWearContract.REST_END, json.optLong(WorkoutWearContract.REST_END))
                    map.putString(WorkoutWearContract.KIND, json.optString(WorkoutWearContract.KIND))
                    map.putString(WorkoutWearContract.SOURCE, json.optString(WorkoutWearContract.SOURCE))
                    applyIncomingDataMap(map)
                }
                "control" -> applyIncomingControl(
                    json.optString(WorkoutWearContract.ACTION),
                    json.optString(WorkoutWearContract.SOURCE),
                )
            }
        }.onFailure { Log.w(TAG, "Bad bridge payload: $line", it) }
    }

    private fun pushWearableData(context: Context, payload: JSONObject) {
        runCatching {
            ignoringOwnWrites.set(true)
            val request = PutDataMapRequest.create(WorkoutWearContract.PATH).apply {
                dataMap.putBoolean(WorkoutWearContract.ACTIVE, payload.optBoolean(WorkoutWearContract.ACTIVE))
                dataMap.putString(WorkoutWearContract.TITLE, payload.optString(WorkoutWearContract.TITLE))
                dataMap.putString(WorkoutWearContract.EXERCISE, payload.optString(WorkoutWearContract.EXERCISE))
                dataMap.putString(WorkoutWearContract.SETS, payload.optString(WorkoutWearContract.SETS))
                dataMap.putBoolean(WorkoutWearContract.RESTING, payload.optBoolean(WorkoutWearContract.RESTING))
                dataMap.putBoolean(WorkoutWearContract.PAUSED, payload.optBoolean(WorkoutWearContract.PAUSED))
                dataMap.putInt(WorkoutWearContract.ELAPSED, payload.optInt(WorkoutWearContract.ELAPSED))
                dataMap.putLong(WorkoutWearContract.TIMER_START, payload.optLong(WorkoutWearContract.TIMER_START))
                dataMap.putLong(WorkoutWearContract.REST_END, payload.optLong(WorkoutWearContract.REST_END))
                dataMap.putString(WorkoutWearContract.KIND, payload.optString(WorkoutWearContract.KIND))
                dataMap.putString(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_PHONE)
                dataMap.putLong(WorkoutWearContract.UPDATED, System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
                .addOnCompleteListener { ignoringOwnWrites.set(false) }
        }.onFailure {
            ignoringOwnWrites.set(false)
            Log.w(TAG, "Wearable put failed", it)
        }
    }

    private fun sendWearableMessage(context: Context, payload: JSONObject) {
        runCatching {
            val bytes = payload.toString().toByteArray(Charsets.UTF_8)
            Wearable.getNodeClient(context).connectedNodes
                .addOnSuccessListener { nodes ->
                    nodes.forEach { node ->
                        Wearable.getMessageClient(context)
                            .sendMessage(node.id, WorkoutWearContract.CONTROL_PATH, bytes)
                    }
                }
        }
    }

    private fun startEmulatorBridge() {
        if (serverSocket != null) return
        bridgeExecutor.execute {
            runCatching {
                val server = ServerSocket(WorkoutWearContract.EMULATOR_BRIDGE_PORT, 4, InetAddress.getByName("0.0.0.0"))
                serverSocket = server
                Log.i(TAG, "Emulator bridge listening on ${WorkoutWearContract.EMULATOR_BRIDGE_PORT}")
                while (!server.isClosed) {
                    val socket = server.accept()
                    bridgeExecutor.execute { handleBridgeClient(socket) }
                }
            }.onFailure { Log.w(TAG, "Emulator bridge failed", it) }
        }
    }

    private fun connectHostRelayClient() {
        bridgeExecutor.execute {
            while (appContext != null) {
                runCatching {
                    val socket = Socket()
                    socket.connect(
                        java.net.InetSocketAddress("127.0.0.1", WorkoutWearContract.EMULATOR_BRIDGE_PORT),
                        2500,
                    )
                    val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
                    val writer = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                    synchronized(bridgeClients) { bridgeClients.add(writer) }
                    Log.i(TAG, "Connected to host sync relay")
                    while (true) {
                        val line = reader.readLine() ?: break
                        if (line.isNotBlank()) applyIncomingJson(line)
                    }
                    synchronized(bridgeClients) { bridgeClients.remove(writer) }
                    socket.close()
                }.onFailure {
                    Log.d(TAG, "Host relay retry: ${it.message}")
                }
                try {
                    Thread.sleep(2000)
                } catch (_: InterruptedException) {
                    return@execute
                }
            }
        }
    }

    private fun handleBridgeClient(socket: Socket) {
        runCatching {
            val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
            val writer = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
            synchronized(bridgeClients) { bridgeClients.add(writer) }
            Log.i(TAG, "Watch bridge connected ${socket.inetAddress}")
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isNotBlank()) applyIncomingJson(line)
            }
            synchronized(bridgeClients) { bridgeClients.remove(writer) }
            socket.close()
        }.onFailure { Log.w(TAG, "Bridge client error", it) }
    }

    private fun broadcastBridge(payload: JSONObject) {
        val line = payload.toString()
        synchronized(bridgeClients) {
            val dead = mutableListOf<BufferedWriter>()
            bridgeClients.forEach { writer ->
                runCatching {
                    writer.write(line)
                    writer.newLine()
                    writer.flush()
                }.onFailure { dead.add(writer) }
            }
            bridgeClients.removeAll(dead)
        }
    }
}
