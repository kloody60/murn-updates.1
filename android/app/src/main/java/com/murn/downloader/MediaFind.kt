package com.murn.downloader

import java.net.URL

/**
 * Finds the direct video file (mp4 / webm / m3u8) inside an ordinary video page, reading the page with the phone's own
 * HTTP stack (like a browser would). Used when a site refuses yt-dlp's requests for the page.
 *
 * Pages usually list several qualities of the same video; the quality of each link is read from its name
 * (..._720p.mp4) or from the label written next to it (video_url_text: '720p', "label":"1080p", res="480"...).
 */
object MediaFind {
    class Found(val url: String, val height: Int?)

    private class Hit(val url: String, val start: Int, val end: Int) {
        var height: Int? = null
    }

    private val EXT = Regex("""https?://[^\s"'<>\\]+?\.(?:mp4|m3u8|webm)/?(?:\?[^\s"'<>\\]*)?""", RegexOption.IGNORE_CASE)
    private val TAG = Regex("""<(?:source|video)\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
    private val META = Regex("""(?:og:video(?::url|:secure_url)?|contentUrl)["']?\s*(?:content\s*=|:)\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)

    private val LBL_P = Regex("""(?<!\d)(\d{3,4})\s*[pP](?![A-Za-z0-9])""")
    private val LBL_KEY = Regex("""(?:label|res|resolution|quality|height|size|title|text)["']?\s*[:=]\s*["']?(\d{3,4})(?!\d)""", RegexOption.IGNORE_CASE)
    private val LBL_WORD = Regex("""\b(4k|2k|fhd|uhd)\b""", RegexOption.IGNORE_CASE)
    private val STANDARD = setOf(144, 240, 360, 480, 540, 576, 720, 1080, 1440, 2160, 4320)

    private fun absolute(base: String, href: String): String? =
        runCatching { URL(URL(base), href.trim()).toString() }.getOrNull()

    private fun heightIn(seg: String): Int? {
        LBL_P.find(seg)?.groupValues?.get(1)?.toIntOrNull()?.takeIf { it in STANDARD }?.let { return it }
        LBL_KEY.find(seg)?.groupValues?.get(1)?.toIntOrNull()?.takeIf { it in STANDARD }?.let { return it }
        return when (LBL_WORD.find(seg)?.value?.lowercase()) {
            "4k", "uhd" -> 2160
            "2k" -> 1440
            "fhd" -> 1080
            else -> null
        }
    }

    private val NOT_VIDEO = listOf(".jpg", ".jpeg", ".png", ".gif", ".webp", ".js", ".css", ".vtt", ".srt")

    /** All video links of the page with the quality read for each (null = unknown). */
    private fun scanHits(pageUrl: String): List<Hit> {
        // the same page as seen by a desktop browser and by a phone: HD links are often only in one of them
        val all = ArrayList<Hit>()
        val seenUrls = HashSet<String>()
        var failure: Throwable? = null
        for (ua in listOf(PageScan.DESKTOP_UA, null)) {
            try {
                val r = if (ua == null) PageScan.fetch(pageUrl) else PageScan.fetch(pageUrl, ua)
                for (h in scanHtml(r.first, r.second)) if (seenUrls.add(h.url)) all += h
            } catch (t: Throwable) { failure = failure ?: t }
        }
        if (all.isEmpty() && failure != null) throw failure
        return all
    }

    private fun scanHtml(final: String, raw: String): List<Hit> {
        val html = raw.replace("\\/", "/").replace("\\u0026", "&").replace("&amp;", "&")

        val hits = ArrayList<Hit>()
        val seen = HashSet<String>()
        fun add(u: String, s: Int, e: Int) { if (seen.add(u)) hits += Hit(u, s, e) }
        EXT.findAll(html).forEach { add(it.value, it.range.first, it.range.last + 1) }
        TAG.findAll(html).forEach { m -> absolute(final, m.groupValues[1])?.let { add(it, m.range.first, m.range.last + 1) } }
        META.findAll(html).forEach { m -> absolute(final, m.groupValues[1])?.let { add(it, m.range.first, m.range.last + 1) } }

        hits.retainAll { h ->
            h.url.startsWith("http") && NOT_VIDEO.none { h.url.substringBefore('?').trimEnd('/').endsWith(it, true) }
        }
        hits.sortBy { it.start }
        for ((i, h) in hits.withIndex()) {
            // 1) the quality is in the file name  2) a label right after the link  3) a label right before it
            var q = heightIn(h.url.substringBefore('?'))
            if (q == null) {
                val limit = hits.getOrNull(i + 1)?.start ?: html.length
                var fwd = html.substring(minOf(h.end, html.length), minOf(h.end + 220, limit, html.length))
                fwd.indexOfAny(charArrayOf('}', '>')).let { if (it >= 0) fwd = fwd.substring(0, it) }
                q = heightIn(fwd)
            }
            if (q == null) {
                val from = maxOf(hits.getOrNull(i - 1)?.end ?: 0, h.start - 220, 0)
                var back = html.substring(from, minOf(h.start, html.length))
                back.lastIndexOfAny(charArrayOf('{', '<')).let { if (it >= 0) back = back.substring(it) }
                q = heightIn(back)
            }
            h.height = q
        }
        return hits
    }

    /** For the "check qualities" report: every video link found in the page and the quality read for it. */
    fun describe(pageUrl: String): List<String> =
        scanHits(pageUrl).map { (it.height?.let { h -> "${h}p" } ?: "?") + "  " + it.url.take(110) }

    /** Best direct media link for the wanted quality, or null if the page has none. */
    fun find(pageUrl: String, quality: Quality): Found? {
        val hits = scanHits(pageUrl)
        if (hits.isEmpty()) return null

        val target = quality.height ?: Int.MAX_VALUE
        fun isHls(h: Hit) = h.url.substringBefore('?').trimEnd('/').endsWith(".m3u8", true)
        val labeled = hits.filter { !isHls(it) && it.height != null }
        val best = labeled.filter { it.height!! <= target }.maxByOrNull { it.height!! }
            ?: labeled.minByOrNull { it.height!! }
        // an HLS playlist lets yt-dlp choose the quality itself: prefer it when no direct file reaches the wanted height
        val hls = hits.firstOrNull { isHls(it) && (it.height == null || it.height!! >= (best?.height ?: 0)) }
        val pick = when {
            best != null && best.height!! >= minOf(target, 1080) -> best
            hls != null -> hls
            best != null -> best
            else -> hits.firstOrNull { !isHls(it) } ?: hits.first()
        }
        return Found(pick.url, pick.height)
    }
}
