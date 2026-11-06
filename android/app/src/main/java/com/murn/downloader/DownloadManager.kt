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
    val engineStatus = MutableStateFlow(tr("جاري تجهيز المحرك (أول مرة ياخذ شوي)...", "Preparing the engine (first time takes a moment)..."))
    val engineBusy = MutableStateFlow(true)
    val parallel = MutableStateFlow(3)
    val quality = MutableStateFlow(Quality.P1080)
    val paused = MutableStateFlow(false)
    /** false = links are treated as videos, true = as pictures */
    val imageMode = MutableStateFlow(false)

    fun setImageMode(b: Boolean) { imageMode.value = b }
    /** report of the tr("فحص الاتصال", "Connection check") button (null = no report to show) */
    val diagText = MutableStateFlow<String?>(null)

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
                engineStatus.value = tr("جاري التأكد من آخر تحديث للمحرك...", "Checking for the latest engine update...")
                // sites change all the time, so refresh yt-dlp on every start (but never wait more than 30s for it)
                val upd = async { runCatching { YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel._NIGHTLY) } }
                withTimeoutOrNull(30_000) { upd.await() }
                ready.complete(true)
                engineBusy.value = false
                engineStatus.value = tr("المحرك جاهز · ${engineVersion()}", "Engine ready · ${engineVersion()}")
            } catch (t: Throwable) {
                ready.complete(false)
                engineBusy.value = false
                engineStatus.value = tr("تعذر تجهيز المحرك: ${t.message ?: t.javaClass.simpleName}", "Could not prepare the engine: ${t.message ?: t.javaClass.simpleName}")
            }
        }
    }

    private fun baseDir(): File = app.getExternalFilesDir(null) ?: app.filesDir

    private fun engineVersion(): String =
        runCatching { YoutubeDL.getInstance().versionName(app) }.getOrNull().orEmpty().ifBlank { "yt-dlp" }

    /** Manual "update yt-dlp" button (the fix when a site stops working). */
    fun updateEngine() {
        if (engineBusy.value || items.value.any { it.status == Status.RUNNING }) {
            engineStatus.value = tr("ما ينفع التحديث وفي تحميل شغال، انتظر يخلص", "Can't update while a download is running, wait for it to finish")
            return
        }
        engineBusy.value = true
        engineStatus.value = tr("جاري تحديث المحرك...", "Updating the engine...")
        scope.launch {
            val msg = try {
                when (YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel._NIGHTLY)) {
                    YoutubeDL.UpdateStatus.DONE -> tr("تم تحديث المحرك", "Engine updated")
                    else -> tr("المحرك على آخر نسخة", "Engine is already up to date")
                }
            } catch (t: Throwable) {
                tr("فشل التحديث: ${t.message ?: "تأكد من الإنترنت"}", "Update failed: ${t.message ?: "check your internet"}")
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
            val images = imageMode.value
            jobs[id] = scope.launch { resolve(id, url, q, limit, pick, zip, batch, images) }
        }
        DownloadService.start(app)
        return urls.size
    }

    /** Search by name. [siteUrl] = search inside that site (its own search form); null = search YouTube. */
    fun search(query: String, siteUrl: String?, q: Quality, limit: Int, pick: Boolean, zip: Boolean) {
        val batch = newId()
        val id = newId()
        val where = if (siteUrl == null) tr("يوتيوب", "YouTube") else runCatching { java.net.URL(siteUrl).host }.getOrDefault(siteUrl)
        items.update { it + Item(id, siteUrl ?: "", title = splitTerms(query).joinToString("، ").let { tt -> tr("بحث: $tt ($where)", "Search: $tt ($where)") }, status = Status.RESOLVING, quality = q, batch = batch, zip = zip) }
        jobs[id] = scope.launch { resolveSearch(id, query, siteUrl, q, limit, pick, zip, batch, tr("نتائج «$query» في $where", "Results for “$query” in $where")) }
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

    // ------------------------------------------------------------------ diagnostics

    /** Lists which qualities the engine and the page itself offer for [url] (to see why a low quality was picked). */
    fun qualityCheck(url: String?) {
        if (url == null) {
            diagText.value = tr("الصق رابط الفيديو في خانة الروابط أول، وبعدين اضغط هذا الزر", "Paste the video link in the links box first, then press this button")
            return
        }
        diagText.value = tr("جاري فحص الجودات...", "Checking qualities...")
        scope.launch {
            val sb = StringBuilder()
            sb.appendLine(tr("النسخة ${Updater.currentName(app)}", "Version ${Updater.currentName(app)}"))
            sb.appendLine(tr("الرابط: $url", "Link: $url"))
            sb.appendLine()
            sb.appendLine(tr("جودات المحرك (yt-dlp):", "Engine formats (yt-dlp):"))
            try {
                if (!ready.await()) error(tr("المحرك غير جاهز", "Engine not ready"))
                val req = YoutubeDLRequest(url).apply {
                    addOption("-F"); addOption("--no-playlist"); addOption("--socket-timeout", 30)
                }
                val out = YoutubeDL.getInstance().execute(req, "q_check").out.orEmpty()
                val rows = out.lines().filter { it.isNotBlank() && !it.startsWith("[") }
                if (rows.isEmpty()) sb.appendLine(tr("(ما رجّع شي)", "(nothing returned)")) else rows.take(45).forEach { sb.appendLine(it.take(110)) }
            } catch (t: Throwable) {
                sb.appendLine(tr("المحرك ما قدر يقرأ الصفحة: ", "The engine could not read the page: ") + friendlyError(t).lines().first())
            }
            sb.appendLine()
            sb.appendLine(tr("روابط الفيديو اللي لقيتها في الصفحة:", "Video links found in the page:"))
            try {
                val l = MediaFind.describe(url)
                if (l.isEmpty()) sb.appendLine(tr("(ما لقيت روابط فيديو في كود الصفحة)", "(no video links in the page's code)")) else l.take(25).forEach { sb.appendLine(it) }
            } catch (t: Throwable) {
                sb.appendLine(tr("تعذر فتح الصفحة: ", "Could not open the page: ") + (t.message ?: t.javaClass.simpleName))
            }
            diagText.value = sb.toString()
        }
    }

    /** One tap that tells what works: internet, YouTube, the given site, the engine, the page scan. */
    fun diagnose(siteUrl: String?) {
        diagText.value = tr("جاري الفحص... (ياخذ نص دقيقة)", "Checking... (takes about half a minute)")
        scope.launch {
            val sb = StringBuilder()
            sb.appendLine(tr("النسخة ${Updater.currentName(app)} · أندرويد ${Build.VERSION.RELEASE}", "Version ${Updater.currentName(app)} · Android ${Build.VERSION.RELEASE}"))
            sb.appendLine(tr("المحرك: ${engineStatus.value}", "Engine: ${engineStatus.value}"))
            fun probe(label: String, url: String) {
                val r = try {
                    val c = (java.net.URL(url).openConnection() as java.net.HttpURLConnection).apply {
                        connectTimeout = 15_000; readTimeout = 15_000; instanceFollowRedirects = true
                        setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36")
                    }
                    val code = c.responseCode
                    c.disconnect()
                    "HTTP $code"
                } catch (t: Throwable) {
                    tr("فشل: ${t.javaClass.simpleName} ${t.message.orEmpty().take(80)}", "Failed: ${t.javaClass.simpleName} ${t.message.orEmpty().take(80)}")
                }
                sb.appendLine("$label: $r")
            }
            probe(tr("1) الإنترنت (google)", "1) Internet (google)"), "https://www.google.com/generate_204")
            probe(tr("2) موقع يوتيوب", "2) YouTube site"), "https://www.youtube.com/")
            if (siteUrl != null) probe(tr("3) الموقع اللي في الخانة", "3) The site in the box"), siteUrl)

            val engineOk = try { ready.await() } catch (_: Throwable) { false }
            if (!engineOk) {
                sb.appendLine(tr("4) المحرك: ما اشتغل أصلاً", "4) Engine: did not start at all"))
            } else {
                try {
                    val l = ytList("diag", "ytsearch2:test", null)
                    sb.appendLine(tr("4) بحث يوتيوب بالمحرك: نجح (${l.size} نتيجة)", "4) YouTube search with the engine: OK (${l.size} results)"))
                } catch (t: Throwable) {
                    sb.appendLine(tr("4) بحث يوتيوب بالمحرك: فشل", "4) YouTube search with the engine: failed") + "\n   ${friendlyError(t).replace("\n", "\n   ")}")
                }
                if (siteUrl != null) {
                    try {
                        val l = ytList("diag", siteUrl, 5)
                        sb.appendLine(tr("5) قراءة الموقع بالمحرك: نجح (${l.size} مقطع)", "5) Reading the site with the engine: OK (${l.size} videos)"))
                    } catch (t: Throwable) {
                        sb.appendLine(tr("5) قراءة الموقع بالمحرك: فشل", "5) Reading the site with the engine: failed") + "\n   ${friendlyError(t).replace("\n", "\n   ")}")
                    }
                    try {
                        val l = PageScan.scan(siteUrl)
                        sb.appendLine(tr("6) فحص الصفحة: لقى ${l.size} مقطع", "6) Page scan: found ${l.size} videos"))
                    } catch (t: Throwable) {
                        sb.appendLine(tr("6) فحص الصفحة: فشل ${t.javaClass.simpleName} ${t.message.orEmpty().take(100)}", "6) Page scan: failed ${t.javaClass.simpleName} ${t.message.orEmpty().take(100)}"))
                    }
                }
            }
            diagText.value = sb.toString()
        }
    }

    // ------------------------------------------------------------------ picker

    fun confirmPicker(id: String, chosen: List<Candidate>) {
        val req = pickers.value.firstOrNull { it.id == id } ?: return
        pickers.update { list -> list.filterNot { it.id == id } }
        pstates.remove(id)
        if (chosen.isNotEmpty()) enqueue(null, chosen.take(req.limit), req.quality, req.zip, req.batch)
        else maybeZip(req.batch)
    }

    fun dismissPicker(id: String) = confirmPicker(id, emptyList())

    // ---- "load more" / "refresh" inside the picker

    private enum class SK { YT_LIST, YT_SEARCH, SITE_SEARCH, PAGE }

    /** one place the picker's videos come from: a yt-dlp list, a YouTube search, or a scanned site page */
    private data class PSrc(
        val kind: SK, val term: String, val url: String?, val nexts: List<String>, val count: Int, val done: Boolean = false,
    )

    private class PState(val srcs: MutableList<PSrc>, val lists: MutableList<List<Candidate>>, val limit: Int, val multi: Boolean)

    private val pstates = ConcurrentHashMap<String, PState>()

    private fun setPicker(id: String, f: PickerRequest.() -> PickerRequest) =
        pickers.update { list -> list.map { if (it.id == id) it.f() else it } }

    private fun merged(st: PState): List<Candidate> = st.lists.flatten().distinctBy { it.url }.take(MAX_LIST)

    private fun splitTerms(q: String): List<String> =
        q.split(Regex("[,،;\\n]+")).map { it.trim() }.filter { it.isNotEmpty() }.distinct().take(10)

    /** Reads [url] and keeps following its "next page" until about [want] videos are found (or [maxPages] pages were read). */
    private fun scanMany(url: String, want: Int, maxPages: Int = 40): Pair<List<Candidate>, List<String>> {
        val first = PageScan.scanWithNext(url) // a failure of the first page is reported to the user
        val seen = first.first.mapTo(HashSet()) { it.url }
        val (more, nexts) = scanNext(first.second, seen, want - first.first.size, maxPages - 1)
        return (first.first + more) to nexts
    }

    /** Follows [starts] (possible addresses of the next page) page after page; only videos not in [seen] count. */
    private fun scanNext(starts: List<String>, seen: MutableSet<String>, want: Int, maxPages: Int): Pair<List<Candidate>, List<String>> {
        var nexts = starts
        val out = ArrayList<Candidate>()
        var pages = 0
        while (out.size < want && pages < maxPages && nexts.isNotEmpty()) {
            var advanced = false
            for (u in nexts) {
                val r = try { PageScan.scanWithNext(u) } catch (_: Throwable) { continue }
                val fresh = r.first.filter { seen.add(it.url) }
                if (fresh.isNotEmpty()) { out += fresh; nexts = r.second; pages++; advanced = true; break }
            }
            if (!advanced) { nexts = emptyList(); break } // no further page: the list is complete
        }
        return out to nexts
    }

    /** First load of a source. */
    private fun fetchFirst(pid: String, src: PSrc, limit: Int): Pair<PSrc, List<Candidate>> = when (src.kind) {
        SK.YT_LIST -> src.copy(count = limit, done = false) to ytList(pid, src.url!!, limit)
        SK.YT_SEARCH -> src.copy(count = limit, done = false) to ytList(pid, "ytsearch$limit:${src.term}", null)
        SK.SITE_SEARCH -> {
            val su = PageScan.findSearchUrl(src.url!!, src.term)
            val (c, nx) = scanMany(su, limit)
            PSrc(SK.PAGE, src.term, su, nx, 0, done = nx.isEmpty()) to c
        }
        SK.PAGE -> {
            val (c, nx) = scanMany(src.url!!, limit)
            src.copy(nexts = nx, done = nx.isEmpty()) to c
        }
    }

    /** The next batch of a source (only videos not already in [have]). */
    private fun fetchMore(pid: String, src: PSrc, have: Set<String>): Pair<PSrc, List<Candidate>> = when (src.kind) {
        SK.PAGE -> {
            // each press loads up to 8 more pages (about 200 more videos)
            val (fresh, nx) = scanNext(src.nexts, have.toMutableSet(), 200, 8)
            if (fresh.isNotEmpty()) src.copy(nexts = nx, done = nx.isEmpty()) to fresh
            else src.copy(done = true) to emptyList()
        }
        SK.YT_LIST, SK.YT_SEARCH -> {
            val n = minOf(src.count + 100, MAX_LIST)
            val all = if (src.kind == SK.YT_SEARCH) ytList(pid, "ytsearch$n:${src.term}", null) else ytList(pid, src.url!!, n)
            val fresh = all.filter { it.url !in have }
            src.copy(count = n, done = fresh.isEmpty() || n >= MAX_LIST) to fresh
        }
        SK.SITE_SEARCH -> src.copy(done = true) to emptyList()
    }

    fun pickerMore(id: String) = pickerReload(id, refresh = false)

    fun pickerRefresh(id: String) = pickerReload(id, refresh = true)

    private fun pickerReload(id: String, refresh: Boolean) {
        val st = pstates[id] ?: return
        if (pickers.value.firstOrNull { it.id == id }?.loading != false) return
        setPicker(id) { copy(loading = true, note = null) }
        scope.launch {
            var err: Throwable? = null
            var added = 0
            resolveGate.withPermit {
                try {
                    if (!ready.await()) error(tr("المحرك غير جاهز", "Engine not ready"))
                    for (i in st.srcs.indices) {
                        try {
                            val src = st.srcs[i]
                            val group = { c: Candidate -> if (st.multi) c.copy(group = src.term) else c }
                            if (refresh) {
                                val (ns, c) = fetchFirst("pk_$id", src, st.limit)
                                st.srcs[i] = ns; st.lists[i] = c.map(group)
                            } else if (!src.done) {
                                val have = merged(st).map { it.url }.toSet()
                                val (ns, fresh) = fetchMore("pk_$id", src, have)
                                st.srcs[i] = ns; st.lists[i] = st.lists[i] + fresh.map(group); added += fresh.size
                            }
                        } catch (t: Throwable) { err = err ?: t }
                    }
                } catch (t: Throwable) { err = t }
            }
            val all = merged(st)
            val note = when {
                err != null && all.isEmpty() -> friendlyError(err!!)
                err != null -> friendlyError(err!!)
                !refresh && added == 0 -> tr("ما لقيت المزيد", "No more results")
                else -> null
            }
            setPicker(id) {
                copy(candidates = all, loading = false, canMore = st.srcs.any { !it.done }, note = note, rev = if (refresh) rev + 1 else rev)
            }
        }
    }

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
        val title = str(o, "title") ?: str(o, "id") ?: tr("فيديو", "Video")
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
        val ck = File(baseDir(), "tmp/ck_$processId/cookies.txt")
        if (!target.startsWith("ytsearch") && CookieStore.exportTo(app, ck)) req.addOption("--cookies", ck.absolutePath)
        val out = try {
            YoutubeDL.getInstance().execute(req, processId).out.orEmpty()
        } finally {
            ck.parentFile?.deleteRecursively()
        }
        val start = out.indexOf('{')
        if (start < 0) error(tr("ما قدرت أقرأ الرابط", "Couldn't read the link"))
        val found = ArrayList<Candidate>()
        collect(JSONObject(out.substring(start)), found, null)
        return found
    }

    /** an error whose message is already written for the user */
    private class PageProblem(message: String) : Exception(message)

    private suspend fun resolve(phId: String, url: String, q: Quality, limit: Int, pick: Boolean, zip: Boolean, batch: String, images: Boolean = false) {
        var cands: List<Candidate>? = null
        var problem: Throwable? = null
        var srcInit: PSrc? = null
        resolveGate.withPermit {
            try {
                if (!ready.await()) error(tr("المحرك غير جاهز", "Engine not ready"))
                if (phId in canceled) throw InterruptedException()
                val directImg = SocialFix.isImageUrl(url)
                if (directImg || images) {
                    update(phId) { copy(info = tr("جاري البحث عن الصور...", "Looking for pictures...")) }
                    cands = if (directImg) listOf(Candidate(url, SocialFix.nameOf(url), url, null, true, url))
                    else ImageFind.find(app, url).also { if (it.isEmpty()) throw PageProblem(tr("ما لقيت صور في الصفحة", "No pictures found in the page")) }
                } else try {
                    cands = ytList(phId, url, limit)
                    srcInit = PSrc(SK.YT_LIST, "", url, emptyList(), limit)
                } catch (t: Throwable) {
                    if (phId in canceled) throw t
                    // yt-dlp could not list it -> if it is an ordinary site, read the page itself and list the links
                    // that have thumbnails (same idea as the Windows tool). Big platforms are not scraped.
                    val host = runCatching { java.net.URL(url).host.lowercase() }.getOrDefault("")
                    val big = listOf("youtube.", "youtu.be", "tiktok.", "instagram.", "twitter.", "x.com", "facebook.")
                    var scanned: List<Candidate> = emptyList()
                    var scanErr: Throwable? = null
                    var scanNexts: List<String> = emptyList()
                    if (big.none { host.contains(it) }) {
                        update(phId) { copy(info = tr("جاري فحص الصفحة...", "Scanning the page...")) }
                        try { val r = scanMany(url, limit); scanned = r.first; scanNexts = r.second } catch (e: Throwable) { scanErr = e }
                    }
                    if (scanned.isNotEmpty()) { cands = scanned; srcInit = PSrc(SK.PAGE, "", url, scanNexts, 0, done = scanNexts.isEmpty()) }
                    else if (scanErr != null) throw PageProblem(tr("تعذر فتح الصفحة: ${scanErr.message ?: scanErr.javaClass.simpleName}\n${friendlyError(t)}", "Could not open the page: ${scanErr.message ?: scanErr.javaClass.simpleName}\n${friendlyError(t)}"))
                    else throw t
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
            found != null -> deliver(phId, tr("الروابط", "Links"), found, q, limit, pick, zip, batch, listOfNotNull(srcInit), listOf(found))
            problem is PageProblem ->
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
        val terms = splitTerms(query).ifEmpty { listOf(query.trim()) }
        val multi = terms.size > 1
        val srcs = ArrayList<PSrc>()
        val lists = ArrayList<List<Candidate>>()
        val failedTerms = ArrayList<String>()
        var firstErr: Throwable? = null
        var problem: Throwable? = null
        resolveGate.withPermit {
            try {
                if (!ready.await()) error(tr("المحرك غير جاهز", "Engine not ready"))
                for ((n, term) in terms.withIndex()) {
                    if (phId in canceled) throw InterruptedException()
                    if (multi) update(phId) { copy(info = "${n + 1}/${terms.size}: $term") }
                    try {
                        val s0 = if (siteUrl == null) PSrc(SK.YT_SEARCH, term, null, emptyList(), limit)
                        else PSrc(SK.SITE_SEARCH, term, siteUrl, emptyList(), 0)
                        val (s1, c) = fetchFirst(phId, s0, limit)
                        srcs += s1
                        lists += c.map { if (multi) it.copy(group = term) else it }
                    } catch (t: Throwable) {
                        if (phId in canceled) throw t
                        failedTerms += term
                        firstErr = firstErr ?: t
                    }
                }
            } catch (t: Throwable) {
                problem = t
            }
        }
        val wasCanceled = canceled.remove(phId)
        jobs.remove(phId)
        val found = lists.flatten()
        val title = if (failedTerms.isEmpty()) label
        else label + tr(" (ما لقيت: ${failedTerms.joinToString("، ")})", " (nothing for: ${failedTerms.joinToString(", ")})")
        when {
            wasCanceled -> { setStatus(phId, Status.CANCELED); maybeZip(batch) }
            problem == null && lists.isNotEmpty() -> deliver(phId, title, found, q, limit, pick, zip, batch, srcs, lists, multi)
            else -> update(phId) { copy(status = Status.FAILED, error = friendlyError(problem ?: firstErr ?: IllegalStateException())) }
        }
    }

    /** Found [cands]: ask the user which ones (picker), or queue them all. */
    private fun deliver(
        phId: String, label: String, cands: List<Candidate>, q: Quality, limit: Int, pick: Boolean, zip: Boolean, batch: String,
        srcs: List<PSrc> = emptyList(), lists: List<List<Candidate>> = emptyList(), multi: Boolean = false,
    ) {
        val list = cands.distinctBy { it.url }.take(MAX_LIST)
        when {
            list.isEmpty() -> update(phId) { copy(status = Status.FAILED, error = tr("ما لقيت فيديوهات", "No videos found")) }
            list.size == 1 || !pick -> enqueue(phId, list.take(limit), q, zip, batch)
            else -> {
                items.update { l -> l.filterNot { it.id == phId } }
                val pid = newId()
                if (srcs.isNotEmpty()) pstates[pid] = PState(srcs.toMutableList(), lists.toMutableList(), limit, multi)
                pickers.update { it + PickerRequest(pid, label, list, limit, q, zip, batch, canMore = srcs.any { s -> !s.done }) }
            }
        }
    }

    /** Turns [cands] into queued rows (replacing the placeholder row [phId] when there is one). */
    private fun enqueue(phId: String?, cands: List<Candidate>, q: Quality, zip: Boolean, batch: String) {
        val rows = cands.map { Item(newId(), it.url, it.title, Status.QUEUED, q, group = it.group, batch = batch, zip = zip, image = it.isImage, referer = it.referer) }
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
                update(item.id) { copy(status = Status.RUNNING, progress = 0f, info = tr("جاري البدء...", "Starting..."), error = null) }
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
            if (!ready.await()) error(tr("المحرك غير جاهز", "Engine not ready"))
            if (id in canceled) throw InterruptedException()
            if (item.image) { downloadImage(id, item, tmp); return }

            try {
                runYtdlp(id, buildRequest(item, tmp))
            } catch (t: Throwable) {
                if (id in canceled || id in pausedIds || t is InterruptedException || t is YoutubeDL.CanceledException) throw t
                val text = t.message.orEmpty()
                val photoUrl = SocialFix.photoUrlIn(text) ?: item.url.takeIf { SocialFix.isTikTokPhoto(it) }
                val isTikTok = photoUrl != null || hostOf(item.url).contains("tiktok.")
                val host0 = hostOf(item.url)
                val imgWorthy = !host0.contains("youtu") &&
                        (text.contains("no video", true) || text.contains("Unsupported URL", true) || text.contains("Unable to extract", true))
                if (isBigHost(host0) && !isTikTok && imgWorthy && tryImages(id, item)) return
                if (text.contains("extracted extension", true)) {
                    // yt-dlp refuses files whose extension looks odd (Snapchat links end in a random code): allow it,
                    // and let ffmpeg repack the file into a normal mp4
                    update(id) { copy(info = tr("جاري المحاولة بطريقة بديلة...", "Trying an alternative way..."), progress = 0f) }
                    try {
                        runYtdlp(id, buildRequest(item, tmp, unsafeExt = true))
                    } catch (t2: Throwable) {
                        if (id in canceled || id in pausedIds || t2 is InterruptedException || t2 is YoutubeDL.CanceledException) throw t2
                        throw PageProblem(friendlyError(t2))
                    }
                } else if (isTikTok) {
                    // yt-dlp cannot read TikTok photo posts, and TikTok often serves yt-dlp an anti-bot page ("Unable to
                    // extract universal data"): open the post in the in-app browser and download from its data
                    val done = try {
                        tiktokViaBrowser(id, item, tmp, photoUrl ?: item.url)
                    } catch (t2: Throwable) {
                        if (id in canceled || id in pausedIds || t2 is InterruptedException || t2 is YoutubeDL.CanceledException) throw t2
                        if (t2 is PageProblem) throw t2
                        throw PageProblem(tr("تيك توك: ${t2.message ?: t2.javaClass.simpleName}\n${friendlyError(t)}", "TikTok: ${t2.message ?: t2.javaClass.simpleName}\n${friendlyError(t)}"))
                    }
                    if (done) return
                } else {
                val blocked = text.contains("451") || text.contains("403") || text.contains("HTTP Error", true) ||
                        text.contains("Unsupported URL", true) || text.contains("Unable to extract", true) ||
                        text.contains("No video formats", true) || text.contains("Unable to download webpage", true)
                if (!blocked || isBigHost(hostOf(item.url))) throw t
                // the site refuses yt-dlp's requests: read the page like a browser would, find the video file in it,
                // and hand that direct link to yt-dlp (with the page as referer)
                update(id) { copy(info = tr("جاري المحاولة بطريقة المتصفح...", "Trying browser mode..."), progress = 0f) }
                val reasons = ArrayList<String>()
                fun attempt(label: String, req: YoutubeDLRequest): Boolean = try {
                    runYtdlp(id, req); true
                } catch (t2: Throwable) {
                    if (id in canceled || id in pausedIds || t2 is InterruptedException || t2 is YoutubeDL.CanceledException) throw t2
                    reasons += "• $label: ${friendlyError(t2).lines().first().take(160)}"
                    false
                }
                var ok = false
                // 1) a video link found in the page's HTML
                val found = runCatching { MediaFind.find(item.url, item.quality) }.getOrNull()
                val media = found?.url
                val nameSuffix = found?.height?.let { " [${it}p]" }.orEmpty()
                if (media != null) ok = attempt(tr("رابط من الصفحة", "Link found in the page"), buildRequest(item, tmp, media, item.url, nameSuffix = nameSuffix))
                if (!ok) {
                    // 2) open the page in the in-app browser (JavaScript, Cloudflare checks, cookies) and use what it got
                    update(id) { copy(info = tr("جاري فتح الصفحة بالمتصفح الداخلي...", "Opening the page in the in-app browser..."), progress = 0f) }
                    val ses = try { WebSniff.session(app, item.url) } catch (e: Throwable) { null }
                    if (id in canceled || id in pausedIds) throw InterruptedException()
                    val lines = ses?.cookies?.takeIf { it.isNotBlank() }?.let { SocialFix.netscapeLines(item.url, it) }.orEmpty()
                    if (lines.isNotEmpty()) {
                        update(id) { copy(info = tr("جاري المحاولة مع كوكيز المتصفح...", "Retrying with the browser's cookies..."), progress = 0f) }
                        ok = attempt(tr("المحرك مع كوكيز المتصفح", "Engine with the browser's cookies"), buildRequest(item, tmp, null, null, lines))
                    }
                    val best = ses?.best
                    if (!ok && best != null && best != media) {
                        update(id) { copy(info = tr("جاري تحميل الفيديو الملتقط...", "Downloading the caught video..."), progress = 0f) }
                        val cdn = SocialFix.netscapeLines(best, WebSniff.cookiesFor(best))
                        ok = attempt(tr("الفيديو الملتقط من المتصفح", "Video caught in the browser"), buildRequest(item, tmp, best, item.url, lines + cdn))
                    }
                    if (!ok && ses != null && ses.best == null) reasons += tr("• المتصفح الداخلي ما لقى رابط فيديو في الصفحة", "• The in-app browser found no video link in the page")
                }
                if (!ok && tryImages(id, item)) return
                if (!ok) {
                    val vpn = if (text.contains("403") || text.contains("451"))
                        "\n" + tr("جرّب تطفي الـVPN أو تغيّر موقعه: بعض المواقع تحجب عناوين الـVPN.", "Try turning the VPN off or changing its location: some sites block VPN addresses.")
                    else ""
                    throw PageProblem(friendlyError(t) + "\n\n" + tr("المحاولات بعدها:", "Attempts after that:") + "\n" + reasons.joinToString("\n") + vpn)
                }
                }
            }
            if (id in canceled || id in pausedIds) throw InterruptedException()

            val file = pickMediaFile(tmp) ?: error(tr("خلص التحميل بس ما لقيت الملف", "Download finished but the file was not found"))
            if (item.zip) {
                val stage = File(baseDir(), "zip/${item.batch}").apply { mkdirs() }
                var dst = File(stage, file.name)
                var n = 1
                while (dst.exists()) { dst = File(stage, "${file.nameWithoutExtension} ($n).${file.extension}"); n++ }
                file.copyTo(dst)
            } else {
                update(id) { copy(info = tr("جاري الحفظ في التنزيلات...", "Saving to Downloads..."), progress = 1f) }
                saveToDownloads(file.name, mimeFor(file.name)) { out -> file.inputStream().use { it.copyTo(out) } }
            }
            val size = videoSize(file)
            val side = size?.let { minOf(it.first, it.second) }
            val resText = size?.let { "${side}p (${it.first}x${it.second})" }
            val wanted = item.quality.height
            val low = side != null && wanted != null && side < wanted * 0.8
            update(id) { copy(status = Status.DONE, info = "", progress = 1f, savedName = file.name, resolution = resText, lowRes = low) }
        } catch (t: Throwable) {
            val userCanceled = id in canceled
            val userPaused = id in pausedIds && !userCanceled
            when {
                userPaused -> {
                    keepTmp = true // .part files stay, so resume continues where it stopped
                    update(id) { copy(status = Status.PAUSED, info = tr("متوقف مؤقتاً", "Paused")) }
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

    /**
     * TikTok through the in-app browser. true = a photo post was saved (item is DONE);
     * false = a video file is now in [tmp] and the normal save step continues.
     */
    private suspend fun tiktokViaBrowser(id: String, item: Item, tmp: File, pageUrl: String): Boolean {
        update(id) { copy(info = tr("جاري فتح تيك توك بالمتصفح الداخلي...", "Opening TikTok in the in-app browser..."), progress = 0f) }
        val json = WebSniff.pageData(app, pageUrl, "__UNIVERSAL_DATA_FOR_REHYDRATION__")
            ?: throw PageProblem(tr("تيك توك ما رضي يفتح الصفحة (حماية ضد البرامج). جرّب تسجل دخولك من الإعدادات ← حسابات المنصات، أو غيّر الشبكة / شغّل VPN، وأعد المحاولة", "TikTok refused to open the page (anti-bot protection). Try signing in from Settings → Platform accounts, or change the network / use a VPN, then retry"))
        if (id in canceled || id in pausedIds) throw InterruptedException()
        val post = SocialFix.parseTikTok(json)
        if (!post.found) throw PageProblem(tr("المنشور غير متاح (محذوف أو خاص أو محجوب في بلدك)", "The post is unavailable (deleted, private or blocked in your country)"))
        val postTitle = post.title.ifBlank { tr("تيك توك", "TikTok") }
        update(id) { copy(title = postTitle.take(120)) }

        if (post.photos.isNotEmpty()) {
            val postId = SocialFix.postId(pageUrl)
            val files = ArrayList<File>()
            post.photos.forEachIndexed { i, u ->
                if (id in canceled || id in pausedIds) throw InterruptedException()
                update(id) { copy(progress = i / post.photos.size.toFloat(), info = tr("صورة ${i + 1} من ${post.photos.size}", "Picture ${i + 1} of ${post.photos.size}")) }
                files += SocialFix.download(u, tmp, "TikTok_${postId}_${i + 1}")
            }
            for (f in files) {
                if (item.zip) {
                    val stage = File(baseDir(), "zip/${item.batch}").apply { mkdirs() }
                    f.copyTo(File(stage, f.name), overwrite = true)
                } else {
                    val mime = when (f.extension) { "png" -> "image/png"; "webp" -> "image/webp"; else -> "image/jpeg" }
                    saveToDownloads(f.name, mime) { out -> f.inputStream().use { it.copyTo(out) } }
                }
            }
            update(id) { copy(status = Status.DONE, info = "", progress = 1f, savedName = tr("${files.size} صورة", "${files.size} pictures")) }
            return true
        }

        val video = post.videoUrl ?: throw PageProblem(tr("لقيت المنشور بس ما لقيت رابط الفيديو فيه", "Found the post but no video link in it"))
        val dest = File(tmp, safeName(postTitle) + ".mp4")
        SocialFix.downloadTo(
            video, dest, "https://www.tiktok.com/", WebSniff.cookiesFor(video),
            cancelled = { id in canceled || id in pausedIds },
        ) { p -> update(id) { copy(progress = p, info = tr("جاري التحميل...", "Downloading...")) } }
        return false
    }

    /** Real (width, height) of a downloaded video, turned upright if it carries a rotation flag. */
    private fun videoSize(f: File): Pair<Int, Int>? = runCatching {
        val r = android.media.MediaMetadataRetriever()
        try {
            r.setDataSource(f.absolutePath)
            val w = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            val rot = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (w == null || h == null) null else if (rot == 90 || rot == 270) h to w else w to h
        } finally {
            r.release()
        }
    }.getOrNull()

    /** No video in the link: look for pictures. true = pictures found (picker shown / queued), the row is replaced. */
    private suspend fun tryImages(id: String, item: Item): Boolean {
        update(id) { copy(info = tr("ما لقيت فيديو، جاري البحث عن صور...", "No video found, looking for pictures..."), progress = 0f) }
        val cands = try { ImageFind.find(app, item.url) } catch (_: Throwable) { emptyList() }
        if (id in canceled || id in pausedIds) throw InterruptedException()
        if (cands.isEmpty()) return false
        deliver(id, tr("صور الصفحة", "Pictures of the page"), cands, item.quality, 1000, true, item.zip, item.batch)
        return true
    }

    /** Downloads one picture file and saves it to Downloads/Murn. */
    private fun downloadImage(id: String, item: Item, tmp: File) {
        update(id) { copy(info = tr("جاري تحميل الصورة...", "Downloading the picture..."), progress = 0f) }
        val base = safeName(item.title.ifBlank { SocialFix.nameOf(item.url) }).take(80)
        val f = SocialFix.download(item.url, tmp, base, item.referer ?: item.url)
        if (id in canceled || id in pausedIds) throw InterruptedException()
        if (item.zip) {
            val stage = File(baseDir(), "zip/${item.batch}").apply { mkdirs() }
            f.copyTo(File(stage, f.name), overwrite = true)
        } else {
            saveToDownloads(f.name, mimeFor(f.name)) { out -> f.inputStream().use { it.copyTo(out) } }
        }
        val o = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
        android.graphics.BitmapFactory.decodeFile(f.absolutePath, o)
        val res = if (o.outWidth > 0) "${o.outWidth}x${o.outHeight}" else null
        update(id) { copy(status = Status.DONE, info = "", progress = 1f, savedName = f.name, resolution = res) }
    }

    private fun hostOf(url: String): String = runCatching { java.net.URL(url).host.lowercase() }.getOrDefault("")

    private fun isBigHost(host: String): Boolean =
        listOf("youtube.", "youtu.be", "tiktok.", "instagram.", "twitter.", "x.com", "facebook.").any { host.contains(it) }

    private fun safeName(title: String): String =
        title.replace(Regex("[\\\\/:*?\"<>|%\\r\\n]"), " ").replace(Regex("\\s+"), " ").trim().take(100).ifBlank { "video" }

    /** Runs one yt-dlp download of [req] for item [id], pushing progress into the list. */
    private fun runYtdlp(id: String, req: YoutubeDLRequest) {
        var last = 0L
        YoutubeDL.getInstance().execute(req, id) { p, eta, line ->
            val now = SystemClock.elapsedRealtime()
            if (now - last < 400 && p < 100f) return@execute
            last = now
            val speed = SPEED_RE.find(line)?.groupValues?.get(1)
            val etaText = if (eta > 0) tr("متبقي ${fmtEta(eta)}", "${fmtEta(eta)} left") else null
            val processing = p < 0 && (line.startsWith("[Merger]") || line.startsWith("[ExtractAudio]") ||
                    line.startsWith("[VideoConvertor]") || line.startsWith("[Fixup"))
            update(id) {
                copy(
                    progress = if (p >= 0) p / 100f else progress,
                    info = when {
                        processing -> tr("جاري الدمج / التحويل...", "Merging / converting...")
                        speed != null || etaText != null -> listOfNotNull(speed, etaText).joinToString(" · ")
                        else -> info
                    },
                )
            }
        }
    }

    private fun buildRequest(
        item: Item, tmp: File, mediaUrl: String? = null, referer: String? = null, cookieLines: String = "", nameSuffix: String = "", unsafeExt: Boolean = false,
    ): YoutubeDLRequest {
        val q = item.quality
        val host = hostOf(item.url)
        return YoutubeDLRequest(mediaUrl ?: item.url).apply {
            addOption("--no-playlist")
            addOption("--no-mtime")
            addOption("--newline")
            addOption("--concurrent-fragments", 4)
            addOption("--retries", 5)
            addOption("--fragment-retries", 5)
            addOption("--socket-timeout", 30)
            if (unsafeExt) {
                addOption("--compat-options", "allow-unsafe-ext")
                addOption("--remux-video", "mp4")
            }
            // logged-in platform accounts (Settings -> platform accounts); a private copy per download
            File(tmp, "cookies.txt").let { if (CookieStore.exportTo(app, it, cookieLines)) addOption("--cookies", it.absolutePath) }
            // a direct media link has no real title, so name the file after the video we picked
            addOption("-o", File(tmp, (if (mediaUrl != null) safeName(item.title) + nameSuffix else "%(title).100s%(height& [{}p]|)s") + ".%(ext)s").absolutePath)
            if (!isBigHost(host)) {
                // ordinary sites: look like the phone's browser
                addOption("--user-agent", PageScan.DESKTOP_UA)
                addOption("--referer", referer ?: (runCatching { java.net.URL(item.url).let { it.protocol + "://" + it.host + "/" } }.getOrNull() ?: item.url))
            }
            val audio = q.audioFormat
            if (audio != null) {
                addOption("-f", if (audio == "m4a") "ba[ext=m4a]/ba/b" else "ba/b")
                addOption("-x")
                addOption("--audio-format", audio)
                addOption("--audio-quality", "0")
            } else {
                val h = q.height
                // Pick by resolution first (res = the smaller side, so vertical videos like TikTok / Shorts are judged right).
                // "res:720" = the best resolution up to 720; a hard height filter would drop vertical 720x1280 videos
                // and fall back to a tiny one. h264 is only the tie-breaker between formats of the same resolution.
                addOption("-f", "bv*+ba/b")
                addOption("-S", (if (h == null) "res" else "res:$h") + ",vcodec:h264,acodec:m4a")
                addOption("--merge-output-format", "mp4")
            }
        }
    }

    // ------------------------------------------------------------------ step 5: saving

    private fun pickMediaFile(tmp: File): File? =
        tmp.listFiles { f ->
            f.isFile && !f.name.startsWith(".") &&
                    listOf(".part", ".ytdl", ".temp", ".json", ".webp", ".jpg", ".png", ".txt").none { f.name.endsWith(it) }
        }?.maxByOrNull { it.length() }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "mp4" -> "video/mp4"
        "mkv" -> "video/x-matroska"
        "webm" -> "video/webm"
        "mp3" -> "audio/mpeg"
        "m4a" -> "audio/mp4"
        "opus", "ogg" -> "audio/ogg"
        "zip" -> "application/zip"
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "gif" -> "image/gif"
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
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error(tr("ما قدرت أحفظ الملف", "Couldn't save the file"))
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
        if (t is PageProblem) return t.message.orEmpty()
        val msg = t.message.orEmpty()
        val line = msg.lines().lastOrNull { it.contains("ERROR", ignoreCase = true) }?.substringAfter("ERROR:")?.trim()
            ?: msg.lines().lastOrNull { it.isNotBlank() }.orEmpty()
        val raw = line.replace(Regex("\\s+"), " ").take(220)
        val friendly: String? = when {
            line.contains("Sign in to confirm", true) || line.contains("not a bot", true) ->
                tr("يوتيوب طلب تأكيد إنك مو روبوت. جرّب تحديث المحرك من الإعدادات أو غيّر الشبكة", "YouTube asked to confirm you are not a robot. Try updating the engine in Settings or change the network")
            line.contains("login required", true) || line.contains("requires authentication", true) ||
                    line.contains("cookies", true) || line.contains("rate-limit", true) ||
                    (line.contains("log in", true) && !line.contains("age", true)) ->
                tr("المنصة تطلب تسجيل دخول. من الإعدادات ← «حسابات المنصات» سجّل دخولك وأعد المحاولة", "The platform requires a login. In Settings → “Platform accounts” sign in and retry")
            line.contains("Private video", true) -> tr("الفيديو خاص", "The video is private")
            line.contains("Video unavailable", true) -> tr("الفيديو غير متاح (محذوف أو محجوب)", "The video is unavailable (deleted or blocked)")
            line.contains("451") -> tr("الموقع محجوب قانونياً في بلدك (451). جرّب VPN", "The site is legally blocked in your country (451). Try a VPN")
            line.contains("HTTP Error 403", true) || line.contains("403: Forbidden", true) ->
                tr("الموقع رفض الطلب (403). ممكن يحمي مقاطعه أو يحتاج VPN", "The site refused the request (403). It may protect its videos or need a VPN")
            line.contains("HTTP Error 404", true) -> tr("الصفحة غير موجودة (404)", "Page not found (404)")
            line.contains("Sign in", true) && line.contains("age", true) -> tr("المقطع يحتاج تسجيل دخول (عمر)", "The video needs a login (age restriction)")
            line.contains("Unsupported URL", true) -> tr("الرابط هذا غير مدعوم عند المحرك", "This link is not supported by the engine")
            line.contains("No address associated", true) || line.contains("Name or service not known", true) ||
                    line.contains("getaddrinfo", true) || line.contains("UnknownHost", true) ->
                tr("الجوال ما قدر يحوّل اسم الموقع لعنوان (DNS)، وغالباً مزود الإنترنت يحجب الموقع. من إعدادات الجوال ← الاتصال ← «DNS خاص» اكتب dns.google وجرّب، أو شغّل VPN",
                    "The phone could not resolve the site's name (DNS); your internet provider probably blocks it. In phone Settings → Connections → “Private DNS” enter dns.google and retry, or turn on a VPN")
            line.contains("Unable to download", true) || line.contains("timed out", true) ||
                    line.contains("resolve", true) || line.contains("UnknownHost", true) ||
                    line.contains("Connection", true) -> tr("مشكلة بالاتصال بالإنترنت", "Internet connection problem")
            line.contains("No space", true) -> tr("ما في مساحة كافية بالجوال", "Not enough storage on the phone")
            else -> null
        }
        return when {
            raw.isBlank() -> friendly ?: tr("فشل", "Failed")
            friendly == null -> raw
            else -> "$friendly\n$raw"
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
