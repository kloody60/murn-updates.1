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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.flow.MutableStateFlow

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleShare(intent)
        setContent {
            MurnTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    MainScreen()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShare(intent)
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
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
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
    val quality by DownloadManager.quality.collectAsStateWithLifecycle()
    val engine by DownloadManager.engineStatus.collectAsStateWithLifecycle()
    val engineBusy by DownloadManager.engineBusy.collectAsStateWithLifecycle()
    val parallel by DownloadManager.parallel.collectAsStateWithLifecycle()
    val shared by MainActivity.sharedText.collectAsStateWithLifecycle()

    var input by rememberSaveable { mutableStateOf("") }
    var maxText by rememberSaveable { mutableStateOf("") }
    var qualityMenu by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

    // Android 13+ needs permission to show the progress notification
    val notifPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    // a link shared from another app lands in the box
    LaunchedEffect(shared) {
        shared?.let {
            input = if (input.isBlank()) it else input.trimEnd() + "\n" + it
            MainActivity.sharedText.value = null
        }
    }

    val done = queue.count { it.status == Status.DONE }
    val failed = queue.count { it.status == Status.FAILED }
    val running = queue.count { it.status == Status.RUNNING }
    val waiting = queue.count { it.status == Status.QUEUED || it.status == Status.RESOLVING }

    fun start() {
        val max = maxText.trim().toIntOrNull()?.takeIf { it > 0 }
        val n = DownloadManager.addLinks(input, quality, max)
        if (n == 0) {
            Toast.makeText(ctx, "ما لقيت أي رابط في النص", Toast.LENGTH_SHORT).show()
        } else {
            input = ""
            Toast.makeText(ctx, "تمت إضافة $n رابط للتحميل", Toast.LENGTH_SHORT).show()
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("مرن · محمّل الفيديوهات") },
                actions = {
                    IconButton(onClick = { showSettings = true }) { Icon(Icons.Filled.Settings, "الإعدادات") }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("الصق الروابط (رابط بكل سطر)، أو رابط قائمة تشغيل / قناة كاملة:", style = MaterialTheme.typography.bodyMedium)
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
                                Text("لصق")
                            }
                            Box {
                                OutlinedButton(onClick = { qualityMenu = true }) { Text(quality.label, maxLines = 1, overflow = TextOverflow.Ellipsis) }
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
                            value = maxText,
                            onValueChange = { s -> maxText = s.filter { it.isDigit() }.take(4) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("أقصى عدد فيديوهات من كل رابط (اتركه فاضي = الكل)") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        )
                        Button(
                            onClick = { start() },
                            enabled = input.isNotBlank(),
                            modifier = Modifier.fillMaxWidth().height(50.dp),
                        ) {
                            Icon(Icons.Filled.Download, null)
                            Spacer(Modifier.width(8.dp))
                            Text("ابدأ التحميل")
                        }
                    }
                }
            }

            if (queue.isNotEmpty()) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "الكل ${queue.size} · تم $done · شغال $running · ينتظر $waiting" + if (failed > 0) " · فشل $failed" else "",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            if (running + waiting > 0) TextButton(onClick = { DownloadManager.cancelAll() }) { Text("إلغاء الكل") }
                            if (failed > 0) TextButton(onClick = { DownloadManager.retryFailed() }) { Text("إعادة الفاشل") }
                            TextButton(onClick = { DownloadManager.clearFinished() }) { Text("مسح المكتمل") }
                        }
                    }
                }
            }

            items(queue, key = { it.id }) { item -> ItemRow(item) }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    if (showSettings) {
        AlertDialog(
            onDismissRequest = { showSettings = false },
            confirmButton = { TextButton(onClick = { showSettings = false }) { Text("تم") } },
            title = { Text("الإعدادات") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("عدد الفيديوهات اللي تتحمل بنفس الوقت:")
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        (1..4).forEach { n ->
                            FilterChip(selected = parallel == n, onClick = { DownloadManager.setParallel(n) }, label = { Text("$n") })
                        }
                    }
                    Text(engine, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    OutlinedButton(onClick = { DownloadManager.updateEngine() }, enabled = !engineBusy) {
                        Icon(Icons.Filled.Refresh, null)
                        Spacer(Modifier.width(6.dp))
                        Text("تحديث المحرك (إذا موقع وقف يحمّل)")
                    }
                    Text(
                        "الملفات تنحفظ في: التنزيلات / Murn",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
        )
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
                        Text("جاري قراءة الرابط...", style = MaterialTheme.typography.bodySmall)
                    }
                    Status.QUEUED -> Text("بالانتظار", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Status.RUNNING -> {
                        LinearProgressIndicator(progress = { item.progress }, modifier = Modifier.fillMaxWidth())
                        Text("${(item.progress * 100).toInt()}%  ${item.info}", style = MaterialTheme.typography.bodySmall)
                    }
                    Status.DONE -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(6.dp))
                        Text("تم التحميل", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                    }
                    Status.FAILED -> Row(verticalAlignment = Alignment.Top) {
                        Icon(Icons.Filled.Error, null, tint = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.width(6.dp))
                        Text(item.error ?: "فشل", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    }
                    Status.CANCELED -> Text("ملغي", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            when (item.status) {
                Status.RESOLVING, Status.QUEUED, Status.RUNNING ->
                    IconButton(onClick = { DownloadManager.cancel(item.id) }) { Icon(Icons.Filled.Close, "إلغاء") }
                Status.FAILED, Status.CANCELED ->
                    IconButton(onClick = { DownloadManager.retry(item.id) }) { Icon(Icons.Filled.Refresh, "إعادة") }
                Status.DONE -> IconButton(onClick = { DownloadManager.remove(item.id) }) { Icon(Icons.Filled.Close, "إخفاء") }
            }
        }
    }
}
