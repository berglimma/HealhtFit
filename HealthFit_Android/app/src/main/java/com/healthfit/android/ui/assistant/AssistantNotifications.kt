package com.healthfit.android.ui.assistant

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.healthfit.android.MainActivity
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.android.ui.workouts.StudyFocusCard
import com.healthfit.android.ui.workouts.StudyFocusSessionRecord
import com.healthfit.android.ui.workouts.StudyPriorityLevel
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Receives exact RTC_WAKEUP alarms (works with screen locked / app killed)
 * and re-arms the schedule after boot or package update.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        try {
            when (intent.action) {
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_LOCKED_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                ACTION_QUICKBOOT,
                ACTION_HTC_QUICKBOOT,
                ACTION_RESCHEDULE -> {
                    // Re-arma tudo sem precisar abrir o IAssistente.
                    AssistantNotifications.rescheduleFromStorage(context)
                }
                else -> {
                    val title = intent.getStringExtra(TITLE) ?: return
                    val body = intent.getStringExtra(BODY) ?: return
                    val id = intent.getIntExtra(ID, 0)
                    AssistantNotifications.show(context, id, title, body)
                    // Re-arm next day / next habit — works with app killed and IAssistente closed.
                    AssistantNotifications.rescheduleFromStorage(context)
                }
            }
        } finally {
            pending.finish()
        }
    }

    companion object {
        const val TITLE = "title"
        const val BODY = "body"
        const val ID = "id"
        const val ACTION_REMINDER = "com.healthfit.android.action.REMINDER"
        const val ACTION_RESCHEDULE = "com.healthfit.android.action.RESCHEDULE"
        private const val ACTION_QUICKBOOT = "android.intent.action.QUICKBOOT_POWERON"
        private const val ACTION_HTC_QUICKBOOT = "com.htc.intent.action.QUICKBOOT_POWERON"
    }
}

/**
 * Background motivation / reminder delivery — same occasions as iOS.
 * Alarms use exact RTC_WAKEUP so they fire with the phone locked and
 * without IAssistente (or the app) being open.
 */
object AssistantNotifications {
    private const val CHANNEL = "healthfit_assistant_v2"
    private const val PREFS = "assistant_notifications.v1"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_NAME = "name"
    private const val KEY_USER_ID = "userId"
    private const val KEY_RULES_DAY = "rules_day"
    private const val KEY_ASKED_BATTERY = "asked_battery"

    private const val STUDY_FOCUS_ID_BASE = 9200

    fun scheduleStudyFocusReminders(context: Context, card: StudyFocusCard, sessionMinutes: Int) {
        cancelStudyFocusReminders(context)
        if (card.priorities.isEmpty() || sessionMinutes <= 0) return
        ensureChannel(context)
        val alarm = context.getSystemService(AlarmManager::class.java)
        val ordered = card.priorities.sortedBy {
            when (it.level) {
                StudyPriorityLevel.High -> 0
                StudyPriorityLevel.Medium -> 1
                StudyPriorityLevel.Low -> 2
            }
        }
        val sessionMs = sessionMinutes * 60_000L
        val step = maxOf(sessionMs / (ordered.size + 1), 60_000L)
        ordered.forEachIndexed { index, item ->
            val fireAt = System.currentTimeMillis() + step * (index + 1)
            if (fireAt >= System.currentTimeMillis() + sessionMs) return@forEachIndexed
            scheduleAt(
                alarm,
                context,
                fireAt,
                STUDY_FOCUS_ID_BASE + index,
                "Prioridade ${item.level.label} · ${card.name}",
                item.title,
            )
        }
    }

