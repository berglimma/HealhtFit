package com.healthfit.android.core

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

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

    val locale: Locale get() = Locale.forLanguageTag(code)

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

fun Context.withAppLocale(language: AppLanguage): Context {
    val locale = language.locale
    Locale.setDefault(locale)
    val config = Configuration(resources.configuration)
    config.setLocales(LocaleList(locale))
    return createConfigurationContext(config)
}

/**
 * Preferência de idioma do app (persiste entre sessões) e aplica locale via AppCompat
 * para que `stringResource` / Resources sigam a escolha do usuário.
 */
object AppLanguageStore {
    private const val Prefs = "app_language.v1"

    private val _language = MutableStateFlow(AppLanguage.Portuguese)
    val language: StateFlow<AppLanguage> = _language.asStateFlow()

    fun init(context: Context) {
        val appCompatTags = AppCompatDelegate.getApplicationLocales().toLanguageTags()
            .ifBlank { null }
        val saved = appCompatTags
            ?: prefs(context).getString(AppLanguage.StorageKey, null)
        val resolved = AppLanguage.fromCode(saved)
        _language.value = resolved
        prefs(context).edit().putString(AppLanguage.StorageKey, resolved.code).apply()
        applyLocales(resolved)
    }

    fun set(context: Context, language: AppLanguage) {
        prefs(context.applicationContext).edit().putString(AppLanguage.StorageKey, language.code).apply()
        _language.value = language
        applyLocales(language)
    }

    private fun applyLocales(language: AppLanguage) {
        Locale.setDefault(language.locale)
        val locales = LocaleListCompat.forLanguageTags(language.code)
        AppCompatDelegate.setApplicationLocales(locales)
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(Prefs, Context.MODE_PRIVATE)
}
