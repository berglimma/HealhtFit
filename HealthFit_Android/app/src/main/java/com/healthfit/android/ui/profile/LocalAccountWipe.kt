package com.healthfit.android.ui.profile

import android.app.NotificationManager
import android.content.Context
import java.io.File

/** Clears on-device HealthFit data after the cloud account is deleted. Keeps the language choice. */
object LocalAccountWipe {
    fun clear(context: Context) {
        val prefsDir = File(context.applicationInfo.dataDir, "shared_prefs")
        prefsDir?.listFiles()?.forEach { file ->
            val name = file.name.removeSuffix(".xml")
            if (name.contains("language", ignoreCase = true)) return@forEach
            context.getSharedPreferences(name, Context.MODE_PRIVATE).edit().clear().apply()
        }
        runCatching {
            context.getSystemService(NotificationManager::class.java).cancelAll()
        }
    }
}