    fun cancelStudyFocusReminders(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until 12) {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_REMINDER
            }
            val pending = PendingIntent.getBroadcast(
                context,
                STUDY_FOCUS_ID_BASE + i,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarm.cancel(pending)
        }
    }

    private const val STUDY_HABIT_ID = 9310
    private const val STUDY_INACTIVITY_ID = 9311

    /** Lembrete diário no horário habitual aprendido (após ≥3 sessões). */
    fun scheduleStudyFocusHabitReminder(context: Context, sessions: List<StudyFocusSessionRecord>) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val cancelIntent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMINDER
        }
        alarm.cancel(
            PendingIntent.getBroadcast(
                context,
                STUDY_HABIT_ID,
                cancelIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        if (sessions.size < 3) return
        ensureChannel(context)
        val hourBuckets = sessions.groupBy {
            Calendar.getInstance().apply { timeInMillis = it.endedAtMillis }.get(Calendar.HOUR_OF_DAY)
        }
        val preferredHour = hourBuckets.maxByOrNull { it.value.size }?.key ?: return
        val fireAt = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, preferredHour)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 2_000L) add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        scheduleAt(
            alarm,
            context,
            fireAt,
            STUDY_HABIT_ID,
            "Hora do Foco em Estudo",
            "Pela sua rotina, este costuma ser um bom horário para estudar. Abra Meditação → Foco em Estudo.",
        )
        // Inatividade 48h a partir da última sessão
        sessions.maxOfOrNull { it.endedAtMillis }?.let { last ->
            val inactivityAt = last + AssistantStudyFocusEngine.InactivityMs
            if (inactivityAt > System.currentTimeMillis()) {
                scheduleAt(
                    alarm,
                    context,
                    inactivityAt,
                    STUDY_INACTIVITY_ID,
                    "Foco em Estudo",
                    "Faz cerca de 48h sem sessão de estudo. Retome suas prioridades no HealthFit.",
                )
            }
        }
    }

    fun show(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        val openApp = PendingIntent.getActivity(
            context,
            id,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setOnlyAlertOnce(false)
            .setOngoing(false)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(id, notification)
    }

    /**
     * Agenda lembretes no aparelho. Não depende do IAssistente estar aberto —
     * AlarmManager + ReminderReceiver disparam com o app morto / tela bloqueada.
     */
    fun ensureBackgroundDelivery(
        context: Context,
        name: String,
        userId: String?,
        requestBatteryExemption: Boolean = false,
    ) {
        persistIdentity(context, name, userId)
        ensureChannel(context)
        if (!hasNotificationPermission(context)) return
        persistEnabled(context, true)
        schedule(context, name, userId)
        restoreStudyFocusHabits(context)
        if (requestBatteryExemption) {
            maybeRequestBatteryExemption(context)
        }
        maybeRequestExactAlarmPermission(context)
    }

    fun activate(context: Context, wellness: DailyWellness, name: String, userId: String?) {
        ensureBackgroundDelivery(context, name, userId, requestBatteryExemption = true)
        if (!hasNotificationPermission(context)) return
        val day = AssistantRoutineStore.dayKey()
        val prefs = prefs(context)
        if (prefs.getString(KEY_RULES_DAY, null) == day) return
        prefs.edit().putString(KEY_RULES_DAY, day).apply()
        val notes = AssistantEngine.alerts(wellness)
        if (notes.isEmpty()) {
            show(
                context,
                4100,
                "IAssistente",
                "$name, sono e água estão em ordem. Os lembretes do dia continuam ativos — mesmo com o IAssistente fechado e o celular bloqueado.",
            )
        } else {
            notes.forEachIndexed { index, note ->
                show(context, 4200 + index, "IAssistente", MotivationMessages.healthIconYellowMessage(note))
            }
        }
    }

    /**
     * Re-arma alarmes após boot / update / disparo.
     * Usa identidade salva — não exige abrir o IAssistente.
     */
    fun rescheduleFromStorage(context: Context) {
        if (!hasNotificationPermission(context)) return
        val prefs = prefs(context)
        val name = prefs.getString(KEY_NAME, null)?.ifBlank { null } ?: "Atleta"
        val userId = prefs.getString(KEY_USER_ID, null)
        // Se o usuário já abriu o app com permissão, mantém ativo mesmo sem tocar no IAssistente.
        if (!prefs.getBoolean(KEY_ENABLED, false) && prefs.getString(KEY_NAME, null).isNullOrBlank()) {
            return
        }
        persistEnabled(context, true)
        schedule(context, name, userId)
        restoreStudyFocusHabits(context)
    }

    fun schedule(context: Context, name: String, userId: String?) {
        persistIdentity(context, name, userId)
        persistEnabled(context, true)
        ensureChannel(context)
        val alarm = context.getSystemService(AlarmManager::class.java)
        buildSlots(name).forEach { slot -> scheduleSlot(alarm, context, slot) }
        scheduleInactivityIfNeeded(alarm, context, userId)
    }

    /** Reagenda hábito / inatividade de Foco em Estudo a partir do histórico local. */
    fun restoreStudyFocusHabits(context: Context) {
        runCatching {
            val sessions = com.healthfit.android.ui.workouts.StudyFocusStore.loadSessions(context)
            if (sessions.isNotEmpty()) {
                scheduleStudyFocusHabitReminder(context, sessions)
            }
        }
    }

    private fun buildSlots(name: String): List<Slot> {
        val slots = mutableListOf<Slot>()

        slots += Slot(
            hour = 6,
            minute = 0,
            id = 600,
            title = MotivationMessages.dailyNotificationTitle(),
            bodyProvider = { MotivationMessages.dailyMessage() },
        )

        for (hour in 8..20 step 2) {
            slots += Slot(
                hour = hour,
                minute = 0,
                id = 800 + hour,
                title = "Água",
                bodyProvider = { MotivationMessages.waterReminderMessage(hour) },
            )
        }

        slots += Slot(
            hour = 9,
            minute = 0,
            id = 901,
            title = "IAssistente",
            bodyProvider = { "Como você está se sentindo hoje, $name?" },
        )

        MotivationMessages.MealType.values().forEachIndexed { index, meal ->
            val (hour, minute) = MotivationMessages.defaultMealClock(meal)
            slots += Slot(
                hour = hour,
                minute = minute,
                id = 7000 + index,
                title = "Cardápio",
                bodyProvider = { MotivationMessages.mealReminderMessage(meal, hour, minute) },
            )
        }

        listOf(6, 9, 12, 15, 18, 21).forEachIndexed { index, hour ->
            slots += Slot(
                hour = hour,
                minute = 0,
                id = 5000 + index,
                title = "Suplemento",
                bodyProvider = { MotivationMessages.supplementReminderBody(hour) },
            )
        }

        slots += Slot(
            hour = 18,
            minute = 0,
            id = 1800,
            title = "Treino",
            bodyProvider = { MotivationMessages.eveningTrainingNudgeMessage() },
        )

        slots += Slot(
            hour = 21,
            minute = 0,
            id = 2101,
            title = "IAssistente",
            bodyProvider = { "Como foi o dia, $name? Sono, treino e refeições." },
        )

        return slots
    }

    private fun scheduleInactivityIfNeeded(alarm: AlarmManager, context: Context, userId: String?) {
        val now = System.currentTimeMillis()
        val lastWorkout = AssistantRoutineStore.lastWorkoutMillis(context, userId)
        val lastCardio = AssistantRoutineStore.lastKindMillis(context, userId, "cardio")
        val lastMeditation = AssistantRoutineStore.lastKindMillis(context, userId, "meditation")
        val lastOpen = AssistantRoutineStore.lastOpenMillis(context, userId)

        fun fireAfter(last: Long, id: Int, title: String, body: String) {
            val anchor = if (last > 0L) last else now
            val whenMillis = anchor + TimeUnit.HOURS.toMillis(48)
            val fireAt = if (whenMillis <= now) {
                now + TimeUnit.MINUTES.toMillis(30)
            } else {
                whenMillis
            }
            scheduleAt(alarm, context, fireAt, id, title, body)
        }

        fireAfter(lastWorkout, 4801, "HealthFit", MotivationMessages.inactivityMessage())
        fireAfter(lastCardio, 4802, "Cardio", MotivationMessages.cardioInactivityMessage())
        fireAfter(lastMeditation, 4803, "Meditação", MotivationMessages.meditationInactivityMessage())
        fireAfter(lastOpen, 4804, "HealthFit", MotivationMessages.appUsageInactivityMessage())
    }

    private fun scheduleSlot(alarm: AlarmManager, context: Context, slot: Slot) {
        scheduleAt(alarm, context, next(slot.hour, slot.minute), slot.id, slot.title, slot.bodyProvider())
    }

    private fun scheduleAt(
        alarm: AlarmManager,
        context: Context,
        whenMillis: Long,
        id: Int,
        title: String,
        body: String,
    ) {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_REMINDER
            putExtra(ReminderReceiver.TITLE, title)
            putExtra(ReminderReceiver.BODY, body)
            putExtra(ReminderReceiver.ID, id)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openApp = PendingIntent.getActivity(
            context,
            id + 50_000,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            // setAlarmClock is the most reliable path on Samsung / Doze — fires with app killed.
            alarm.setAlarmClock(AlarmManager.AlarmClockInfo(whenMillis, openApp), pending)
        } catch (_: SecurityException) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarm.canScheduleExactAlarms()) {
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
                } else {
                    alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
                }
            } catch (_: SecurityException) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
            }
        } catch (_: Exception) {
            runCatching {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
            }
        }
    }

    private fun next(hour: Int, minute: Int): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 2_000L) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        return calendar.timeInMillis
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        // Recreate channel with lock-screen visibility for locked-phone delivery.
        runCatching { manager.deleteNotificationChannel("healthfit_assistant") }
        val channel = NotificationChannel(CHANNEL, "Lembretes HealthFit", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Água, sono, treino, estudo e motivação — mesmo com o IAssistente fechado e o celular bloqueado"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(true)
            setShowBadge(true)
            setBypassDnd(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun maybeRequestExactAlarmPermission(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val alarm = context.getSystemService(AlarmManager::class.java)
        if (alarm.canScheduleExactAlarms()) return
        runCatching {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    private fun maybeRequestBatteryExemption(context: Context) {
        val prefs = prefs(context)
        if (prefs.getBoolean(KEY_ASKED_BATTERY, false)) return
        val power = context.getSystemService(PowerManager::class.java)
        if (power.isIgnoringBatteryOptimizations(context.packageName)) {
            prefs.edit().putBoolean(KEY_ASKED_BATTERY, true).apply()
            return
        }
        prefs.edit().putBoolean(KEY_ASKED_BATTERY, true).apply()
        runCatching {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    private fun persistIdentity(context: Context, name: String, userId: String?) {
        prefs(context).edit()
            .putString(KEY_NAME, name)
            .putString(KEY_USER_ID, userId)
            .apply()
    }

    private fun persistEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private data class Slot(
        val hour: Int,
        val minute: Int,
        val id: Int,
        val title: String,
        val bodyProvider: () -> String,
    )
}
