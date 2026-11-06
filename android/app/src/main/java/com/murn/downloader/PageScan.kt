package com.murn.downloader

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Fallback for sites yt-dlp has no extractor for: read the normal web page (e.g. a site's home page or its
 * search-results page) and list the links that have a thumbnail on the same site. Every link is then handed to
 * yt-dlp one by one (its generic extractor finds the video inside the page).
 * Same idea as the Windows app's pagescan.py.
 */
object PageScan {
    private const val UA =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36"

    private val ANCHOR = Regex("<a\\b([^>]*)>(.*?)</a>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
    private val IMG = Regex("<img\\b([^>]*)>", RegexOption.IGNORE_CASE)
    private val FORM = Regex("<form\\b([^>]*)>(.*?)</form>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
    private val INPUT = Regex("<input\\b([^>]*)>", RegexOption.IGNORE_CASE)
    private val TAG = Regex("<[^>]*>")
    private val SPACES = Regex("\\s+")
    private val ATTR = Regex("""([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))""")
    private val JUNK = Regex("(login|register|ajax|favorites|/tag|/models?/?$)")

    private class Rec(var title: String, var thumb: String?)

    /** Returns (final url after redirects, html). */
    fun fetch(url: String): Pair<String, String> {
        var current = url
        repeat(6) {
            val c = (URL(current).openConnection() as HttpURLConnection).apply {
                setRequestProperty("User-Agent", UA)
                setRequestProperty("Accept-Language", "en,ar;q=0.8")
                connectTimeout = 20_000
                readTimeout = 25_000
                instanceFollowRedirects = false
            }
            try {
                val code = c.responseCode
                if (code in listOf(301, 302, 303, 307, 308)) {
                    val loc = c.getHeaderField("Location") ?: error("redirect without location")
                    current = URL(URL(current), loc).toString()
                    return@repeat
                }
                val cs = Regex("charset=([\\w-]+)", RegexOption.IGNORE_CASE)
                    .find(c.contentType.orEmpty())?.groupValues?.get(1)
                    ?.let { runCatching { java.nio.charset.Charset.forName(it) }.getOrNull() } ?: Charsets.UTF_8
                val body = (if (code >= 400) c.errorStream else c.inputStream)?.use { it.readBytes() } ?: ByteArray(0)
                if (code >= 400) error("HTTP $code")
                return current to String(body, cs)
            } finally {
                c.disconnect()
            }
        }
        error("too many redirects")
    }

    private fun unescape(s: String) = s
        .replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'").replace("&apos;", "'")
        .replace("&lt;", "<").replace("&gt;", ">").replace("&nbsp;", " ")

    private fun attrs(s: String): Map<String, String> = ATTR.findAll(s).associate { m ->
        val v = m.groupValues[2].ifEmpty { m.groupValues[3].ifEmpty { m.groupValues[4] } }
        m.groupValues[1].lowercase() to unescape(v)
    }

    private fun absolute(base: String, href: String): String? =
        runCatching { URL(URL(base), href).toString() }.getOrNull()

    /** Likely video links (links with a thumbnail) found on [pageUrl], same site only. */
    fun scan(pageUrl: String): List<Candidate> {
        val (final, html) = fetch(pageUrl)
        val host = URL(final).host
        val root = host.split('.').takeLast(2).joinToString(".")
        val seen = LinkedHashMap<String, Rec>()

        for (m in ANCHOR.findAll(html)) {
            val a = attrs(m.groupValues[1])
            val href = a["href"]?.trim()?.takeIf { it.isNotEmpty() } ?: continue
            val u = (absolute(final, href) ?: continue).substringBefore('#')
            val url = runCatching { URL(u) }.getOrNull() ?: continue
            if (url.protocol != "http" && url.protocol != "https") continue
            if (!url.host.contains(root)) continue
            if (url.path.isEmpty() || url.path == "/" || JUNK.containsMatchIn(u)) continue

            val inner = m.groupValues[2]
            val img = IMG.find(inner)?.let { attrs(it.groupValues[1]) }
            val thumb = img?.let { i ->
                listOf("data-src", "data-original", "src").mapNotNull { i[it] }
                    .firstOrNull { it.isNotBlank() && !it.startsWith("data:") }
                    ?.let { absolute(final, it) }
            }
            val text = unescape(inner.replace(TAG, " "))
            val title = (a["title"].orEmpty().ifBlank { img?.get("alt").orEmpty() }.ifBlank { text })
                .replace(SPACES, " ").trim()

            val old = seen[u]
            if (old != null) { // same video linked twice (thumbnail + title): keep the longest title / any thumb
                if (title.length > old.title.length) old.title = title
                if (old.thumb == null) old.thumb = thumb
                continue
            }
            if (img == null) continue
            seen[u] = Rec(title.ifBlank { url.path.trim('/').substringAfterLast('/') }, thumb)
        }
        return seen.map { (u, r) -> Candidate(u, r.title, r.thumb, host) }
    }

    /** Finds the site's own search form on [siteUrl] and builds the results-page URL for [query]. */
    fun findSearchUrl(siteUrl: String, query: String): String {
        val (final, html) = fetch(siteUrl)
        val prefer = setOf("q", "s", "k", "search", "query", "keyword", "keywords", "text", "kw", "search_query")
        class Input(val name: String?, val type: String, val value: String)

        var bestScore = -1
        var bestAction = ""
        var bestInputs: List<Input> = emptyList()
        var bestTexts: List<String> = emptyList()

        for (f in FORM.findAll(html)) {
            val fa = attrs(f.groupValues[1])
            if ((fa["method"] ?: "get").lowercase() != "get") continue
            val inputs = INPUT.findAll(f.groupValues[2]).map {
                val a = attrs(it.groupValues[1])
                Input(a["name"], (a["type"] ?: "text").lowercase(), a["value"].orEmpty())
            }.toList()
            val texts = inputs.filter { !it.name.isNullOrEmpty() && (it.type == "text" || it.type == "search") }.map { it.name!! }
            if (texts.isEmpty()) continue
            var score = if (inputs.any { it.type == "search" }) 2 else 0
            if (texts.any { it.lowercase() in prefer }) score += 1
            if (score > bestScore) {
                bestScore = score; bestAction = fa["action"].orEmpty(); bestInputs = inputs; bestTexts = texts
            }
        }
        if (bestScore < 0) error(tr("ما لقيت خانة بحث في هذا الموقع", "No search box found on this site"))

        val nameField = bestTexts.firstOrNull { it.lowercase() in prefer } ?: bestTexts.first()
        val params = bestInputs.filter { !it.name.isNullOrEmpty() && it.type == "hidden" }.map { it.name!! to it.value } +
                (nameField to query)
        val query2 = params.joinToString("&") { (k, v) -> URLEncoder.encode(k, "UTF-8") + "=" + URLEncoder.encode(v, "UTF-8") }
        val base = absolute(final, bestAction.ifEmpty { final }) ?: final
        return base + (if (base.contains('?')) "&" else "?") + query2
    }
}
