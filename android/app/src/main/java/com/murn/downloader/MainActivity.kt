@file:OptIn(ExperimentalMaterial3Api::class)

package com.murn.downloader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Badge
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.delay
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import kotlinx.coroutines.flow.MutableStateFlow

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Lang.init(this) // re-read: the language may have been changed from the phone settings
        enableEdgeToEdge()
        handleShare(intent)
        publishShareTarget()
        setContent {
            MurnTheme {
                CompositionLocalProvider(LocalLayoutDirection provides if (Lang.en) LayoutDirection.Ltr else LayoutDirection.Rtl) {
                    MainScreen()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShare(intent)
    }

    /** Registers Murn as a direct share target (shows up in the system share sheet). */
    private fun publishShareTarget() {
        runCatching {
            val info = androidx.core.content.pm.ShortcutInfoCompat.Builder(this, "murn_share")
                .setShortLabel(tr("تحميل بمرن", "Download with Murn"))
                .setLongLived(true)
                .setIcon(androidx.core.graphics.drawable.IconCompat.createWithResource(this, R.drawable.ic_launcher))
                .setIntent(Intent(this, MainActivity::class.java).setAction(Intent.ACTION_VIEW))
                .setCategories(setOf("com.murn.downloader.category.SHARE_TARGET"))
                .build()
            androidx.core.content.pm.ShortcutManagerCompat.pushDynamicShortcut(this, info)
        }
    }

    private fun handleShare(i: Intent?) {
        if (i?.action == Intent.ACTION_SEND) {
            i.getStringExtra(Intent.EXTRA_TEXT)?.let { sharedText.value = it }
        }
    }

    companion object {
        /** Text shared into the app from another app (YouTube "Share" -> Murn). */
        val sharedText = MutableStateFlow<String?>(null)
    }
}

@Composable
fun MurnTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val colors = if (dark) {
        darkColorScheme(
            primary = Color(0xFF3DCB85), onPrimary = Color(0xFF00210F),
            background = Color(0xFF14161C), surface = Color(0xFF14161C),
            surfaceVariant = Color(0xFF262A33), onSurface = Color(0xFFECEFF4),
            onSurfaceVariant = Color(0xFFB3B8C4), secondary = Color(0xFFE8C35A),
        )
    } else {
        lightColorScheme(
            primary = Color(0xFF0E7A43), secondary = Color(0xFF9A7B12),
            background = Color(0xFFF3F4F7), surface = Color(0xFFF3F4F7), surfaceVariant = Color(0xFFFFFFFF),
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}

@Composable
fun MainScreen() {
    val ctx = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val queue by DownloadManager.items.collectAsStateWithLifecycle()
    val pickers by DownloadManager.pickers.collectAsStateWithLifecycle()
    val quality by DownloadManager.quality.collectAsStateWithLifecycle()
    val engine by DownloadManager.engineStatus.collectAsStateWithLifecycle()
    val engineBusy by DownloadManager.engineBusy.collectAsStateWithLifecycle()
    val parallel by DownloadManager.parallel.collectAsStateWithLifecycle()
    val paused by DownloadManager.paused.collectAsStateWithLifecycle()
    val shared by MainActivity.sharedText.collectAsStateWithLifecycle()
    val diag by DownloadManager.diagText.collectAsStateWithLifecycle()
    val upd by Updater.state.collectAsStateWithLifecycle()
    var showUpdate by remember { mutableStateOf(false) }

    var input by rememberSaveable { mutableStateOf("") }
    var limitText by rememberSaveable { mutableStateOf("200") }
    var pick by rememberSaveable { mutableStateOf(true) }
    val zip = false // ZIP option removed from the screen
    var searchText by rememberSaveable { mutableStateOf("") }
    var searchInSite by rememberSaveable { mutableStateOf(false) }
    var qualityMenu by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var showAccounts by remember { mutableStateOf(false) }

    // Android 13+ needs permission to show the progress notification
    val notifPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    // quietly look for a new version when the app opens; if there is one, the update icon gets a dot
    LaunchedEffect(Unit) { Updater.check(ctx, silent = true) }

    // a link shared from another app lands in the box
    // ("Share -> Murn" from TikTok / Instagram / YouTube ...) the link starts downloading right away
    LaunchedEffect(shared) {
        shared?.let {
            MainActivity.sharedText.value = null
            val lim = limitText.trim().toIntOrNull()?.coerceIn(1, 200) ?: 200
            val n = DownloadManager.addLinks(it, quality, lim, pick, false)
            if (n > 0) Toast.makeText(ctx, tr("بدأ تحميل الرابط اللي شاركته", "Started downloading the link you shared"), Toast.LENGTH_SHORT).show()
            else input = if (input.isBlank()) it else input.trimEnd() + "\n" + it
        }
    }

    // a link copied with "Copy link" in another app is put in the box when Murn opens
    var clipCheck by remember { mutableIntStateOf(0) }
    DisposableEffect(Unit) {
        val lc = (ctx as? ComponentActivity)?.lifecycle
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_RESUME) clipCheck++ }
        lc?.addObserver(obs)
        onDispose { lc?.removeObserver(obs) }
    }
    LaunchedEffect(clipCheck) {
        delay(500) // the window must have focus before Android lets an app read the clipboard
        val url = clipboard.getText()?.text?.let { DownloadManager.firstUrl(it) } ?: return@LaunchedEffect
        val prefs = ctx.getSharedPreferences("murn", 0)
        if (url != prefs.getString("lastClip", null) && !input.contains(url)) {
            prefs.edit().putString("lastClip", url).apply()
            input = if (input.isBlank()) url else input.trimEnd() + "\n" + url
            Toast.makeText(ctx, tr("لقيت رابط منسوخ وحطيته في الخانة", "Found a copied link and put it in the box"), Toast.LENGTH_SHORT).show()
        }
    }

    val done = queue.count { it.status == Status.DONE }
    val failed = queue.count { it.status == Status.FAILED }
    val running = queue.count { it.status == Status.RUNNING }
    val waiting = queue.count { it.status == Status.QUEUED || it.status == Status.RESOLVING }
    val pausedCount = queue.count { it.status == Status.PAUSED }
    val limit = limitText.trim().toIntOrNull()?.coerceIn(1, 200) ?: 200

    fun scanLinks() {
        val n = DownloadManager.addLinks(input, quality, limit, pick, zip)
        if (n == 0) {
            Toast.makeText(ctx, tr("ما لقيت أي رابط في النص", "No link found in the text"), Toast.LENGTH_SHORT).show()
        } else {
            input = ""
            Toast.makeText(ctx, tr("جاري فحص $n رابط", "Scanning $n link(s)"), Toast.LENGTH_SHORT).show()
        }
    }

    fun doSearch() {
        val site = if (searchInSite) DownloadManager.firstUrl(input) else null
        if (searchInSite && site == null) {
            Toast.makeText(ctx, tr("حط رابط الموقع في الخانة اللي فوق أول، وبعدين ابحث", "Put the site link in the box above first, then search"), Toast.LENGTH_LONG).show()
            return
        }
        DownloadManager.search(searchText.trim(), site, quality, limit, pick, zip)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Download, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(8.dp))
                        Text(tr("مرن · محمّل الفيديوهات", "Murn · Video Downloader"))
                    }
                },
                actions = {
                    IconButton(onClick = { showUpdate = true; if (!Updater.hasUpdate) Updater.check(ctx) }) {
                        if (Updater.hasUpdate) {
                            BadgedBox(badge = { Badge() }) { Icon(Icons.Filled.SystemUpdate, tr("تحديث التطبيق", "Update app"), tint = MaterialTheme.colorScheme.secondary) }
                        } else {
                            Icon(Icons.Filled.SystemUpdate, tr("تحديث التطبيق", "Update app"))
                        }
                    }
                    IconButton(onClick = { showSettings = true }) { Icon(Icons.Filled.Settings, tr("الإعدادات", "Settings")) }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // ---------------------------------------------------- links
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(tr("الصق الروابط (رابط بكل سطر) — يوتيوب / تيك توك / تويتر / انستغرام وغيرها، أو رابط قائمة / قناة / صفحة موقع:", "Paste links (one per line) — YouTube / TikTok / Twitter / Instagram and more, or a playlist / channel / site page link:"),
                            style = MaterialTheme.typography.bodyMedium)
                        OutlinedTextField(
                            value = input,
                            onValueChange = { input = it },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 3,
                            maxLines = 8,
                            placeholder = { Text("https://www.youtube.com/playlist?list=...") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            OutlinedButton(onClick = {
                                clipboard.getText()?.text?.takeIf { it.isNotBlank() }?.let {
                                    input = if (input.isBlank()) it else input.trimEnd() + "\n" + it
                                }
                            }) {
                                Icon(Icons.Filled.ContentPaste, null)
                                Spacer(Modifier.width(6.dp))
                                Text(tr("لصق", "Paste"))
                            }
                            Box {
                                OutlinedButton(onClick = { qualityMenu = true }) {
                                    Text(tr("الجودة: ${quality.label}", "Quality: ${quality.label}"), maxLines = 1, overflow = TextOverflow.Ellipsis)
                                }
                                DropdownMenu(expanded = qualityMenu, onDismissRequest = { qualityMenu = false }) {
                                    Quality.entries.forEach { q ->
                                        DropdownMenuItem(text = { Text(q.label) }, onClick = {
                                            DownloadManager.setQuality(q); qualityMenu = false
                                        })
                                    }
                                }
                            }
                        }
                        OutlinedTextField(
                            value = limitText,
                            onValueChange = { s -> limitText = s.filter { it.isDigit() }.take(3) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text(tr("الحد الأقصى للمقاطع من كل رابط (1 إلى 200)", "Max videos per link (1 to 200)")) },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                        CheckRow(tr("أخليني أختار المقاطع (نافذة مربعات) إذا الرابط فيه مقاطع كثيرة", "Let me pick the videos (thumbnail grid) when a link has many"), pick) { pick = it }
                        Button(
                            onClick = { scanLinks() },
                            enabled = input.isNotBlank(),
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                        ) {
                            Icon(Icons.Filled.Download, null)
                            Spacer(Modifier.width(8.dp))
                            Text(tr("فحص الروابط وتحميلها", "Scan links and download"))
                        }
                    }
                }
            }

            // ---------------------------------------------------- search by name
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(tr("بحث بالاسم", "Search by name"), style = MaterialTheme.typography.titleSmall)
                        OutlinedTextField(
                            value = searchText,
                            onValueChange = { searchText = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text(tr("اكتب اسم اللي تبيه", "Type what you are looking for")) },
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(selected = !searchInSite, onClick = { searchInSite = false }, label = { Text(tr("في يوتيوب", "On YouTube")) })
                            FilterChip(selected = searchInSite, onClick = { searchInSite = true }, label = { Text(tr("داخل الموقع اللي فوق", "Inside the site above")) })
                        }
                        Button(
                            onClick = { doSearch() },
                            enabled = searchText.isNotBlank(),
                            modifier = Modifier.fillMaxWidth().height(46.dp),
                        ) {
                            Icon(Icons.Filled.Search, null)
                            Spacer(Modifier.width(8.dp))
                            Text(tr("ابحث", "Search"))
                        }
                    }
                }
            }

            // ---------------------------------------------------- queue header
            if (queue.isNotEmpty()) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            tr("الكل ${queue.size} · تم $done · شغال $running · ينتظر $waiting", "All ${queue.size} · done $done · running $running · waiting $waiting") +
                                    (if (pausedCount > 0) tr(" · متوقف $pausedCount", " · paused $pausedCount") else "") +
                                    (if (failed > 0) tr(" · فشل $failed", " · failed $failed") else ""),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            if (paused || pausedCount > 0) {
                                TextButton(onClick = { DownloadManager.resume() }) {
                                    Icon(Icons.Filled.PlayArrow, null); Spacer(Modifier.width(4.dp)); Text(tr("استئناف", "Resume"))
                                }
                            } else if (running > 0) {
                                TextButton(onClick = { DownloadManager.pause() }) {
                                    Icon(Icons.Filled.Pause, null); Spacer(Modifier.width(4.dp)); Text(tr("إيقاف مؤقت", "Pause"))
                                }
                            }
                            if (running + waiting + pausedCount > 0) TextButton(onClick = { DownloadManager.cancelAll() }) { Text(tr("إيقاف الكل", "Stop all")) }
                            if (failed > 0) TextButton(onClick = { DownloadManager.retryFailed() }) { Text(tr("إعادة الفاشل", "Retry failed")) }
                            TextButton(onClick = { DownloadManager.clearFinished() }) { Text(tr("مسح المكتمل", "Clear finished")) }
                        }
                    }
                }
            }

            items(queue, key = { it.id }) { item -> ItemRow(item) }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    // ---------------------------------------------------- thumbnail picker (one at a time)
    pickers.firstOrNull()?.let { req ->
        PickerDialog(
            req = req,
            onConfirm = { chosen -> DownloadManager.confirmPicker(req.id, chosen) },
            onDismiss = { DownloadManager.dismissPicker(req.id) },
        )
    }

    // ---------------------------------------------------- connection report
    diag?.let { report ->
        AlertDialog(
            onDismissRequest = { DownloadManager.diagText.value = null },
            confirmButton = { TextButton(onClick = { DownloadManager.diagText.value = null }) { Text(tr("إغلاق", "Close")) } },
            title = { Text(tr("تقرير الفحص", "Check report")) },
            text = {
                SelectionContainer {
                    Text(report, modifier = Modifier.verticalScroll(rememberScrollState()), style = MaterialTheme.typography.bodySmall)
                }
            },
        )
    }

    // ---------------------------------------------------- app update
    if (showUpdate) {
        AlertDialog(
            onDismissRequest = { showUpdate = false; Updater.reset() },
            confirmButton = {
                when (val u = upd) {
                    is Updater.State.Available ->
                        Button(onClick = { Updater.download(ctx) }) { Text(tr("حمّل وثبّت التحديث", "Download and install update")) }
                    is Updater.State.Ready ->
                        Button(onClick = { Updater.install(ctx, u.file) }) { Text(tr("ثبّت الحين", "Install now")) }
                    is Updater.State.Failed ->
                        Button(onClick = { Updater.check(ctx) }) { Text(tr("إعادة المحاولة", "Retry")) }
                    else -> TextButton(onClick = { showUpdate = false; Updater.reset() }) { Text(tr("تم", "Done")) }
                }
            },
            dismissButton = {
                if (upd is Updater.State.Available || upd is Updater.State.Ready || upd is Updater.State.Failed)
                    TextButton(onClick = { showUpdate = false; Updater.reset() }) { Text(tr("لاحقاً", "Later")) }
            },
            title = { Text(tr("تحديث التطبيق", "Update app")) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(tr("النسخة الحالية: ${Updater.currentName(ctx)}", "Current version: ${Updater.currentName(ctx)}"), style = MaterialTheme.typography.bodyMedium)
                    when (val u = upd) {
                        is Updater.State.Checking, Updater.State.Idle -> {
                            LinearProgressIndicator(Modifier.fillMaxWidth())
                            Text(tr("جاري البحث عن تحديث...", "Looking for an update..."))
                        }
                        is Updater.State.UpToDate -> Text(tr("عندك آخر نسخة، ما فيه تحديث جديد ✔", "You have the latest version, no new update ✔"))
                        is Updater.State.Available -> {
                            Text(tr("يوجد تحديث جديد: ${u.name}", "New update available: ${u.name}"), color = MaterialTheme.colorScheme.secondary)
                            if (u.notes.isNotBlank()) Text(u.notes, style = MaterialTheme.typography.bodySmall)
                            Text(tr("بينزل الملف (حوالي 105 ميجا) وبعدها يطلع لك تثبيت أندرويد، اضغط تثبيت وتتحدث النسخة فوق القديمة وتبقى إعداداتك.", "The file (about 105 MB) will download, then Android shows its install screen. Tap Install and the new version replaces the old one, keeping your settings."),
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        is Updater.State.Downloading -> {
                            LinearProgressIndicator(progress = { u.percent / 100f }, modifier = Modifier.fillMaxWidth())
                            Text(tr("جاري تنزيل ${u.name}... ${u.percent}%", "Downloading ${u.name}... ${u.percent}%"))
                        }
                        is Updater.State.Ready -> Text(tr("نزل التحديث ${u.name}. اضغط «ثبّت الحين» (إذا طلب السماح بالتثبيت من هذا التطبيق فعّله وارجع).", "Update ${u.name} downloaded. Tap “Install now” (if it asks to allow installs from this app, enable it and come back)."))
                        is Updater.State.Failed -> Text(u.msg, color = MaterialTheme.colorScheme.error)
                    }
                }
            },
        )
    }

    if (showAccounts) AccountsDialog(onDismiss = { showAccounts = false })

    // ---------------------------------------------------- settings
    if (showSettings) {
        AlertDialog(
            onDismissRequest = { showSettings = false },
            confirmButton = { TextButton(onClick = { showSettings = false }) { Text(tr("تم", "Done")) } },
            title = { Text(tr("الإعدادات", "Settings")) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(tr("اللغة:", "Language:"))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        FilterChip(selected = !Lang.en, onClick = { Lang.set(ctx, false) }, label = { Text("العربية") })
                        FilterChip(selected = Lang.en, onClick = { Lang.set(ctx, true) }, label = { Text("English") })
                    }
                    Text(tr("عدد الفيديوهات اللي تتحمل بنفس الوقت:", "Number of videos downloading at the same time:"))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(1, 2, 3, 4, 8, 16).forEach { n ->
                            FilterChip(selected = parallel == n, onClick = { DownloadManager.setParallel(n) }, label = { Text("$n") })
                        }
                    }
                    Text(tr("رقم كبير يبطّئ النت وممكن الموقع يحظرك.", "A big number slows the internet and the site may block you."), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(engine, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    OutlinedButton(onClick = { DownloadManager.updateEngine() }, enabled = !engineBusy) {
                        Icon(Icons.Filled.Refresh, null)
                        Spacer(Modifier.width(6.dp))
                        Text(tr("تحديث المحرك (إذا موقع وقف يحمّل)", "Update engine (if a site stopped downloading)"))
                    }
                    OutlinedButton(onClick = { showSettings = false; showAccounts = true }) {
                        Text(tr("حسابات المنصات (إنستغرام، فيسبوك، تيك توك، سناب...)", "Platform accounts (Instagram, Facebook, TikTok, Snap...)"))
                    }
                    OutlinedButton(onClick = {
                        showSettings = false
                        DownloadManager.diagnose(DownloadManager.firstUrl(input))
                    }) { Text(tr("فحص الاتصال (يطلّع تقرير)", "Connection check (shows a report)")) }
                    Text(
                        tr("الملفات تنحفظ في: التنزيلات / Murn", "Files are saved in: Downloads / Murn"),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
        )
    }
}

@Composable
private fun CheckRow(text: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(checked = checked, onCheckedChange = onChange)
        Text(text, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
    }
}

/** Full-screen grid: every video is a square tile with its picture and name, tap to select / unselect. */
@Composable
private fun PickerDialog(req: PickerRequest, onConfirm: (List<Candidate>) -> Unit, onDismiss: () -> Unit) {
    val total = req.candidates.size
    val max = req.limit
    val selected = remember(req.id) { mutableStateListOf<Int>().apply { addAll(0 until minOf(total, max)) } }
    var firstN by remember(req.id) { mutableStateOf("") }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Column(Modifier.systemBarsPadding().padding(horizontal = 10.dp).padding(top = 8.dp, bottom = 8.dp)) {
                Text(req.title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(
                    tr("محدد ${selected.size} من $total  (الحد الأقصى $max)", "Selected ${selected.size} of $total  (max $max)"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = firstN,
                        onValueChange = { s -> firstN = s.filter { it.isDigit() }.take(3) },
                        modifier = Modifier.width(96.dp),
                        singleLine = true,
                        label = { Text(tr("أول", "First")) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    )
                    OutlinedButton(onClick = {
                        val n = (firstN.toIntOrNull() ?: 0).coerceIn(0, minOf(total, max))
                        selected.clear(); selected.addAll(0 until n)
                    }) { Text(tr("تحديد", "Select")) }
                    OutlinedButton(onClick = { selected.clear(); selected.addAll(0 until minOf(total, max)) }) { Text(tr("الكل", "All")) }
                    TextButton(onClick = { selected.clear() }) { Text(tr("إلغاء التحديد", "Clear selection")) }
                }
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Button(
                        onClick = { onConfirm(selected.sorted().map { req.candidates[it] }) },
                        enabled = selected.isNotEmpty(),
                        modifier = Modifier.weight(1f).height(48.dp),
                    ) { Text(tr("تحميل المحدد (${selected.size})", "Download selected (${selected.size})")) }
                    OutlinedButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) { Text(tr("إلغاء", "Cancel")) }
                }
                Spacer(Modifier.height(8.dp))
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    itemsIndexed(req.candidates, key = { i, _ -> i }) { index, c ->
                        val on = index in selected
                        val shape = RoundedCornerShape(10.dp)
                        Column(
                            Modifier
                                .clip(shape)
                                .border(if (on) 3.dp else 1.dp, if (on) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline, shape)
                                .clickable {
                                    if (on) {
                                        selected.remove(index)
                                    } else if (selected.size < max) {
                                        selected.add(index)
                                    }
                                },
                        ) {
                            Box(Modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp))) {
                                if (c.thumb != null) {
                                    AsyncImage(
                                        model = c.thumb, contentDescription = null,
                                        contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize(),
                                    )
                                } else {
                                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                        Icon(Icons.Filled.Download, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                if (on) {
                                    Icon(
                                        Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.align(Alignment.TopStart).padding(6.dp),
                                    )
                                }
                            }
                            Text(
                                c.title, maxLines = 2, overflow = TextOverflow.Ellipsis,
                                style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(6.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ItemRow(item: Item) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(item.title, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyLarge)
                if (item.group != null) {
                    Text(item.group, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                when (item.status) {
                    Status.RESOLVING -> {
                        LinearProgressIndicator(Modifier.fillMaxWidth())
                        Text(item.info.ifEmpty { tr("جاري القراءة / البحث...", "Reading / searching...") }, style = MaterialTheme.typography.bodySmall)
                    }
                    Status.QUEUED -> Text(tr("بالانتظار", "Waiting"), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Status.RUNNING -> {
                        LinearProgressIndicator(progress = { item.progress }, modifier = Modifier.fillMaxWidth())
                        Text("${(item.progress * 100).toInt()}%  ${item.info}", style = MaterialTheme.typography.bodySmall)
                    }
                    Status.PAUSED -> {
                        LinearProgressIndicator(progress = { item.progress }, modifier = Modifier.fillMaxWidth())
                        Text(tr("⏸ متوقف مؤقتاً (${(item.progress * 100).toInt()}%)", "⏸ Paused (${(item.progress * 100).toInt()}%)"), style = MaterialTheme.typography.bodySmall)
                    }
                    Status.DONE -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(6.dp))
                        Text(if (item.zip) tr("تم (يدخل في ملف ZIP)", "Done (goes into the ZIP file)") else tr("تم التحميل", "Downloaded"), style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary)
                    }
                    Status.FAILED -> Row(verticalAlignment = Alignment.Top) {
                        Icon(Icons.Filled.Error, null, tint = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.width(6.dp))
                        Text(item.error ?: tr("فشل", "Failed"), maxLines = 5, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    }
                    Status.CANCELED -> Text(tr("⏹ متوقف", "⏹ Stopped"), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            when (item.status) {
                Status.RESOLVING, Status.QUEUED, Status.RUNNING, Status.PAUSED ->
                    IconButton(onClick = { DownloadManager.cancel(item.id) }) { Icon(Icons.Filled.Close, tr("إلغاء", "Cancel")) }
                Status.FAILED, Status.CANCELED ->
                    IconButton(onClick = { DownloadManager.retry(item.id) }) { Icon(Icons.Filled.Refresh, tr("إعادة", "Retry")) }
                Status.DONE -> IconButton(onClick = { DownloadManager.remove(item.id) }) { Icon(Icons.Filled.Close, tr("إخفاء", "Hide")) }
            }
        }
    }
}
