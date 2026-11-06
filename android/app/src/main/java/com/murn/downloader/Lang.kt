package com.murn.downloader

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** App language (Arabic / English). [en] is Compose state, so every screen that reads it redraws when it changes. */
object Lang {
    var en by mutableStateOf(false)
        private set

    fun init(ctx: Context) {
        en = ctx.getSharedPreferences("murn", 0).getString("lang", "ar") == "en"
    }

    fun set(ctx: Context, english: Boolean) {
        en = english
        ctx.getSharedPreferences("murn", 0).edit().putString("lang", if (english) "en" else "ar").apply()
    }
}

/** Picks the Arabic or the English text for the current app language. */
fun tr(ar: String, en: String): String = if (Lang.en) en else ar
