package com.murn.downloader

import java.net.URL

/**
 * Finds the direct video file (mp4 / webm / m3u8) inside an ordinary video page, reading the page with the phone's own
 * HTTP stack (like a browser would). Used when a site refuses yt-dlp's requests for the page.
 */
object MediaFind {
    private val EXT = Regex("""https?://[^\s"'<>\\]+?\.(?:mp4|m3u8|webm)(?:\?[^\s"'<>\\]*)?""", RegexOption.IGNORE_CASE)
    private val TAG = Regex("""<(?:source|video)\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
    private val META = Regex("""(?:og:video(?::url|:secure_url)?|contentUrl)["']?\s*(?:content\s*=|:)\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
    private val HEIGHT = Regex("""(?<!\d)(2160|1440|1080|720|480|360|240)(?!\d)""")

    private fun absolute(base: String, href: String): String? =
        runCatching { URL(URL(base), href.trim()).toString() }.getOrNull()

    /** Best direct media link for the wanted quality, or null if the page has none. */
    fun find(pageUrl: String, quality: Quality): String? {
        val (final, raw) = PageScan.fetch(pageUrl)
        val html = raw.replace("\\/", "/").replace("\\u0026", "&").replace("&amp;", "&")
        val found = LinkedHashSet<String>()
        EXT.findAll(html).forEach { found += it.value }
        TAG.findAll(html).forEach { m -> absolute(final, m.groupValues[1])?.let { found += it } }
        META.findAll(html).forEach { m -> absolute(final, m.groupValues[1])?.let { found += it } }

        val target = quality.height ?: Int.MAX_VALUE
        return found
            .filter { it.startsWith("http") }
            .filterNot { u -> listOf(".jpg", ".jpeg", ".png", ".gif", ".webp", ".js", ".css", ".vtt", ".srt").any { u.substringBefore('?').endsWith(it, true) } }
            .maxByOrNull { u ->
                val path = u.substringBefore('?').lowercase()
                val h = HEIGHT.find(u)?.value?.toInt() ?: 0
                (if (path.endsWith(".mp4")) 1_000_000 else 0) +
                        (if (h in 1..target) h else if (h == 0) 1 else 0)
            }
    }
}
