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
                    AssistantNotifications.rescheduleFromStorage(context)
                }
                else -> {
                    val title = intent.getStringExtra(TITLE) ?: return
                    val body = intent.getStringExtra(BODY) ?: return
                    val id = intent.getIntExtra(ID, 0)
                    AssistantNotifications.show(context, id, title, body)
                    // Re-arm next occurrence so delivery continues without opening the app.
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
     * Call from app entry (any tab) so scheduling does not depend on IAssistente being open.
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
                "$name, sono e água estão em ordem. Os lembretes do dia continuam ativos — mesmo com o celular bloqueado.",
            )
        } else {
            notes.forEachIndexed { index, note ->
                show(context, 4200 + index, "IAssistente", MotivationMessages.healthIconYellowMessage(note))
            }
        }
    }

    fun rescheduleFromStorage(context: Context) {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        if (!hasNotificationPermission(context)) return
        val name = prefs.getString(KEY_NAME, null)?.ifBlank { null } ?: "Atleta"
        val userId = prefs.getString(KEY_USER_ID, null)
        schedule(context, name, userId)
    }

    fun schedule(context: Context, name: String, userId: String?) {
        persistIdentity(context, name, userId)
        persistEnabled(context, true)
        ensureChannel(context)
        val alarm = context.getSystemService(AlarmManager::class.java)
        buildSlots(name).forEach { slot -> scheduleSlot(alarm, context, slot) }
        scheduleInactivityIfNeeded(alarm, context, userId)
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
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarm.canScheduleExactAlarms()) {
                    alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
                } else {
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
                }
            } else {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
            }
        } catch (_: SecurityException) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
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
        val channel = NotificationChannel(CHANNEL, "IAssistente", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Água, sono, treino, suplemento, refeições e motivação — mesmo com o celular bloqueado"
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
