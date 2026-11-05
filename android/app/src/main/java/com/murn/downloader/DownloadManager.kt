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
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.Deflater
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * The whole download queue lives here (one process-wide instance), so it keeps working
 * while the screen is off / the activity is closed, as long as [DownloadService] keeps the process alive.
 *
 * Flow for every pasted link / search:
 *   1. RESOLVING : yt-dlp lists it (single video, playlist, channel...). Sites yt-dlp does not know are
 *                  read as a normal web page ([PageScan]) and their thumbnail links are listed.
 *   2. >1 video  : the picker (thumbnail grid) opens so you tick what you want  (or everything is queued directly)
 *   3. every chosen video is its own QUEUED row with its own progress bar
 *   4. up to [parallel] rows download at the same time (RUNNING)
 *   5. the finished file goes to  Downloads/Murn  (DONE) - or, in ZIP mode, into one ZIP when the batch finishes
 */
object DownloadManager {
    private lateinit var app: Application
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val resolveGate = Semaphore(2)
    private val jobs = ConcurrentHashMap<String, Job>()
    private val canceled: MutableSet<String> = Collections.synchronizedSet(HashSet())
    private val pausedIds: MutableSet<String> = Collections.synchronizedSet(HashSet())
    private val ready = CompletableDeferred<Boolean>()
    private val pumpLock = Any()
    private val zipLock = Any()

    val items = MutableStateFlow<List<Item>>(emptyList())
    val pickers = MutableStateFlow<List<PickerRequest>>(emptyList())
    val engineStatus = MutableStateFlow("جاري تجهيز المحرك (أول مرة ياخذ شوي)...")
    val engineBusy = MutableStateFlow(true)
    val parallel = MutableStateFlow(3)
    val quality = MutableStateFlow(Quality.P1080)
    val paused = MutableStateFlow(false)

    // ------------------------------------------------------------------ setup

    fun init(application: Application) {
        if (::app.isInitialized) return
        app = application
        val p = app.getSharedPreferences("murn", 0)
        parallel.value = p.getInt("parallel", 3).coerceIn(1, 16)
        quality.value = Quality.entries.firstOrNull { it.name == p.getString("quality", null) } ?: Quality.P1080
        // leftovers of a killed run
        File(baseDir(), "tmp").deleteRecursively()
        File(baseDir(), "zip").deleteRecursively()

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

    private fun baseDir(): File = app.getExternalFilesDir(null) ?: app.filesDir

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
        parallel.value = n.coerceIn(1, 16)
        app.getSharedPreferences("murn", 0).edit().putInt("parallel", parallel.value).apply()
        pump()
    }

    fun setQuality(q: Quality) {
        quality.value = q
        app.getSharedPreferences("murn", 0).edit().putString("quality", q.name).apply()
    }

    // ------------------------------------------------------------------ public actions

    /**
     * Accepts any text with links (one per line, or a whole shared message). Returns how many links it found.
     * [pick] = open the thumbnail picker when a link has several videos; [zip] = put everything in one ZIP.
     */
    fun addLinks(raw: String, q: Quality, limit: Int, pick: Boolean, zip: Boolean): Int {
        val urls = extractUrls(raw)
        if (urls.isEmpty()) return 0
        val batch = newId()
        for (url in urls) {
            val id = newId()
            items.update { it + Item(id, url, title = url, status = Status.RESOLVING, quality = q, batch = batch, zip = zip) }
            jobs[id] = scope.launch { resolve(id, url, q, limit, pick, zip, batch) }
        }
        DownloadService.start(app)
        return urls.size
    }

    /** Search by name. [siteUrl] = search inside that site (its own search form); null = search YouTube. */
    fun search(query: String, siteUrl: String?, q: Quality, limit: Int, pick: Boolean, zip: Boolean) {
        val batch = newId()
        val id = newId()
        val where = if (siteUrl == null) "يوتيوب" else runCatching { java.net.URL(siteUrl).host }.getOrDefault(siteUrl)
        items.update { it + Item(id, siteUrl ?: "", title = "بحث: $query ($where)", status = Status.RESOLVING, quality = q, batch = batch, zip = zip) }
        jobs[id] = scope.launch { resolveSearch(id, query, siteUrl, q, limit, pick, zip, batch, "نتائج «$query» في $where") }
        DownloadService.start(app)
    }

