package com.healthfit.android.core

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Idiomas alinhados ao iOS `AppLanguage` / Localizable. */
enum class AppLanguage(
    val code: String,
    val flag: String,
    val nativeName: String,
) {
    Portuguese("pt-BR", "🇧🇷", "Português"),
    English("en", "🇺🇸", "English"),
    Spanish("es", "🇪🇸", "Español"),
    French("fr", "🇫🇷", "Français"),
    German("de", "🇩🇪", "Deutsch"),
    Italian("it", "🇮🇹", "Italiano");

    val menuLabel: String get() = "$flag $nativeName"

    companion object {
        const val StorageKey = "healthfit_app_language"

        fun fromCode(code: String?): AppLanguage =
            entries.firstOrNull { it.code.equals(code, ignoreCase = true) }
                ?: entries.firstOrNull {
                    it.code.substringBefore('-').equals(code?.substringBefore('-'), ignoreCase = true)
                }
                ?: Portuguese
    }
}

/**
 * Preferência de idioma do app (persiste entre sessões) e aplica locale via AppCompat.
 */
object AppLanguageStore {
    private const val Prefs = "app_language.v1"

    private val _language = MutableStateFlow(AppLanguage.Portuguese)
    val language: StateFlow<AppLanguage> = _language.asStateFlow()

    fun init(context: Context) {
        val saved = prefs(context).getString(AppLanguage.StorageKey, null)
        val resolved = AppLanguage.fromCode(saved)
        _language.value = resolved
        applyLocales(resolved)
    }

    fun set(context: Context, language: AppLanguage) {
        if (_language.value == language) {
            applyLocales(language)
            return
        }
        prefs(context).edit().putString(AppLanguage.StorageKey, language.code).apply()
        _language.value = language
        applyLocales(language)
    }

    private fun applyLocales(language: AppLanguage) {
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(language.code))
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
