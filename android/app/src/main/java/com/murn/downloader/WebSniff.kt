package com.murn.downloader

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Collections

/**
 * Last-resort "browser mode" for any link: opens the page in a hidden in-app browser (so JavaScript runs, cookies and
 * redirects work like in Chrome), presses play, and records the network requests. The first real video stream
 * (.m3u8 / .mp4 / .webm / .mpd) it sees is returned, and then handed to yt-dlp / ffmpeg to download.
 */
object WebSniff {
    private const val UA =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36"
    private val MEDIA = Regex("""\.(m3u8|mp4|webm|mpd)(\?|#|$)""", RegexOption.IGNORE_CASE)
    private val BAD = Regex("(doubleclick|googlesyndication|adservice|analytics|/ads?/|adserver|pixel|tracking)", RegexOption.IGNORE_CASE)

    // press play on every <video>, click the usual play buttons, and report a direct (non-blob) video address
    private const val JS = """
        (function(){
          try{
            document.querySelectorAll('video').forEach(function(v){try{v.muted=true;v.play();}catch(e){}});
            ['.vjs-big-play-button','.jw-icon-display','.plyr__control--overlaid','[class*=play-button]','[class*=PlayButton]','button[aria-label*=lay]']
              .forEach(function(s){var b=document.querySelector(s); if(b){try{b.click();}catch(e){}}});
            var v=document.querySelector('video'); var s=v&&(v.currentSrc||v.src);
            if(!s){var so=document.querySelector('video source'); s=so&&so.src;}
            return (s&&s.indexOf('http')===0)?s:'';
          }catch(e){return '';}
        })()
    """

    @SuppressLint("SetJavaScriptEnabled")
    suspend fun find(ctx: Context, pageUrl: String, timeoutMs: Long = 30_000): String? {
        val hits = Collections.synchronizedList(ArrayList<String>())
        var web: WebView? = null
        withContext(Dispatchers.Main) {
            val w = WebView(ctx.applicationContext)
            web = w
            w.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                mediaPlaybackRequiresUserGesture = false
                userAgentString = UA
            }
            CookieManager.getInstance().setAcceptCookie(true)
            CookieManager.getInstance().setAcceptThirdPartyCookies(w, true)
            w.webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                    val u = request.url.toString()
                    if (MEDIA.containsMatchIn(u) && !BAD.containsMatchIn(u) && u !in hits) hits += u
                    return null
                }

                override fun onPageFinished(view: WebView, url: String?) {
                    view.evaluateJavascript(JS) { r ->
                        val u = r?.trim('"')?.replace("\\/", "/").orEmpty()
                        if (u.startsWith("http") && MEDIA.containsMatchIn(u) && u !in hits) hits += u
                    }
                    // some players only start after a moment: poke them again
                    view.postDelayed({ view.evaluateJavascript(JS, null) }, 3000)
                }
            }
            w.loadUrl(pageUrl)
        }

        val start = System.currentTimeMillis()
        var firstHit = 0L
        while (System.currentTimeMillis() - start < timeoutMs) {
            delay(500)
            if (hits.isNotEmpty() && firstHit == 0L) firstHit = System.currentTimeMillis()
            // after the first hit give the page a few more seconds, so a better (m3u8) stream can show up
            if (firstHit != 0L && System.currentTimeMillis() - firstHit > 3500) break
        }
        withContext(Dispatchers.Main) { runCatching { web?.stopLoading(); web?.destroy() } }

        val all = synchronized(hits) { hits.toList() }
        return all.firstOrNull { it.contains(".m3u8", true) }
            ?: all.firstOrNull { it.contains(".mp4", true) }
            ?: all.firstOrNull()
    }
}