    fun cancel(id: String) {
        val item = items.value.firstOrNull { it.id == id } ?: return
        when (item.status) {
            Status.QUEUED -> setStatus(id, Status.CANCELED)
            Status.PAUSED -> {
                pausedIds -= id
                File(baseDir(), "tmp/$id").deleteRecursively()
                setStatus(id, Status.CANCELED)
                maybeZip(item.batch)
            }
            Status.RUNNING, Status.RESOLVING -> {
                canceled += id
                runCatching { YoutubeDL.getInstance().destroyProcessById(id) }
            }
            else -> Unit
        }
    }

    fun cancelAll() {
        paused.value = false
        items.value.filter { it.active || it.status == Status.PAUSED }.forEach { cancel(it.id) }
    }

    /** Stops every running download in the middle; resume continues each one from where it stopped. */
    fun pause() {
        if (paused.value) return
        paused.value = true
        for (item in items.value) {
            if (item.status == Status.RUNNING) {
                pausedIds += item.id
                runCatching { YoutubeDL.getInstance().destroyProcessById(item.id) }
            }
        }
    }

    fun resume() {
        if (!paused.value) return
        paused.value = false
        pausedIds.clear()
        items.update { list -> list.map { if (it.status == Status.PAUSED) it.copy(status = Status.QUEUED, info = "") else it } }
        DownloadService.start(app)
        pump()
    }

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

    // ------------------------------------------------------------------ picker

    fun confirmPicker(id: String, chosen: List<Candidate>) {
        val req = pickers.value.firstOrNull { it.id == id } ?: return
        pickers.update { list -> list.filterNot { it.id == id } }
        if (chosen.isNotEmpty()) enqueue(null, chosen.take(req.limit), req.quality, req.zip, req.batch)
        else maybeZip(req.batch)
    }

    fun dismissPicker(id: String) = confirmPicker(id, emptyList())

    // ------------------------------------------------------------------ step 1: expand a link / search into videos

    private fun str(o: JSONObject, key: String): String? =
        if (o.isNull(key)) null else o.optString(key).takeIf { it.isNotBlank() }

    /** Walks yt-dlp's JSON: playlists can contain playlists (channel tabs), single videos are leaves. */
    private fun collect(o: JSONObject, out: MutableList<Candidate>, group: String?) {
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
        val thumb = str(o, "thumbnail") ?: o.optJSONArray("thumbnails")?.let { arr ->
            (arr.length() - 1 downTo 0).firstNotNullOfOrNull { i -> arr.optJSONObject(i)?.let { str(it, "url") } }
        }
        if (link != null) out += Candidate(link, title, thumb, group)
    }

    /** Lists [target] (a link or "ytsearchN:text") with yt-dlp. Throws on failure. */
    private fun ytList(processId: String, target: String, limit: Int?): List<Candidate> {
        val req = YoutubeDLRequest(target).apply {
            addOption("--flat-playlist")
            addOption("--dump-single-json")
            addOption("--no-warnings")
            addOption("--skip-download")
            addOption("--socket-timeout", 30)
            if (limit != null) addOption("--playlist-end", limit)
        }
        val out = YoutubeDL.getInstance().execute(req, processId).out.orEmpty()
        val start = out.indexOf('{')
        if (start < 0) error("ما قدرت أقرأ الرابط")
        val found = ArrayList<Candidate>()
        collect(JSONObject(out.substring(start)), found, null)
        return found
    }

    private suspend fun resolve(phId: String, url: String, q: Quality, limit: Int, pick: Boolean, zip: Boolean, batch: String) {
        var cands: List<Candidate>? = null
        var problem: Throwable? = null
        resolveGate.withPermit {
            try {
                if (!ready.await()) error("المحرك غير جاهز")
                if (phId in canceled) throw InterruptedException()
                try {
                    cands = ytList(phId, url, limit)
                } catch (t: Throwable) {
                    if (phId in canceled) throw t
                    // yt-dlp does not know this site -> read the page itself and list the links that have thumbnails
                    if (t.message.orEmpty().contains("Unsupported URL", ignoreCase = true)) {
                        update(phId) { copy(info = "جاري فحص الصفحة...") }
                        val scanned = PageScan.scan(url)
                        if (scanned.isEmpty()) error("الموقع غير مدعوم وما لقيت مقاطع بالصفحة") else cands = scanned
                    } else {
                        throw t
                    }
                }
            } catch (t: Throwable) {
                problem = t
            }
        }

        val wasCanceled = canceled.remove(phId)
        jobs.remove(phId)
        val found = cands
        when {
            wasCanceled -> { setStatus(phId, Status.CANCELED); maybeZip(batch) }
            found != null -> deliver(phId, "الروابط", found, q, limit, pick, zip, batch)
            problem?.message.orEmpty().let { it.contains("الموقع غير مدعوم") } ->
                update(phId) { copy(status = Status.FAILED, error = problem?.message) }
            else -> {
                // could not list it -> still try the link as one single download, the download shows the real error
                update(phId) { copy(status = Status.QUEUED, title = url, info = "") }
                pump()
            }
        }
    }

