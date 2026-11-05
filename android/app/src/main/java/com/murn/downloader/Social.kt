package com.murn.downloader

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

private const val MOBILE_UA =
    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36"

/**
 * Login for the social platforms. The user signs in once inside the app (a normal web page); the cookies of that
 * session are saved per platform in Netscape format and handed to yt-dlp (--cookies) so it can download what only
 * a logged-in account can see (Instagram / Facebook / TikTok / Snapchat / X). Cookies never leave the phone, except
 * to the platform they belong to.
 */
object CookieStore {
    class Platform(val key: String, val label: String, val loginUrl: String, val cookieUrls: List<String>, val domains: List<String>)

    val platforms = listOf(
        Platform("instagram", "إنستغرام", "https://www.instagram.com/accounts/login/",
            listOf("https://www.instagram.com"), listOf("instagram.com")),
        Platform("facebook", "فيسبوك", "https://m.facebook.com/login/",
            listOf("https://www.facebook.com", "https://m.facebook.com"), listOf("facebook.com")),
        Platform("tiktok", "تيك توك", "https://www.tiktok.com/login",
            listOf("https://www.tiktok.com"), listOf("tiktok.com")),
        Platform("snapchat", "سناب شات", "https://accounts.snapchat.com/accounts/v2/login",
            listOf("https://www.snapchat.com", "https://accounts.snapchat.com"), listOf("snapchat.com")),
        Platform("x", "إكس (تويتر)", "https://x.com/i/flow/login",
            listOf("https://x.com", "https://twitter.com"), listOf("x.com", "twitter.com")),
    )

    private fun dir(ctx: Context) = File(ctx.filesDir, "cookies").apply { mkdirs() }
    private fun fileOf(ctx: Context, p: Platform) = File(dir(ctx), "${p.key}.txt")

    fun isLoggedIn(ctx: Context, p: Platform): Boolean = fileOf(ctx, p).let { it.isFile && it.length() > 0 }

    /** Reads the cookies the login page just set and stores them. Returns how many were saved. */
    fun save(ctx: Context, p: Platform): Int {
        val cm = CookieManager.getInstance()
        cm.flush()
        val expiry = System.currentTimeMillis() / 1000 + 365L * 24 * 3600
        val lines = LinkedHashMap<String, String>()
        for (u in p.cookieUrls) {
            val host = URL(u).host
            val d = p.domains.firstOrNull { host.endsWith(it) } ?: continue
            val raw = cm.getCookie(u) ?: continue
            for (part in raw.split(';')) {
                val kv = part.trim()
                val eq = kv.indexOf('=')
                if (eq <= 0) continue
                val name = kv.substring(0, eq)
                val value = kv.substring(eq + 1)
                lines["$d|$name"] = ".$d\tTRUE\t/\tTRUE\t$expiry\t$name\t$value"
            }
        }
        if (lines.isEmpty()) return 0
        fileOf(ctx, p).writeText(lines.values.joinToString("\n", postfix = "\n"))
        return lines.size
    }

    fun logout(ctx: Context, p: Platform) {
        fileOf(ctx, p).delete()
        runCatching {
            val cm = CookieManager.getInstance()
            for (u in p.cookieUrls) cm.getCookie(u)?.split(';')?.forEach { c ->
                val name = c.trim().substringBefore('=')
                val host = URL(u).host
                cm.setCookie(u, "$name=; Max-Age=0; Domain=.${p.domains.firstOrNull { host.endsWith(it) } ?: host}; Path=/")
            }
            cm.flush()
        }
    }

    /** Writes all saved logins into one Netscape cookies file for yt-dlp. False = nobody is logged in. */
    fun exportTo(ctx: Context, dest: File): Boolean {
        val parts = platforms.map { fileOf(ctx, it) }.filter { it.isFile && it.length() > 0 }
        if (parts.isEmpty()) return false
        dest.parentFile?.mkdirs()
        dest.writeText("# Netscape HTTP Cookie File\n" + parts.joinToString("") { it.readText() })
        return true
    }
}

/** Fixes for posts yt-dlp cannot read by itself. */
object SocialFix {
    private val PHOTO_URL = Regex("""https?://[^\s'"]*tiktok\.com/[^\s'"]*/photo/\d+[^\s'"]*""")

    fun isTikTokPhoto(url: String) = url.contains("tiktok.com/") && url.contains("/photo/")

    /** yt-dlp says "Unsupported URL: <the real photo link>" even for short vt.tiktok.com links; pull that link out. */
    fun photoUrlIn(text: String): String? = PHOTO_URL.find(text)?.value

    fun asVideoUrl(url: String) = url.replace("/photo/", "/video/")

    fun postId(url: String) = Regex("""/photo/(\d+)""").find(url)?.groupValues?.get(1) ?: "post"

