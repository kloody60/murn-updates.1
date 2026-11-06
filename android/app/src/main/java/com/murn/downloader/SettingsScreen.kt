package com.murn.downloader

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

private val Bg = Color(0xFF0A0F1E)
private val CardBg = Color(0xFF111A2F)
private val Line = Color(0xFF2B3558)
private val Mint = Color(0xFF63DCBD)
private val Muted = Color(0xFFB4BBCD)
private val ChipOn = Color(0xFF3B3650)

/** Full-screen settings page: a title, then cards (language, app + updates, download tool, accounts, checks). */
@Composable
fun SettingsScreen(
    parallel: Int,
    engine: String,
    engineBusy: Boolean,
    linkInBox: String?,
    onClose: () -> Unit,
    onOpenUpdate: () -> Unit,
    onOpenAccounts: () -> Unit,
) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("murn", 0) }
    var autoUpdate by remember { mutableStateOf(prefs.getBoolean("autoUpdate", true)) }

    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Surface(Modifier.fillMaxSize(), color = Bg) {
            Column(Modifier.systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
                // ---- title bar
                Row(Modifier.fillMaxWidth().padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onClose) { Icon(Icons.AutoMirrored.Filled.ArrowBack, tr("رجوع", "Back"), tint = Color.White) }
                    Text(tr("الإعدادات", "Settings"), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Medium)
                }

                // ---- language
                SCard {
                    CardTitle(tr("اللغة", "Language"))
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        LangChip("العربية", !Lang.en) { Lang.set(ctx, false) }
                        LangChip("English", Lang.en) { Lang.set(ctx, true) }
                    }
                }

                // ---- app + updates
                Spacer(Modifier.height(14.dp))
                SCard {
                    Text("Murn", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text(
                        tr("الإصدار ${Updater.currentName(ctx)} (بناء ${Updater.currentCode(ctx)})", "Version ${Updater.currentName(ctx)} (build ${Updater.currentCode(ctx)})"),
                        color = Muted, fontSize = 16.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                    Spacer(Modifier.height(18.dp))
                    SButton(
                        if (Updater.hasUpdate) tr("التحقق من وجود تحديث  (يوجد تحديث جديد!)", "Check for updates  (new version available!)")
                        else tr("التحقق من وجود تحديث", "Check for updates"),
                    ) {
                        onOpenUpdate()
                        if (!Updater.hasUpdate) Updater.check(ctx)
                    }
                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(tr("التحقق التلقائي من التحديثات", "Check for updates automatically"), color = Color.White, fontSize = 17.sp, modifier = Modifier.weight(1f))
                        Switch(
                            checked = autoUpdate,
                            onCheckedChange = { autoUpdate = it; prefs.edit().putBoolean("autoUpdate", it).apply() },
                            colors = SwitchDefaults.colors(
                                checkedTrackColor = Mint, checkedThumbColor = Color(0xFF0B2A24), checkedBorderColor = Mint,
                                uncheckedTrackColor = Bg, uncheckedThumbColor = Muted, uncheckedBorderColor = Line,
                            ),
                        )
                    }
                }

                // ---- downloads
                SectionTitle(tr("التحميل", "Downloads"))
                SCard {
                    Text(tr("عدد الفيديوهات اللي تتحمل بنفس الوقت", "Videos downloading at the same time"), color = Color.White, fontSize = 17.sp)
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(1, 2, 3, 4, 8, 16).forEach { n ->
                            NumChip(n.toString(), parallel == n) { DownloadManager.setParallel(n) }
                        }
                    }
                    Text(
                        tr("رقم كبير يبطّئ النت وممكن الموقع يحظرك.", "A big number slows the internet and the site may block you."),
                        color = Muted, fontSize = 14.sp, modifier = Modifier.padding(top = 10.dp),
                    )
                    Text(
                        tr("الملفات تنحفظ في: التنزيلات / Murn", "Files are saved in: Downloads / Murn"),
                        color = Muted, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp),
                    )
                }

                // ---- download tool
                SectionTitle(tr("أداة التحميل", "Download tool"))
                SCard {
                    Text(
                        tr("يعتمد التحميل على yt-dlp. إن توقف التحميل من موقع معيّن فغالبًا يكفي تحديث الأداة (يلزم اتصال بالإنترنت).",
                            "Downloading relies on yt-dlp. If a site stops downloading, updating the tool usually fixes it (needs an internet connection)."),
                        color = Color.White, fontSize = 16.sp, lineHeight = 26.sp,
                    )
                    Text(engine, color = Muted, fontSize = 13.sp, modifier = Modifier.padding(top = 8.dp))
                    Spacer(Modifier.height(14.dp))
                    SButton(tr("تحديث أداة التحميل", "Update the download tool"), enabled = !engineBusy) { DownloadManager.updateEngine() }
                }

                // ---- accounts
                SectionTitle(tr("الحسابات", "Accounts"))
                SCard {
                    Text(
                        tr("سجّل دخولك لتحميل اللي يحتاج حساب (إنستغرام، فيسبوك، تيك توك، سناب شات، إكس).",
                            "Sign in to download what needs an account (Instagram, Facebook, TikTok, Snapchat, X)."),
                        color = Color.White, fontSize = 16.sp, lineHeight = 26.sp,
                    )
                    Spacer(Modifier.height(14.dp))
                    SButton(tr("حسابات المنصات", "Platform accounts")) { onOpenAccounts() }
                }

                // ---- checks
                SectionTitle(tr("الفحص", "Diagnostics"))
                SCard {
                    Text(
                        tr("لو حاجة ما تشتغل، افحص الاتصال أو الجودات المتاحة للرابط اللي في الخانة.",
                            "If something does not work, check the connection or the qualities available for the link in the box."),
                        color = Color.White, fontSize = 16.sp, lineHeight = 26.sp,
                    )
                    Spacer(Modifier.height(14.dp))
                    SButton(tr("فحص الاتصال", "Connection check")) {
                        onClose()
                        DownloadManager.diagnose(linkInBox)
                    }
                    Spacer(Modifier.height(10.dp))
                    SButton(tr("فحص جودات الرابط", "Check the link's qualities")) {
                        onClose()
                        DownloadManager.qualityCheck(linkInBox)
                    }
                }
                Spacer(Modifier.height(28.dp))
            }
        }
    }
}

@Composable
private fun SCard(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(CardBg, RoundedCornerShape(28.dp)).padding(22.dp),
    ) { content() }
}

@Composable
private fun CardTitle(text: String) = Text(text, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Medium)

@Composable
private fun SectionTitle(text: String) =
    Text(text, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(top = 26.dp, bottom = 12.dp, start = 4.dp))

@Composable
private fun SButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(58.dp),
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.5.dp, Line),
    ) { Text(text, color = if (enabled) Mint else Muted, fontSize = 17.sp, fontWeight = FontWeight.Medium) }
}

@Composable
private fun LangChip(text: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text, fontSize = 16.sp, color = Color.White) },
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.height(48.dp),
        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = ChipOn, containerColor = Color.Transparent),
        border = FilterChipDefaults.filterChipBorder(enabled = true, selected = selected, borderColor = Line, selectedBorderColor = ChipOn),
    )
}

@Composable
private fun NumChip(text: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(text, fontSize = 16.sp, color = if (selected) Mint else Color.White) },
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.height(44.dp),
        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = ChipOn, containerColor = Color.Transparent),
        border = FilterChipDefaults.filterChipBorder(enabled = true, selected = selected, borderColor = Line, selectedBorderColor = ChipOn),
    )
}