    private suspend fun resolveSearch(
        phId: String, query: String, siteUrl: String?, q: Quality, limit: Int,
        pick: Boolean, zip: Boolean, batch: String, label: String,
    ) {
        var cands: List<Candidate>? = null
        var problem: Throwable? = null
        resolveGate.withPermit {
            try {
                if (!ready.await()) error("المحرك غير جاهز")
                if (phId in canceled) throw InterruptedException()
                cands = if (siteUrl == null) {
                    ytList(phId, "ytsearch$limit:$query", null)
                } else {
                    PageScan.scan(PageScan.findSearchUrl(siteUrl, query))
                }
            } catch (t: Throwable) {
                problem = t
            }
        }
        val wasCanceled = canceled.remove(phId)
        jobs.remove(phId)
        val found = cands
        when {
            wasCanceled -> { setStatus(phId, Status.CANCELED); maybeZip(batch) }
            found != null -> deliver(phId, label, found, q, limit, pick, zip, batch)
            else -> update(phId) { copy(status = Status.FAILED, error = friendlyError(problem ?: IllegalStateException())) }
        }
    }

    /** Found [cands]: ask the user which ones (picker), or queue them all. */
    private fun deliver(phId: String, label: String, cands: List<Candidate>, q: Quality, limit: Int, pick: Boolean, zip: Boolean, batch: String) {
        val list = cands.distinctBy { it.url }.take(MAX_LIST)
        when {
            list.isEmpty() -> update(phId) { copy(status = Status.FAILED, error = "ما لقيت فيديوهات") }
            list.size == 1 || !pick -> enqueue(phId, list.take(limit), q, zip, batch)
            else -> {
                items.update { l -> l.filterNot { it.id == phId } }
                pickers.update { it + PickerRequest(newId(), label, list, limit, q, zip, batch) }
            }
        }
    }

    /** Turns [cands] into queued rows (replacing the placeholder row [phId] when there is one). */
    private fun enqueue(phId: String?, cands: List<Candidate>, q: Quality, zip: Boolean, batch: String) {
        val rows = cands.map { Item(newId(), it.url, it.title, Status.QUEUED, q, group = it.group, batch = batch, zip = zip) }
        items.update { list ->
            if (phId == null) list + rows else list.flatMap { if (it.id == phId) rows else listOf(it) }
        }
        DownloadService.start(app)
        pump()
    }

    // ------------------------------------------------------------------ step 3: the scheduler