    /** The picture links of a TikTok photo post (reads the page's embedded JSON like a browser would). */
    fun tiktokPhotos(url: String): List<String> {
        val (_, html) = PageScan.fetch(url)
        val out = LinkedHashSet<String>()
        val m = Regex("""<script[^>]*id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>""", RegexOption.DOT_MATCHES_ALL).find(html)
        if (m != null) runCatching { collectImages(JSONObject(m.groupValues[1]), out) }
        if (out.isEmpty()) {
            Regex("""<meta[^>]*property="og:image"[^>]*content="([^"]+)"""").find(html)
                ?.groupValues?.get(1)?.replace("&amp;", "&")?.let { out += it }
        }
        return out.toList()
    }

    private fun collectImages(node: Any?, out: MutableSet<String>) {
        when (node) {
            is JSONObject -> {
                val post = node.optJSONObject("imagePost")
                if (post != null) {
                    val imgs = post.optJSONArray("images")
                    if (imgs != null) for (i in 0 until imgs.length()) {
                        val list = imgs.optJSONObject(i)?.optJSONObject("imageURL")?.optJSONArray("urlList")
                        val u = list?.let { l -> (0 until l.length()).map { l.optString(it) }.firstOrNull { it.startsWith("http") } }
                        if (u != null) out += u.replace("\\u002F", "/")
                    }
                    return
                }
                for (k in node.keys()) collectImages(node.opt(k), out)
            }
            is JSONArray -> for (i in 0 until node.length()) collectImages(node.opt(i), out)
        }
    }

    /** Downloads [url] to a file named [base] + the right extension. */
    fun download(url: String, dir: File, base: String): File {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            setRequestProperty("User-Agent", MOBILE_UA)
            setRequestProperty("Referer", "https://www.tiktok.com/")
            connectTimeout = 20_000
            readTimeout = 30_000
        }
        try {
            if (c.responseCode != 200) error("HTTP ${c.responseCode}")
            val ext = when {
                c.contentType.orEmpty().contains("webp") -> "webp"
                c.contentType.orEmpty().contains("png") -> "png"
                else -> "jpg"
            }
            val f = File(dir, "$base.$ext")
            c.inputStream.use { i -> f.outputStream().use { o -> i.copyTo(o) } }
            return f
        } finally {
            c.disconnect()
        }
    }
}

// ---------------------------------------------------------------------------------------- UI

@Composable
fun AccountsDialog(onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    var refresh by remember { mutableIntStateOf(0) }
    var loginFor by remember { mutableStateOf<CookieStore.Platform?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("تم") } },
        title = { Text("حسابات المنصات") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "سجّل دخولك مرة وحدة عشان التطبيق يقدر يحمّل اللي يحتاج حساب (ستوري، منشورات خاصة بحسابك، مقاطع محدودة العمر...). " +
                            "المقاطع العامة تحمّلها بدون تسجيل. بيانات الدخول تبقى بالجوال بس.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                val logged = remember(refresh) { CookieStore.platforms.associateWith { CookieStore.isLoggedIn(ctx, it) } }
                CookieStore.platforms.forEach { p ->
                    val on = logged[p] == true
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(p.label + if (on) "  ✔ مسجّل" else "")
                        if (on) {
                            OutlinedButton(onClick = { CookieStore.logout(ctx, p); refresh++ }) { Text("خروج") }
                        } else {
                            Button(onClick = { loginFor = p }) { Text("تسجيل دخول") }
                        }
                    }
                }
            }
        },
    )

    loginFor?.let { p ->
        LoginDialog(p, onSaved = { loginFor = null; refresh++ }, onCancel = { loginFor = null })
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LoginDialog(p: CookieStore.Platform, onSaved: () -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var web by remember { mutableStateOf<WebView?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }

    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Column(Modifier.systemBarsPadding()) {
                Row(Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Button(onClick = {
                        val n = CookieStore.save(ctx, p)
                        if (n > 0) onSaved() else msg = "ما لقيت جلسة دخول، سجّل دخولك أول ثم اضغط حفظ"
                    }) { Text("تم تسجيل الدخول - احفظ") }
                    OutlinedButton(onClick = onCancel) { Text("إلغاء") }
                }
                msg?.let { Text(it, Modifier.padding(horizontal = 12.dp), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
                Text("سجّل دخولك في ${p.label} بالصفحة تحت، وبعدها اضغط «احفظ».", Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.bodySmall)
                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { c ->
                        WebView(c).apply {
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            settings.userAgentString = MOBILE_UA
                            CookieManager.getInstance().setAcceptCookie(true)
                            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                            webViewClient = WebViewClient()
                            loadUrl(p.loginUrl)
                            web = this
                        }
                    },
                    onRelease = { it.destroy() },
                )
            }
        }
    }
}
