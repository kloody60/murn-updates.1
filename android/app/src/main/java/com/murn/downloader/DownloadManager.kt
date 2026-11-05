package com.murn.downloader

import android.app.Application
import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject
import java.io.File
import java.util.Collections
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * The whole download queue lives here (one process-wide instance), so it keeps working
 * while the screen is off / the activity is closed, as long as [DownloadService] keeps the process alive.
 *
 * Flow for every pasted link:
 *   1. RESOLVING : yt-dlp lists the link (a single video, or a playlist / channel with 60-70+ videos)
 *   2. every video becomes its own QUEUED row with its own progress bar
 *   3. up to [parallel] rows download at the same time (RUNNING)
 *   4. the finished file is copied into  Downloads/Murn  (DONE)
 */
object DownloadManager {
    private lateinit var app: Application
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val resolveGate = Semaphore(2)
    private val jobs = ConcurrentHashMap<String, Job>()
    private val canceled: MutableSet<String> = Collections.synchronizedSet(HashSet())
    private val ready = CompletableDeferred<Boolean>()
    private val pumpLock = Any()

    val items = MutableStateFlow<List<Item>>(emptyList())
    val engineStatus = MutableStateFlow("جاري تجهيز المحرك (أول مرة ياخذ شوي)...")
    val engineBusy = MutableStateFlow(true)
    val parallel = MutableStateFlow(2)
    val quality = MutableStateFlow(Quality.P1080)

    // ------------------------------------------------------------------ setup

