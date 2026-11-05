package com.murn.downloader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * In-app updates: the CI publishes version.json + Murn-Downloader.apk on the "android-latest" release.
 * The app reads version.json, and if its versionCode is newer it downloads the APK and opens the system installer
 * (Android always asks the user to confirm the install; the signing key must be the same as the installed one).
 */
object Updater {
    private const val BASE = "https://github.com/kloody60/murn-updates.1/releases/download/android-latest/"

    sealed class State {
        object Idle : State()
        object Checking : State()
        data class Available(val name: String, val code: Long, val notes: String) : State()
        data class Downloading(val name: String, val percent: Int) : State()
        data class Ready(val file: File, val name: String) : State()
        object UpToDate : State()
        data class Failed(val msg: String) : State()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state

    val hasUpdate: Boolean get() = _state.value.let { it is State.Available || it is State.Downloading || it is State.Ready }

    fun currentCode(ctx: Context): Long = runCatching {
        val p = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong()
    }.getOrDefault(0)

    fun currentName(ctx: Context): String =
        runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "?"

    private fun open(path: String): HttpURLConnection =
        (URL(BASE + path).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20_000
            readTimeout = 30_000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "MurnDownloader")
            useCaches = false
        }

    fun check(ctx: Context, silent: Boolean = false) {
        if (_state.value is State.Checking || _state.value is State.Downloading) return
        val app = ctx.applicationContext
        if (!silent) _state.value = State.Checking
        scope.launch {
            try {
                val c = open("version.json?t=${System.currentTimeMillis()}")
                val text = try {
                    if (c.responseCode != 200) error("HTTP ${c.responseCode}")
                    c.inputStream.use { it.readBytes() }.toString(Charsets.UTF_8)
                } finally { c.disconnect() }
                val j = JSONObject(text)
                val code = j.getLong("versionCode")
                val name = j.optString("versionName", code.toString())
                _state.value =
                    if (code > currentCode(app)) State.Available(name, code, j.optString("notes", ""))
                    else if (silent) State.Idle else State.UpToDate
            } catch (e: Exception) {
                _state.value = if (silent) State.Idle else State.Failed("ما قدرت أفحص التحديث: ${e.message ?: e.javaClass.simpleName}")
            }
        }
    }

    fun download(ctx: Context) {
        val s = _state.value as? State.Available ?: return
        val app = ctx.applicationContext
        _state.value = State.Downloading(s.name, 0)
        scope.launch {
            try {
                val dir = File(app.cacheDir, "updates").apply { mkdirs(); listFiles()?.forEach { it.delete() } }
                val out = File(dir, "Murn-Downloader.apk")
                val c = open("Murn-Downloader.apk")
                try {
                    if (c.responseCode != 200) error("HTTP ${c.responseCode}")
                    val total = c.contentLengthLong
                    var got = 0L
                    var last = -1
                    c.inputStream.use { ins ->
                        out.outputStream().use { os ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = ins.read(buf)
                                if (n < 0) break
                                os.write(buf, 0, n)
                                got += n
                                if (total > 0) {
                                    val p = (got * 100 / total).toInt()
                                    if (p != last) { last = p; _state.value = State.Downloading(s.name, p) }
                                }
                            }
                        }
                    }
                    if (total > 0 && got != total) error("الملف ناقص ($got من $total)")
                } finally { c.disconnect() }
                _state.value = State.Ready(out, s.name)
                install(app, out)
            } catch (e: Exception) {
                _state.value = State.Failed("فشل تنزيل التحديث: ${e.message ?: e.javaClass.simpleName}")
            }
        }
    }

    /** Opens the system installer for [apk]; if the app may not install apps yet, opens that setting first. */
    fun install(ctx: Context, apk: File) {
        val app = ctx.applicationContext
        if (Build.VERSION.SDK_INT >= 26 && !app.packageManager.canRequestPackageInstalls()) {
            app.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${app.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            return
        }
        val uri = FileProvider.getUriForFile(app, "${app.packageName}.files", apk)
        app.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    fun reset() { if (_state.value is State.UpToDate || _state.value is State.Failed) _state.value = State.Idle }
}
