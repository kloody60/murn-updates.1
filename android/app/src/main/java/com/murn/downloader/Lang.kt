package com.murn.downloader

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.LocaleList
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** App language (Arabic / English). [en] is Compose state, so every screen that reads it redraws when it changes. */
object Lang {
    var en by mutableStateOf(false)
        private set

    /** Reads the language: the phone's per-app language setting (Android 13+) wins, else the saved choice. */
    fun init(ctx: Context) {
        var chosen: String? = null
        if (Build.VERSION.SDK_INT >= 33) {
            val l = runCatching { ctx.getSystemService(LocaleManager::class.java).applicationLocales }.getOrNull()
            if (l != null && !l.isEmpty) chosen = l[0].language
        }
        en = (chosen ?: ctx.getSharedPreferences("murn", 0).getString("lang", "ar")) == "en"
    }

    fun set(ctx: Context, english: Boolean) {
        en = english
        ctx.getSharedPreferences("murn", 0).edit().putString("lang", if (english) "en" else "ar").apply()
        // keep the phone's own "App language" setting (Settings -> Apps -> Murn -> Language) in step
        if (Build.VERSION.SDK_INT >= 33) {
            runCatching {
                ctx.getSystemService(LocaleManager::class.java)
                    .applicationLocales = LocaleList.forLanguageTags(if (english) "en" else "ar")
            }
        }
    }
}

/** Picks the Arabic or the English text for the current app language. */
fun tr(ar: String, en: String): String = if (Lang.en) en else ar