    fun init(application: Application) {
        if (::app.isInitialized) return
        app = application
        val p = app.getSharedPreferences("murn", 0)
        parallel.value = p.getInt("parallel", 2).coerceIn(1, 4)
        quality.value = Quality.entries.firstOrNull { it.name == p.getString("quality", null) } ?: Quality.P1080

        scope.launch {
            try {
                YoutubeDL.getInstance().init(app)
                FFmpeg.getInstance().init(app)
                engineStatus.value = "جاري التأكد من آخر تحديث للمحرك..."
                // sites change all the time, so refresh yt-dlp on every start (but never wait more than 30s for it)
                val upd = async { runCatching { YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel._NIGHTLY) } }
                withTimeoutOrNull(30_000) { upd.await() }
                ready.complete(true)
                engineBusy.value = false
                engineStatus.value = "المحرك جاهز · ${engineVersion()}"
            } catch (t: Throwable) {
                ready.complete(false)
                engineBusy.value = false
                engineStatus.value = "تعذر تجهيز المحرك: ${t.message ?: t.javaClass.simpleName}"
            }
        }
    }

    private fun engineVersion(): String =
        runCatching { YoutubeDL.getInstance().versionName(app) }.getOrNull().orEmpty().ifBlank { "yt-dlp" }

    /** Manual "update yt-dlp" button (the fix when a site stops working). */
    fun updateEngine() {
        if (engineBusy.value || items.value.any { it.status == Status.RUNNING }) {
            engineStatus.value = "ما ينفع التحديث وفي تحميل شغال، انتظر يخلص"
            return
        }
        engineBusy.value = true
        engineStatus.value = "جاري تحديث المحرك..."
        scope.launch {
            val msg = try {
                when (YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel._NIGHTLY)) {
                    YoutubeDL.UpdateStatus.DONE -> "تم تحديث المحرك"
                    else -> "المحرك على آخر نسخة"
                }
            } catch (t: Throwable) {
                "فشل التحديث: ${t.message ?: "تأكد من الإنترنت"}"
            }
            engineBusy.value = false
            engineStatus.value = "$msg · ${engineVersion()}"
        }
    }

    // ------------------------------------------------------------------ settings

    fun setParallel(n: Int) {
        parallel.value = n.coerceIn(1, 4)
        app.getSharedPreferences("murn", 0).edit().putInt("parallel", parallel.value).apply()
        pump()
    }

    fun setQuality(q: Quality) {
        quality.value = q
        app.getSharedPreferences("murn", 0).edit().putString("quality", q.name).apply()
    }

    // ------------------------------------------------------------------ public actions

    /** Accepts any text with links (one per line, or a whole shared message). Returns how many links it found. */
    fun addLinks(raw: String, q: Quality, maxPerLink: Int?): Int {
        val urls = extractUrls(raw)
        if (urls.isEmpty()) return 0
        for (url in urls) {
            val id = newId()
            items.update { it + Item(id, url, title = url, status = Status.RESOLVING, quality = q) }
            jobs[id] = scope.launch { resolve(id, url, q, maxPerLink) }
        }
        DownloadService.start(app)
        return urls.size
    }

    fun cancel(id: String) {
        val item = items.value.firstOrNull { it.id == id } ?: return
        when (item.status) {
            Status.QUEUED -> setStatus(id, Status.CANCELED, info = "")
            Status.RUNNING, Status.RESOLVING -> {
                canceled += id
                runCatching { YoutubeDL.getInstance().destroyProcessById(id) }
            }
            else -> Unit
        }
    }

    fun cancelAll() = items.value.filter { it.active }.forEach { cancel(it.id) }

    fun retry(id: String) {
        val item = items.value.firstOrNull { it.id == id } ?: return
        if (item.status != Status.FAILED && item.status != Status.CANCELED) return
        canceled -= id
        update(id) { copy(status = Status.QUEUED, progress = 0f, info = "", error = null) }
        DownloadService.start(app)
        pump()
    }

    fun retryFailed() = items.value.filter { it.status == Status.FAILED }.forEach { retry(it.id) }

    fun remove(id: String) = items.update { list -> list.filterNot { it.id == id && !it.active } }

    fun clearFinished() = items.update { list -> list.filterNot { it.status == Status.DONE || it.status == Status.CANCELED } }

    // ------------------------------------------------------------------ step 1: expand links into videos

    private data class Entry(val url: String, val title: String, val group: String?)

    private suspend fun resolve(phId: String, url: String, q: Quality, maxPerLink: Int?) {
        val entries: List<Entry>? = resolveGate.withPermit {
            try {
                if (!ready.await()) error("المحرك غير جاهز")
                if (phId in canceled) throw InterruptedException()
                val req = YoutubeDLRequest(url).apply {
                    addOption("--flat-playlist")
                    addOption("--dump-single-json")
                    addOption("--no-warnings")
                    addOption("--skip-download")
                    addOption("--socket-timeout", 30)
                    if (maxPerLink != null) addOption("--playlist-end", maxPerLink)
                }
                val out = YoutubeDL.getInstance().execute(req, phId).out.orEmpty()
                val start = out.indexOf('{')
                if (start < 0) error("ما قدرت أقرأ الرابط")
                val found = ArrayList<Entry>()
                collect(JSONObject(out.substring(start)), found, null)
                found
            } catch (t: Throwable) {
                null
            }
        }

        val wasCanceled = canceled.remove(phId)
        jobs.remove(phId)
        when {
            wasCanceled -> setStatus(phId, Status.CANCELED)
            entries == null -> {
                // could not list it (some sites refuse listing) -> still try the link as a single download
                update(phId) { copy(status = Status.QUEUED, title = url, info = "") }
                pump()
            }
            entries.isEmpty() -> update(phId) { copy(status = Status.FAILED, error = "ما لقيت فيديوهات في هالرابط") }
            else -> {
                val rows = entries.take(MAX_PER_LINK).map {
                    Item(newId(), it.url, it.title, Status.QUEUED, q, group = it.group)
                }
                items.update { list -> list.flatMap { if (it.id == phId) rows else listOf(it) } }
                pump()
            }
        }
    }

    private fun str(o: JSONObject, key: String): String? =
        if (o.isNull(key)) null else o.optString(key).takeIf { it.isNotBlank() }

    /** Walks yt-dlp's JSON: playlists can contain playlists (channel tabs), single videos are leaves. */
    private fun collect(o: JSONObject, out: MutableList<Entry>, group: String?) {
        val entries = o.optJSONArray("entries")
        if (entries != null) {
            val g = str(o, "title") ?: group
            for (i in 0 until entries.length()) {
                val e = entries.optJSONObject(i) ?: continue
                collect(e, out, g)
            }
            return
        }
        val title = str(o, "title") ?: str(o, "id") ?: "فيديو"
        if (title == "[Private video]" || title == "[Deleted video]") return
        var link = listOf("webpage_url", "url", "original_url").mapNotNull { str(o, it) }.firstOrNull { it.startsWith("http") }
        if (link == null) {
            val id = str(o, "id")
            if (id != null && (str(o, "ie_key") ?: "").startsWith("Youtube")) link = "https://www.youtube.com/watch?v=$id"
        }
        if (link != null) out += Entry(link, title, group)
    }

    // ------------------------------------------------------------------ step 2/3: the scheduler

    private fun pump() {
        synchronized(pumpLock) {
            var slots = parallel.value - items.value.count { it.status == Status.RUNNING }
            for (item in items.value) {
                if (slots <= 0) break
                if (item.status != Status.QUEUED) continue
                update(item.id) { copy(status = Status.RUNNING, progress = 0f, info = "جاري البدء...", error = null) }
                jobs[item.id] = scope.launch { runDownload(item.id) }
                slots--
            }
        }
    }

    private suspend fun runDownload(id: String) {
        val item = items.value.firstOrNull { it.id == id } ?: return
        val base = app.getExternalFilesDir(null) ?: app.filesDir
        val tmp = File(base, "tmp/$id").apply { mkdirs() }
        try {
            if (!ready.await()) error("المحرك غير جاهز")
            if (id in canceled) throw InterruptedException()

            val req = buildRequest(item, tmp)
            var last = 0L
            YoutubeDL.getInstance().execute(req, id) { p, eta, line ->
                val now = SystemClock.elapsedRealtime()
                if (now - last < 400 && p < 100f) return@execute
                last = now
                val speed = SPEED_RE.find(line)?.groupValues?.get(1)
                val etaText = if (eta > 0) "متبقي ${fmtEta(eta)}" else null
                val processing = p < 0 && (line.startsWith("[Merger]") || line.startsWith("[ExtractAudio]") ||
                        line.startsWith("[VideoConvertor]") || line.startsWith("[FixupM4a]") || line.startsWith("[Fixup"))
                update(id) {
                    copy(
                        progress = if (p >= 0) p / 100f else progress,
                        info = when {
                            processing -> "جاري الدمج / التحويل..."
                            speed != null || etaText != null -> listOfNotNull(speed, etaText).joinToString(" · ")
                            else -> info
                        },
                    )
                }
            }
            if (id in canceled) throw InterruptedException()

            update(id) { copy(info = "جاري الحفظ في التنزيلات...", progress = 1f) }
            val saved = publish(tmp)
            if (saved == null) error("خلص التحميل بس ما لقيت الملف")
            update(id) { copy(status = Status.DONE, info = "", progress = 1f, savedName = saved) }
        } catch (t: Throwable) {
            if (id in canceled || t is InterruptedException || t is YoutubeDL.CanceledException) {
                update(id) { copy(status = Status.CANCELED, info = "") }
            } else {
                update(id) { copy(status = Status.FAILED, info = "", error = friendlyError(t)) }
            }
        } finally {
            canceled.remove(id)
            jobs.remove(id)
            tmp.deleteRecursively()
            pump()
        }
    }

    private fun buildRequest(item: Item, tmp: File): YoutubeDLRequest {
        val q = item.quality
        return YoutubeDLRequest(item.url).apply {
            addOption("--no-playlist")
            addOption("--no-mtime")
            addOption("--newline")
            addOption("--concurrent-fragments", 4)
            addOption("--retries", 5)
            addOption("--fragment-retries", 5)
            addOption("--socket-timeout", 30)
            addOption("-o", File(tmp, "%(title).100s.%(ext)s").absolutePath)
            val audio = q.audioFormat
            if (audio != null) {
                addOption("-f", if (audio == "m4a") "ba[ext=m4a]/ba/b" else "ba/b")
                addOption("-x")
                addOption("--audio-format", audio)
                addOption("--audio-quality", "0")
            } else {
                val h = q.height
                if (h == null) {
                    addOption("-f", "bv*+ba/b")
                    addOption("-S", "res,vcodec:h264,acodec:m4a")
                } else {
                    addOption("-f", "bv*[height<=$h]+ba/b[height<=$h]/b")
                    addOption("-S", "vcodec:h264,res,acodec:m4a")
                }
                addOption("--merge-output-format", "mp4")
            }
        }
    }

    // ------------------------------------------------------------------ step 4: move the file to Downloads/Murn

    private fun publish(tmp: File): String? {
        val files = tmp.listFiles { f ->
            f.isFile && !f.name.startsWith(".") &&
                    listOf(".part", ".ytdl", ".temp", ".json", ".webp", ".jpg", ".png").none { f.name.endsWith(it) }
        }?.sortedByDescending { it.length() }.orEmpty()
        val file = files.firstOrNull() ?: return null
        saveToDownloads(file)
        return file.name
    }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "mp4" -> "video/mp4"
        "mkv" -> "video/x-matroska"
        "webm" -> "video/webm"
        "mp3" -> "audio/mpeg"
        "m4a" -> "audio/mp4"
        "opus", "ogg" -> "audio/ogg"
        else -> "application/octet-stream"
    }

    private fun saveToDownloads(src: File) {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, src.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(src.name))
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Murn")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = app.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("ما قدرت أحفظ الملف")
            try {
                resolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
                val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
            } catch (t: Throwable) {
                runCatching { resolver.delete(uri, null, null) }
                throw t
            }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Murn")
            dir.mkdirs()
            var dst = File(dir, src.name)
            var n = 1
            while (dst.exists()) { dst = File(dir, "${src.nameWithoutExtension} ($n).${src.extension}"); n++ }
            src.copyTo(dst)
            MediaScannerConnection.scanFile(app, arrayOf(dst.absolutePath), null, null)
        }
    }

    // ------------------------------------------------------------------ helpers

    private fun update(id: String, f: Item.() -> Item) =
        items.update { list -> list.map { if (it.id == id) it.f() else it } }

    private fun setStatus(id: String, s: Status, info: String = "") = update(id) { copy(status = s, info = info) }

    private fun newId() = UUID.randomUUID().toString()

    private fun fmtEta(sec: Long): String {
        val h = sec / 3600
        val m = (sec % 3600) / 60
        val s = sec % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
    }

    private fun friendlyError(t: Throwable): String {
        val msg = t.message.orEmpty()
        val line = msg.lines().lastOrNull { it.contains("ERROR", ignoreCase = true) }?.substringAfter("ERROR:")?.trim()
            ?: msg.lines().lastOrNull { it.isNotBlank() }.orEmpty()
        return when {
            line.contains("Sign in to confirm", true) || line.contains("not a bot", true) ->
                "يوتيوب طلب تأكيد إنك مو روبوت. جرّب تحديث المحرك من الإعدادات أو غيّر الشبكة"
            line.contains("Private video", true) -> "الفيديو خاص"
            line.contains("unavailable", true) -> "الفيديو غير متاح (محذوف أو محجوب في بلدك)"
            line.contains("age", true) && line.contains("restrict", true) -> "الفيديو مقيّد بالعمر ويحتاج تسجيل دخول"
            line.contains("Unsupported URL", true) -> "الرابط هذا غير مدعوم"
            line.contains("Unable to download", true) || line.contains("timed out", true) || line.contains("resolve", true) ->
                "مشكلة بالاتصال بالإنترنت"
            line.contains("No space", true) -> "ما في مساحة كافية بالجوال"
            line.isBlank() -> "فشل التحميل"
            else -> line.take(160)
        }
    }

    private fun extractUrls(raw: String): List<String> =
        raw.split(Regex("\\s+"))
            .map { it.trim().trimEnd('.', ',', ')', ';', '،', '"', '\'') }
            .mapNotNull {
                when {
                    it.startsWith("http://", true) || it.startsWith("https://", true) -> it
                    BARE_DOMAIN_RE.matches(it) -> "https://$it"
                    else -> null
                }
            }
            .distinct()

    private val SPEED_RE = Regex("""at\s+(\S+/s)""")
    private val BARE_DOMAIN_RE = Regex("""^[\w-]+(\.[\w-]+)+/\S+$""")
    private const val MAX_PER_LINK = 1000
}
