package com.healthfit.android.ui.assistant

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.healthfit.android.ui.home.DailyWellness
import java.util.Calendar

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(TITLE) ?: return
        val body = intent.getStringExtra(BODY) ?: return
        val id = intent.getIntExtra(ID, 0)
        AssistantNotifications.show(context, id, title, body)
    }

    companion object {
        const val TITLE = "title"
        const val BODY = "body"
        const val ID = "id"
    }
}

object AssistantNotifications {
    private const val CHANNEL = "healthfit_assistant"
    private var postedRules = false

    fun show(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(id, notification)
    }

    fun activate(context: Context, wellness: DailyWellness, name: String) {
        ensureChannel(context)
        schedule(context, name)
        if (!postedRules) {
            postedRules = true
            val notes = AssistantEngine.alerts(wellness)
            if (notes.isEmpty()) {
                show(context, 4100, "IAssistente", "$name, sono e água estão em ordem. Os lembretes do dia continuam ativos.")
            } else {
                notes.forEachIndexed { index, note ->
                    show(context, 4200 + index, "IAssistente", note)
                }
            }
        }
    }

    fun schedule(context: Context, name: String) {
        val slots = listOf(
            Slot(6, 0, 601, "HealthFit", "Bom dia, $name. Uma frase para o treino de hoje."),
            Slot(8, 0, 801, "Água", "Hora de beber água. A meta do dia está no card de hidratação."),
            Slot(9, 0, 901, "IAssistente", "Como você está se sentindo hoje?"),
            Slot(10, 0, 1001, "Água", "Mais um copo. A meta segue 35 ml por kg."),
            Slot(12, 0, 1201, "Água", "Meio-dia: confira a água e o almoço no cardápio."),
            Slot(12, 0, 1202, "Suplemento", "Registre o suplemento do meio-dia, se fizer parte do seu plano."),
            Slot(14, 0, 1401, "Água", "Tarde: faltam copos para a meta."),
            Slot(15, 0, 1501, "Suplemento", "Janela de suplemento da tarde."),
            Slot(16, 0, 1601, "Água", "Mais água antes do treino."),
            Slot(18, 0, 1801, "Treino", "18h: se ainda não treinou, a ficha do método está em Treinos."),
            Slot(18, 0, 1802, "Suplemento", "Suplemento do fim da tarde, se estiver no plano."),
            Slot(20, 0, 2001, "Água", "Último lembrete de água do dia."),
            Slot(21, 0, 2101, "IAssistente", "Como foi o dia? Sono, treino e refeições."),
            Slot(21, 0, 2102, "Suplemento", "Último registro de suplemento do dia."),
        )
        val alarm = context.getSystemService(AlarmManager::class.java)
        slots.forEach { slot ->
            val whenMillis = next(slot.hour, slot.minute)
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                putExtra(ReminderReceiver.TITLE, slot.title)
                putExtra(ReminderReceiver.BODY, slot.body)
                putExtra(ReminderReceiver.ID, slot.id)
            }
            val pending = PendingIntent.getBroadcast(
                context,
                slot.id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
        }
    }

    private fun next(hour: Int, minute: Int): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        return calendar.timeInMillis
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL, "IAssistente", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Água, sono, treino, suplemento e check-in do HealthFit"
        }
        manager.createNotificationChannel(channel)
    }

    private data class Slot(val hour: Int, val minute: Int, val id: Int, val title: String, val body: String)
}
