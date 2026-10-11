package com.healthfit.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.healthfit.core.workout.WorkoutWearContract
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

/**
 * Pushes local watch workouts to the phone and applies phone controls.
 * Uses Wearable when nodes exist; otherwise TCP to the phone emulator via 10.0.2.2.
 */
object WatchPhoneSync {
    private const val TAG = "WatchPhoneSync"
    private const val HOST_LOOPBACK = "10.0.2.2"

    private var appContext: Context? = null
    private val executor = Executors.newCachedThreadPool()
    private val bridgeConnected = AtomicBoolean(false)
    private var bridgeWriter: BufferedWriter? = null
    private val ignoringOwn = AtomicBoolean(false)

    fun start(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        runCatching { connectEmulatorBridge() }
        runCatching {
            Wearable.getMessageClient(context.applicationContext).addListener(messageListener)
        }.onFailure { Log.w(TAG, "Message listener failed", it) }
    }

    private val messageListener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path != WorkoutWearContract.CONTROL_PATH) return@OnMessageReceivedListener
        val json = runCatching { JSONObject(String(event.data, Charsets.UTF_8)) }.getOrNull() ?: return@OnMessageReceivedListener
        applyControl(
            action = json.optString(WorkoutWearContract.ACTION),
            source = json.optString(WorkoutWearContract.SOURCE),
        )
    }

    fun publishSession(session: ActiveSession?) {
        val ctx = appContext ?: return
        val payload = if (session == null || session.fromPhone) {
            JSONObject()
                .put("type", "state")
                .put(WorkoutWearContract.ACTIVE, false)
                .put(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_WATCH)
                .put(WorkoutWearContract.UPDATED, System.currentTimeMillis())
        } else {
            JSONObject()
                .put("type", "state")
                .put(WorkoutWearContract.ACTIVE, true)
                .put(WorkoutWearContract.TITLE, session.title)
                .put(WorkoutWearContract.EXERCISE, session.exerciseName)
                .put(WorkoutWearContract.SETS, if (session.isPaused) "Pausado" else session.kind.name)
                .put(WorkoutWearContract.RESTING, session.isResting)
                .put(WorkoutWearContract.PAUSED, session.isPaused)
                .put(WorkoutWearContract.ELAPSED, session.elapsedSeconds())
                .put(WorkoutWearContract.TIMER_START, session.sessionStartEpoch)
                .put(WorkoutWearContract.REST_END, session.restEndEpoch)
                .put(
                    WorkoutWearContract.KIND,
                    when (session.kind) {
                        SessionKind.Cardio -> WorkoutWearContract.KIND_CARDIO
                        SessionKind.Meditation -> WorkoutWearContract.KIND_MEDITATION
                        SessionKind.Strength -> WorkoutWearContract.KIND_STRENGTH
                    },
                )
                .put(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_WATCH)
                .put(WorkoutWearContract.UPDATED, System.currentTimeMillis())
        }
        pushWearable(ctx, payload)
        sendBridge(payload)
    }

    fun sendControl(action: String) {
        val ctx = appContext ?: return
        val payload = JSONObject()
            .put("type", "control")
            .put(WorkoutWearContract.ACTION, action)
            .put(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_WATCH)
            .put(WorkoutWearContract.UPDATED, System.currentTimeMillis())
        runCatching {
            val bytes = payload.toString().toByteArray(Charsets.UTF_8)
            Wearable.getNodeClient(ctx).connectedNodes.addOnSuccessListener { nodes ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(ctx).sendMessage(node.id, WorkoutWearContract.CONTROL_PATH, bytes)
                }
            }
        }
        sendBridge(payload)
    }

    fun applyControl(action: String, source: String) {
        if (source != WorkoutWearContract.SOURCE_PHONE) return
        when (action) {
            WorkoutWearContract.ACTION_PAUSE -> {
                val s = LocalWatchSession.state.value ?: return
                if (!s.isPaused) LocalWatchSession.togglePause(fromRemote = true)
            }
            WorkoutWearContract.ACTION_RESUME -> {
                val s = LocalWatchSession.state.value ?: return
                if (s.isPaused) LocalWatchSession.togglePause(fromRemote = true)
            }
            WorkoutWearContract.ACTION_STOP -> LocalWatchSession.stop(fromRemote = true)
        }
    }

    fun applyBridgeLine(line: String) {
        runCatching {
            val json = JSONObject(line)
            when (json.optString("type")) {
                "control" -> applyControl(
                    json.optString(WorkoutWearContract.ACTION),
                    json.optString(WorkoutWearContract.SOURCE),
                )
                "state" -> {
                    if (json.optString(WorkoutWearContract.SOURCE) != WorkoutWearContract.SOURCE_PHONE) return
                    if (ignoringOwn.get()) return
                    val active = json.optBoolean(WorkoutWearContract.ACTIVE)
                    if (!active) {
                        WorkoutWearSession.clear()
                        return
                    }
                    WorkoutWearSession.apply(
                        com.google.android.gms.wearable.DataMap().apply {
                            putBoolean(WorkoutWearContract.ACTIVE, true)
                            putString(WorkoutWearContract.TITLE, json.optString(WorkoutWearContract.TITLE))
                            putString(WorkoutWearContract.EXERCISE, json.optString(WorkoutWearContract.EXERCISE))
                            putString(WorkoutWearContract.SETS, json.optString(WorkoutWearContract.SETS))
                            putBoolean(WorkoutWearContract.RESTING, json.optBoolean(WorkoutWearContract.RESTING))
                            putBoolean(WorkoutWearContract.PAUSED, json.optBoolean(WorkoutWearContract.PAUSED))
                            putInt(WorkoutWearContract.ELAPSED, json.optInt(WorkoutWearContract.ELAPSED))
                            putLong(WorkoutWearContract.TIMER_START, json.optLong(WorkoutWearContract.TIMER_START))
                            putLong(WorkoutWearContract.REST_END, json.optLong(WorkoutWearContract.REST_END))
                        },
                    )
                }
            }
        }.onFailure { Log.w(TAG, "Bad bridge line", it) }
    }

    private fun pushWearable(context: Context, payload: JSONObject) {
        runCatching {
            ignoringOwn.set(true)
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
                dataMap.putString(WorkoutWearContract.SOURCE, WorkoutWearContract.SOURCE_WATCH)
                dataMap.putLong(WorkoutWearContract.UPDATED, System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
                .addOnCompleteListener { ignoringOwn.set(false) }
        }.onFailure {
            ignoringOwn.set(false)
            Log.w(TAG, "Wearable put failed", it)
        }
    }

    private fun connectEmulatorBridge() {
        executor.execute {
            while (appContext != null) {
                runCatching {
                    val socket = Socket()
                    socket.connect(InetSocketAddress(HOST_LOOPBACK, WorkoutWearContract.EMULATOR_BRIDGE_PORT), 2500)
                    val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
                    val writer = BufferedWriter(OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8))
                    bridgeWriter = writer
                    bridgeConnected.set(true)
                    Log.i(TAG, "Connected to phone emulator bridge")
                    LocalWatchSession.refreshPhoneReachable()
                    while (true) {
                        val line = reader.readLine() ?: break
                        if (line.isNotBlank()) applyBridgeLine(line)
                    }
                }.onFailure {
                    Log.d(TAG, "Bridge retry: ${it.message}")
                }
                bridgeConnected.set(false)
                bridgeWriter = null
                try {
                    Thread.sleep(2000)
                } catch (_: InterruptedException) {
                    return@execute
                }
            }
        }
    }

    private fun sendBridge(payload: JSONObject) {
        val writer = bridgeWriter ?: return
        runCatching {
            synchronized(writer) {
                writer.write(payload.toString())
                writer.newLine()
                writer.flush()
            }
        }.onFailure {
            bridgeConnected.set(false)
            bridgeWriter = null
        }
    }
}