    private fun pump() {
        synchronized(pumpLock) {
            if (paused.value) return
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
        val tmp = File(baseDir(), "tmp/$id").apply { mkdirs() }
        var keepTmp = false
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
                        line.startsWith("[VideoConvertor]") || line.startsWith("[Fixup"))
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
            if (id in canceled || id in pausedIds) throw InterruptedException()

            val file = pickMediaFile(tmp) ?: error("خلص التحميل بس ما لقيت الملف")
            if (item.zip) {
                val stage = File(baseDir(), "zip/${item.batch}").apply { mkdirs() }
                var dst = File(stage, file.name)
                var n = 1
                while (dst.exists()) { dst = File(stage, "${file.nameWithoutExtension} ($n).${file.extension}"); n++ }
                file.copyTo(dst)
            } else {
                update(id) { copy(info = "جاري الحفظ في التنزيلات...", progress = 1f) }
                saveToDownloads(file.name, mimeFor(file.name)) { out -> file.inputStream().use { it.copyTo(out) } }
            }
            update(id) { copy(status = Status.DONE, info = "", progress = 1f, savedName = file.name) }
        } catch (t: Throwable) {
            val userCanceled = id in canceled
            val userPaused = id in pausedIds && !userCanceled
            when {
                userPaused -> {
                    keepTmp = true // .part files stay, so resume continues where it stopped
                    update(id) { copy(status = Status.PAUSED, info = "متوقف مؤقتاً") }
                }
                userCanceled || t is InterruptedException || t is YoutubeDL.CanceledException ->
                    update(id) { copy(status = Status.CANCELED, info = "") }
                else -> update(id) { copy(status = Status.FAILED, info = "", error = friendlyError(t)) }
            }
        } finally {
            canceled.remove(id)
            if (items.value.firstOrNull { it.id == id }?.status != Status.PAUSED) pausedIds.remove(id)
            jobs.remove(id)
            if (!keepTmp) tmp.deleteRecursively()
            maybeZip(item.batch)
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
                    // phones play h264 best, but YouTube only has h264 up to 1080p -> above that resolution wins
                    addOption("-S", if (h > 1080) "res,vcodec:h264,acodec:m4a" else "vcodec:h264,res,acodec:m4a")
                }
                addOption("--merge-output-format", "mp4")
            }
        }
    }

    // ------------------------------------------------------------------ step 5: saving

    private fun pickMediaFile(tmp: File): File? =
        tmp.listFiles { f ->
            f.isFile && !f.name.startsWith(".") &&
                    listOf(".part", ".ytdl", ".temp", ".json", ".webp", ".jpg", ".png").none { f.name.endsWith(it) }
        }?.maxByOrNull { it.length() }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "mp4" -> "video/mp4"
        "mkv" -> "video/x-matroska"
        "webm" -> "video/webm"
        "mp3" -> "audio/mpeg"
        "m4a" -> "audio/mp4"
        "opus", "ogg" -> "audio/ogg"
        "zip" -> "application/zip"
        else -> "application/octet-stream"
    }

    /** Writes a new file into  Downloads/Murn  (public folder, visible in the gallery / files app). */
    private fun saveToDownloads(name: String, mime: String, write: (OutputStream) -> Unit) {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Murn")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = app.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("ما قدرت أحفظ الملف")
            try {
                resolver.openOutputStream(uri)!!.use(write)
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
            val base = name.substringBeforeLast('.')
            val ext = name.substringAfterLast('.', "")
            var dst = File(dir, name)
            var n = 1
            while (dst.exists()) { dst = File(dir, "$base ($n).$ext"); n++ }
            dst.outputStream().use(write)
            MediaScannerConnection.scanFile(app, arrayOf(dst.absolutePath), null, null)
        }
    }

    /** ZIP mode: when nothing of the batch is left to do, pack everything downloaded into one ZIP. */
    private fun maybeZip(batch: String) {
        if (batch.isEmpty()) return
        synchronized(zipLock) {
            val stage = File(baseDir(), "zip/$batch")
            if (!stage.isDirectory) return
            val pending = items.value.any { it.batch == batch && (it.active || it.status == Status.PAUSED) } ||
                    pickers.value.any { it.batch == batch }
            if (pending) return
            val files = stage.listFiles()?.filter { it.isFile }?.sortedBy { it.name }.orEmpty()
            try {
                if (files.isNotEmpty()) {
                    val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
                    saveToDownloads("Murn_$stamp.zip", "application/zip") { out ->
                        ZipOutputStream(out.buffered()).use { zip ->
                            zip.setLevel(Deflater.NO_COMPRESSION) // videos are already compressed
                            for (f in files) {
                                zip.putNextEntry(ZipEntry(f.name))
                                f.inputStream().use { it.copyTo(zip) }
                                zip.closeEntry()
                            }
                        }
                    }
                }
            } catch (_: Throwable) {
                return // keep the staged files, the next call tries again
            }
            stage.deleteRecursively()
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
            line.contains("Unable to download", true) || line.contains("timed out", true) ||
                    line.contains("resolve", true) || line.contains("UnknownHost", true) -> "مشكلة بالاتصال بالإنترنت"
            line.contains("No space", true) -> "ما في مساحة كافية بالجوال"
            line.isBlank() -> "فشل"
            else -> line.take(160)
        }
    }

    private fun extractUrls(raw: String): List<String> {
        val tokens = raw.split(Regex("\\s+")).map { it.trim().trimEnd('.', ',', ')', ';', '،', '"', '\'') }.filter { it.isNotEmpty() }
        return tokens.mapNotNull {
            when {
                it.startsWith("http://", true) || it.startsWith("https://", true) -> it
                BARE_PATH_RE.matches(it) -> "https://$it"
                // a bare site name (m.example.com) counts only when it is the only thing pasted, or starts with www.
                BARE_HOST_RE.matches(it) && (tokens.size == 1 || it.startsWith("www.", true)) -> "https://$it"
                else -> null
            }
        }.distinct()
    }

    /** First link in free text (used for "search inside the site in the box above"). */
    fun firstUrl(raw: String): String? = extractUrls(raw).firstOrNull()

    private val SPEED_RE = Regex("""at\s+(\S+/s)""")
    private val BARE_PATH_RE = Regex("""^[\w-]+(\.[\w-]+)+/\S*$""")
    private val BARE_HOST_RE = Regex("""^[\w-]+(\.[\w-]+)+$""")
    private const val MAX_LIST = 1000
}
