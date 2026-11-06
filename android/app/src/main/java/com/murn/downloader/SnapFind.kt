package com.murn.downloader

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Snapchat links (Spotlight, public stories, profiles, the short t.snapchat.com links): reads the page's embedded data
 * and returns every picture AND video in it as direct files (Snapchat's file links have no normal extension, so they
 * are downloaded directly and named by their real type).
 */
object SnapFind {
    private val NEXT = Regex("""<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>""", RegexOption.DOT_MATCHES_ALL)
    private val OG = Regex("""<meta\b[^>]*>""", RegexOption.IGNORE_CASE)
    private val ATTR = Regex("""([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))""")

    fun isSnap(url: String): Boolean =
        runCatching { URL(url).host.lowercase().let { it == "snapchat.com" || it.endsWith(".snapchat.com") } }.getOrDefault(false)

    private class Snap(val url: String, val type: Int, val thumb: String?) // type: 0 picture, 1 video, -1 unknown

    private fun walk(n: Any?, out: MutableList<Snap>) {
        when (n) {
            is JSONObject -> {
                val urls = n.optJSONObject("snapUrls")
                val mu = urls?.optString("mediaUrl").orEmpty()
                if (mu.startsWith("http")) {
                    val t = when {
                        n.has("snapMediaType") -> n.optInt("snapMediaType", -1)
                        n.optString("mediaType").uppercase().contains("VIDEO") -> 1
                        n.optString("mediaType").uppercase().let { it.contains("IMAGE") || it.contains("PHOTO") } -> 0
                        else -> -1
                    }
                    out += Snap(mu, t, urls?.optString("mediaPreviewUrl")?.takeIf { it.startsWith("http") })
                } else {
                    val cu = n.optString("contentUrl")
                    if (cu.startsWith("http")) out += Snap(cu, 1, n.optString("thumbnailUrl").takeIf { it.startsWith("http") })
                }
                for (k in n.keys()) walk(n.opt(k), out)
            }
            is JSONArray -> for (i in 0 until n.length()) walk(n.opt(i), out)
        }
    }

    private fun parse(json: String?, single: Boolean): List<Snap> {
        if (json.isNullOrBlank()) return emptyList()
        val root = runCatching { JSONObject(json) }.getOrNull() ?: return emptyList()
        val all = ArrayList<Snap>()
        walk(root, all)
        val distinct = all.distinctBy { it.url }
        // a Spotlight page lists other people's videos too: only the first one is the post that was opened
        return if (single) distinct.take(1) else distinct
    }

    private fun contentType(url: String): String = runCatching {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "HEAD"; connectTimeout = 8_000; readTimeout = 8_000
            setRequestProperty("User-Agent", PageScan.DESKTOP_UA)
            setRequestProperty("Referer", "https://www.snapchat.com/")
        }
        try { c.responseCode; c.contentType.orEmpty().lowercase() } finally { c.disconnect() }
    }.getOrDefault("")

    suspend fun find(ctx: Context, url: String): List<Candidate> {
        val single = url.contains("/spotlight/", true)
        var html = ""
        var snaps: List<Snap> = emptyList()
        try {
            val (_, h) = PageScan.fetch(url, PageScan.DESKTOP_UA)
            html = h
            snaps = parse(NEXT.find(h)?.groupValues?.get(1), single)
        } catch (_: Throwable) {}
        if (snaps.isEmpty()) {
            // the page data is only there after the browser ran the page
            val json = try { WebSniff.pageData(ctx, url, "__NEXT_DATA__") } catch (_: Throwable) { null }
            snaps = parse(json, single)
        }
        if (snaps.isEmpty() && html.isNotEmpty()) {
            // last resort: the share-preview tags (og:video / og:image)
            val found = LinkedHashMap<String, Int>()
            for (m in OG.findAll(html)) {
                val a = ATTR.findAll(m.value).associate { x -> x.groupValues[1].lowercase() to x.groupValues[2].ifEmpty { x.groupValues[3].ifEmpty { x.groupValues[4] } } }
                val key = (a["property"] ?: a["name"] ?: "").lowercase()
                val c = a["content"]?.replace("&amp;", "&") ?: continue
                if (!c.startsWith("http")) continue
                if (key.startsWith("og:video")) found.putIfAbsent(c, 1) else if (key.startsWith("og:image")) found.putIfAbsent(c, 0)
            }
            snaps = found.map { (u, t) -> Snap(u, t, null) }
            if (found.values.any { it == 1 }) snaps = snaps.filter { it.type == 1 } // the preview picture of a video is not a snap
        }
        return snaps.mapIndexed { i, s ->
            val ct = if (s.type >= 0) "" else contentType(s.url)
            val video = if (s.type >= 0) s.type == 1 else ct.startsWith("video") || (ct.isEmpty() && s.url.contains(".mp4", true))
            val label = if (video) tr("فيديو", "video") else tr("صورة", "picture")
            Candidate(
                url = s.url,
                title = tr("سناب ${i + 1} ($label)", "Snap ${i + 1} ($label)"),
                thumb = if (video) s.thumb else s.url,
                group = null,
                isImage = true, // "a direct file": downloaded as is, named by its real type
                referer = "https://www.snapchat.com/",
            )
        }
    }
}
