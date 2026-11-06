package com.murn.downloader

import android.content.Context
import java.net.URL

/**
 * Pictures from any page / post: reads the page like a browser (og:image, links to full-size files, <img> with the
 * biggest srcset entry); when the page builds its pictures with JavaScript (Instagram, X, Pinterest ...) it is opened
 * in the in-app browser (with the logins saved in Settings) and the loaded pictures are collected.
 */
object ImageFind {
    private val IMG_EXT = Regex("""\.(?:jpe?g|png|webp|gif|bmp|avif)(?:$|[?#])""", RegexOption.IGNORE_CASE)
    private val JUNK = Regex("(logo|icon|sprite|avatar|favicon|pixel|spacer|blank|placeholder|emoji|badge|banner|/ads?/|\\.svg|loading|1x1|tracking)", RegexOption.IGNORE_CASE)
    private val ANCHOR = Regex("<a\\b([^>]*)>(.*?)</a>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
    private val IMG = Regex("<img\\b([^>]*)>", RegexOption.IGNORE_CASE)
    private val META = Regex("""<meta\b[^>]*>""", RegexOption.IGNORE_CASE)
    private val ATTR = Regex("""([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))""")

    private fun attrs(s: String): Map<String, String> = ATTR.findAll(s).associate { m ->
        val v = m.groupValues[2].ifEmpty { m.groupValues[3].ifEmpty { m.groupValues[4] } }
        m.groupValues[1].lowercase() to v.replace("&amp;", "&")
    }

    private fun absolute(base: String, href: String): String? =
        runCatching { URL(URL(base), href.trim()).toString() }.getOrNull()

    /** the biggest address in a srcset ("a.jpg 320w, b.jpg 1080w") */
    private fun bestOfSrcset(v: String): String? =
        v.split(',').mapNotNull { part ->
            val p = part.trim().split(Regex("\\s+"))
            if (p.isEmpty() || p[0].isBlank()) null else p[0] to (p.getOrNull(1)?.trimEnd('w', 'x')?.toDoubleOrNull() ?: 0.0)
        }.maxByOrNull { it.second }?.first

    private fun httpFind(pageUrl: String): List<Candidate> {
        val (final, html) = PageScan.fetch(pageUrl, PageScan.DESKTOP_UA)
        val out = LinkedHashMap<String, Candidate>()
        val thumbs = HashSet<String>()
        fun add(url: String, title: String, thumb: String?) {
            if (!url.startsWith("http") || JUNK.containsMatchIn(url) || url in out) return
            out[url] = Candidate(url, title.ifBlank { SocialFix.nameOf(url) }.take(120), thumb ?: url, null, true, final)
        }
        for (m in META.findAll(html)) {
            val a = attrs(m.value)
            val key = (a["property"] ?: a["name"] ?: "").lowercase()
            if (key.startsWith("og:image") || key.startsWith("twitter:image")) a["content"]?.let { c -> absolute(final, c)?.let { add(it, "", null) } }
        }
        for (m in ANCHOR.findAll(html)) {
            val a = attrs(m.groupValues[1])
            val href = absolute(final, a["href"].orEmpty()) ?: continue
            if (!IMG_EXT.containsMatchIn(href)) continue
            val img = IMG.find(m.groupValues[2])?.let { attrs(it.groupValues[1]) }
            val t = img?.let { i -> listOf("data-src", "src").mapNotNull { i[it] }.firstOrNull { it.isNotBlank() && !it.startsWith("data:") } }?.let { absolute(final, it) }
            if (t != null) thumbs += t
            add(href, img?.get("alt").orEmpty(), t)
        }
        for (m in IMG.findAll(html)) {
            val a = attrs(m.groupValues[1])
            val raw = listOf("srcset", "data-srcset").mapNotNull { a[it]?.let(::bestOfSrcset) }.firstOrNull()
                ?: listOf("data-original", "data-src", "data-lazy-src", "src").mapNotNull { a[it] }.firstOrNull { it.isNotBlank() && !it.startsWith("data:") }
                ?: continue
            val u = absolute(final, raw) ?: continue
            if (u in thumbs) continue
            val w = a["width"]?.toIntOrNull()
            val h = a["height"]?.toIntOrNull()
            if ((w != null && w < 120) || (h != null && h < 120)) continue
            add(u, a["alt"].orEmpty(), null)
        }
        return out.values.toList()
    }

    /** Pictures of [pageUrl] (a gallery, a post...). Empty = none found. */
    suspend fun find(ctx: Context, pageUrl: String): List<Candidate> {
        val http = try { httpFind(pageUrl) } catch (_: Throwable) { emptyList() }
        if (http.size >= 4) return http
        // few or none in the plain HTML: the page probably builds them with JavaScript -> in-app browser
        val web = try { WebSniff.images(ctx, pageUrl) } catch (_: Throwable) { emptyList() }
        val merged = LinkedHashMap<String, Candidate>()
        http.forEach { merged[it.url] = it }
        for (u in web) if (u !in merged && !JUNK.containsMatchIn(u)) merged[u] = Candidate(u, SocialFix.nameOf(u), u, null, true, pageUrl)
        return merged.values.toList()
    }
}
