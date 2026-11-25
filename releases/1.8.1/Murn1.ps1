# Murn Interface - أدوات تصليح + تنظيف مباشر + مراقبة حرارة المعالج / الرام / كرت الشاشة / الهاردسكات

# ---------- CLI ----------
$script:CliArgs = @($args)
$script:CliCmd = if ($script:CliArgs.Count -gt 0) { $script:CliArgs[0] } else { $null }
$script:CliMode = [bool]$script:CliCmd
if ($script:CliMode) {
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
    try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
}
$script:CliMutating = @('--clean', '--clean-ram', '--tweak-apply', '--tweak-undo', '--startup-enable', '--startup-disable', '--update-install')

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $env:MURN_TEST) {
    if ($script:CliMode -and ($script:CliCmd -notin $script:CliMutating)) {
        # أوامر القراءة فقط (أو أمر غير معروف) تشتغل بدون صلاحيات مدير
    } elseif ($script:CliMode) {
        Write-Host 'الأمر هذا يحتاج صلاحيات المدير. شغّل موجّه الأوامر (PowerShell/CMD) كمسؤول (Run as Administrator) وجرّب مرة ثانية.' -ForegroundColor Red
        exit 1
    } else {
        Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}

$script:AppDir = if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE) -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $env:MURN_EXE) 'Murn1.ps1'))) { Split-Path -Parent $env:MURN_EXE } else { $PSScriptRoot }
$script:ThemeFile = Join-Path $script:AppDir 'theme.txt'
$script:DesignId = 'fluentcc'
try {
    if (Test-Path -LiteralPath $script:ThemeFile) {
        $savedTheme = ([IO.File]::ReadAllText($script:ThemeFile)).Trim().ToLower()
        $legacyTheme = @{ 'dark' = 'nexus'; 'gold' = 'royal'; 'light' = 'minimal-light' }
        if ($legacyTheme.ContainsKey($savedTheme)) { $savedTheme = $legacyTheme[$savedTheme] }
        if ($savedTheme -in @('nexus', 'royal', 'fluent', 'control', 'minimal-light', 'minimal-dark', 'fluentcc')) { $script:DesignId = $savedTheme }
    }
} catch {}
if ($env:MURN_DESIGN) { $script:DesignId = $env:MURN_DESIGN }
# every page is built once in the canonical palette below; the selected design is applied on top (see Design System)
$script:ThemeMode = 'dark'
$script:AppVersion = '1.8.1'
# ينفّذ كود باور شيل بملف مؤقت عادي (-File) بدل كوماند مشفر Base64 بالخفاء،
# لأن EncodedCommand+Hidden نمط تحتفظ فيه برامج الحماية كتوقيع لبرامج التحكم عن بعد/الفدية
function Invoke-PlainScript($code, [switch]$Hidden, [switch]$CaptureOutput) {
    $tmpPs1 = Join-Path $env:TEMP ('murn_' + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($tmpPs1, $code, (New-Object Text.UTF8Encoding($false)))
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tmpPs1)
    if ($CaptureOutput) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        [System.Diagnostics.Process]::Start($psi)
    } elseif ($Hidden) {
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList $argList
    } else {
        Start-Process powershell.exe -ArgumentList $argList
    }
}
function Set-DB($c) { try { $c.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($c, $true, $null) } catch {} }
Add-Type -AssemblyName System.Drawing
function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$script:AccentDark = (C 0 214 240)   # سماوي مثل مداد
$script:AccentGold = (C 231 181 92)  # ذهبي - التصميم الثاني
$script:Accent = $script:AccentDark
$script:AccentOk = (C 40 220 130)
$script:PalDark = @{
    Bg = (C 10 17 27); Card = (C 16 26 40); CardTop = (C 22 36 54); CardBot = (C 14 23 36)
    CardBorder = (C 30 50 72); Track = (C 28 42 60); Tick = (C 70 92 118); Input = (C 8 13 21)
    TitleBar = (C 12 20 32); Side = (C 8 14 22); NavHover = (C 18 30 46); NavActive = (C 14 40 56)
    Text = [System.Drawing.Color]::White; SubText = [System.Drawing.Color]::Silver
    NavText = [System.Drawing.Color]::Gainsboro; LogText = [System.Drawing.Color]::LightGray
    Good = [System.Drawing.Color]::LightGreen; DarkMode = $true
}
$script:PalLight = @{
    Bg = (C 240 241 244); Card = [System.Drawing.Color]::White; CardTop = [System.Drawing.Color]::White; CardBot = (C 244 245 248)
    CardBorder = (C 214 216 222); Track = (C 222 224 230); Tick = (C 150 152 160); Input = [System.Drawing.Color]::White
    TitleBar = [System.Drawing.Color]::White; Side = (C 230 232 238); NavHover = (C 218 221 230); NavActive = (C 255 241 214)
    Text = (C 25 27 32); SubText = (C 90 92 100)
    NavText = (C 40 42 48); LogText = (C 60 62 68)
    Good = (C 20 140 80); DarkMode = $false
}
$script:PalGold = @{
    Bg = (C 7 7 10); Card = (C 14 14 19); CardTop = (C 20 20 26); CardBot = (C 10 10 14)
    CardBorder = (C 58 48 26); Track = (C 28 28 34); Tick = (C 110 95 60); Input = (C 14 14 19)
    TitleBar = (C 12 12 16); Side = (C 10 10 14); NavHover = (C 24 24 30); NavActive = (C 46 36 16)
    Text = (C 242 237 228); SubText = (C 158 158 166)
    NavText = (C 138 138 148); LogText = (C 160 160 168)
    Good = (C 127 224 168); DarkMode = $true
}
function Get-PalByMode($mode) {
    switch ($mode) { 'light' { $script:PalLight }; 'gold' { $script:PalGold }; default { $script:PalDark } }
}
$script:Pal = Get-PalByMode $script:ThemeMode
$script:Accent = if ($script:ThemeMode -eq 'gold') { $script:AccentGold } else { $script:AccentDark }
$script:CardRadius = if ($script:ThemeMode -eq 'gold') { 4 } else { 18 }
# canonical design tokens (used while the pages are being built; replaced by Apply-Design)
$script:D = @{ Id = 'canonical'; Bg = (C 10 17 27); Card = (C 16 26 40); Input = (C 8 13 21); Text = [System.Drawing.Color]::White; Muted = [System.Drawing.Color]::Gray
    NavText = [System.Drawing.Color]::Gainsboro; LogText = [System.Drawing.Color]::LightGray; Good = [System.Drawing.Color]::LightGreen; Accent = (C 0 214 240); Accent2 = (C 0 214 240)
    Border = (C 40 60 80); Track = (C 45 48 58); OnAccent = (C 6 14 22); Danger = (C 160 50 50); Warn = (C 176 100 30); Btn2 = (C 60 66 80); Hover = (C 18 30 46); SelBg = (C 0 70 92)
    BtnShape = 'pill'; Dark = $true; GaugeSize = @(176, 222); Bg2 = (C 10 17 27) }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# own taskbar identity so the taskbar shows the falcon, not the PowerShell icon
try { Add-Type -Namespace Murn -Name Shell -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern void SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string id);'; [Murn.Shell]::SetCurrentProcessExplicitAppUserModelID('Murn.Waja.App') } catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Installer (first run only, silent - no dialog) ----------
function Install-Silent {
    $target = 'C:\Program Files (x86)\Murn Interface'
    try {
        function NormP($p) { ([IO.Path]::GetFullPath($p)).TrimEnd('\') }

        try { $sameDir = (NormP $target) -ieq (NormP $script:AppDir) }
        catch { throw "فشل تحليل المسار (NormP): $($_.Exception.GetType().Name) - $($_.Exception.Message)" }

        try { if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Force -Path $target | Out-Null } }
        catch { throw "فشل إنشاء مجلد التثبيت '$target': $($_.Exception.GetType().Name) - $($_.Exception.Message)" }

        if (-not $sameDir) {
            try {
                $exclude = @('installed.marker', 'update-token.secret')
                Get-ChildItem -LiteralPath $script:AppDir -Force | Where-Object { $_.Name -notin $exclude -and $_.Extension -ne '.zip' } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Recurse -Force
                }
            } catch { throw "فشل نسخ ملفات البرنامج: $($_.Exception.GetType().Name) - $($_.Exception.Message)" }
        }

        $targetExe = Join-Path $target 'Murn Interface.exe'
        try {
            if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE) -and ((NormP $env:MURN_EXE) -ne (NormP $targetExe))) {
                Copy-Item -LiteralPath $env:MURN_EXE -Destination $targetExe -Force
            }
        } catch { throw "فشل نسخ ملف البرنامج التنفيذي: $($_.Exception.GetType().Name) - $($_.Exception.Message)" }

        try { Set-Content -LiteralPath (Join-Path $target 'installed.marker') (Get-Date -Format 'o') -Encoding utf8 }
        catch { throw "فشل كتابة ملف installed.marker بمجلد التثبيت: $($_.Exception.GetType().Name) - $($_.Exception.Message)" }
        try { Set-Content -LiteralPath (Join-Path $script:AppDir 'installed.marker') (Get-Date -Format 'o') -Encoding utf8 } catch {}

        try {
            $iconPath = Join-Path $target 'falcon.ico'
            $wsh = New-Object -ComObject WScript.Shell
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $sc = $wsh.CreateShortcut((Join-Path $desktopPath 'Murn Interface.lnk'))
            $sc.TargetPath = $targetExe
            $sc.WorkingDirectory = $target
            if (Test-Path -LiteralPath $iconPath) { $sc.IconLocation = "$iconPath,0" }
            $sc.Save()
            $programsPath = [Environment]::GetFolderPath('Programs')
            $sc2 = $wsh.CreateShortcut((Join-Path $programsPath 'Murn Interface.lnk'))
            $sc2.TargetPath = $targetExe
            $sc2.WorkingDirectory = $target
            if (Test-Path -LiteralPath $iconPath) { $sc2.IconLocation = "$iconPath,0" }
            $sc2.Save()
        } catch {}

        if ($sameDir) { return 'continue' }
        try { Start-Process -FilePath $targetExe } catch {}
        return 'relaunched'
    } catch {
        [System.Windows.Forms.MessageBox]::Show('صار خطأ أثناء التثبيت: ' + $_.Exception.Message, 'Murn Interface', 'OK', 'Error') | Out-Null
        return 'error'
    }
}

if (-not $env:MURN_TEST -and -not (Test-Path -LiteralPath (Join-Path $script:AppDir 'installed.marker'))) {
    $instResult = Install-Silent
    if ($instResult -ne 'continue') { exit }
}

# ---------- icons: dark glass badges with a gold rim, used everywhere in the UI ----------
$script:IcoCache = @{}
function Get-SysIcon($rel, $size = 24) {
    try {
        $p = Join-Path $env:windir $rel
        $src = [System.Drawing.Icon]::ExtractAssociatedIcon($p).ToBitmap()
        $bmp = New-Object System.Drawing.Bitmap $size, $size
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
        $g.DrawImage($src, 0, 0, $size, $size); $g.Dispose(); $src.Dispose()
        $bmp
    } catch { $null }
}
function New-Badge($size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $w = $size - 1
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $w
    $grad = New-Object System.Drawing.Drawing2D.GraphicsPath; $grad.AddEllipse($rect)
    $br = New-Object System.Drawing.Drawing2D.PathGradientBrush $grad
    $br.CenterPoint = New-Object System.Drawing.PointF ($size * 0.36), ($size * 0.3)
    $br.CenterColor = [System.Drawing.Color]::FromArgb(255, 56, 61, 76)
    $br.SurroundColors = @([System.Drawing.Color]::FromArgb(255, 22, 24, 30))
    $g.FillEllipse($br, $rect); $br.Dispose(); $grad.Dispose()
    # glossy highlight across the top
    $glossH = [math]::Max(2, [int]($size * 0.34))
    $glossRect = New-Object System.Drawing.Rectangle ([int]($size * 0.1)), ([int]($size * 0.06)), ([int]($size * 0.8)), $glossH
    $glossBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $glossRect, ([System.Drawing.Color]::FromArgb(70, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255)), 90
    $g.FillEllipse($glossBrush, $glossRect); $glossBrush.Dispose()
    # gold rim
    $rimW = [single]([math]::Max(1, $size * 0.045))
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(190, 0, 214, 240)), $rimW
    $g.DrawEllipse($pen, $rect); $pen.Dispose()
    $g.Dispose(); $bmp
}
function New-GlyphIcon($glyph, $r, $gr, $b, $size = 24) {
    $bmp = New-Badge $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $f = New-Object System.Drawing.Font('Segoe UI Emoji', [single]($size * 0.44), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $tintBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $g.DrawString($glyph, $f, $tintBrush, (New-Object System.Drawing.RectangleF 1, 2, $size, $size), $sf)
    $tintBrush.Dispose(); $g.Dispose(); $bmp
}
function New-BadgedSysIcon($rel, $size) {
    $bmp = New-Badge $size
    try {
        $p = Join-Path $env:windir $rel
        $src = [System.Drawing.Icon]::ExtractAssociatedIcon($p).ToBitmap()
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
        $isz = [int]($size * 0.56); $off = [int](($size - $isz) / 2)
        $g.DrawImage($src, $off, $off, $isz, $isz)
        $g.Dispose(); $src.Dispose()
    } catch {}
    $bmp
}
function Get-Ico($key, $size = 24) {
    $ck = "$key/$size"
    if ($script:IcoCache.ContainsKey($ck)) { return $script:IcoCache[$ck] }
    $gold = @($script:Accent.R, $script:Accent.G, $script:Accent.B); $white = @(235, 238, 244)
    $img = switch ($key) {
        'mon'     { New-BadgedSysIcon 'System32\Taskmgr.exe' $size }
        'fix'     { New-BadgedSysIcon 'System32\mmc.exe' $size }
        'tweaks'  { New-BadgedSysIcon 'System32\control.exe' $size }
        'startup' { New-BadgedSysIcon 'System32\msconfig.exe' $size }
        'apps'    { New-BadgedSysIcon 'System32\ComputerDefaults.exe' $size }
        'tools'   { New-BadgedSysIcon 'System32\cleanmgr.exe' $size }
        'shield'  { New-BadgedSysIcon 'System32\SecurityHealthSystray.exe' $size }
        'mrt'     { New-BadgedSysIcon 'System32\mrt.exe' $size }
        'ram'     { New-BadgedSysIcon 'System32\mdsched.exe' $size }
        'disk'    { New-BadgedSysIcon 'System32\dfrgui.exe' $size }
        'procs'   { New-BadgedSysIcon 'System32\Taskmgr.exe' $size }
        'display' { New-BadgedSysIcon 'System32\DisplaySwitch.exe' $size }
        'cpu'     { New-GlyphIcon ([string][char]0x2699) $white[0] $white[1] $white[2] $size }
        'gpu'     { New-GlyphIcon ([char]::ConvertFromUtf32(0x1F3AE)) $white[0] $white[1] $white[2] $size }
        'yt'      { New-GlyphIcon ([string][char]0x25B6) $gold[0] $gold[1] $gold[2] $size }
        'conv'    { New-GlyphIcon ([char]::ConvertFromUtf32(0x1F39E)) $gold[0] $gold[1] $gold[2] $size }
        'update'  { New-GlyphIcon ([string][char]0x27F3) $white[0] $white[1] $white[2] $size }
        'about'   { New-GlyphIcon ([string][char]0x2605) $gold[0] $gold[1] $gold[2] $size }
        'fan'     { New-GlyphIcon ([char]::ConvertFromUtf32(0x1F300)) $white[0] $white[1] $white[2] $size }
        default   { $null }
    }
    if (-not $img -and $key -in 'mon', 'fix', 'tweaks', 'startup', 'apps', 'tools', 'shield', 'mrt', 'ram', 'disk', 'procs', 'display') { $img = New-GlyphIcon ([string][char]0x2699) 180 184 192 $size }
    $script:IcoCache[$ck] = $img
    $img
}


$L = $env:LOCALAPPDATA; $R = $env:APPDATA; $W = $env:windir
$script:Lhm = $null

# قراءة الحرارة عبر LibreHardwareMonitor اتشالت نهائياً: تحتاج سواقة WinRing0 محظورة
# رسمياً من مايكروسوفت على قائمة السواقات الخطرة (VulnerableDriver:WinNT/Winring0)،
# وتخلي حماية ويندوز تحذف البرنامج. الحرارة الآن تعتمد بس على المصادر الآمنة
# (WMI/nvidia-smi) الموجودة أصلاً بدالة Get-Stats.
function Get-LhmTemp($type) { $null }

# ---------- Stats ----------
$script:DiskTemps = @{}
$script:DiskTick = 99

function Get-Stats {
    $rows = New-Object System.Collections.ArrayList

    # CPU
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ct = Get-LhmTemp 'Cpu'
    if ($null -eq $ct) {
        try {
            $z = Get-CimInstance -Namespace root/wmi MSAcpi_ThermalZoneTemperature -ErrorAction Stop | Select-Object -First 1
            $ct = [math]::Round($z.CurrentTemperature / 10 - 273.15, 1)
        } catch {}
    }
    [void]$rows.Add([pscustomobject]@{ Name = "المعالج: $($cpu.Name.Trim())"; Usage = "$($cpu.LoadPercentage)%"; Temp = $ct; Pct = $cpu.LoadPercentage; Kind = 'cpu' })

    # RAM
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { $os = $null }
    if ($os.TotalVisibleMemorySize) {
        $totalGB = $os.TotalVisibleMemorySize / 1MB
        $usedGB = $totalGB - ($os.FreePhysicalMemory / 1MB)
        [void]$rows.Add([pscustomobject]@{ Name = 'الرام'; Usage = ('{0:N1} / {1:N1} GB' -f $usedGB, $totalGB); Temp = (Get-LhmTemp 'Memory'); Pct = [int](100 * $usedGB / $totalGB); Kind = 'ram' })
    }

    # GPU
    $nv = $null
    try { $nv = & nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>$null } catch {}
    if ($nv) {
        foreach ($line in $nv) {
            $p = $line -split ',\s*'
            [void]$rows.Add([pscustomobject]@{ Name = "كرت الشاشة: $($p[0])"; Usage = ('{0}%  |  VRAM {1}/{2} MB' -f $p[2], $p[3], $p[4]); Temp = [double]$p[1]; Pct = [int]$p[2]; Kind = 'gpu' })
        }
    }
    $lg = Get-LhmTemp 'Gpu*'
    if (-not $nv -and $null -ne $lg) { [void]$rows.Add([pscustomobject]@{ Name = 'كرت الشاشة'; Usage = '-'; Temp = $lg; Pct = 0; Kind = 'gpu' }) }

    # Disks (temperature refreshed every ~10s)
    $script:DiskTick++
    if ($script:DiskTick -ge 5) {
        $script:DiskTick = 0
        $script:DiskTemps = @{}
        try {
            foreach ($d in Get-PhysicalDisk) {
                $rc = $d | Get-StorageReliabilityCounter -ErrorAction Stop
                $script:DiskTemps[$d.DeviceId] = @{ Name = $d.FriendlyName; Size = [math]::Round($d.Size / 1GB); Temp = $rc.Temperature }
            }
        } catch {}
    }
    foreach ($k in ($script:DiskTemps.Keys | Sort-Object)) {
        $d = $script:DiskTemps[$k]
        [void]$rows.Add([pscustomobject]@{ Name = "هارد: $($d.Name)"; Usage = "$($d.Size) GB"; Temp = $d.Temp; Pct = 0; Kind = 'disk' })
    }
    foreach ($v in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        $used = ($v.Size - $v.FreeSpace) / 1GB
        [void]$rows.Add([pscustomobject]@{ Name = "قرص $($v.DeviceID)"; Usage = ('{0:N0} / {1:N0} GB مستخدم' -f $used, ($v.Size / 1GB)); Temp = $null; Pct = [int](100 * $used / ($v.Size / 1GB)); Kind = 'disk' })
    }
    $rows
}

# ---------- Cleaning ----------
function Resolve-Paths($paths) {
    foreach ($p in $paths) { Resolve-Path $p -ErrorAction SilentlyContinue | ForEach-Object { $_.ProviderPath } }
}
function Get-SizeMB($paths) {
    $sum = 0
    foreach ($r in (Resolve-Paths $paths)) {
        $item = Get-Item -LiteralPath $r -Force -ErrorAction SilentlyContinue
        if ($item.PSIsContainer) { $sum += (Get-ChildItem -LiteralPath $r -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
        elseif ($item) { $sum += $item.Length }
    }
    [math]::Round($sum / 1MB, 1)
}
function Remove-Paths($paths) {
    foreach ($r in (Resolve-Paths $paths)) {
        $item = Get-Item -LiteralPath $r -Force -ErrorAction SilentlyContinue
        if ($item.PSIsContainer) { Get-ChildItem -LiteralPath $r -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
        elseif ($item) { Remove-Item -LiteralPath $r -Force -ErrorAction SilentlyContinue }
    }
}

function Get-CleanTargets {
    $b = @("Cache", "Code Cache", "GPUCache", "Service Worker\CacheStorage")
    $browserRoots = @("$L\Google\Chrome\User Data", "$L\Microsoft\Edge\User Data", "$L\BraveSoftware\Brave-Browser\User Data")
    $browserPaths = foreach ($broot in $browserRoots) { foreach ($x in $b) { "$broot\*\$x" }; "$broot\ShaderCache"; "$broot\GrShaderCache" }
    @(
        @{ N = 'ملفات ويندوز المؤقتة'; P = @("$W\Temp") },
        @{ N = 'ملفات المستخدم المؤقتة'; P = @($env:TEMP) },
        @{ N = 'Prefetch'; P = @("$W\Prefetch") },
        @{ N = 'كاش تحديثات ويندوز'; P = @("$W\SoftwareDistribution\Download") },
        @{ N = 'Internet cache'; P = @("$L\Microsoft\Windows\INetCache") },
        @{ N = 'تقارير الأعطال'; P = @("$L\CrashDumps", "$W\Minidump", "$W\MEMORY.DMP", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue") },
        @{ N = 'GPU shader cache'; P = @("$L\D3DSCache", "$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache", "$L\NVIDIA Corporation\NV_Cache", "$L\AMD\DxCache", "$L\AMD\GLCache") },
        @{ N = 'كاش المتصفحات (Chrome/Edge/Brave)'; P = @($browserPaths) },
        @{ N = 'كاش VS Code'; P = @("$R\Code\Cache", "$R\Code\CachedData", "$R\Code\Code Cache", "$R\Code\GPUCache") }
    )
}

function Write-Log($text) {
    $script:Log.AppendText($text + "`r`n")
    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-Clean {
    $script:BtnClean.Enabled = $false
    $script:Log.Clear()
    $total = 0
    Write-Log 'بدأ التنظيف...'

    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    foreach ($t in Get-CleanTargets) {
        $before = Get-SizeMB $t.P
        if (-not $before) { continue }
        Remove-Paths $t.P
        $freed = [math]::Max(0, [math]::Round($before - (Get-SizeMB $t.P), 1))
        $total += $freed
        Write-Log ("  {0}: تم تحرير {1} MB" -f $t.N, $freed)
    }
    Start-Service wuauserv, bits -ErrorAction SilentlyContinue

    if ($script:ChkBin.Checked) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Log '  تم تفريغ سلة المحذوفات'
    }


    $b = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
    Add-Type -Namespace Win32 -Name Psapi -ErrorAction SilentlyContinue -MemberDefinition '[DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);'
    Get-Process | ForEach-Object { try { [void][Win32.Psapi]::EmptyWorkingSet($_.Handle) } catch {} }
    [GC]::Collect()
    $a = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
    Write-Log "  الرام الفاضي: $b MB  ->  $a MB"

    Write-Log ("انتهى. المساحة المحررة: {0} MB (الملفات المستخدمة تُتخطى)" -f [math]::Round($total, 1))
    $script:BtnClean.Enabled = $true
    Show-Done 'تم تنظيف الجهاز'
}

# ---------- UI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Murn Interface'
$form.Size = New-Object System.Drawing.Size(1060, 720); $form.MinimumSize = New-Object System.Drawing.Size(900, 640)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$iconPath = Join-Path $script:AppDir 'falcon.ico'
if (Test-Path $iconPath) { $form.Icon = New-Object System.Drawing.Icon $iconPath }
$form.RightToLeft = 'Yes'

try {
    Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MurnDwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
'@
    $form.Add_HandleCreated({
        try { $v = 1; [void][MurnDwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4) } catch {}
    })
} catch {}

try {
    Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MurnUi {
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
'@
} catch {}
function Set-DarkInput($ctrl) {
    try { [void][MurnUi]::SetWindowTheme($ctrl.Handle, '', '') } catch {}
}
function Set-DarkProgress($bar, $trackColor, $fillColor) {
    try {
        [void][MurnUi]::SetWindowTheme($bar.Handle, '', '')
        $bar.BackColor = $trackColor
        $trackRef = [IntPtr]([uint32]($trackColor.R -bor ($trackColor.G * 256) -bor ($trackColor.B * 65536)))
        $fillRef = [IntPtr]([uint32]($fillColor.R -bor ($fillColor.G * 256) -bor ($fillColor.B * 65536)))
        [void][MurnUi]::SendMessage($bar.Handle, 0x2001, [IntPtr]::Zero, $trackRef)
        [void][MurnUi]::SendMessage($bar.Handle, 0x409, [IntPtr]::Zero, $fillRef)
    } catch {}
}
# controls needing the theme-disable fix must be registered, then fixed up once at the very end
# (right before the window is shown) -- reparenting a control recreates its native handle and
# undoes SetWindowTheme, so applying it immediately after creation does not stick.
$script:DarkInputCtrls = New-Object System.Collections.ArrayList
$script:DarkProgressCtrls = New-Object System.Collections.ArrayList
function Register-DarkInput($ctrl) { [void]$script:DarkInputCtrls.Add($ctrl) }
function Register-DarkProgress($bar, $trackColor, $fillColor) { [void]$script:DarkProgressCtrls.Add(@{ Bar = $bar; Track = $trackColor; Fill = $fillColor }) }
function Apply-DarkInputFixups {
    foreach ($c in $script:DarkInputCtrls) { Set-DarkInput $c }
    foreach ($d in $script:DarkProgressCtrls) { Set-DarkProgress $d.Bar $script:D.Track $script:D.Accent }
}
$form.RightToLeftLayout = $true

# completion notification (falcon icon + sound)
$script:Notify = New-Object System.Windows.Forms.NotifyIcon
$script:Notify.Icon = if ($form.Icon) { $form.Icon } else { [System.Drawing.SystemIcons]::Information }
$script:Notify.Text = $form.Text
$script:Notify.Visible = $true
function Show-Done($what) {
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    try {
        $script:Notify.BalloonTipTitle = 'تم الاكتمال ✓'
        $script:Notify.BalloonTipText = "$what"
        $script:Notify.BalloonTipIcon = 'None'
        $script:Notify.ShowBalloonTip(6000)
    } catch {}
}

$gFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$gFlow.Dock = 'Fill'; $gFlow.FlowDirection = 'RightToLeft'; $gFlow.WrapContents = $true; $gFlow.AutoScroll = $true
$gFlow.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27); $gFlow.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 4)
$gFlow.RightToLeft = 'No'
$script:GaugeList = New-Object System.Collections.ArrayList
$script:GFontBig = New-Object System.Drawing.Font('Segoe UI', 24, [System.Drawing.FontStyle]::Bold)
$script:GFontSub = New-Object System.Drawing.Font('Segoe UI', 9)
$script:GFontName = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$script:GFmtL = New-Object System.Drawing.StringFormat; $script:GFmtL.Alignment = 'Center'; $script:GFmtL.LineAlignment = 'Center'; $script:GFmtL.Trimming = 'EllipsisCharacter'
$script:GFmt = New-Object System.Drawing.StringFormat
$script:GFmt.Alignment = 'Center'; $script:GFmt.LineAlignment = 'Center'; $script:GFmt.Trimming = 'EllipsisCharacter'; $script:GFmt.FormatFlags = 'DirectionRightToLeft'

function Get-RoundRectPath($rect, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $p.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $p.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $p
}

function Get-GaugeColor($pct) {
    if ($pct -ge 90) { [System.Drawing.Color]::FromArgb(235, 70, 60) } elseif ($pct -ge 75) { [System.Drawing.Color]::FromArgb(240, 150, 30) } else { $script:Accent }
}

# (gauge painters live in the Design System section)

function Get-TopProcesses($kind) {
    try {
        switch ($kind) {
            'ram' {
                Get-Process | Where-Object { $_.WorkingSet64 -gt 0 } | Sort-Object WorkingSet64 -Descending | Select-Object -First 7 |
                    ForEach-Object { [pscustomobject]@{ Name = $_.ProcessName; Val = ('{0:N0} MB' -f ($_.WorkingSet64 / 1MB)) } }
            }
            'cpu' {
                $c = Get-Counter '\Process(*)\% Processor Time' -ErrorAction Stop
                $cores = [math]::Max(1, [Environment]::ProcessorCount)
                $c.CounterSamples | Where-Object { $_.InstanceName -notin '_total', 'idle' -and $_.CookedValue -gt 0 } |
                    Group-Object InstanceName | ForEach-Object {
                        $v = ($_.Group | Measure-Object CookedValue -Sum).Sum / $cores
                        [pscustomobject]@{ Name = ($_.Name -replace '#\d+$', ''); Val = $v }
                    } | Group-Object Name | ForEach-Object {
                        [pscustomobject]@{ Name = $_.Name; Val = ($_.Group | Measure-Object Val -Sum).Sum }
                    } | Sort-Object Val -Descending | Select-Object -First 7 |
                    ForEach-Object { [pscustomobject]@{ Name = $_.Name; Val = ('{0:N1}%' -f $_.Val) } }
            }
            'gpu' {
                $c = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
                $c.CounterSamples | Where-Object { $_.CookedValue -gt 0 -and $_.InstanceName -match 'pid_(\d+)' } | ForEach-Object {
                    $pid2 = [int]$Matches[1]
                    [pscustomobject]@{ Pid2 = $pid2; Val = $_.CookedValue }
                } | Group-Object Pid2 | ForEach-Object {
                    $sum = ($_.Group | Measure-Object Val -Sum).Sum
                    $nm = try { (Get-Process -Id $_.Name -ErrorAction Stop).ProcessName } catch { "PID $($_.Name)" }
                    [pscustomobject]@{ Name = $nm; Val = $sum }
                } | Sort-Object Val -Descending | Select-Object -First 7 |
                    ForEach-Object { [pscustomobject]@{ Name = $_.Name; Val = ('{0:N1}%' -f $_.Val) } }
            }
            'disk' {
                $c = Get-Counter '\Process(*)\IO Data Bytes/sec' -ErrorAction Stop
                $c.CounterSamples | Where-Object { $_.InstanceName -notin '_total', 'idle' -and $_.CookedValue -gt 1024 } |
                    Group-Object InstanceName | ForEach-Object {
                        $v = ($_.Group | Measure-Object CookedValue -Sum).Sum
                        [pscustomobject]@{ Name = ($_.Name -replace '#\d+$', ''); Val = $v }
                    } | Group-Object Name | ForEach-Object {
                        [pscustomobject]@{ Name = $_.Name; Val = ($_.Group | Measure-Object Val -Sum).Sum }
                    } | Sort-Object Val -Descending | Select-Object -First 7 |
                    ForEach-Object { [pscustomobject]@{ Name = $_.Name; Val = ('{0:N0} KB/s' -f ($_.Val / 1KB)) } }
            }
            default { @() }
        }
    } catch { $null }
}

function Show-GaugeMenu($panel) {
    $kind = $panel.Tag.Kind
    if (-not $kind) { return }
    $cm = New-Object System.Windows.Forms.ContextMenuStrip
    $cm.RenderMode = 'System'
    $head = New-Object System.Windows.Forms.ToolStripMenuItem 'أكثر العمليات استهلاكاً:'
    $head.Enabled = $false; $head.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    [void]$cm.Items.Add($head); [void]$cm.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $list = Get-TopProcesses $kind
    if (-not $list -or $list.Count -eq 0) {
        $it = New-Object System.Windows.Forms.ToolStripMenuItem 'ما قدرت أجيب البيانات الحين'
        $it.Enabled = $false; [void]$cm.Items.Add($it)
    } else {
        foreach ($p in $list) {
            $it = New-Object System.Windows.Forms.ToolStripMenuItem ("$($p.Name)   —   $($p.Val)")
            $it.Enabled = $false
            [void]$cm.Items.Add($it)
        }
    }
    $cm.Show($panel, (New-Object System.Drawing.Point(20, 20)))
}

# (New-Gauge lives in the Design System section)

$script:BtnClean = New-Object System.Windows.Forms.Button
$BtnClean.Text = 'نظّف الآن'
$BtnClean.Height = 46; $BtnClean.Dock = 'Top'
$BtnClean.FlatStyle = 'Flat'; $BtnClean.FlatAppearance.BorderSize = 0
$BtnClean.BackColor = $script:Accent; $BtnClean.ForeColor = [System.Drawing.Color]::FromArgb(6, 14, 22)
$BtnClean.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

$script:ChkBin = New-Object System.Windows.Forms.CheckBox
$ChkBin.Text = 'فرّغ سلة المحذوفات أيضاً'
$ChkBin.Dock = 'Top'; $ChkBin.Height = 30; $ChkBin.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 0)

$script:Log = New-Object System.Windows.Forms.TextBox
$Log.Multiline = $true; $Log.ReadOnly = $true; $Log.Dock = 'Fill'; $Log.ScrollBars = 'None'
$Log.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 21); $Log.ForeColor = [System.Drawing.Color]::LightGray
$Log.BorderStyle = 'None'; $Log.Font = New-Object System.Drawing.Font('Consolas', 10)

$status = New-Object System.Windows.Forms.Label
$status.Dock = 'Bottom'; $status.Height = 24; $status.ForeColor = [System.Drawing.Color]::Gray
$status.Text = if ($script:Lhm) { 'مصدر الحرارة: LibreHardwareMonitor (كامل)' } else { '' }
$status.Visible = [bool]$script:Lhm

# ---------- Tabs ----------
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.RightToLeftLayout = $true
$tabMon = New-Object System.Windows.Forms.TabPage 'الرئيسية'
$tabFix = New-Object System.Windows.Forms.TabPage 'أدوات التصليح'
foreach ($t in $tabMon, $tabFix) { $t.BackColor = $form.BackColor; $t.ForeColor = [System.Drawing.Color]::White }
[void]$tabs.TabPages.Add($tabMon)
[void]$tabs.TabPages.Add($tabFix)
$form.Controls.Add($tabs)

# add in reverse dock order
$tabMon.Controls.Add($gFlow)
$tabMon.Controls.Add($status)

# ---------- Repair tools ----------
$edgeCmd = @'
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
(Get-ItemProperty $k).PSObject.Properties | Where-Object { $_.Name -like 'MicrosoftEdgeAutoLaunch_*' } | ForEach-Object { Remove-ItemProperty -Path $k -Name $_.Name }
$p = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; New-Item $p -Force | Out-Null
Set-ItemProperty $p -Name BackgroundModeEnabled -Value 0 -Type DWord
Set-ItemProperty $p -Name StartupBoostEnabled -Value 0 -Type DWord
Set-ItemProperty $p -Name HubsSidebarEnabled -Value 0 -Type DWord
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
'@
$copilotRemoveCmd = @'
Get-AppxPackage -Name '*Copilot*' | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName }
'@
$edgeRemoveCmd = @'
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
$roots = @("$env:ProgramFiles(x86)\Microsoft\Edge\Application", "$env:ProgramFiles\Microsoft\Edge\Application")
$setup = $null
foreach ($root in $roots) {
    if (Test-Path $root) {
        $setup = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+\.' } |
            Sort-Object { [version]$_.Name } -Descending |
            ForEach-Object { Join-Path $_.FullName 'Installer\setup.exe' } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($setup) { break }
    }
}
if (-not $setup) { throw 'ما قدرت ألقى ملف إزالة Edge (setup.exe) بجهازك.' }
Start-Process -FilePath $setup -ArgumentList '--uninstall', '--system-level', '--verbose-logging', '--force-uninstall' -Wait
'@
$edgeInstallCmd = @'
$dst = Join-Path $env:TEMP 'MicrosoftEdgeSetup.exe'
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2093437' -OutFile $dst -UseBasicParsing
Start-Process -FilePath $dst -ArgumentList '/silent', '/install' -Wait
Remove-Item $dst -Force -ErrorAction SilentlyContinue
'@
$copilotInstallCmd = @'
$prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like '*Copilot*' }
if (-not $prov) { throw 'ما قدرت ألقى حزمة Copilot الأصلية بجهازك عشان أرجعها.' }
foreach ($p in $prov) {
    $manifest = Join-Path $env:SystemRoot ('SystemApps\' + $p.PackageName + '\AppXManifest.xml')
    if (Test-Path $manifest) { Add-AppxPackage -DisableDevelopmentMode -Register $manifest }
    else { throw 'ملفات Copilot الأصلية مو موجودة بجهازك، لازم تثبيته من متجر مايكروسوفت.' }
}
'@
$wuCmd = @'
Stop-Service wuauserv, bits, cryptsvc -Force -ErrorAction SilentlyContinue
Remove-Item "$env:windir\SoftwareDistribution.old", "$env:windir\System32\catroot2.old" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "$env:windir\SoftwareDistribution" 'SoftwareDistribution.old' -ErrorAction SilentlyContinue
Rename-Item "$env:windir\System32\catroot2" 'catroot2.old' -ErrorAction SilentlyContinue
Start-Service cryptsvc, bits, wuauserv
'@
$iconCmd = @'
Stop-Process -Name explorer -Force
Start-Sleep 2
$L = $env:LOCALAPPDATA
Remove-Item "$L\Microsoft\Windows\Explorer\thumbcache_*.db", "$L\Microsoft\Windows\Explorer\iconcache_*.db", "$L\IconCache.db" -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
'@

$tools = @(
    @{ N = 'إصلاح ويندوز الكامل (DISM + SFC)'; D = 'يفحص ويصلح ملفات النظام التالفة. ياخذ 20-60 دقيقة'; Confirm = $false
       C = 'dism /Online /Cleanup-Image /CheckHealth; dism /Online /Cleanup-Image /ScanHealth; dism /Online /Cleanup-Image /RestoreHealth; sfc /scannow' },
    @{ N = 'فحص ملفات النظام (SFC)'; D = 'فحص سريع وإصلاح لملفات النظام'; Confirm = $false; C = 'sfc /scannow' },
    @{ N = 'فحص الهارد (CHKDSK C:)'; D = 'يفحص أخطاء القرص C بدون إعادة تشغيل'; Confirm = $false; C = 'chkdsk C: /scan' },
    @{ N = 'صحة الهاردسكات (SMART)'; D = 'يعرض حالة الصحة لكل هارد'; Confirm = $false
       C = 'Get-PhysicalDisk | Format-Table FriendlyName, MediaType, HealthStatus, OperationalStatus -AutoSize' },
    @{ N = 'فحص الرام (Memory Diagnostic)'; D = 'يفتح أداة ويندوز لفحص الرام وتحتاج إعادة تشغيل'; Confirm = $false; C = 'mdsched.exe' },
    @{ N = 'فحص فايروسات سريع (Defender)'; D = 'يشغل فحص Microsoft Defender السريع'; Confirm = $false; C = 'Start-MpScan -ScanType QuickScan' },
    @{ N = 'إصلاح الإنترنت (Reset Network)'; D = 'يصفّر Winsock وIP ويمسح DNS. يحتاج إعادة تشغيل'; Confirm = $true
       C = 'ipconfig /flushdns; ipconfig /registerdns; netsh winsock reset; netsh int ip reset' },
    @{ N = 'إصلاح تحديثات ويندوز'; D = 'يعيد ضبط كاش وخدمات Windows Update'; Confirm = $true; C = $wuCmd },
    @{ N = 'إصلاح متجر مايكروسوفت'; D = 'يصفّر كاش المتجر (wsreset)'; Confirm = $false; C = 'wsreset.exe' },
    @{ N = 'إعادة بناء كاش الأيقونات والصور المصغرة'; D = 'يصلح الأيقونات المكسورة. شريط المهام يعيد تشغيل لثواني'; Confirm = $true; C = $iconCmd },
    @{ N = 'إعادة تشغيل Explorer'; D = 'يصلح تعليق شريط المهام وسطح المكتب'; Confirm = $false
       C = 'Stop-Process -Name explorer -Force; Start-Sleep 2; Start-Process explorer.exe' },
    @{ N = 'إنشاء نقطة استعادة'; D = 'يحفظ حالة النظام قبل أي تصليح (مرة كل 24 ساعة)'; Confirm = $false
       C = 'Enable-ComputerRestore -Drive "C:\"; Checkpoint-Computer -Description "Murn Interface" -RestorePointType MODIFY_SETTINGS' },
    @{ N = 'تحديث كل البرامج (winget)'; D = 'يحدّث كل البرامج المثبتة عندك دفعة وحدة. ياخذ شوي'; Confirm = $true
       C = 'winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements' },
    @{ N = 'إيقاف Edge'; D = 'يوقف تشغيل Edge التلقائي بالخلفية والشريط الجانبي'; Confirm = $true; C = $edgeCmd },
    @{ N = 'حذف Edge'; D = 'يحذف متصفح Edge بالكامل من الجهاز'; Confirm = $true; C = $edgeRemoveCmd },
    @{ N = 'تثبيت Edge'; D = 'يحمّل ويثبت متصفح Edge من جديد'; Confirm = $true; C = $edgeInstallCmd },
    @{ N = 'حذف Copilot'; D = 'يحذف تطبيق Copilot من الجهاز'; Confirm = $true; C = $copilotRemoveCmd },
    @{ N = 'تثبيت Copilot'; D = 'يرجع تطبيق Copilot بعد حذفه'; Confirm = $true; C = $copilotInstallCmd }
)

$flow = New-Object System.Windows.Forms.FlowLayoutPanel
$flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.Padding = New-Object System.Windows.Forms.Padding(8)
$flow.RightToLeft = 'Yes'
$tabFix.Controls.Add($flow)

$script:FixPending = @()
$fixTimer = New-Object System.Windows.Forms.Timer; $fixTimer.Interval = 1500
$fixTimer.Add_Tick({
    $left = @()
    foreach ($x in $script:FixPending) {
        if (Test-Path -LiteralPath $x.M) {
            $result = Get-Content -LiteralPath $x.M -Raw -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $x.M -Force -ErrorAction SilentlyContinue
            Show-Done ('تم الانتهاء من: ' + $x.N)
            if ($result -like 'ERR:*') {
                [System.Windows.Forms.MessageBox]::Show("صار خطأ أثناء: $($x.N)`r`n`r`n$($result.Substring(4))", 'Murn Interface', 'OK', 'Error') | Out-Null
            } else {
                [System.Windows.Forms.MessageBox]::Show("تم العملية بنجاح: $($x.N)", 'Murn Interface', 'OK', 'Information') | Out-Null
            }
        }
        else { $left += $x }
    }
    $script:FixPending = $left
    if (-not $left.Count) { $fixTimer.Stop() }
})
function Start-Tool($tool) {
    if ($tool.Confirm) {
        $r = [System.Windows.Forms.MessageBox]::Show("$($tool.N)`r`n`r`n$($tool.D)`r`n`r`nتكمل؟", 'Murn Interface', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
    }
    $marker = Join-Path $env:TEMP ('murn_done_' + [guid]::NewGuid().ToString('N'))
    $cmd = "try { $($tool.C) ; Set-Content -LiteralPath '$marker' -Value 'OK' -Encoding UTF8 } catch { Set-Content -LiteralPath '$marker' -Value ('ERR:' + `$_.Exception.Message) -Encoding UTF8 }"
    Invoke-PlainScript $cmd -Hidden
    $script:FixPending += @{ M = $marker; N = $tool.N }; $fixTimer.Start()
}

foreach ($tool in $tools) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "$($tool.N)`r`n$($tool.D)"
    $b.Width = 370; $b.Height = 62; $b.Margin = New-Object System.Windows.Forms.Padding(6)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $script:Accent
    $b.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $b.ForeColor = [System.Drawing.Color]::White
    $b.TextAlign = 'MiddleRight'
    $b.Tag = $tool
    $b.Add_Click({ param($s, $e) Start-Tool $s.Tag })
    $flow.Controls.Add($b)
}

# ---------- Windows tweaks ----------
function Set-Reg($path, $name, $value, $type = 'DWord') {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
}
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$mm  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

$tweaks = @(
    @{ N = 'خطة طاقة: الأداء العالي'; D = 'يرفع أداء المعالج. يتراجع للمتوازنة'
       A = { $o = powercfg -list | Select-String '8c5e7fda'; if (-not $o) { powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null }; powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }
       U = { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e } },
    @{ N = 'إيقاف الشفافية'; D = 'يخفف حمل كرت الشاشة والواجهة'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' EnableTransparency 0 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' EnableTransparency 1 } },
    @{ N = 'إيقاف حركات النوافذ'; D = 'تصغير وتكبير النوافذ وشريط المهام بدون أنيميشن'
       A = { Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' MinAnimate '0' String; Set-Reg $adv TaskbarAnimations 0 }
       U = { Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' MinAnimate '1' String; Set-Reg $adv TaskbarAnimations 1 } },
    @{ N = 'القوائم أسرع'; D = 'يلغي تأخير ظهور القوائم'
       A = { Set-Reg 'HKCU:\Control Panel\Desktop' MenuShowDelay '0' String }
       U = { Set-Reg 'HKCU:\Control Panel\Desktop' MenuShowDelay '400' String } },
    @{ N = 'إيقاف تسجيل Xbox Game DVR'; D = 'يوقف تسجيل الألعاب بالخلفية لزيادة الفريمات'
       A = { Set-Reg 'HKCU:\System\GameConfigStore' GameDVR_Enabled 0; Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled 0 }
       U = { Set-Reg 'HKCU:\System\GameConfigStore' GameDVR_Enabled 1; Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled 1 } },
    @{ N = 'تشغيل Game Mode'; D = 'يعطي الأولوية للعبة اللي تشتغل'
       A = { Set-Reg 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 1 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 0 } },
    @{ N = 'تجدول GPU بالهاردوير (HAGS)'; D = 'يحسّن كرت الشاشة. يحتاج إعادة تشغيل'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode 2 }
       U = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode 1 } },
    @{ N = 'تحسين استجابة الشبكة والألعاب'; D = 'يوقف تقييد الشبكة ويحسّن استجابة النظام'
       A = { Set-Reg $mm NetworkThrottlingIndex 0xffffffff; Set-Reg $mm SystemResponsiveness 0 }
       U = { Set-Reg $mm NetworkThrottlingIndex 10; Set-Reg $mm SystemResponsiveness 20 } },
    @{ N = 'إيقاف تسارع الماوس'; D = 'حركة ماوس دقيقة للألعاب. يحتاج تسجيل خروج'
       A = { Set-Reg 'HKCU:\Control Panel\Mouse' MouseSpeed '0' String; Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold1 '0' String; Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold2 '0' String }
       U = { Set-Reg 'HKCU:\Control Panel\Mouse' MouseSpeed '1' String; Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold1 '6' String; Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold2 '10' String } },
    @{ N = 'إيقاف الإعلانات والاقتراحات'; D = 'يوقف إعلانات ويندوز واقتراحات قائمة ابدأ'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0; foreach ($n in 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Value', 'SubscribedContent-338389Value', 'SubscribedContent-310093Value', 'SoftLandingEnabled') { Set-Reg $cdm $n 0 } }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 1; foreach ($n in 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338388Value', 'SubscribedContent-338389Value', 'SubscribedContent-310093Value', 'SoftLandingEnabled') { Set-Reg $cdm $n 1 } } },
    @{ N = 'إيقاف بحث Bing في ابدأ'; D = 'البحث يعرض نتائج جهازك فقط'
       A = { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 1 }
       U = { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 0 } },
    @{ N = 'إظهار الامتدادات والملفات المخفية'; D = 'يعرض .exe .jpg والملفات المخفية بالمستكشف'
       A = { Set-Reg $adv HideFileExt 0; Set-Reg $adv Hidden 1 }
       U = { Set-Reg $adv HideFileExt 1; Set-Reg $adv Hidden 2 } },
    @{ N = 'قائمة الكليك اليمين القديمة (ويندوز 11)'; D = 'يرجع القائمة الكاملة بدون Show more. يحتاج إعادة تشغيل Explorer'
       A = { New-Item -Path "$clsid\InprocServer32" -Force | Out-Null; Set-ItemProperty -Path "$clsid\InprocServer32" -Name '(default)' -Value '' }
       U = { Remove-Item -Path $clsid -Recurse -Force -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف السبات (Hibernate)'; D = 'يحرر عدة جيجا من القرص C (hiberfil.sys) ويوقف Fast Startup'
       A = { powercfg /hibernate off }
       U = { powercfg /hibernate on } },
    @{ N = 'إزالة تأخير بدء البرامج'; D = 'برامج الشروع تشتغل أسرع بعد تسجيل الدخول'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' StartupDelayInMSec 0 }
       U = { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name StartupDelayInMSec -ErrorAction SilentlyContinue } }
)

function Set-Svc($names, $mode) {
    foreach ($n in $names) {
        try {
            Set-Service -Name $n -StartupType $mode -ErrorAction Stop
            if ($mode -eq 'Disabled') { Stop-Service $n -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
}
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$uacc = 'HKCU:\Control Panel\Accessibility'

$proTweaks = @(
    @{ N = 'خطة طاقة: الأداء النهائي (Ultimate)'; D = 'أعلى أداء للمعالج بدون توفير طاقة. للمكتبي وليس اللابتوب'
       A = { $o = powercfg -list | Out-String; if ($o -match '([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\s+\(Ultimate Performance') { powercfg /setactive $Matches[1] } else { $r = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-String; if ($r -match '([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})') { powercfg /setactive $Matches[1] } } }
       U = { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e } },
    @{ N = 'إيقاف التتبع والتيليمتري'; D = 'يوقف خدمات DiagTrack وإرسال بيانات الاستخدام لمايكروسوفت'
       A = { Set-Reg "$pol\DataCollection" AllowTelemetry 0; Set-Svc 'DiagTrack', 'dmwappushservice' 'Disabled' }
       U = { Remove-ItemProperty -Path "$pol\DataCollection" -Name AllowTelemetry -ErrorAction SilentlyContinue; Set-Svc 'DiagTrack' 'Automatic'; Set-Svc 'dmwappushservice' 'Manual' } },
    @{ N = 'إيقاف سجل النشاط (Activity History)'; D = 'يوقف تسجيل نشاطك ورفعه لحساب مايكروسوفت'
       A = { foreach ($n in 'EnableActivityFeed', 'PublishUserActivities', 'UploadUserActivities') { Set-Reg "$pol\System" $n 0 } }
       U = { foreach ($n in 'EnableActivityFeed', 'PublishUserActivities', 'UploadUserActivities') { Set-Reg "$pol\System" $n 1 } } },
    @{ N = 'إيقاف تقارير الأخطاء (WER)'; D = 'ما يرسل تقارير الأعطال ويخفف الخلفية'
       A = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' Disabled 1 }
       U = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' Disabled 0 } },
    @{ N = 'منع التطبيقات من الشغل بالخلفية'; D = 'يوفر رام ومعالج. ممكن توقف إشعارات بعض تطبيقات المتجر'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' GlobalUserDisabled 1; Set-Reg "$pol\AppPrivacy" LetAppsRunInBackground 2 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' GlobalUserDisabled 0; Remove-ItemProperty -Path "$pol\AppPrivacy" -Name LetAppsRunInBackground -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف رفع التحديثات لأجهزة ثانية'; D = 'Delivery Optimization: يوقف استخدام الإنترنت لرفع تحديثات لغيرك'
       A = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' DODownloadMode 0 }
       U = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' DODownloadMode 1 } },
    @{ N = 'إيقاف SysMain (Superfetch)'; D = 'مناسب لأقراص SSD. يخفف استخدام القرص والرام'
       A = { Set-Svc 'SysMain' 'Disabled' }
       U = { Set-Svc 'SysMain' 'Automatic'; Start-Service SysMain -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف فهرسة البحث (Windows Search)'; D = 'يوفر القرص والمعالج لكن البحث بالمستكشف يصير أبطأ'
       A = { Set-Svc 'WSearch' 'Disabled' }
       U = { Set-Svc 'WSearch' 'Automatic'; Start-Service WSearch -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف خدمات غير ضرورية'; D = 'خرائط، وضع العرض التجريبي، الفاكس، مشاركة وسائط WMP'
       A = { Set-Svc 'MapsBroker', 'RetailDemo', 'Fax', 'WMPNetworkSvc' 'Disabled' }
       U = { Set-Svc 'MapsBroker' 'Automatic'; Set-Svc 'RetailDemo', 'Fax', 'WMPNetworkSvc' 'Manual' } },
    @{ N = 'إيقاف Power Throttling'; D = 'يمنع ويندوز من تقليل أداء البرامج بالخلفية'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' PowerThrottlingOff 1 }
       U = { Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name PowerThrottlingOff -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف USB Selective Suspend'; D = 'يمنع فصل منافذ USB لتوفير الطاقة (يصلح قطع الماوس والكيبورد)'
       A = { powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0; powercfg /setactive scheme_current }
       U = { powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1; powercfg /setactive scheme_current } },
    @{ N = 'إغلاق البرامج والخدمات أسرع'; D = 'يقلل مهلة إغلاق التطبيقات المعلقة عند الإغلاق وإعادة التشغيل'
       A = { Set-Reg 'HKCU:\Control Panel\Desktop' WaitToKillAppTimeout '2000' String; Set-Reg 'HKCU:\Control Panel\Desktop' HungAppTimeout '1000' String; Set-Reg 'HKCU:\Control Panel\Desktop' AutoEndTasks '1' String; Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' WaitToKillServiceTimeout '2000' String }
       U = { Set-Reg 'HKCU:\Control Panel\Desktop' WaitToKillAppTimeout '20000' String; Set-Reg 'HKCU:\Control Panel\Desktop' HungAppTimeout '5000' String; Set-Reg 'HKCU:\Control Panel\Desktop' AutoEndTasks '0' String; Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' WaitToKillServiceTimeout '5000' String } },
    @{ N = 'المؤثرات البصرية: أفضل أداء'; D = 'يضبط خيارات الأداء بخصائص النظام على أفضل أداء'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' VisualFXSetting 2 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' VisualFXSetting 0 } },
    @{ N = 'إخفاء ويدجت والدردشة وعرض المهام'; D = 'ينظف شريط المهام (ويندوز 11). يحتاج إعادة تشغيل Explorer'
       A = { Set-Reg $adv TaskbarDa 0; Set-Reg $adv TaskbarMn 0; Set-Reg $adv ShowTaskViewButton 0 }
       U = { Set-Reg $adv TaskbarDa 1; Set-Reg $adv TaskbarMn 1; Set-Reg $adv ShowTaskViewButton 1 } },
    @{ N = 'إيقاف نافذة Sticky Keys'; D = 'ما تطلع نافذة المفاتيح اللاصقة وقت الألعاب (ضغط Shift 5 مرات)'
       A = { Set-Reg "$uacc\StickyKeys" Flags '506' String; Set-Reg "$uacc\Keyboard Response" Flags '122' String; Set-Reg "$uacc\ToggleKeys" Flags '58' String }
       U = { Set-Reg "$uacc\StickyKeys" Flags '510' String; Set-Reg "$uacc\Keyboard Response" Flags '126' String; Set-Reg "$uacc\ToggleKeys" Flags '62' String } },
    @{ N = 'إيقاف المساعدة عن بعد'; D = 'يمنع اتصال Remote Assistance بجهازك'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' fAllowToGetHelp 0 }
       U = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' fAllowToGetHelp 1 } }
)
$featTweaks = @(
    @{ N = 'إيقاف خدمة الطابعات (Spooler)'; D = 'إذا ما تستخدم طابعة. يوفر رام ويقلل المخاطر'
       A = { Set-Svc 'Spooler' 'Disabled' }
       U = { Set-Svc 'Spooler' 'Automatic'; Start-Service Spooler -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف البلوتوث'; D = 'يوقف خدمة البلوتوث. لا تستخدمه إذا ماوسك أو سماعتك بلوتوث'
       A = { Set-Svc 'bthserv' 'Disabled' }
       U = { Set-Svc 'bthserv' 'Manual'; Start-Service bthserv -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف خدمات Xbox'; D = 'يوقف خدمات Xbox بالخلفية. لا تستخدمه إذا تلعب ألعاب Xbox أو Game Pass'
       A = { Set-Svc 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc' 'Disabled' }
       U = { Set-Svc 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc' 'Manual' } },
    @{ N = 'إيقاف التحديث التلقائي لويندوز'; D = 'ما ينزّل ويثبّت تحديثات لحاله. تقدر تحدّث يدوياً من الإعدادات'
       A = { Set-Reg "$pol\WindowsUpdate\AU" NoAutoUpdate 1 }
       U = { Remove-ItemProperty -Path "$pol\WindowsUpdate\AU" -Name NoAutoUpdate -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف Copilot'; D = 'يخفي مساعد Copilot من ويندوز'
       A = { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1 }
       U = { Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 0 } },
    @{ N = 'إيقاف إشعارات ويندوز'; D = 'ما تطلع لك إشعارات التطبيقات والنظام'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' ToastEnabled 0 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' ToastEnabled 1 } },
    @{ N = 'إيقاف تحديد الموقع'; D = 'يمنع ويندوز والتطبيقات من معرفة موقعك'
       A = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' Value 'Deny' String }
       U = { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' Value 'Allow' String } },
    @{ N = 'إيقاف التشغيل السريع (Fast Startup)'; D = 'يحل مشاكل الإغلاق وإعادة التشغيل والأجهزة اللي ما تتعرف بعد الإغلاق'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' HiberbootEnabled 0 }
       U = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' HiberbootEnabled 1 } },
    @{ N = 'الوضع الداكن'; D = 'يشغّل المظهر الداكن لويندوز والتطبيقات'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme 0; Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' SystemUsesLightTheme 0 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme 1; Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' SystemUsesLightTheme 1 } }
)

# current-state checks: return $true when the tweak is applied
function RegIs($path, $name, $val) { try { (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name -eq $val } catch { $false } }
function SvcIs($name, $type) { $s = Get-Service -Name $name -ErrorAction SilentlyContinue; [bool]($s -and "$($s.StartType)" -eq $type) }
$persz = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$tweakChecks = @{
    'خطة طاقة: الأداء العالي' = { [bool]((powercfg /getactivescheme | Out-String) -match '8c5e7fda') }
    'إيقاف الشفافية' = { RegIs $persz EnableTransparency 0 }
    'إيقاف حركات النوافذ' = { RegIs 'HKCU:\Control Panel\Desktop\WindowMetrics' MinAnimate '0' }
    'القوائم أسرع' = { RegIs 'HKCU:\Control Panel\Desktop' MenuShowDelay '0' }
    'إيقاف تسجيل Xbox Game DVR' = { RegIs 'HKCU:\System\GameConfigStore' GameDVR_Enabled 0 }
    'تشغيل Game Mode' = { RegIs 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 1 }
    'تجدول GPU بالهاردوير (HAGS)' = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode 2 }
    'تحسين استجابة الشبكة والألعاب' = { (RegIs $mm NetworkThrottlingIndex -1) -and (RegIs $mm SystemResponsiveness 0) }
    'إيقاف تسارع الماوس' = { RegIs 'HKCU:\Control Panel\Mouse' MouseSpeed '0' }
    'إيقاف الإعلانات والاقتراحات' = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0 }
    'إيقاف بحث Bing في ابدأ' = { RegIs 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 1 }
    'إظهار الامتدادات والملفات المخفية' = { RegIs $adv HideFileExt 0 }
    'قائمة الكليك اليمين القديمة (ويندوز 11)' = { Test-Path "$clsid\InprocServer32" }
    'إيقاف السبات (Hibernate)' = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' HibernateEnabled 0 }
    'إزالة تأخير بدء البرامج' = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' StartupDelayInMSec 0 }
    'خطة طاقة: الأداء النهائي (Ultimate)' = { [bool]((powercfg /getactivescheme | Out-String) -match 'e9a42b02|Ultimate') }
    'إيقاف التتبع والتيليمتري' = { RegIs "$pol\DataCollection" AllowTelemetry 0 }
    'إيقاف سجل النشاط (Activity History)' = { RegIs "$pol\System" EnableActivityFeed 0 }
    'إيقاف تقارير الأخطاء (WER)' = { RegIs 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' Disabled 1 }
    'منع التطبيقات من الشغل بالخلفية' = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' GlobalUserDisabled 1 }
    'إيقاف رفع التحديثات لأجهزة ثانية' = { RegIs 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' DODownloadMode 0 }
    'إيقاف SysMain (Superfetch)' = { SvcIs 'SysMain' 'Disabled' }
    'إيقاف فهرسة البحث (Windows Search)' = { SvcIs 'WSearch' 'Disabled' }
    'إيقاف خدمات غير ضرورية' = { SvcIs 'MapsBroker' 'Disabled' }
    'إيقاف Power Throttling' = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' PowerThrottlingOff 1 }
    'إغلاق البرامج والخدمات أسرع' = { RegIs 'HKCU:\Control Panel\Desktop' WaitToKillAppTimeout '2000' }
    'المؤثرات البصرية: أفضل أداء' = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' VisualFXSetting 2 }
    'إخفاء ويدجت والدردشة وعرض المهام' = { RegIs $adv TaskbarDa 0 }
    'إيقاف نافذة Sticky Keys' = { RegIs "$uacc\StickyKeys" Flags '506' }
    'إيقاف المساعدة عن بعد' = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' fAllowToGetHelp 0 }
    'إيقاف خدمة الطابعات (Spooler)' = { SvcIs 'Spooler' 'Disabled' }
    'إيقاف البلوتوث' = { SvcIs 'bthserv' 'Disabled' }
    'إيقاف خدمات Xbox' = { SvcIs 'XblGameSave' 'Disabled' }
    'إيقاف التحديث التلقائي لويندوز' = { RegIs "$pol\WindowsUpdate\AU" NoAutoUpdate 1 }
    'إيقاف Copilot' = { RegIs 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1 }
    'إيقاف إشعارات ويندوز' = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' ToastEnabled 0 }
    'إيقاف تحديد الموقع' = { RegIs 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' Value 'Deny' }
    'إيقاف التشغيل السريع (Fast Startup)' = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' HiberbootEnabled 0 }
    'الوضع الداكن' = { RegIs $persz AppsUseLightTheme 0 }
}
$featTweaks += @(
    @{ N = 'تفعيل المسارات الطويلة (Long Paths)'; D = 'يسمح بمسارات ملفات أطول من 260 حرف'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled 1 }
       U = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled 0 } },
    @{ N = 'إنهاء المهمة بالكليك اليمين (شريط المهام)'; D = 'يضيف End Task بقائمة الكليك اليمين على أيقونة البرنامج'
       A = { Set-Reg "$adv\TaskbarDeveloperSettings" TaskbarEndTask 1 }
       U = { Set-Reg "$adv\TaskbarDeveloperSettings" TaskbarEndTask 0 } },
    @{ N = 'إيقاف شاشة القفل'; D = 'يدخل مباشرة لشاشة تسجيل الدخول بدون شاشة القفل'
       A = { Set-Reg "$pol\Personalization" NoLockScreen 1 }
       U = { Remove-ItemProperty -Path "$pol\Personalization" -Name NoLockScreen -ErrorAction SilentlyContinue } },
    @{ N = 'تشغيل Num Lock عند الإقلاع'; D = 'يشتغل زر الأرقام تلقائياً عند تشغيل الجهاز'
       A = { Set-Reg 'HKCU:\Control Panel\Keyboard' InitialKeyboardIndicators '2' String; Set-Reg 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' InitialKeyboardIndicators '2' String }
       U = { Set-Reg 'HKCU:\Control Panel\Keyboard' InitialKeyboardIndicators '0' String; Set-Reg 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' InitialKeyboardIndicators '0' String } },
    @{ N = 'إخفاء أيقونة البحث من شريط المهام'; D = 'يخفي مربع/أيقونة البحث (ويندوز 11)'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 2 } },
    @{ N = 'أيقونات شريط المهام على اليسار'; D = 'يرجع محاذاة شريط المهام لليسار مثل ويندوز 10 (ويندوز 11)'
       A = { Set-Reg $adv TaskbarAl 0 }
       U = { Set-Reg $adv TaskbarAl 1 } },
    @{ N = 'أشرطة التمرير ظاهرة دائماً'; D = 'ما تختفي أشرطة التمرير تلقائياً'
       A = { Set-Reg 'HKCU:\Control Panel\Accessibility' DynamicScrollbars 0 }
       U = { Set-Reg 'HKCU:\Control Panel\Accessibility' DynamicScrollbars 1 } },
    @{ N = 'إيقاف Storage Sense'; D = 'يوقف التنظيف التلقائي للملفات المؤقتة وسلة المحذوفات'
       A = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0 }
       U = { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 1 } },
    @{ N = 'إيقاف WPBT'; D = 'يمنع الشركات المصنعة من حقن برامج بالإقلاع (Windows Platform Binary Table)'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' DisableWpbtExecution 1 }
       U = { Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name DisableWpbtExecution -ErrorAction SilentlyContinue } },
    @{ N = 'إيقاف IPv6 (متقدم)'; D = 'حذر: بعض الشبكات والتطبيقات تحتاجه. يحتاج إعادة تشغيل'
       A = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' DisabledComponents 255 }
       U = { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' DisabledComponents 0 } }
)
$tweakChecks['تفعيل المسارات الطويلة (Long Paths)'] = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled 1 }
$tweakChecks['إنهاء المهمة بالكليك اليمين (شريط المهام)'] = { RegIs "$adv\TaskbarDeveloperSettings" TaskbarEndTask 1 }
$tweakChecks['إيقاف شاشة القفل'] = { RegIs "$pol\Personalization" NoLockScreen 1 }
$tweakChecks['تشغيل Num Lock عند الإقلاع'] = { RegIs 'HKCU:\Control Panel\Keyboard' InitialKeyboardIndicators '2' }
$tweakChecks['إخفاء أيقونة البحث من شريط المهام'] = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0 }
$tweakChecks['أيقونات شريط المهام على اليسار'] = { RegIs $adv TaskbarAl 0 }
$tweakChecks['أشرطة التمرير ظاهرة دائماً'] = { RegIs 'HKCU:\Control Panel\Accessibility' DynamicScrollbars 0 }
$tweakChecks['إيقاف Storage Sense'] = { RegIs 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0 }
$tweakChecks['إيقاف WPBT'] = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' DisableWpbtExecution 1 }
$tweakChecks['إيقاف IPv6 (متقدم)'] = { RegIs 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' DisabledComponents 255 }
foreach ($t in $tweaks) { $t.G = 'basic' }
foreach ($t in $proTweaks) { $t.G = 'pro' }
foreach ($t in $featTweaks) { $t.G = 'feat' }
$tweaks += $proTweaks
$tweaks += $featTweaks
foreach ($t in $tweaks) { $t.C = $tweakChecks[$t.N] }

$lvT = New-Object System.Windows.Forms.ListView
$lvT.View = 'Details'; $lvT.CheckBoxes = $true; $lvT.FullRowSelect = $true; $lvT.HeaderStyle = 'None'
$lvT.Dock = 'Fill'; $lvT.BorderStyle = 'None'
$lvT.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $lvT.ForeColor = [System.Drawing.Color]::White
[void]$lvT.Columns.Add('التويك', 270)
[void]$lvT.Columns.Add('الحالة', 90)
[void]$lvT.Columns.Add('الوصف', 330)
[void]$lvT.Columns.Add('النوع', 90)
$lvT.ShowGroups = $false
$gBasic = New-Object System.Windows.Forms.ListViewGroup 'تويكات أساسية'
$gPro = New-Object System.Windows.Forms.ListViewGroup 'تويكات احترافية (للمستخدم المتقدم)'
$gFeat = New-Object System.Windows.Forms.ListViewGroup 'تشغيل وإيقاف ميزات محددة'
[void]$lvT.Groups.Add($gBasic); [void]$lvT.Groups.Add($gPro); [void]$lvT.Groups.Add($gFeat)
foreach ($t in $tweaks) {
    $it = New-Object System.Windows.Forms.ListViewItem($t.N)
    $it.Group = switch ($t.G) { 'pro' { $gPro } 'feat' { $gFeat } default { $gBasic } }
    [void]$it.SubItems.Add('...')
    [void]$it.SubItems.Add($t.D)
    [void]$it.SubItems.Add($(switch ($t.G) { 'pro' { 'احترافي' } 'feat' { 'ميزة' } default { 'أساسي' } }))
    $it.Tag = $t
    [void]$lvT.Items.Add($it)
}

$tLog = New-Object System.Windows.Forms.TextBox
$tLog.Multiline = $true; $tLog.ReadOnly = $true; $tLog.Dock = 'Bottom'; $tLog.Height = 110; $tLog.ScrollBars = 'None'
$tLog.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 21); $tLog.ForeColor = [System.Drawing.Color]::LightGray
$tLog.BorderStyle = 'None'; $tLog.Font = New-Object System.Drawing.Font('Consolas', 10)

$btnPanel = New-Object System.Windows.Forms.TableLayoutPanel
$btnPanel.Dock = 'Bottom'; $btnPanel.Height = 48; $btnPanel.ColumnCount = 3; $btnPanel.RowCount = 1
foreach ($i in 1..3) { [void]$btnPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent', 33.33)) }
function New-TweakButton($text, $color) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Dock = 'Fill'; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $b
}
$btnApply = New-TweakButton 'طبّق المحدد' ([System.Drawing.Color]::FromArgb(0, 190, 215))
$btnUndo  = New-TweakButton 'تراجع عن المحدد' ([System.Drawing.Color]::FromArgb(176, 100, 30))
$btnAll   = New-TweakButton 'تحديث الحالة' ([System.Drawing.Color]::FromArgb(60, 66, 80))
$btnPanel.Controls.Add($btnApply, 0, 0); $btnPanel.Controls.Add($btnUndo, 1, 0); $btnPanel.Controls.Add($btnAll, 2, 0)

function Invoke-Tweaks($undo) {
    $sel = @($lvT.CheckedItems)
    if (-not $sel.Count) { $tLog.AppendText("حدد تويك واحد على الأقل`r`n"); return }
    $verb = if ($undo) { 'التراجع عن' } else { 'تطبيق' }
    $r = [System.Windows.Forms.MessageBox]::Show("$verb $($sel.Count) تويك؟", 'Murn Interface', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    if (-not $undo) { try { Checkpoint-Computer -Description 'Murn Interface tweaks' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; $tLog.AppendText("تم إنشاء نقطة استعادة`r`n") } catch { $tLog.AppendText("ما انعملت نقطة استعادة (يسمح بوحدة كل 24 ساعة)`r`n") } }
    foreach ($it in $sel) {
        $t = $it.Tag
        try { & $(if ($undo) { $t.U } else { $t.A }); $tLog.AppendText("تم: $($t.N)`r`n") }
        catch { $tLog.AppendText("فشل: $($t.N) - $($_.Exception.Message)`r`n") }
    }
    $tLog.AppendText("انتهى. بعض التويكات تحتاج إعادة تشغيل الجهاز أو تسجيل خروج.`r`n")
    Update-TweakStates
    Show-Done 'تم تطبيق التويكات'
}
$btnApply.Add_Click({ Invoke-Tweaks $false })
$btnUndo.Add_Click({ Invoke-Tweaks $true })

# current state column
function Get-TweakState($t) {
    if (-not $t.C) { return $null }
    try { [bool](& $t.C) } catch { $null }
}
function Update-TweakStates {
    $lvT.BeginUpdate()
    foreach ($it in $lvT.Items) {
        $s = Get-TweakState $it.Tag
        $it.SubItems[1].Text = if ($null -eq $s) { '—' } elseif ($s) { 'مطبّق ✓' } else { 'غير مطبّق' }
        $it.ForeColor = if ($null -eq $s) { $script:D.Muted } elseif ($s) { $script:D.Good } else { $script:D.Text }
    }
    $lvT.EndUpdate()
}
$btnAll.Add_Click({ Update-TweakStates; $tLog.AppendText("تم تحديث الحالة`r`n") })

# presets by device strength
$presetMid = @(
    'القوائم أسرع', 'إيقاف تسجيل Xbox Game DVR', 'تشغيل Game Mode', 'إيقاف الإعلانات والاقتراحات', 'إيقاف بحث Bing في ابدأ',
    'إظهار الامتدادات والملفات المخفية', 'إزالة تأخير بدء البرامج', 'إيقاف التتبع والتيليمتري', 'إيقاف سجل النشاط (Activity History)',
    'إيقاف تقارير الأخطاء (WER)', 'إيقاف رفع التحديثات لأجهزة ثانية', 'إغلاق البرامج والخدمات أسرع', 'إيقاف نافذة Sticky Keys', 'إيقاف Copilot'
)
$presetWeak = $presetMid + @(
    'إيقاف الشفافية', 'إيقاف حركات النوافذ', 'المؤثرات البصرية: أفضل أداء', 'منع التطبيقات من الشغل بالخلفية',
    'إيقاف SysMain (Superfetch)', 'إيقاف فهرسة البحث (Windows Search)', 'إيقاف خدمات غير ضرورية',
    'إخفاء ويدجت والدردشة وعرض المهام', 'إيقاف السبات (Hibernate)', 'إيقاف خدمات Xbox'
)
$presetStrong = $presetMid + @(
    'خطة طاقة: الأداء النهائي (Ultimate)', 'تجدول GPU بالهاردوير (HAGS)', 'تحسين استجابة الشبكة والألعاب',
    'إيقاف تسارع الماوس', 'إيقاف Power Throttling', 'إيقاف USB Selective Suspend'
)
function Select-Preset($names, $label) {
    foreach ($it in $lvT.Items) { $it.Checked = ($names -contains $it.Tag.N) }
    $tLog.AppendText("تم تحديد تويكات '$label' ($(@($lvT.CheckedItems).Count)). راجعها واضغط طبّق المحدد`r`n")
}
function Get-DevicePower {
    try {
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $cores = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum
        $laptop = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    } catch { return $null }
    $lvl = if ($ramGB -le 8 -or $cores -le 4) { 'weak' } elseif ($ramGB -ge 16 -and $cores -ge 8) { 'strong' } else { 'mid' }
    @{ RamGB = $ramGB; Cores = $cores; Laptop = $laptop; Level = $lvl }
}

$presetPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$presetPanel.Dock = 'Top'; $presetPanel.Height = 46; $presetPanel.Padding = New-Object System.Windows.Forms.Padding(4, 4, 4, 0)
function New-PresetButton($text, $w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $w; $b.Height = 36; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = [System.Drawing.Color]::FromArgb(60, 66, 80); $b.ForeColor = [System.Drawing.Color]::White
    $presetPanel.Controls.Add($b); $b
}
$bpAuto = New-PresetButton 'تلقائي (حسب جهازي)' 150
$bpWeak = New-PresetButton 'جهاز ضعيف' 110
$bpMid  = New-PresetButton 'جهاز متوسط' 110
$bpStr  = New-PresetButton 'جهاز قوي / ألعاب' 130
$bpCur  = New-PresetButton 'المطبّق حالياً' 110
$bpClr  = New-PresetButton 'مسح التحديد' 100
$bpAuto.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 190)
$bpWeak.Add_Click({ Select-Preset $presetWeak 'جهاز ضعيف' })
$bpMid.Add_Click({ Select-Preset $presetMid 'جهاز متوسط' })
$bpStr.Add_Click({ Select-Preset $presetStrong 'جهاز قوي / ألعاب' })
$bpClr.Add_Click({ foreach ($it in $lvT.Items) { $it.Checked = $false } })
$bpCur.Add_Click({
    Update-TweakStates
    foreach ($it in $lvT.Items) { $it.Checked = ($it.SubItems[1].Text -like 'مطبّق*') }
})
$bpAuto.Add_Click({
    $d = Get-DevicePower
    if (-not $d) { $tLog.AppendText("ما قدرت أقرأ مواصفات الجهاز`r`n"); return }
    $names = switch ($d.Level) { 'weak' { $presetWeak } 'strong' { $presetStrong } default { $presetMid } }
    if ($d.Laptop) { $names = @($names | Where-Object { $_ -notmatch 'Ultimate|USB Selective' }) }
    $lbl = switch ($d.Level) { 'weak' { 'ضعيف' } 'strong' { 'قوي' } default { 'متوسط' } }
    $tLog.AppendText("جهازك: رام $($d.RamGB)GB ومعالج $($d.Cores) أنوية" + $(if ($d.Laptop) { ' (لابتوب)' } else { '' }) + " => مستوى $lbl`r`n")
    Select-Preset $names "تلقائي ($lbl)"
})

$tabTw = New-Object System.Windows.Forms.TabPage 'تويكات ويندوز'
$tabTw.BackColor = $form.BackColor; $tabTw.ForeColor = [System.Drawing.Color]::White
$tabTw.Controls.Add($lvT); $tabTw.Controls.Add($tLog); $tabTw.Controls.Add($btnPanel); $tabTw.Controls.Add($presetPanel)
[void]$tabs.TabPages.Add($tabTw)
$script:TweaksLoaded = $false
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -eq $tabTw -and -not $script:TweaksLoaded) {
        $script:TweaksLoaded = $true; Update-TweakStates
        $tLog.AppendText("اختر مستوى جهازك من الأزرار فوق (أو تلقائي) ثم اضغط طبّق المحدد. الأخضر = مطبّق حالياً.`r`n")
    }
})

# ---------- Startup apps ----------
$apprRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'

function Get-ApprState($hive, $sub, $name) {
    try {
        $v = (Get-Item -Path "${hive}:\$apprRoot\$sub" -ErrorAction Stop).GetValue($name)
        if ($v -and ($v[0] -band 1)) { return $false }
    } catch {}
    $true
}

function Set-ApprState($hive, $sub, $name, $enabled) {
    $p = "${hive}:\$apprRoot\$sub"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    $b = New-Object byte[] 12
    if ($enabled) { $b[0] = 2 } else { $b[0] = 3; [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($b, 4) }
    Set-ItemProperty -Path $p -Name $name -Value $b -Type Binary
}

function Get-StartupItems {
    $items = New-Object System.Collections.ArrayList
    $regSources = @(
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Hive = 'HKCU'; Sub = 'Run'; Src = 'تسجيل المستخدم' },
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Hive = 'HKLM'; Sub = 'Run'; Src = 'تسجيل النظام' },
        @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Hive = 'HKLM'; Sub = 'Run32'; Src = 'تسجيل النظام (32 بت)' }
    )
    foreach ($s in $regSources) {
        if (-not (Test-Path $s.Key)) { continue }
        $k = Get-Item $s.Key -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            if (-not $n) { continue }
            [void]$items.Add([pscustomobject]@{ Name = $n; Src = $s.Src; Cmd = [string]$k.GetValue($n); Enabled = (Get-ApprState $s.Hive $s.Sub $n); Kind = 'Reg'; Hive = $s.Hive; Sub = $s.Sub; Task = $null })
        }
    }
    $folders = @(
        @{ Path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; Hive = 'HKCU'; Src = 'مجلد بدء التشغيل (المستخدم)' },
        @{ Path = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; Hive = 'HKLM'; Src = 'مجلد بدء التشغيل (الكل)' }
    )
    foreach ($f in $folders) {
        if (-not (Test-Path $f.Path)) { continue }
        foreach ($file in Get-ChildItem $f.Path -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
            [void]$items.Add([pscustomobject]@{ Name = $file.Name; Src = $f.Src; Cmd = $file.FullName; Enabled = (Get-ApprState $f.Hive 'StartupFolder' $file.Name); Kind = 'Reg'; Hive = $f.Hive; Sub = 'StartupFolder'; Task = $null })
        }
    }
    try {
        foreach ($t in Get-ScheduledTask -ErrorAction Stop) {
            if ($t.TaskPath -like '\Microsoft\*') { continue }
            if (-not ($t.Triggers | Where-Object { $_.CimClass.CimClassName -in 'MSFT_TaskLogonTrigger', 'MSFT_TaskBootTrigger' })) { continue }
            $a = $t.Actions | Select-Object -First 1
            [void]$items.Add([pscustomobject]@{ Name = $t.TaskName; Src = 'مهمة مجدولة'; Cmd = ("$($a.Execute) $($a.Arguments)").Trim(); Enabled = ($t.State -ne 'Disabled'); Kind = 'Task'; Hive = $null; Sub = $null; Task = $t })
        }
    } catch {}
    $items
}

function Get-ExePathFromCmd($cmd) {
    if (-not $cmd) { return $null }
    $cmd = $cmd.Trim()
    if ($cmd.StartsWith('"')) {
        $end = $cmd.IndexOf('"', 1)
        if ($end -gt 0) { return $cmd.Substring(1, $end - 1) }
    }
    $m = [regex]::Match($cmd, '^[^\s]+\.exe', 'IgnoreCase')
    if ($m.Success) { return $m.Value }
    ($cmd -split '\s+')[0]
}
$script:StartupIcoCache = @{}
function Get-StartupItemIcon($x) {
    try {
        $path = if ($x.Sub -eq 'StartupFolder') { $x.Cmd } else { Get-ExePathFromCmd $x.Cmd }
        if (-not $path) { return $null }
        $path = [Environment]::ExpandEnvironmentVariables($path.Trim('"'))
        if ($script:StartupIcoCache.ContainsKey($path)) { return $script:StartupIcoCache[$path] }
        $bmp = $null
        if (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue) {
            $ic = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
            if ($ic) { $bmp = $ic.ToBitmap() }
        }
        $script:StartupIcoCache[$path] = $bmp
        $bmp
    } catch { $null }
}

$stFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$stFlow.Dock = 'Fill'; $stFlow.FlowDirection = 'TopDown'; $stFlow.WrapContents = $false; $stFlow.AutoScroll = $true
$stFlow.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27); $stFlow.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$stFlow.RightToLeft = 'No'
$stFlow.Add_Resize({ $w = [math]::Max(300, $stFlow.ClientSize.Width - 36); foreach ($r in $stFlow.Controls) { $r.Width = $w } })

$sStatus = New-Object System.Windows.Forms.Label
$sStatus.Dock = 'Bottom'; $sStatus.Height = 30; $sStatus.ForeColor = [System.Drawing.Color]::Gray; $sStatus.TextAlign = 'MiddleCenter'
$btnSRef = New-TweakButton 'تحديث القائمة' ([System.Drawing.Color]::FromArgb(60, 66, 80))
$btnSRef.Dock = 'Bottom'; $btnSRef.Height = 44

# (Get-ToggleBitmap lives in the Design System section)
function New-ToggleSwitch {
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Width = 64; $pb.Height = 28; $pb.Cursor = 'Hand'
    $pb.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40)
    $pb.SizeMode = 'CenterImage'
    $pb
}
function Set-ToggleLook($b, $on) {
    if ($b.Image) { $old = $b.Image; $b.Image = $null; $old.Dispose() }
    $b.Image = Get-ToggleBitmap $on
}
function Update-StartupCount {
    $all = @($stFlow.Controls | ForEach-Object { $_.Tag })
    $off = @($all | Where-Object { -not $_.Enabled }).Count
    $sStatus.Text = "المجموع: $($all.Count) | معطّل: $off. اضغط على الحالة لتفعيل التطبيق أو تعطيله (التعطيل ما يحذف التطبيق)."
}
function Switch-Startup($b) {
    $x = $b.Tag; $new = -not $x.Enabled
    try {
        if ($x.Kind -eq 'Task') {
            if ($new) { Enable-ScheduledTask -TaskName $x.Task.TaskName -TaskPath $x.Task.TaskPath -ErrorAction Stop | Out-Null }
            else { Disable-ScheduledTask -TaskName $x.Task.TaskName -TaskPath $x.Task.TaskPath -ErrorAction Stop | Out-Null }
        } else { Set-ApprState $x.Hive $x.Sub $x.Name $new }
        $x.Enabled = $new; Set-ToggleLook $b $new; Update-StartupCount
    } catch { $sStatus.Text = 'ما قدرت أغيّر حالة: ' + $x.Name }
}

function Update-Startup {
    $sStatus.Text = 'جاري القراءة...'; [System.Windows.Forms.Application]::DoEvents()
    $stFlow.SuspendLayout()
    foreach ($c in @($stFlow.Controls)) { $stFlow.Controls.Remove($c); $c.Dispose() }
    $w = [math]::Max(300, $stFlow.ClientSize.Width - 36)
    foreach ($x in @(Get-StartupItems | Sort-Object @{Expression = { -not $_.Enabled } }, Name)) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Width = $w; $row.Height = 50; $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 7)
        $row.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $row.Tag = $x
        $tgWrap = New-Object System.Windows.Forms.Panel
        $tgWrap.Dock = 'Left'; $tgWrap.Width = 86; $tgWrap.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40)
        $tg = New-ToggleSwitch
        $tg.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40)
        $tg.Location = New-Object System.Drawing.Point(10, 10); $tg.Tag = $x
        Set-ToggleLook $tg $x.Enabled
        $tg.Add_Click({ param($s, $e) Switch-Startup $s })
        $tgWrap.Controls.Add($tg)
        $icoBox = New-Object System.Windows.Forms.PictureBox
        $icoBox.Dock = 'Right'; $icoBox.Width = 42; $icoBox.SizeMode = 'CenterImage'
        $icoBmp = Get-StartupItemIcon $x
        if ($icoBmp) { $icoBox.Image = $icoBmp }
        $nm = New-Object System.Windows.Forms.Label
        $nm.Dock = 'Fill'; $nm.TextAlign = 'MiddleRight'; $nm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
        $nm.Font = New-Object System.Drawing.Font('Segoe UI', 11); $nm.ForeColor = [System.Drawing.Color]::White
        $nm.Text = ($x.Name -replace '\.lnk$', '')
        $row.Controls.Add($nm); $row.Controls.Add($icoBox); $row.Controls.Add($tgWrap)
        $stFlow.Controls.Add($row)
    }
    $stFlow.ResumeLayout()
    Update-StartupCount
}
$btnSRef.Add_Click({ Update-Startup })

$tabSt = New-Object System.Windows.Forms.TabPage 'تطبيقات بدء التشغيل'
$tabSt.BackColor = $form.BackColor; $tabSt.ForeColor = [System.Drawing.Color]::White
$tabSt.Controls.Add($stFlow); $tabSt.Controls.Add($sStatus); $tabSt.Controls.Add($btnSRef)
[void]$tabs.TabPages.Add($tabSt)
$script:StartupLoaded = $false
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -eq $tabSt -and -not $script:StartupLoaded) { $script:StartupLoaded = $true; Update-Startup }
})

# ---------- Running programs ----------
$rpFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$rpFlow.Dock = 'Fill'; $rpFlow.FlowDirection = 'TopDown'; $rpFlow.WrapContents = $false; $rpFlow.AutoScroll = $true
$rpFlow.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27); $rpFlow.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$rpFlow.RightToLeft = 'No'
$rpFlow.Add_Resize({ $w = [math]::Max(300, $rpFlow.ClientSize.Width - 36); foreach ($r in $rpFlow.Controls) { $r.Width = $w } })

$rpStatus = New-Object System.Windows.Forms.Label
$rpStatus.Dock = 'Bottom'; $rpStatus.Height = 30; $rpStatus.ForeColor = [System.Drawing.Color]::Gray; $rpStatus.TextAlign = 'MiddleCenter'
$btnRpRef = New-TweakButton 'تحديث القائمة' ([System.Drawing.Color]::FromArgb(60, 66, 80))
$btnRpRef.Dock = 'Bottom'; $btnRpRef.Height = 44

function End-RunningProgram($b) {
    $x = $b.Tag
    try {
        Stop-Process -Id $x.Id -Force -ErrorAction Stop
        $rpStatus.Text = "تم إنهاء: $($x.Name)"
        Update-RunningProgs
    } catch { $rpStatus.Text = "ما قدرت أنهي: $($x.Name)" }
}

function Update-RunningProgs {
    $rpStatus.Text = 'جاري القراءة...'; [System.Windows.Forms.Application]::DoEvents()
    $rpFlow.SuspendLayout()
    foreach ($c in @($rpFlow.Controls)) {
        foreach ($pb in @($c.Controls | Where-Object { $_ -is [System.Windows.Forms.PictureBox] })) {
            if ($pb.Image) { $img = $pb.Image; $pb.Image = $null; $img.Dispose() }
        }
        $rpFlow.Controls.Remove($c); $c.Dispose()
    }
    $w = [math]::Max(300, $rpFlow.ClientSize.Width - 36)
    $procs = @(Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } | Sort-Object WorkingSet64 -Descending)
    foreach ($x in $procs) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Width = $w; $row.Height = 50; $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 7)
        $row.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $row.Tag = $x
        $isSelf = ($x.Id -eq $PID)
        $icoBox = New-Object System.Windows.Forms.PictureBox
        $icoBox.Dock = 'Right'; $icoBox.Width = 42; $icoBox.SizeMode = 'CenterImage'
        try {
            if ($isSelf) {
                $selfExePath = if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE)) { $env:MURN_EXE } else { Join-Path $script:AppDir 'Murn Interface.exe' }
                if (Test-Path -LiteralPath $selfExePath) {
                    $ic = [System.Drawing.Icon]::ExtractAssociatedIcon($selfExePath)
                    if ($ic) { $icoBox.Image = $ic.ToBitmap(); $ic.Dispose() }
                }
            } else {
                $exePath = $x.Path
                if (-not $exePath) { $exePath = $x.MainModule.FileName }
                if ($exePath -and (Test-Path -LiteralPath $exePath -ErrorAction SilentlyContinue)) {
                    $ic = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
                    if ($ic) { $icoBox.Image = $ic.ToBitmap(); $ic.Dispose() }
                }
            }
        } catch {}
        $nm = New-Object System.Windows.Forms.Label
        $nm.Dock = 'Fill'; $nm.TextAlign = 'MiddleRight'; $nm.Padding = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
        $nm.Font = New-Object System.Drawing.Font('Segoe UI', 11); $nm.ForeColor = [System.Drawing.Color]::White
        $mem = '{0:N0} MB' -f ($x.WorkingSet64 / 1MB)
        $dispName = if ($isSelf) { 'Murn Interface' } else { $x.ProcessName }
        $nm.Text = "$dispName  —  $mem"
        $endBtn = New-Object System.Windows.Forms.Button
        $endBtn.Dock = 'Left'; $endBtn.Width = 90; $endBtn.FlatStyle = 'Flat'; $endBtn.FlatAppearance.BorderSize = 0
        $endBtn.ForeColor = [System.Drawing.Color]::White; $endBtn.BackColor = [System.Drawing.Color]::FromArgb(150, 55, 55)
        $endBtn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $endBtn.Text = 'إنهاء'; $endBtn.Cursor = 'Hand'; $endBtn.Tag = $x
        $endBtn.Add_Click({ param($s, $e) End-RunningProgram $s })
        $row.Controls.Add($nm); $row.Controls.Add($icoBox); $row.Controls.Add($endBtn)
        $rpFlow.Controls.Add($row)
    }
    $rpFlow.ResumeLayout()
    $rpStatus.Text = "عدد البرامج الشغالة (بواجهة): $($procs.Count)"
}
$btnRpRef.Add_Click({ Update-RunningProgs })

$tabRp = New-Object System.Windows.Forms.TabPage 'البرامج الشغالة'
$tabRp.BackColor = $form.BackColor; $tabRp.ForeColor = [System.Drawing.Color]::White
$tabRp.Controls.Add($rpFlow); $tabRp.Controls.Add($rpStatus); $tabRp.Controls.Add($btnRpRef)
[void]$tabs.TabPages.Add($tabRp)
$script:RunProgsLoaded = $false
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -eq $tabRp -and -not $script:RunProgsLoaded) { $script:RunProgsLoaded = $true; Update-RunningProgs }
})

# ---------- Displays (brightness / resolution+Hz / night light) ----------
try {
    Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace MurnDisplay {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
        public int dmFields; public int dmPositionX; public int dmPositionY;
        public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency; public int dmICMMethod; public int dmICMIntent;
        public int dmMediaType; public int dmDitherType; public int dmReserved1; public int dmReserved2;
        public int dmPanningWidth; public int dmPanningHeight;
    }

    public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

    public class Native {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

        [DllImport("user32.dll")]
        public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);

        [DllImport("dxva2.dll")]
        public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref uint pdwNumberOfPhysicalMonitors);

        [DllImport("dxva2.dll")]
        public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

        [DllImport("dxva2.dll")]
        public static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, PHYSICAL_MONITOR[] pPhysicalMonitorArray);

        [DllImport("dxva2.dll")]
        public static extern bool GetMonitorBrightness(IntPtr hMonitor, ref uint pdwMinimumBrightness, ref uint pdwCurrentBrightness, ref uint pdwMaximumBrightness);

        [DllImport("dxva2.dll")]
        public static extern bool SetMonitorBrightness(IntPtr hMonitor, uint dwNewBrightness);
    }
}
'@
    $script:HasDisplayNative = $true
} catch { $script:HasDisplayNative = $false }

function Get-MonitorHandle($screenBounds) {
    if (-not $script:HasDisplayNative) { return $null }
    $found = [ref]([IntPtr]::Zero)
    $cb = [MurnDisplay.MonitorEnumDelegate]{
        param($hMonitor, $hdc, [ref]$rc, $data)
        $r = $rc.Value
        if ($r.Left -eq $screenBounds.X -and $r.Top -eq $screenBounds.Y) { $script:TmpMonHandle = $hMonitor }
        return $true
    }
    $script:TmpMonHandle = [IntPtr]::Zero
    [void][MurnDisplay.Native]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero)
    $script:TmpMonHandle
}

function Get-PhysicalMonitor($hMonitor) {
    if ($hMonitor -eq [IntPtr]::Zero) { return $null }
    try {
        $n = [uint32]0
        if (-not [MurnDisplay.Native]::GetNumberOfPhysicalMonitorsFromHMONITOR($hMonitor, [ref]$n) -or $n -eq 0) { return $null }
        $arr = New-Object 'MurnDisplay.PHYSICAL_MONITOR[]' $n
        if (-not [MurnDisplay.Native]::GetPhysicalMonitorsFromHMONITOR($hMonitor, $n, $arr)) { return $null }
        $arr[0].hPhysicalMonitor
    } catch { $null }
}

function Get-DisplayModes($deviceName) {
    $cur = New-Object MurnDisplay.DEVMODE; $cur.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][MurnDisplay.DEVMODE])
    [void][MurnDisplay.Native]::EnumDisplaySettings($deviceName, -1, [ref]$cur)
    $modes = New-Object System.Collections.Generic.HashSet[string]
    $i = 0
    while ($true) {
        $dm = New-Object MurnDisplay.DEVMODE; $dm.dmSize = $cur.dmSize
        if (-not [MurnDisplay.Native]::EnumDisplaySettings($deviceName, $i, [ref]$dm)) { break }
        if ($dm.dmPelsWidth -gt 0) { [void]$modes.Add("$($dm.dmPelsWidth)x$($dm.dmPelsHeight)@$($dm.dmDisplayFrequency)") }
        $i++
        if ($i -gt 300) { break }
    }
    $maxW = $cur.dmPelsWidth
    foreach ($m in $modes) { $ww = [int]($m -split 'x')[0]; if ($ww -gt $maxW) { $maxW = $ww } }
    [pscustomobject]@{ Current = "$($cur.dmPelsWidth) × $($cur.dmPelsHeight) @ $($cur.dmDisplayFrequency)Hz"; MaxWidth = $maxW; Count = $modes.Count }
}

function Get-WmiBrightness {
    try { (Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness } catch { $null }
}
function Set-WmiBrightness($val) {
    try {
        $m = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop | Select-Object -First 1
        Invoke-CimMethod -InputObject $m -MethodName WmiSetBrightness -Arguments @{ Timeout = 0; Brightness = [byte]$val } -ErrorAction Stop | Out-Null
        $true
    } catch { $false }
}

function Get-NightLightOn {
    try {
        $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate'
        $d = (Get-ItemProperty -Path $p -ErrorAction Stop).Data
        if ($d.Length -gt 24) { return ($d[23] -eq 0x10 -or $d[23] -eq 0x15 -or $d[23] -eq 0x11) -and ($d[23] % 2 -eq 1) }
        $null
    } catch { $null }
}
function Switch-NightLight {
    try {
        $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate'
        $d = (Get-ItemProperty -Path $p -ErrorAction Stop).Data
        $d[23] = if ($d[23] % 2 -eq 1) { $d[23] - 1 } else { $d[23] + 1 }
        Set-ItemProperty -Path $p -Name Data -Value $d -ErrorAction Stop
        $true
    } catch { $false }
}

$dpFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$dpFlow.Dock = 'Fill'; $dpFlow.FlowDirection = 'TopDown'; $dpFlow.WrapContents = $false; $dpFlow.AutoScroll = $true
$dpFlow.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27); $dpFlow.Padding = New-Object System.Windows.Forms.Padding(14)
$dpFlow.RightToLeft = 'No'
$dpFlow.Add_Resize({ $w = [math]::Max(320, $dpFlow.ClientSize.Width - 48); foreach ($r in $dpFlow.Controls) { $r.Width = $w } })

function New-DpLabel($text, $bold, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.AutoSize = $false; $l.Height = 26; $l.Dock = 'Top'
    $l.TextAlign = 'MiddleRight'; $l.ForeColor = $(if ($color) { $color } else { [System.Drawing.Color]::White })
    $l.Font = New-Object System.Drawing.Font('Segoe UI', $(if ($bold) { 12 } else { 10 }), $(if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }))
    $l
}

function Update-Displays {
    $dpFlow.SuspendLayout()
    foreach ($c in @($dpFlow.Controls)) { $dpFlow.Controls.Remove($c); $c.Dispose() }
    $w = [math]::Max(320, $dpFlow.ClientSize.Width - 48)

    $i = 0
    foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
        $i++
        $card = New-Object System.Windows.Forms.Panel
        $card.Width = $w; $card.Height = 170; $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
        $card.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $card.Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 10)

        $title = New-DpLabel ("شاشة $i" + $(if ($scr.Primary) { '  (الرئيسية)' } else { '' })) $true ($script:Accent)
        $title.Dock = 'Top'

        $modes = Get-DisplayModes $scr.DeviceName
        $badge = if ($modes.MaxWidth -ge 3840) { '  ✓ يدعم 4K' } elseif ($modes.MaxWidth -ge 2560) { '  ✓ يدعم 2K' } else { '' }
        $resLbl = New-DpLabel ("الدقة الحالية: $($modes.Current)$badge") $false $null
        $resLbl.Dock = 'Top'

        $brightRow = New-Object System.Windows.Forms.Panel
        $brightRow.Dock = 'Top'; $brightRow.Height = 40
        $brightLbl = New-Object System.Windows.Forms.Label
        $brightLbl.Text = 'السطوع'; $brightLbl.Dock = 'Right'; $brightLbl.Width = 60; $brightLbl.TextAlign = 'MiddleRight'; $brightLbl.ForeColor = [System.Drawing.Color]::Gainsboro
        $track = New-Object System.Windows.Forms.TrackBar
        $track.Dock = 'Fill'; $track.Minimum = 0; $track.Maximum = 100; $track.TickStyle = 'None'

        $hMon = Get-MonitorHandle $scr.Bounds
        $phys = Get-PhysicalMonitor $hMon
        $useWmi = $scr.Primary -and ($null -ne (Get-WmiBrightness))
        if ($useWmi) {
            $track.Value = [math]::Min(100, [math]::Max(0, [int](Get-WmiBrightness)))
            $track.Add_Scroll({ param($s, $e) [void](Set-WmiBrightness $s.Value) }.GetNewClosure())
        } elseif ($phys -and $phys -ne [IntPtr]::Zero) {
            $mn = [uint32]0; $cv = [uint32]0; $mx = [uint32]100
            if ([MurnDisplay.Native]::GetMonitorBrightness($phys, [ref]$mn, [ref]$cv, [ref]$mx)) {
                $track.Minimum = [int]$mn; $track.Maximum = [int]$mx; $track.Value = [int]$cv
                $physCap = $phys
                $track.Add_Scroll({ param($s, $e) [void][MurnDisplay.Native]::SetMonitorBrightness($physCap, [uint32]$s.Value) }.GetNewClosure())
            } else { $track.Enabled = $false; $brightLbl.Text = 'السطوع (غير مدعوم)' }
        } else { $track.Enabled = $false; $brightLbl.Text = 'السطوع (غير مدعوم)' }
        $brightRow.Controls.Add($track); $brightRow.Controls.Add($brightLbl)

        $card.Controls.Add($brightRow); $card.Controls.Add($resLbl); $card.Controls.Add($title)
        $dpFlow.Controls.Add($card)
    }

    $nlCard = New-Object System.Windows.Forms.Panel
    $nlCard.Width = $w; $nlCard.Height = 110; $nlCard.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 10)
    $nlCard.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $nlCard.Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 10)
    $nlTitle = New-DpLabel 'الضوء الليلي' $true ($script:Accent); $nlTitle.Dock = 'Top'
    $nlRow = New-Object System.Windows.Forms.Panel; $nlRow.Dock = 'Top'; $nlRow.Height = 46
    $nlToggleWrap = New-Object System.Windows.Forms.Panel
    $nlToggleWrap.Dock = 'Right'; $nlToggleWrap.Width = 90; $nlToggleWrap.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40)
    $nlToggle = New-ToggleSwitch
    $nlToggle.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40)
    $nlToggle.Location = New-Object System.Drawing.Point(10, 9)
    $nlOpen = New-TweakButton 'فتح إعدادات ويندوز' ([System.Drawing.Color]::FromArgb(60, 66, 80))
    $nlOpen.Dock = 'Left'; $nlOpen.Width = 170
    $nlStatus = New-Object System.Windows.Forms.Label
    $nlStatus.Dock = 'Fill'; $nlStatus.TextAlign = 'MiddleCenter'; $nlStatus.ForeColor = [System.Drawing.Color]::Gray
    $on = Get-NightLightOn
    $nlStatus.Text = if ($null -eq $on) { 'ما قدرت أعرف الحالة' } elseif ($on) { 'شغّال الحين' } else { 'مطفي الحين' }
    Set-ToggleLook $nlToggle ([bool]$on)
    $nlToggle.Add_Click({
        if (Switch-NightLight) {
            $newOn = [bool](Get-NightLightOn)
            Set-ToggleLook $nlToggle $newOn
            $nlStatus.Text = if ($newOn) { 'شغّال الحين' } else { 'مطفي الحين' }
        } else { $nlStatus.Text = 'ما قدرت أبدّل، افتح إعدادات ويندوز' }
    }.GetNewClosure())
    $nlOpen.Add_Click({ Start-Process 'ms-settings:nightlight' })
    $nlToggleWrap.Controls.Add($nlToggle)
    $nlRow.Controls.Add($nlStatus); $nlRow.Controls.Add($nlOpen); $nlRow.Controls.Add($nlToggleWrap)
    $nlCard.Controls.Add($nlRow); $nlCard.Controls.Add($nlTitle)
    $dpFlow.Controls.Add($nlCard)

    $dpFlow.ResumeLayout()
}

$tabDp = New-Object System.Windows.Forms.TabPage 'الشاشات'
$tabDp.BackColor = $form.BackColor; $tabDp.ForeColor = [System.Drawing.Color]::White
$tabDp.Controls.Add($dpFlow)
[void]$tabs.TabPages.Add($tabDp)
$script:DisplaysLoaded = $false
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -eq $tabDp -and -not $script:DisplaysLoaded) { $script:DisplaysLoaded = $true; Update-Displays }
})

# ---------- YouTube downloader (yt-dlp) ----------
$toolsDir = Join-Path $script:AppDir 'tools'
$ytExe = Join-Path $toolsDir 'yt-dlp.exe'

function Find-Ffmpeg {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $cmd = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $toolsDir 'ffmpeg.exe'
    if (Test-Path $local) { return $local }
    $pk = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pk) { return $pk.FullName }
    $null
}

function Find-JsRuntime {
    # yt-dlp needs a JavaScript runtime for YouTube. Returns 'name:path' or $null
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    foreach ($n in 'deno', 'node', 'bun') {
        $c = Get-Command "$n.exe" -ErrorAction SilentlyContinue
        if ($c) { return "${n}:$($c.Source)" }
    }
    $pk = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter deno.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pk) { return "deno:$($pk.FullName)" }
    $null
}

function Q($s) { "'" + ($s -replace "'", "''") + "'" }

function Start-InWindow($cmd) {
    $full = "[Console]::OutputEncoding = [Text.Encoding]::UTF8; $cmd; Write-Host ''; Read-Host 'اضغط Enter للإغلاق'"
    Invoke-PlainScript $full
}

function Get-YtDlp {
    if (Test-Path $ytExe) { return $ytExe }
    $r = [System.Windows.Forms.MessageBox]::Show("التحميل يحتاج أداة مساعدة صغيرة (حوالي 18 ميجا).`r`nتحمّلها الحين؟", 'Murn Interface', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return $null }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        $script:YtStatus.Text = 'جاري تجهيز أداة التحميل...'; [System.Windows.Forms.Application]::DoEvents()
        Invoke-WebRequest 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile $ytExe -UseBasicParsing
        $script:YtStatus.Text = 'تم تجهيز أداة التحميل'
        return $ytExe
    } catch {
        $script:YtStatus.Text = 'فشل تجهيز أداة التحميل: ' + $_.Exception.Message
        return $null
    }
}

$ytFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$ytFlow.Dock = 'Fill'; $ytFlow.FlowDirection = 'TopDown'; $ytFlow.WrapContents = $false; $ytFlow.AutoScroll = $true
$ytFlow.Padding = New-Object System.Windows.Forms.Padding(14)

function New-YtLabel($text) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.AutoSize = $true; $l.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 3)
    $ytFlow.Controls.Add($l)
}

New-YtLabel 'رابط الفيديو (يوتيوب / تيك توك / انستقرام / تويتر وغيرها):'
$script:YtUrl = New-Object System.Windows.Forms.TextBox
$YtUrl.Width = 740; $YtUrl.RightToLeft = 'No'
$YtUrl.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $YtUrl.ForeColor = [System.Drawing.Color]::White
$ytFlow.Controls.Add($YtUrl)

New-YtLabel 'الجودة:'
$script:YtQuality = New-Object System.Windows.Forms.ComboBox
$YtQuality.Width = 740; $YtQuality.DropDownStyle = 'DropDownList'; $YtQuality.FlatStyle = 'Flat'
$YtQuality.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $YtQuality.ForeColor = [System.Drawing.Color]::White
$qualities = @(
    @{ N = 'جودة عادية (سريعة)'; F = @('-f', 'b[ext=mp4]/b'); Ff = $false },
    @{ N = 'أفضل جودة (MP4) - تحتاج أداة التحويل'; F = @('-f', 'bv*+ba/b', '--merge-output-format', 'mp4'); Ff = $true },
    @{ N = '1080p (MP4) - تحتاج أداة التحويل'; F = @('-f', 'bv*[height<=1080]+ba/b[height<=1080]', '--merge-output-format', 'mp4'); Ff = $true },
    @{ N = '720p (MP4) - تحتاج أداة التحويل'; F = @('-f', 'bv*[height<=720]+ba/b[height<=720]', '--merge-output-format', 'mp4'); Ff = $true },
    @{ N = 'صوت فقط (MP3) - تحتاج أداة التحويل'; F = @('-x', '--audio-format', 'mp3', '--audio-quality', '0'); Ff = $true }
)
foreach ($q in $qualities) { [void]$YtQuality.Items.Add($q.N) }
$YtQuality.SelectedIndex = 0
$ytFlow.Controls.Add($YtQuality)
Register-DarkInput $YtQuality

New-YtLabel 'مجلد الحفظ:'
$folderRow = New-Object System.Windows.Forms.Panel
$folderRow.Width = 740; $folderRow.Height = 28
$script:YtFolder = New-Object System.Windows.Forms.TextBox
$YtFolder.Dock = 'Fill'; $YtFolder.RightToLeft = 'No'; $YtFolder.Text = 'C:\Users\KKHLD\OneDrive\Desktop\c'
$YtFolder.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $YtFolder.ForeColor = [System.Drawing.Color]::White
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'اختر...'; $btnBrowse.Dock = 'Right'; $btnBrowse.Width = 90
$btnBrowse.FlatStyle = 'Flat'; $btnBrowse.ForeColor = [System.Drawing.Color]::White
$folderRow.Controls.Add($YtFolder); $folderRow.Controls.Add($btnBrowse)
$ytFlow.Controls.Add($folderRow)
$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.SelectedPath = $YtFolder.Text
    if ($d.ShowDialog() -eq 'OK') { $YtFolder.Text = $d.SelectedPath }
})

$script:YtPlaylist = New-Object System.Windows.Forms.CheckBox
$YtPlaylist.Text = 'حمّل قائمة التشغيل كاملة (إذا الرابط قائمة)'; $YtPlaylist.AutoSize = $true
$YtPlaylist.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$ytFlow.Controls.Add($YtPlaylist)

$ytMaxRow = New-Object System.Windows.Forms.FlowLayoutPanel
$ytMaxRow.AutoSize = $true; $ytMaxRow.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$ytMaxLbl = New-Object System.Windows.Forms.Label
$ytMaxLbl.Text = 'أقصى عدد فيديوهات من القائمة:'; $ytMaxLbl.AutoSize = $true; $ytMaxLbl.Margin = New-Object System.Windows.Forms.Padding(0, 6, 8, 0)
$script:YtMax = New-Object System.Windows.Forms.NumericUpDown
$YtMax.Minimum = 1; $YtMax.Maximum = 5000; $YtMax.Value = 200; $YtMax.Width = 80
$ytMaxRow.Controls.Add($ytMaxLbl); $ytMaxRow.Controls.Add($YtMax)
$ytFlow.Controls.Add($ytMaxRow)

$ytBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$ytBtns.Width = 740; $ytBtns.Height = 56; $ytBtns.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
function New-YtButton($text, $color, $w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $w; $b.Height = 46; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $ytBtns.Controls.Add($b); $b
}
$btnDl  = New-YtButton 'حمّل' ([System.Drawing.Color]::FromArgb(0, 190, 215)) 140
$btnCan = New-YtButton 'إلغاء' ([System.Drawing.Color]::FromArgb(160, 50, 50)) 140
$btnCan.Enabled = $false
$ytFlow.Controls.Add($ytBtns)

# progress inside the program (no console window)
$script:YtBar = New-Object System.Windows.Forms.ProgressBar
$YtBar.Width = 740; $YtBar.Height = 24; $YtBar.Minimum = 0; $YtBar.Maximum = 100
$YtBar.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$ytFlow.Controls.Add($YtBar)
Register-DarkProgress $YtBar ([System.Drawing.Color]::FromArgb(45, 48, 58)) ([System.Drawing.Color]::FromArgb(0, 190, 215))
$script:YtInfo = New-Object System.Windows.Forms.Label
$YtInfo.AutoSize = $true; $YtInfo.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
$YtInfo.ForeColor = $script:D.Good; $YtInfo.Text = ' '
$ytFlow.Controls.Add($YtInfo)
$script:YtLog = New-Object System.Windows.Forms.TextBox
$YtLog.Multiline = $true; $YtLog.ReadOnly = $true; $YtLog.ScrollBars = 'None'; $YtLog.Width = 740; $YtLog.Height = 110
$YtLog.RightToLeft = 'No'; $YtLog.BorderStyle = 'None'; $YtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$YtLog.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 21); $YtLog.ForeColor = [System.Drawing.Color]::LightGray
$ytFlow.Controls.Add($YtLog)

$script:YtProc = $null; $script:YtCancel = $false
$script:YtR = @{ Out = $null; Err = $null }
$ytTimer = New-Object System.Windows.Forms.Timer; $ytTimer.Interval = 120

function Read-YtLine($line) {
    if ($line -match '^\[download\]\s+([\d\.]+)%') {
        $pct = [double]$Matches[1]
        $speed = if ($line -match '\sat\s+(\S+)') { $Matches[1] } else { '' }
        $eta = if ($line -match 'ETA\s+(\S+)') { $Matches[1] } else { '' }
        $YtBar.Value = [int][math]::Min(100, [math]::Max(0, [math]::Round($pct)))
        $YtInfo.Text = ('{0}%   |   السرعة: {1}   |   المتبقي: {2}' -f $pct, $speed, $eta)
        return
    }
    if ($line -match '^\[download\]\s+Destination:\s+(.+)$') { $YtLog.AppendText('الملف: ' + [IO.Path]::GetFileName($Matches[1]) + "`r`n") }
    elseif ($line -match '^\[Merger\]') { $YtLog.AppendText("جاري دمج الصوت والفيديو...`r`n") }
    elseif ($line -match 'has already been downloaded') { $YtLog.AppendText("الملف موجود مسبقاً`r`n") }
    elseif ($line -match '^ERROR') { $YtLog.AppendText($line.Trim() + "`r`n") }
}

function Complete-YtDownload {
    $ytTimer.Stop()
    $p = $script:YtProc
    $p.WaitForExit()
    $code = $p.ExitCode
    $p.Dispose(); $script:YtProc = $null
    $btnDl.Enabled = $true; $btnCan.Enabled = $false
    if ($script:YtCancel) { $YtStatus.Text = 'تم إلغاء التحميل'; $YtInfo.Text = ' ' }
    elseif ($code -eq 0) { $YtBar.Value = 100; $YtInfo.Text = 'تم التحميل بنجاح'; $YtStatus.Text = 'انحفظ الملف في: ' + $YtFolder.Text; Show-Done 'تم تحميل الفيديو' }
    else { $YtStatus.Text = 'فشل التحميل. شوف السجل فوق (انسخ الخطأ وارسله لي إذا ما فهمته)'; $YtInfo.Text = ' ' }
}

$ytTimer.Add_Tick({
    $p = $script:YtProc
    if (-not $p) { return }
    foreach ($k in 'Out', 'Err') {
        $n = 0
        while ($script:YtR[$k] -and $script:YtR[$k].IsCompleted -and $n++ -lt 300) {
            $line = $script:YtR[$k].Result
            if ($null -eq $line) { $script:YtR[$k] = $null; break }
            Read-YtLine $line
            $script:YtR[$k] = if ($k -eq 'Out') { $p.StandardOutput.ReadLineAsync() } else { $p.StandardError.ReadLineAsync() }
        }
    }
    if (-not $script:YtR['Out'] -and -not $script:YtR['Err']) { Complete-YtDownload }
})

function Start-YtDownload($exePath, $ytArgs) {
    $all = @($ytArgs) + @('--newline', '--no-colors', '--encoding', 'utf-8')
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.Arguments = ($all | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $YtLog.Clear(); $YtBar.Value = 0; $YtInfo.Text = 'جاري البدء...'
    $script:YtCancel = $false
    $script:YtProc = [System.Diagnostics.Process]::Start($psi)
    $script:YtR['Out'] = $script:YtProc.StandardOutput.ReadLineAsync()
    $script:YtR['Err'] = $script:YtProc.StandardError.ReadLineAsync()
    $btnDl.Enabled = $false; $btnCan.Enabled = $true
    $YtStatus.Text = 'جاري التحميل...'
    $ytTimer.Start()
}

$script:YtStatus = New-Object System.Windows.Forms.Label
$YtStatus.AutoSize = $true; $YtStatus.ForeColor = [System.Drawing.Color]::Gray; $YtStatus.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$ytFlow.Controls.Add($YtStatus)

$btnDl.Add_Click({
    $url = $YtUrl.Text.Trim()
    if ($url -notmatch '^https?://') { $YtStatus.Text = 'حط رابط صحيح يبدأ بـ https://'; return }
    $q = $qualities[$YtQuality.SelectedIndex]
    $ff = Find-Ffmpeg
    if ($q.Ff -and -not $ff) { $YtStatus.Text = 'هالجودة تحتاج أداة التحويل (تثبّتها من تبويب تحويل الفيديو). اختر الجودة العادية'; return }
    $exe = Get-YtDlp
    if (-not $exe) { return }
    $js = Find-JsRuntime
    if (-not $js) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { $YtStatus.Text = 'التحميل يحتاج أداة مساعدة غير موجودة عندك وما قدرت أثبتها تلقائياً'; return }
        $r = [System.Windows.Forms.MessageBox]::Show("التحميل يحتاج أداة مساعدة صغيرة عشان يشتغل.`r`nأثبّتها لك؟", 'Murn Interface', 'YesNo', 'Question')
        if ($r -eq 'Yes') { Start-InWindow 'winget install --id DenoLand.Deno -e --accept-package-agreements --accept-source-agreements'; $YtStatus.Text = 'بعد ما يخلص التثبيت اضغط حمّل مرة ثانية' }
        return
    }
    New-Item -ItemType Directory -Path $YtFolder.Text -Force -ErrorAction SilentlyContinue | Out-Null
    $a = @($q.F) + @('-P', $YtFolder.Text, '-o', '%(title)s.%(ext)s', $(if ($YtPlaylist.Checked) { '--yes-playlist', '--playlist-end', [string][int]$YtMax.Value } else { '--no-playlist' }))
    $a += @('--js-runtimes', $js)
    if ($ff) { $a += @('--ffmpeg-location', $ff) }
    $a += $url
    Start-YtDownload $exe $a
})
$btnCan.Add_Click({
    if ($script:YtProc) {
        $script:YtCancel = $true
        Start-Process taskkill -ArgumentList '/PID', $script:YtProc.Id, '/T', '/F' -WindowStyle Hidden
    }
})

$tabYt = New-Object System.Windows.Forms.TabPage 'تحميل من المنصات'
$tabYt.BackColor = $form.BackColor; $tabYt.ForeColor = [System.Drawing.Color]::White
$tabYt.Controls.Add($ytFlow)
[void]$tabs.TabPages.Add($tabYt)

# ---------- Video converter (ffmpeg) ----------
$cvFormats = @(
    @{ N = 'MP4 (فيديو)'; Ext = 'mp4'; Audio = $false; CopyOk = $true
       Cp  = @('-c', 'copy', '-movflags', '+faststart')
       Enc = @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart') },
    @{ N = 'TS (فيديو)'; Ext = 'ts'; Audio = $false; CopyOk = $true
       Cp  = @('-c', 'copy')
       Enc = @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k') },
    @{ N = 'MKV (فيديو)'; Ext = 'mkv'; Audio = $false; CopyOk = $true
       Cp  = @('-c', 'copy')
       Enc = @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k') },
    @{ N = 'MOV (فيديو)'; Ext = 'mov'; Audio = $false; CopyOk = $true
       Cp  = @('-c', 'copy')
       Enc = @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k') },
    @{ N = 'AVI (فيديو)'; Ext = 'avi'; Audio = $false; CopyOk = $false
       Cp  = @()
       Enc = @('-c:v', 'mpeg4', '-q:v', '3', '-c:a', 'libmp3lame', '-b:a', '192k') },
    @{ N = 'WebM (فيديو)'; Ext = 'webm'; Audio = $false; CopyOk = $false
       Cp  = @()
       Enc = @('-c:v', 'libvpx-vp9', '-crf', '32', '-b:v', '0', '-deadline', 'good', '-cpu-used', '4', '-row-mt', '1', '-c:a', 'libopus', '-b:a', '128k') },
    @{ N = 'MP3 (صوت فقط)'; Ext = 'mp3'; Audio = $true; CopyOk = $false
       Cp  = @()
       Enc = @('-c:a', 'libmp3lame', '-q:a', '2') },
    @{ N = 'M4A (صوت فقط)'; Ext = 'm4a'; Audio = $true; CopyOk = $false
       Cp  = @()
       Enc = @('-c:a', 'aac', '-b:a', '192k') },
    @{ N = 'WAV (صوت فقط)'; Ext = 'wav'; Audio = $true; CopyOk = $false
       Cp  = @()
       Enc = @('-c:a', 'pcm_s16le') },
    @{ N = 'FLAC (صوت فقط)'; Ext = 'flac'; Audio = $true; CopyOk = $false
       Cp  = @()
       Enc = @('-c:a', 'flac') }
)

$cvFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$cvFlow.Dock = 'Fill'; $cvFlow.FlowDirection = 'TopDown'; $cvFlow.WrapContents = $false
$cvFlow.Padding = New-Object System.Windows.Forms.Padding(14)

function New-CvLabel($text) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.AutoSize = $true; $l.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 3)
    $cvFlow.Controls.Add($l)
}

$script:CvFiles = @()
New-CvLabel 'الفيديوهات اللي تبي تحوّلها (تقدر تحدد أكثر من ملف):'
$cvFileRow = New-Object System.Windows.Forms.Panel
$cvFileRow.Width = 740; $cvFileRow.Height = 28
$script:CvFile = New-Object System.Windows.Forms.TextBox
$CvFile.Dock = 'Fill'; $CvFile.RightToLeft = 'No'; $CvFile.ReadOnly = $true
$CvFile.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $CvFile.ForeColor = [System.Drawing.Color]::White
$CvFile.BorderStyle = 'FixedSingle'; Register-DarkInput $CvFile
$btnCvPick = New-Object System.Windows.Forms.Button
$btnCvPick.Text = 'اختر...'; $btnCvPick.Dock = 'Right'; $btnCvPick.Width = 90
$btnCvPick.FlatStyle = 'Flat'; $btnCvPick.ForeColor = [System.Drawing.Color]::White
$cvFileRow.Controls.Add($CvFile); $cvFileRow.Controls.Add($btnCvPick)
$cvFlow.Controls.Add($cvFileRow)
$btnCvPick.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Multiselect = $true
    $d.Filter = 'فيديو وصوت|*.mp4;*.ts;*.mkv;*.mov;*.avi;*.webm;*.flv;*.wmv;*.m4v;*.mpg;*.mpeg;*.3gp;*.mts;*.m2ts;*.mp3;*.m4a;*.wav;*.flac;*.aac;*.ogg|كل الملفات|*.*'
    if ($d.ShowDialog() -eq 'OK') {
        $script:CvFiles = @($d.FileNames)
        $CvFile.Text = if ($script:CvFiles.Count -eq 1) { $script:CvFiles[0] } else { "$($script:CvFiles.Count) ملفات: " + (($script:CvFiles | ForEach-Object { [IO.Path]::GetFileName($_) }) -join ' ، ') }
    }
})

New-CvLabel 'حوّلها إلى صيغة:'
$script:CvFormat = New-Object System.Windows.Forms.ComboBox
$CvFormat.Width = 740; $CvFormat.DropDownStyle = 'DropDownList'; $CvFormat.FlatStyle = 'Flat'
$CvFormat.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $CvFormat.ForeColor = [System.Drawing.Color]::White
foreach ($f in $cvFormats) { [void]$CvFormat.Items.Add($f.N) }
$CvFormat.SelectedIndex = 0
$cvFlow.Controls.Add($CvFormat)
Register-DarkInput $CvFormat

New-CvLabel 'مجلد الحفظ (فاضي = نفس مجلد الفيديو الأصلي):'
$cvOutRow = New-Object System.Windows.Forms.Panel
$cvOutRow.Width = 740; $cvOutRow.Height = 28
$script:CvFolder = New-Object System.Windows.Forms.TextBox
$CvFolder.Dock = 'Fill'; $CvFolder.RightToLeft = 'No'
$CvFolder.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $CvFolder.ForeColor = [System.Drawing.Color]::White
$CvFolder.BorderStyle = 'FixedSingle'; Register-DarkInput $CvFolder
$btnCvBrowse = New-Object System.Windows.Forms.Button
$btnCvBrowse.Text = 'اختر...'; $btnCvBrowse.Dock = 'Right'; $btnCvBrowse.Width = 90
$btnCvBrowse.FlatStyle = 'Flat'; $btnCvBrowse.ForeColor = [System.Drawing.Color]::White
$cvOutRow.Controls.Add($CvFolder); $cvOutRow.Controls.Add($btnCvBrowse)
$cvFlow.Controls.Add($cvOutRow)
$btnCvBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($CvFolder.Text.Trim() -and (Test-Path -LiteralPath $CvFolder.Text.Trim())) { $d.SelectedPath = $CvFolder.Text.Trim() }
    if ($d.ShowDialog() -eq 'OK') { $CvFolder.Text = $d.SelectedPath }
})

$script:CvReenc = New-Object System.Windows.Forms.CheckBox
$CvReenc.Text = 'إعادة ترميز كاملة (أبطأ، لكن أوسع توافق). بدونها التحويل سريع وبدون فقدان جودة'; $CvReenc.AutoSize = $true
$CvReenc.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$cvFlow.Controls.Add($CvReenc)

$cvBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$cvBtns.Width = 740; $cvBtns.Height = 56; $cvBtns.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
function New-CvButton($text, $color, $w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $w; $b.Height = 46; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $cvBtns.Controls.Add($b); $b
}
$btnCv    = New-CvButton 'حوّل' ([System.Drawing.Color]::FromArgb(0, 190, 215)) 140
$btnCvCan = New-CvButton 'إلغاء' ([System.Drawing.Color]::FromArgb(160, 50, 50)) 140
$btnCvCan.Enabled = $false
$cvFlow.Controls.Add($cvBtns)

$script:CvBar = New-Object System.Windows.Forms.ProgressBar
$CvBar.Width = 740; $CvBar.Height = 24; $CvBar.Minimum = 0; $CvBar.Maximum = 100
$CvBar.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$cvFlow.Controls.Add($CvBar)
Register-DarkProgress $CvBar ([System.Drawing.Color]::FromArgb(45, 48, 58)) ([System.Drawing.Color]::FromArgb(0, 190, 215))
$script:CvInfo = New-Object System.Windows.Forms.Label
$CvInfo.AutoSize = $true; $CvInfo.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
$CvInfo.ForeColor = $script:D.Good; $CvInfo.Text = ' '
$cvFlow.Controls.Add($CvInfo)
$script:CvLog = New-Object System.Windows.Forms.TextBox
$CvLog.Multiline = $true; $CvLog.ReadOnly = $true; $CvLog.ScrollBars = 'None'; $CvLog.Width = 740; $CvLog.Height = 110
$CvLog.RightToLeft = 'No'; $CvLog.BorderStyle = 'None'; $CvLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$CvLog.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 21); $CvLog.ForeColor = [System.Drawing.Color]::LightGray
$cvFlow.Controls.Add($CvLog)
$script:CvStatus = New-Object System.Windows.Forms.Label
$CvStatus.AutoSize = $true; $CvStatus.ForeColor = [System.Drawing.Color]::Gray; $CvStatus.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$cvFlow.Controls.Add($CvStatus)

$script:CvProc = $null; $script:CvCancel = $false; $script:CvMode = 'convert'
$script:CvR = @{ Out = $null; Err = $null }
$script:CvQueue = @(); $script:CvIdx = 0; $script:CvOk = 0; $script:CvFail = 0
$script:CvOut = $null; $script:CvDur = 0.0; $script:CvFrac = 0.0; $script:CvSpeed = ''; $script:CvRetry = $false; $script:CvFfmpeg = $null
$cvTimer = New-Object System.Windows.Forms.Timer; $cvTimer.Interval = 120

function Update-CvInfo {
    $n = $script:CvQueue.Count
    $overall = if ($n -gt 0) { (($script:CvIdx + $script:CvFrac) / $n) * 100 } else { 0 }
    $CvBar.Value = [int][math]::Min(100, [math]::Max(0, [math]::Round($overall)))
    $txt = if ($script:CvDur -gt 0) { '{0}%' -f [math]::Round($script:CvFrac * 100) } else { 'جاري التحويل...' }
    if ($n -gt 1) { $txt += ('   |   الملف {0} من {1}' -f ($script:CvIdx + 1), $n) }
    if ($script:CvSpeed) { $txt += '   |   السرعة: ' + $script:CvSpeed }
    $CvInfo.Text = $txt
}

function Read-CvInstallLine($line) {
    $t = $line.Trim()
    if ($t.Length -lt 3) { return }
    if ($t -match '([\d\.]+)\s*(KB|MB|GB)\s*/\s*([\d\.]+)\s*(KB|MB|GB)') {
        $u = @{ KB = 1; MB = 1024; GB = 1048576 }
        $c = [double]$Matches[1] * $u[$Matches[2]]; $tt = [double]$Matches[3] * $u[$Matches[4]]
        if ($tt -gt 0) {
            $CvBar.Value = [int][math]::Min(100, [math]::Round($c / $tt * 100))
            $CvInfo.Text = 'جاري التنزيل: {0} {1} من {2} {3}' -f $Matches[1], $Matches[2], $Matches[3], $Matches[4]
        }
        return
    }
    if ($t -match '^[\-\\|/\s█▒▓░]+$') { return }
    if ($t -match 'rror|fail|فشل') { $CvLog.AppendText($t + "`r`n") }
}

function Read-CvLine($k, $line) {
    if ($script:CvMode -eq 'install') { Read-CvInstallLine $line; return }
    if ($k -eq 'Out') {
        if ($line -match '^out_time_(?:us|ms)=(\d+)') {
            $sec = [double]$Matches[1] / 1000000
            if ($script:CvDur -gt 0) { $script:CvFrac = [math]::Min(1.0, $sec / $script:CvDur) }
            Update-CvInfo
        } elseif ($line -match '^speed=\s*([\d\.]+)x') {
            $script:CvSpeed = $Matches[1] + 'x'
            Update-CvInfo
        }
        return
    }
    if ($script:CvDur -eq 0 -and $line -match 'Duration:\s*(\d+):(\d+):([\d\.]+)') {
        $script:CvDur = [int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [double]::Parse($Matches[3], [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($line -match 'rror|Invalid|No such|failed|Unable|Unknown|not supported|Permission|already exists') { $CvLog.AppendText($line.Trim() + "`r`n") }
}

function Remove-CvPartial {
    if ($script:CvOut -and (Test-Path -LiteralPath $script:CvOut)) { Remove-Item -LiteralPath $script:CvOut -Force -ErrorAction SilentlyContinue }
}

function Get-CvOutPath($in, $ext, $folder) {
    $dir = if ($folder.Trim()) { $folder.Trim() } else { [IO.Path]::GetDirectoryName($in) }
    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
    $base = [IO.Path]::GetFileNameWithoutExtension($in)
    $p = Join-Path $dir "$base.$ext"; $i = 2
    while (Test-Path -LiteralPath $p) { $p = Join-Path $dir "$base ($i).$ext"; $i++ }
    $p
}

function Start-CvProcess($exePath, $procArgs, $mode) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.Arguments = ($procArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $script:CvMode = $mode
    $script:CvProc = [System.Diagnostics.Process]::Start($psi)
    $script:CvR['Out'] = $script:CvProc.StandardOutput.ReadLineAsync()
    $script:CvR['Err'] = $script:CvProc.StandardError.ReadLineAsync()
    $btnCv.Enabled = $false; $btnCvCan.Enabled = $true
    $cvTimer.Start()
}

function Start-CvFile {
    $in = $script:CvQueue[$script:CvIdx]
    $f = $cvFormats[$CvFormat.SelectedIndex]
    if (-not $script:CvRetry) { $script:CvOut = Get-CvOutPath $in $f.Ext $CvFolder.Text }
    $useEnc = $CvReenc.Checked -or (-not $f.CopyOk) -or $script:CvRetry
    $a = @('-hide_banner', '-nostdin', '-n', '-i', $in)
    if ($f.Audio) { $a += @('-vn', '-map', '0:a:0') } else { $a += @('-map', '0:v:0?', '-map', '0:a?') }
    $a += $(if ($useEnc) { $f.Enc } else { $f.Cp })
    $a += @('-progress', 'pipe:1', '-nostats', $script:CvOut)
    $script:CvDur = 0.0; $script:CvFrac = 0.0; $script:CvSpeed = ''
    $CvLog.AppendText('> ' + [IO.Path]::GetFileName($in) + ' -> ' + [IO.Path]::GetFileName($script:CvOut) + $(if ($useEnc) { '  (إعادة ترميز)' } else { '  (نسخ سريع)' }) + "`r`n")
    Update-CvInfo
    Start-CvProcess $script:CvFfmpeg $a 'convert'
}

function Finish-Cv {
    $btnCv.Enabled = $true; $btnCvCan.Enabled = $false
    if ($script:CvCancel) { $CvStatus.Text = 'تم إلغاء التحويل'; $CvInfo.Text = ' '; return }
    Show-Done $(if ($script:CvFail -eq 0) { 'تم تحويل الفيديو' } else { 'انتهى التحويل وفيه أخطاء' })
    if ($script:CvFail -eq 0) { $CvBar.Value = 100; $CvInfo.Text = 'تم التحويل بنجاح'; $CvStatus.Text = "تم تحويل $($script:CvOk) ملف. انحفظ في: " + $(if ($CvFolder.Text.Trim()) { $CvFolder.Text.Trim() } else { 'نفس مجلد الفيديو الأصلي' }) }
    else { $CvInfo.Text = ' '; $CvStatus.Text = "نجح $($script:CvOk) وفشل $($script:CvFail). شوف السجل فوق" }
}

function Complete-CvProc {
    $cvTimer.Stop()
    $p = $script:CvProc
    $p.WaitForExit(); $code = $p.ExitCode; $p.Dispose(); $script:CvProc = $null
    if ($script:CvMode -eq 'install') {
        $btnCv.Enabled = $true; $btnCvCan.Enabled = $false
        if ($script:CvCancel) { $CvStatus.Text = 'تم إلغاء التثبيت'; $CvInfo.Text = ' ' }
        elseif (Find-Ffmpeg) { $CvBar.Value = 100; $CvInfo.Text = 'تم تثبيت أداة التحويل'; Show-Done 'تم تثبيت أداة التحويل'; $CvStatus.Text = 'جاهز. اضغط حوّل' }
        else { $CvInfo.Text = ' '; $CvStatus.Text = 'فشل التثبيت' }
        return
    }
    if ($script:CvCancel) { Remove-CvPartial; Finish-Cv; return }
    if ($code -ne 0) {
        Remove-CvPartial
        $f = $cvFormats[$CvFormat.SelectedIndex]
        if (-not $script:CvRetry -and $f.CopyOk -and -not $CvReenc.Checked) {
            $script:CvRetry = $true
            $CvLog.AppendText("النسخ السريع ما نفع مع هالملف، أعيد الترميز...`r`n")
            Start-CvFile; return
        }
        $script:CvFail++
    } else { $script:CvOk++ }
    $script:CvIdx++; $script:CvRetry = $false
    if ($script:CvIdx -lt $script:CvQueue.Count) { Start-CvFile } else { Finish-Cv }
}

$cvTimer.Add_Tick({
    $p = $script:CvProc
    if (-not $p) { return }
    foreach ($k in 'Out', 'Err') {
        $n = 0
        while ($script:CvR[$k] -and $script:CvR[$k].IsCompleted -and $n++ -lt 300) {
            $line = $script:CvR[$k].Result
            if ($null -eq $line) { $script:CvR[$k] = $null; break }
            Read-CvLine $k $line
            $script:CvR[$k] = if ($k -eq 'Out') { $p.StandardOutput.ReadLineAsync() } else { $p.StandardError.ReadLineAsync() }
        }
    }
    if (-not $script:CvR['Out'] -and -not $script:CvR['Err']) { Complete-CvProc }
})

$btnCv.Add_Click({
    if ($script:CvFiles.Count -eq 0) { $CvStatus.Text = 'اختر ملف فيديو أول'; return }
    $ff = Find-Ffmpeg
    if (-not $ff) {
        $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $wg) { $CvStatus.Text = 'التحويل يحتاج أداة مساعدة وما قدرت أثبتها تلقائياً على جهازك'; return }
        $r = [System.Windows.Forms.MessageBox]::Show("التحويل يحتاج أداة مساعدة مجانية وغير مثبتة عندك.`r`nأثبّتها لك؟ (مرة وحدة بس)", 'Murn Interface', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $CvLog.Clear(); $CvBar.Value = 0; $CvInfo.Text = 'جاري تثبيت أداة التحويل...'; $CvStatus.Text = 'لا تسكر البرنامج لين يخلص'
        $script:CvCancel = $false
        Start-CvProcess $wg.Source @('install', '--id', 'Gyan.FFmpeg', '-e', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') 'install'
        return
    }
    $script:CvFfmpeg = $ff
    $script:CvQueue = @($script:CvFiles | Where-Object { Test-Path -LiteralPath $_ })
    if ($script:CvQueue.Count -eq 0) { $CvStatus.Text = 'الملفات المحددة مو موجودة'; return }
    $script:CvIdx = 0; $script:CvOk = 0; $script:CvFail = 0; $script:CvRetry = $false; $script:CvCancel = $false
    $CvLog.Clear(); $CvBar.Value = 0; $CvStatus.Text = 'جاري التحويل...'
    Start-CvFile
})
$btnCvCan.Add_Click({
    if ($script:CvProc) {
        $script:CvCancel = $true
        Start-Process taskkill -ArgumentList '/PID', $script:CvProc.Id, '/T', '/F' -WindowStyle Hidden
    }
})

$tabCv = New-Object System.Windows.Forms.TabPage 'تحويل الفيديو'
$tabCv.BackColor = $form.BackColor; $tabCv.ForeColor = [System.Drawing.Color]::White
$tabCv.Controls.Add($cvFlow)
[void]$tabs.TabPages.Add($tabCv)

# ---------- Tools: cleaning ----------
$tlNames = @{ 'Prefetch' = 'ملفات Prefetch (تسريع الإقلاع)'; 'Internet cache' = 'كاش الإنترنت'; 'GPU shader cache' = 'كاش كرت الشاشة' }
$tlTargets = New-Object System.Collections.ArrayList
foreach ($t in Get-CleanTargets) {
    $nm = if ($tlNames.ContainsKey($t.N)) { $tlNames[$t.N] } else { $t.N }
    [void]$tlTargets.Add(@{ K = 'path'; N = $nm; P = $t.P })
}
[void]$tlTargets.Add(@{ K = 'path'; N = 'كاش الصور المصغرة'; P = @("$L\Microsoft\Windows\Explorer\thumbcache_*.db") })
[void]$tlTargets.Add(@{ K = 'path'; N = 'كاش تحسين التسليم (Delivery Optimization)'; P = @("$W\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache") })
[void]$tlTargets.Add(@{ K = 'bin'; N = 'سلة المحذوفات' })
[void]$tlTargets.Add(@{ K = 'ram'; N = 'تحرير الرام (تفريغ الذاكرة غير المستخدمة)' })

# caches of installed apps: only the ones found on this PC are listed
$tlCatalog = @(
    @{ N = 'كاش Opera'; P = @("$R\Opera Software\Opera Stable\Cache", "$R\Opera Software\Opera Stable\Code Cache", "$R\Opera Software\Opera Stable\GPUCache") },
    @{ N = 'كاش Opera GX'; P = @("$R\Opera Software\Opera GX Stable\Cache", "$R\Opera Software\Opera GX Stable\Code Cache", "$R\Opera Software\Opera GX Stable\GPUCache") },
    @{ N = 'كاش Vivaldi'; P = @("$L\Vivaldi\User Data\Default\Cache", "$L\Vivaldi\User Data\Default\Code Cache", "$L\Vivaldi\User Data\Default\GPUCache") },
    @{ N = 'كاش Firefox'; P = @("$L\Mozilla\Firefox\Profiles\*\cache2") },
    @{ N = 'كاش Discord'; P = @("$R\discord\Cache", "$R\discord\Code Cache", "$R\discord\GPUCache") },
    @{ N = 'كاش Steam (المتجر فقط)'; P = @("$L\Steam\htmlcache") },
    @{ N = 'كاش Spotify'; P = @("$L\Spotify\Data", "$L\Spotify\Storage", "$L\Packages\SpotifyAB.SpotifyMusic_*\LocalCache\Spotify\Data") },
    @{ N = 'كاش Microsoft Teams'; P = @("$R\Microsoft\Teams\Cache", "$R\Microsoft\Teams\Code Cache", "$R\Microsoft\Teams\GPUCache") },
    @{ N = 'كاش Slack'; P = @("$R\Slack\Cache", "$R\Slack\Code Cache", "$R\Slack\GPUCache") },
    @{ N = 'كاش Epic Games'; P = @("$L\EpicGamesLauncher\Saved\webcache*") },
    @{ N = 'كاش Adobe للوسائط'; P = @("$R\Adobe\Common\Media Cache Files", "$R\Adobe\Common\Media Cache") }
)
foreach ($c in $tlCatalog) { [void]$tlTargets.Add(@{ K = 'path'; N = $c.N; P = $c.P }) }
$tlTargets = @($tlTargets | Where-Object { $_.K -ne 'path' -or @($_.P | Where-Object { Test-Path -Path $_ -ErrorAction SilentlyContinue }).Count })

function Get-BinMB {
    try {
        $sh = New-Object -ComObject Shell.Application
        $sum = ($sh.Namespace(0xA).Items() | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum
        [math]::Round($sum / 1MB, 1)
    } catch { 0 }
}
function Get-FreeRamMB { [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB) }

$tlFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$tlFlow.Dock = 'Fill'; $tlFlow.FlowDirection = 'TopDown'; $tlFlow.WrapContents = $false; $tlFlow.AutoScroll = $true
$tlFlow.Padding = New-Object System.Windows.Forms.Padding(20)
$tlTitle = New-Object System.Windows.Forms.Label
$tlTitle.Text = 'أداة التنظيف'; $tlTitle.AutoSize = $true
$tlTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$tlTitle.ForeColor = $script:Accent
$tlFlow.Controls.Add($tlTitle)
$tlDesc = New-Object System.Windows.Forms.Label
$tlDesc.AutoSize = $false; $tlDesc.Width = 740; $tlDesc.Height = 150; $tlDesc.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$tlDesc.Text = "زر واحد ينظف جهازك بدون ما تختار شي بنفسك. يشيل:`r`n`r`n• الملفات المؤقتة (Temp) وملفات تقارير الأعطال`r`n• كاش المتصفحات والبرامج المثبتة عندك (كروم، ديسكورد، ستيم وغيرها)`r`n• بقايا تحديثات ويندوز القديمة`r`n• سلة المحذوفات`r`n• ويحرر الرام غير المستخدمة"
$tlFlow.Controls.Add($tlDesc)
$btnTlGo = New-Object System.Windows.Forms.Button
$btnTlGo.Text = 'تنظيف سريع'; $btnTlGo.Width = 300; $btnTlGo.Height = 70; $btnTlGo.FlatStyle = 'Flat'; $btnTlGo.FlatAppearance.BorderSize = 0
$btnTlGo.BackColor = [System.Drawing.Color]::FromArgb(0, 190, 215); $btnTlGo.ForeColor = [System.Drawing.Color]::White
$btnTlGo.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$btnTlGo.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$tlFlow.Controls.Add($btnTlGo)
$btnTlDisk = New-Object System.Windows.Forms.Button
$btnTlDisk.Text = 'منظف القرص (أداة ويندوز الرسمية)'; $btnTlDisk.Width = 300; $btnTlDisk.Height = 50; $btnTlDisk.FlatStyle = 'Flat'; $btnTlDisk.FlatAppearance.BorderSize = 0
$btnTlDisk.BackColor = [System.Drawing.Color]::FromArgb(60, 66, 80); $btnTlDisk.ForeColor = [System.Drawing.Color]::White
$btnTlDisk.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btnTlDisk.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$tlFlow.Controls.Add($btnTlDisk)
$tlStatus = New-Object System.Windows.Forms.Label
$tlStatus.AutoSize = $true; $tlStatus.ForeColor = [System.Drawing.Color]::Gray; $tlStatus.Margin = New-Object System.Windows.Forms.Padding(0, 14, 0, 0)

# ---- RAM cleaner section (Wise-Memory-Optimizer style) ----
$ramCard = New-Object System.Windows.Forms.Panel
$ramCard.Width = 740; $ramCard.Height = 170; $ramCard.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
$ramCard.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $ramCard.Padding = New-Object System.Windows.Forms.Padding(18, 12, 18, 12)
$ramTitle = New-Object System.Windows.Forms.Label
$ramTitle.Text = 'تنظيف الرامات'; $ramTitle.Dock = 'Top'; $ramTitle.Height = 28; $ramTitle.TextAlign = 'MiddleRight'
$ramTitle.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold); $ramTitle.ForeColor = $script:Accent
$ramInfo = New-Object System.Windows.Forms.Label
$ramInfo.Dock = 'Top'; $ramInfo.Height = 26; $ramInfo.TextAlign = 'MiddleRight'; $ramInfo.ForeColor = [System.Drawing.Color]::Gainsboro
$ramInfo.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
$ramBar = New-Object System.Windows.Forms.ProgressBar
$ramBar.Dock = 'Top'; $ramBar.Height = 20; $ramBar.Minimum = 0; $ramBar.Maximum = 100; $ramBar.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 8)
Register-DarkProgress $ramBar ([System.Drawing.Color]::FromArgb(45, 48, 58)) ([System.Drawing.Color]::FromArgb(0, 190, 215))
$ramBtnRow = New-Object System.Windows.Forms.Panel
$ramBtnRow.Dock = 'Top'; $ramBtnRow.Height = 46
$btnRamClean = New-TweakButton 'نظّف الرام الآن' ([System.Drawing.Color]::FromArgb(0, 190, 215))
$btnRamClean.Dock = 'Right'; $btnRamClean.Width = 200
$chkRamAuto = New-Object System.Windows.Forms.CheckBox
$chkRamAuto.Text = 'تنظيف تلقائي إذا تجاوز الرام'; $chkRamAuto.Dock = 'Left'; $chkRamAuto.Width = 220
$chkRamAuto.Padding = New-Object System.Windows.Forms.Padding(0, 14, 0, 0); $chkRamAuto.ForeColor = [System.Drawing.Color]::Gainsboro
$numRamAuto = New-Object System.Windows.Forms.NumericUpDown
$numRamAuto.Dock = 'Left'; $numRamAuto.Width = 70; $numRamAuto.Minimum = 50; $numRamAuto.Maximum = 95; $numRamAuto.Value = 85
$numRamAuto.Margin = New-Object System.Windows.Forms.Padding(4, 9, 0, 0)
$numRamAuto.BackColor = [System.Drawing.Color]::FromArgb(45, 48, 58); $numRamAuto.ForeColor = $script:Accent
$numRamAuto.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$numRamAuto.BorderStyle = 'FixedSingle'
$numRamAuto.TextAlign = 'Center'
$pctLbl = New-Object System.Windows.Forms.Label
$pctLbl.Text = '%'; $pctLbl.Dock = 'Left'; $pctLbl.Width = 24; $pctLbl.Padding = New-Object System.Windows.Forms.Padding(0, 14, 0, 0); $pctLbl.ForeColor = [System.Drawing.Color]::Gainsboro
$ramBtnRow.Controls.Add($btnRamClean); $ramBtnRow.Controls.Add($pctLbl); $ramBtnRow.Controls.Add($numRamAuto); $ramBtnRow.Controls.Add($chkRamAuto)
$ramCard.Controls.Add($ramBtnRow); $ramCard.Controls.Add($ramBar); $ramCard.Controls.Add($ramInfo); $ramCard.Controls.Add($ramTitle)
$tlFlow.Controls.Add($ramCard)
$tlFlow.Controls.Add($tlStatus)

function Clean-Ram {
    $before = Get-FreeRamMB
    Add-Type -Namespace Win32 -Name Psapi -ErrorAction SilentlyContinue -MemberDefinition '[DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);'
    Get-Process | ForEach-Object { try { [void][Win32.Psapi]::EmptyWorkingSet($_.Handle) } catch {} }
    [GC]::Collect()
    $after = Get-FreeRamMB
    [math]::Max(0, $after - $before)
}
function Update-RamCard {
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { $os = $null }
    if (-not $os.TotalVisibleMemorySize) { return 0 }
    $totalGB = $os.TotalVisibleMemorySize / 1MB
    $usedGB = $totalGB - ($os.FreePhysicalMemory / 1MB)
    $pct = [int](100 * $usedGB / $totalGB)
    $ramBar.Value = [math]::Min(100, [math]::Max(0, $pct))
    $ramInfo.Text = ('{0:N1} / {1:N1} GB مستخدم  ({2}%)' -f $usedGB, $totalGB, $pct)
    $pct
}
$btnRamClean.Add_Click({
    $btnRamClean.Enabled = $false
    $freed = Clean-Ram
    Update-RamCard | Out-Null
    $tlStatus.ForeColor = $script:D.Good
    $tlStatus.Text = "تم تنظيف الرام ✓  تحرر تقريباً $freed MB"
    $btnRamClean.Enabled = $true
})
$script:RamLastAutoClean = [DateTime]::MinValue
$ramTimer = New-Object System.Windows.Forms.Timer; $ramTimer.Interval = 5000
$ramTimer.Add_Tick({
    if ($tabs.SelectedTab -eq $tabTl) { $pct = Update-RamCard } else { try { $pct = Update-RamCard } catch { $pct = 0 } }
    if ($chkRamAuto.Checked -and $pct -ge [int]$numRamAuto.Value -and ([DateTime]::Now - $script:RamLastAutoClean).TotalSeconds -gt 60) {
        $script:RamLastAutoClean = [DateTime]::Now
        $freed = Clean-Ram
        Update-RamCard | Out-Null
        if ($tabs.SelectedTab -eq $tabTl) { $tlStatus.ForeColor = [System.Drawing.Color]::Gold; $tlStatus.Text = "تنظيف تلقائي ✓ تحرر تقريباً $freed MB" }
    }
})
$ramTimer.Start()
Update-RamCard | Out-Null

$btnTlDisk.Add_Click({
    $cm = Join-Path $env:windir 'System32\cleanmgr.exe'
    if (Test-Path $cm) { Start-Process $cm; $tlStatus.Text = 'انفتح منظف القرص. اختر القرص والملفات اللي تبي تحذفها.' }
    else { $tlStatus.Text = 'منظف القرص غير موجود بنسختك من ويندوز' }
})
$btnTlGo.Add_Click({
    $btnTlGo.Enabled = $false; $tlStatus.ForeColor = $script:D.Good; $tlStatus.Text = 'جاري التنظيف...'
    [System.Windows.Forms.Application]::DoEvents()
    $total = 0
    $needWu = [bool]($tlTargets | Where-Object { $_.K -eq 'path' -and ($_.P -join ' ') -match 'SoftwareDistribution|DeliveryOptimization' })
    if ($needWu) { Stop-Service wuauserv, bits, dosvc -Force -ErrorAction SilentlyContinue }
    foreach ($t in $tlTargets) {
        switch ($t.K) {
            'path' {
                $before = Get-SizeMB $t.P
                if ($before) { Remove-Paths $t.P; $total += [math]::Max(0, [math]::Round($before - (Get-SizeMB $t.P), 1)) }
            }
            'bin' { $before = Get-BinMB; Clear-RecycleBin -Force -ErrorAction SilentlyContinue; $total += $before }
            'ram' {
                Add-Type -Namespace Win32 -Name Psapi -ErrorAction SilentlyContinue -MemberDefinition '[DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);'
                Get-Process | ForEach-Object { try { [void][Win32.Psapi]::EmptyWorkingSet($_.Handle) } catch {} }
                [GC]::Collect()
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($needWu) { Start-Service wuauserv, bits, dosvc -ErrorAction SilentlyContinue }
    $tlStatus.Text = "انتهى التنظيف ✓  تحررت {0:N0} MB" -f $total
    Show-Done 'تم تنظيف الجهاز'
    $btnTlGo.Enabled = $true
})

$tabTl = New-Object System.Windows.Forms.TabPage 'أدوات التنظيف'
$tabTl.BackColor = $form.BackColor; $tabTl.ForeColor = [System.Drawing.Color]::White
$tabTl.Controls.Add($tlFlow)
[void]$tabs.TabPages.Add($tabTl)

# ---------- Device scan (Microsoft Malicious Software Removal Tool) ----------
$scFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$scFlow.Dock = 'Fill'; $scFlow.FlowDirection = 'TopDown'; $scFlow.WrapContents = $false
$scFlow.Padding = New-Object System.Windows.Forms.Padding(20)
$scTitle = New-Object System.Windows.Forms.Label
$scTitle.Text = 'حماية الجهاز'; $scTitle.AutoSize = $true
$scTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$scTitle.ForeColor = $script:Accent
$scFlow.Controls.Add($scTitle)
$scDesc = New-Object System.Windows.Forms.Label
$scDesc.AutoSize = $false; $scDesc.Width = 740; $scDesc.Height = 110; $scDesc.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$scDesc.Text = "زر واحد يفتح أداة فحص الخبيثات الرسمية من مايكروسوفت (موجودة بويندوز). تفحص جهازك وتشيل الفيروسات والبرمجيات الخبيثة المنتشرة.`r`n`r`nبعد ما تنفتح اختر الفحص السريع، أو الفحص الكامل إذا تشك بالجهاز.`r`n`r`nوبالأسفل أداة فحص التعدين الخفي اللي تلقط برامج تسرق موارد جهازك للتعدين بدون علمك."
$scFlow.Controls.Add($scDesc)
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "أداة فحص الجهاز
MRT"; $btnScan.Width = 300; $btnScan.Height = 70; $btnScan.FlatStyle = 'Flat'; $btnScan.FlatAppearance.BorderSize = 0
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(0, 190, 215); $btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$scFlow.Controls.Add($btnScan)
function New-ScButton($text, $color) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = 300; $b.Height = 70; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.Margin = New-Object System.Windows.Forms.Padding(3, 10, 3, 0)
    $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $scFlow.Controls.Add($b); $b
}
$btnDef  = New-ScButton 'حماية ويندوز' ([System.Drawing.Color]::FromArgb(0, 120, 190))
$btnSec  = New-ScButton 'افتح أمان ويندوز' ([System.Drawing.Color]::FromArgb(60, 66, 80))
$btnSec.Height = 50; $btnSec.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

$scStatus = New-Object System.Windows.Forms.Label
$scStatus.AutoSize = $true; $scStatus.ForeColor = [System.Drawing.Color]::Gray; $scStatus.Margin = New-Object System.Windows.Forms.Padding(0, 14, 0, 0)
$scFlow.Controls.Add($scStatus)
$btnScan.Add_Click({
    $mrt = Join-Path $env:windir 'System32\mrt.exe'
    if (-not (Test-Path $mrt)) { $scStatus.Text = 'أداة الفحص غير موجودة بنسختك من ويندوز'; return }
    Start-Process $mrt
    $scStatus.Text = 'انفتحت أداة الفحص. اختر الفحص السريع وكمّل'
})

# Windows Security quick scan (runs in the background, result shown in the program)
$script:DefProc = $null; $script:DefOut = $null
$defTimer = New-Object System.Windows.Forms.Timer; $defTimer.Interval = 1000
$defTimer.Add_Tick({
    $p = $script:DefProc
    if (-not $p) { $defTimer.Stop(); return }
    if (-not $p.HasExited) { $scStatus.Text = 'جاري فحص حماية ويندوز... ممكن ياخذ دقايق'; return }
    $defTimer.Stop()
    $out = $script:DefOut.Result
    $p.Dispose(); $script:DefProc = $null; $btnDef.Enabled = $true
    if ($out -match 'THREATS:(\d+)') {
        $n = [int]$Matches[1]
        $scStatus.Text = if ($n -eq 0) { 'انتهى الفحص: ما انلقى أي تهديد ✓' } else { "انتهى الفحص: انلقى $n تهديد. افتح أمان ويندوز تشوفها وتعالجها" }
        Show-Done $(if ($n -eq 0) { 'انتهى فحص الجهاز: ما انلقى تهديدات' } else { "انتهى فحص الجهاز: انلقى $n تهديد" })
    } else {
        $scStatus.Text = 'ما قدرت أشغل فحص ويندوز. غالباً عندك برنامج حماية ثاني شغال بدالها'
    }
})
$btnDef.Add_Click({
    $cmd = '$s = Get-Date; try { Start-MpScan -ScanType QuickScan -ErrorAction Stop; $n = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object { $_.InitialDetectionTime -ge $s }).Count; Write-Output "THREATS:$n" } catch { Write-Output "ERR" }'
    $script:DefProc = Invoke-PlainScript $cmd -CaptureOutput
    $script:DefOut = $script:DefProc.StandardOutput.ReadToEndAsync()
    $btnDef.Enabled = $false
    $scStatus.Text = 'بدأ فحص حماية ويندوز...'
    $defTimer.Start()
})
$btnSec.Add_Click({ try { Start-Process 'windowsdefender:' } catch { $scStatus.Text = 'ما قدرت أفتح أمان ويندوز' } })

# ---------- Hidden mining (cryptojacking) scan ----------
$scSep1 = New-Object System.Windows.Forms.Panel
$scSep1.Width = 740; $scSep1.Height = 1; $scSep1.BackColor = [System.Drawing.Color]::FromArgb(40, 60, 80)
$scSep1.Margin = New-Object System.Windows.Forms.Padding(0, 22, 0, 16)
$scFlow.Controls.Add($scSep1)

$minTitle = New-Object System.Windows.Forms.Label
$minTitle.Text = 'فحص التعدين الخفي'; $minTitle.AutoSize = $true
$minTitle.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$minTitle.ForeColor = $script:Accent
$scFlow.Controls.Add($minTitle)

$minDesc = New-Object System.Windows.Forms.Label
$minDesc.AutoSize = $false; $minDesc.Width = 740; $minDesc.Height = 54; $minDesc.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$minDesc.Text = "يفحص العمليات الشغالة وبرامج بدء التشغيل عن أي شيء يشبه برامج تعدين العملات الرقمية اللي تستخدم معالجك أو كرت الشاشة بدون علمك."
$scFlow.Controls.Add($minDesc)

$btnMinScan = New-Object System.Windows.Forms.Button
$btnMinScan.Text = 'فحص التعدين'; $btnMinScan.Width = 300; $btnMinScan.Height = 60; $btnMinScan.FlatStyle = 'Flat'; $btnMinScan.FlatAppearance.BorderSize = 0
$btnMinScan.BackColor = [System.Drawing.Color]::FromArgb(190, 90, 0); $btnMinScan.ForeColor = [System.Drawing.Color]::White
$btnMinScan.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$btnMinScan.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$scFlow.Controls.Add($btnMinScan)

$btnMinKill = New-Object System.Windows.Forms.Button
$btnMinKill.Text = 'أوقف العنصر المحدد'; $btnMinKill.Width = 300; $btnMinKill.Height = 46; $btnMinKill.FlatStyle = 'Flat'; $btnMinKill.FlatAppearance.BorderSize = 0
$btnMinKill.BackColor = [System.Drawing.Color]::FromArgb(160, 50, 50); $btnMinKill.ForeColor = [System.Drawing.Color]::White
$btnMinKill.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$btnMinKill.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$scFlow.Controls.Add($btnMinKill)

$minStatus = New-Object System.Windows.Forms.Label
$minStatus.AutoSize = $true; $minStatus.ForeColor = [System.Drawing.Color]::Gray; $minStatus.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$minStatus.Text = 'اضغط فحص التعدين عشان يفحص جهازك'
$scFlow.Controls.Add($minStatus)

$minList = New-Object System.Windows.Forms.ListBox
$minList.Width = 740; $minList.Height = 160; $minList.RightToLeft = 'No'; $minList.BorderStyle = 'None'
$minList.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $minList.ForeColor = [System.Drawing.Color]::White
$minList.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$scFlow.Controls.Add($minList)

$script:MinerNames = @(
    'xmrig', 'xmr-stak', 'xmrstak', 'cpuminer', 'minerd', 'ccminer', 'cgminer', 'bfgminer',
    'claymore', 'phoenixminer', 't-rex', 'trex', 'lolminer', 'gminer', 'ethminer', 'nbminer',
    'srbminer', 'teamredminer', 'nicehash', 'nheqminer', 'excavator', 'wildrig', 'kryptex',
    'nanominer', 'bminer', 'z-enemy', 'pooler', 'sgminer'
)
$script:MinerHits = @()

function Get-MinerSuspects {
    $hits = New-Object System.Collections.ArrayList
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Select-Object ProcessId, Name, CommandLine, ExecutablePath)
    foreach ($p in $procs) {
        $nm = ($p.Name -replace '\.exe$', '').ToLower()
        $cmd = [string]$p.CommandLine
        $isNamed = [bool]($script:MinerNames | Where-Object { $nm -like "*$_*" })
        $isPool = $cmd -match 'stratum\+tcp|stratum\+ssl|(?i)pool\.(minexmr|supportxmr|nanopool|ethermine|hiveon|2miners|f2pool)|--?algo\s|--?donate-level'
        if ($isNamed -or $isPool) {
            $reason = if ($isNamed) { 'اسم العملية يطابق برنامج تعدين معروف' } else { 'سطر التشغيل فيه اتصال بمنصة تعدين (pool/stratum)' }
            [void]$hits.Add([pscustomobject]@{ Name = $p.Name; Pid2 = $p.ProcessId; Reason = $reason; Path = $p.ExecutablePath })
        }
    }
    try {
        $runKeys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')
        foreach ($rk in $runKeys) {
            if (Test-Path $rk) {
                (Get-Item $rk).GetValueNames() | ForEach-Object {
                    $v = [string](Get-ItemProperty -Path $rk -Name $_ -ErrorAction SilentlyContinue).$_
                    if ($v -and ($script:MinerNames | Where-Object { $v.ToLower() -like "*$_*" })) {
                        [void]$hits.Add([pscustomobject]@{ Name = $_; Pid2 = $null; Reason = 'مضاف لبدء التشغيل ويشبه برنامج تعدين'; Path = $v })
                    }
                }
            }
        }
    } catch {}
    $hits
}

$btnMinScan.Add_Click({
    $btnMinScan.Enabled = $false; $minStatus.ForeColor = $script:D.Good; $minStatus.Text = 'جاري الفحص...'
    [System.Windows.Forms.Application]::DoEvents()
    $minList.Items.Clear()
    $res = @(Get-MinerSuspects)
    $script:MinerHits = $res
    foreach ($r in $res) { [void]$minList.Items.Add("$($r.Name)  —  $($r.Reason)") }
    $n = $res.Count
    $minStatus.ForeColor = if ($n -eq 0) { $script:D.Good } else { [System.Drawing.Color]::FromArgb(235, 70, 60) }
    $minStatus.Text = if ($n -eq 0) { 'انتهى الفحص: ما انلقى شيء يشبه برامج التعدين ✓' } else { "انتهى الفحص: انلقى $n شيء مشتبه فيه" }
    Show-Done $(if ($n -eq 0) { 'فحص التعدين: كل شي سليم' } else { "فحص التعدين: انلقى $n شيء مشتبه فيه" })
    $btnMinScan.Enabled = $true
})
$btnMinKill.Add_Click({
    $i = $minList.SelectedIndex
    if ($i -lt 0 -or $i -ge $script:MinerHits.Count) { $minStatus.Text = 'حدد عنصر من القائمة أول'; return }
    $h = $script:MinerHits[$i]
    if ($h.Pid2) {
        try { Stop-Process -Id $h.Pid2 -Force -ErrorAction Stop; $minStatus.Text = "تم إيقاف $($h.Name) ✓" }
        catch { $minStatus.Text = "ما قدرت أوقف $($h.Name)" }
    } else {
        $minStatus.Text = 'هذا عنصر بدء تشغيل، احذفه من تبويب تطبيقات بدء التشغيل'
    }
})

$tabSc = New-Object System.Windows.Forms.TabPage 'فحص الجهاز'
$tabSc.BackColor = $form.BackColor; $tabSc.ForeColor = [System.Drawing.Color]::White
$tabSc.Controls.Add($scFlow)
[void]$tabs.TabPages.Add($tabSc)

# ---------- Windows Update check ----------
$wuFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$wuFlow.Dock = 'Fill'; $wuFlow.FlowDirection = 'TopDown'; $wuFlow.WrapContents = $false
$wuFlow.Padding = New-Object System.Windows.Forms.Padding(20)
$wuTitle = New-Object System.Windows.Forms.Label
$wuTitle.Text = 'تحديث ويندوز'; $wuTitle.AutoSize = $true
$wuTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$wuTitle.ForeColor = $script:Accent
$wuFlow.Controls.Add($wuTitle)
$wuBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$wuBtns.Width = 740; $wuBtns.Height = 70; $wuBtns.Margin = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$btnWuChk = New-Object System.Windows.Forms.Button
$btnWuChk.Text = 'فحص التحديثات'; $btnWuChk.Width = 260; $btnWuChk.Height = 60; $btnWuChk.FlatStyle = 'Flat'; $btnWuChk.FlatAppearance.BorderSize = 0
$btnWuChk.BackColor = [System.Drawing.Color]::FromArgb(0, 190, 215); $btnWuChk.ForeColor = [System.Drawing.Color]::White
$btnWuChk.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$btnWuOpen = New-Object System.Windows.Forms.Button
$btnWuOpen.Text = 'افتح تحديث ويندوز'; $btnWuOpen.Width = 260; $btnWuOpen.Height = 60; $btnWuOpen.FlatStyle = 'Flat'; $btnWuOpen.FlatAppearance.BorderSize = 0
$btnWuOpen.BackColor = [System.Drawing.Color]::FromArgb(60, 66, 80); $btnWuOpen.ForeColor = [System.Drawing.Color]::White
$btnWuOpen.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$wuBtns.Controls.Add($btnWuChk); $wuBtns.Controls.Add($btnWuOpen)
$wuFlow.Controls.Add($wuBtns)
$wuStatus = New-Object System.Windows.Forms.Label
$wuStatus.AutoSize = $true; $wuStatus.ForeColor = $script:D.Good; $wuStatus.Text = 'اضغط فحص التحديثات'
$wuStatus.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 6)
$wuFlow.Controls.Add($wuStatus)
$wuList = New-Object System.Windows.Forms.ListBox
$wuList.Width = 740; $wuList.Height = 300; $wuList.RightToLeft = 'No'; $wuList.BorderStyle = 'None'
$wuList.BackColor = [System.Drawing.Color]::FromArgb(16, 26, 40); $wuList.ForeColor = [System.Drawing.Color]::White
$wuFlow.Controls.Add($wuList)

$script:WuProc = $null; $script:WuOut = $null
$wuTimer = New-Object System.Windows.Forms.Timer; $wuTimer.Interval = 800
$wuTimer.Add_Tick({
    $p = $script:WuProc
    if (-not $p) { $wuTimer.Stop(); return }
    if (-not $p.HasExited) { return }
    $wuTimer.Stop()
    $lines = @($script:WuOut.Result -split "`r?`n" | Where-Object { $_ })
    $p.Dispose(); $script:WuProc = $null; $btnWuChk.Enabled = $true
    $wuList.Items.Clear()
    $err = $lines | Where-Object { $_ -like 'ERR:*' } | Select-Object -First 1
    if ($err -or -not ($lines | Where-Object { $_ -like 'DONE:*' })) { $wuStatus.Text = 'ما قدرت أفحص التحديثات. تأكد من الإنترنت وجرّب مرة ثانية'; return }
    foreach ($l in $lines) { if ($l -like 'UPD:*') { [void]$wuList.Items.Add($l.Substring(4)) } }
    $n = $wuList.Items.Count
    $wuStatus.Text = if ($n -eq 0) { 'جهازك محدّث ✓ ما فيه تحديثات جديدة' } else { "فيه $n تحديث متاح. اضغط افتح تحديث ويندوز عشان تثبّتها" }
    Show-Done $(if ($n -eq 0) { 'ويندوز محدّث، ما فيه تحديثات' } else { "فيه $n تحديث متاح لويندوز" })
})
$btnWuChk.Add_Click({
    $cmd = 'try { $s = New-Object -ComObject Microsoft.Update.Session; $r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0"); foreach ($u in $r.Updates) { Write-Output ("UPD:" + $u.Title) }; Write-Output ("DONE:" + $r.Updates.Count) } catch { Write-Output ("ERR:" + $_.Exception.Message) }'
    $script:WuProc = Invoke-PlainScript $cmd -CaptureOutput
    $script:WuOut = $script:WuProc.StandardOutput.ReadToEndAsync()
    $btnWuChk.Enabled = $false; $wuList.Items.Clear(); $wuStatus.Text = 'جاري الفحص... ممكن ياخذ نص دقيقة'
    $wuTimer.Start()
})
$btnWuOpen.Add_Click({ try { Start-Process 'ms-settings:windowsupdate' } catch { $wuStatus.Text = 'ما قدرت أفتح الإعدادات' } })

$tabWu = New-Object System.Windows.Forms.TabPage 'تحديث ويندوز'
$tabWu.BackColor = $form.BackColor; $tabWu.ForeColor = [System.Drawing.Color]::White
$tabWu.Controls.Add($wuFlow)
[void]$tabs.TabPages.Add($tabWu)

# ---------- about page (last) ----------
$abFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$abFlow.Dock = 'Fill'; $abFlow.FlowDirection = 'TopDown'; $abFlow.WrapContents = $false; $abFlow.Padding = New-Object System.Windows.Forms.Padding(30, 24, 30, 0)
$abTitle = New-Object System.Windows.Forms.Label
$abTitle.Text = 'واجهة مرن'; $abTitle.AutoSize = $true
$abTitle.Font = New-Object System.Drawing.Font('Segoe UI', 26, [System.Drawing.FontStyle]::Bold); $abTitle.ForeColor = $script:Accent
$abDesc = New-Object System.Windows.Forms.Label
$abDesc.AutoSize = $false; $abDesc.Width = 700; $abDesc.Height = 300; $abDesc.Margin = New-Object System.Windows.Forms.Padding(0, 14, 0, 0)
$abDesc.Font = New-Object System.Drawing.Font('Segoe UI', 12); $abDesc.ForeColor = [System.Drawing.Color]::FromArgb(225, 225, 230)
$abDesc.Text = "مراقبة حيّة للمعالج والرام وكرت الشاشة والأقراص، وتنظيف بضغطة.`r`n`r`nتصليح ويندوز، تويكات حسب قوة الجهاز، تحكم ببرامج بدء التشغيل.`r`n`r`nتحميل الفيديوهات من يوتيوب وتيك توك وانستقرام وتويتر، وتحويل الفيديو.`r`n`r`nفحص الجهاز وتحديث ويندوز.`r`n`r`nالمجسّم الثلاثي الأبعاد بصفحة المراقبة يدور بالفأرة، ولونه يتغير حسب حمل جهازك."
$abThemeLbl = New-Object System.Windows.Forms.Label
$abThemeLbl.AutoSize = $true; $abThemeLbl.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 8)
$abThemeLbl.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$abThemeLbl.Text = 'تصميم الواجهة  —  اختر واحد من ستة تصاميم (أو Ctrl+1 … Ctrl+6)'
$abThemeRow = New-Object System.Windows.Forms.FlowLayoutPanel
$abThemeRow.AutoSize = $true; $abThemeRow.FlowDirection = 'RightToLeft'; $abThemeRow.WrapContents = $true; $abThemeRow.RightToLeft = 'No'
$abModeRow = New-Object System.Windows.Forms.FlowLayoutPanel
$abModeRow.AutoSize = $true; $abModeRow.FlowDirection = 'RightToLeft'; $abModeRow.WrapContents = $false; $abModeRow.RightToLeft = 'No'
$abModeRow.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
foreach ($mm in @(@{ T = 'البسيط: الوضع الفاتح'; I = 'minimal-light'; G = 'sun' }, @{ T = 'البسيط: الوضع الداكن'; I = 'minimal-dark'; G = 'moon' })) {
    $mb = New-Object System.Windows.Forms.Button
    $mb.Text = $mm.T; $mb.Width = 220; $mb.Height = 40; $mb.FlatStyle = 'Flat'; $mb.FlatAppearance.BorderSize = 0
    $mb.BackColor = [System.Drawing.Color]::FromArgb(60, 66, 80); $mb.ForeColor = [System.Drawing.Color]::White
    $mb.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold); $mb.Tag = $mm
    $mb.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $mb.Add_Click({ param($s, $e) Apply-Design ([string]$s.Tag.I) $true })
    $abModeRow.Controls.Add($mb)
}
$abFlow.AutoScroll = $true
$abFlow.Controls.Add($abTitle); $abFlow.Controls.Add($abDesc); $abFlow.Controls.Add($abThemeLbl); $abFlow.Controls.Add($abThemeRow); $abFlow.Controls.Add($abModeRow)
$tabAb = New-Object System.Windows.Forms.TabPage 'واجهة مرن'
$tabAb.BackColor = $form.BackColor; $tabAb.ForeColor = [System.Drawing.Color]::White
$tabAb.Controls.Add($abFlow)
[void]$tabs.TabPages.Add($tabAb)

# ---------- app update (checks a version file on the update host, downloads and swaps the program files) ----------
$script:UpdInfo = $null; $script:UpdSilent = $false; $script:UpdPhase = ''
$script:UpdBox = [hashtable]::Synchronized(@{ Done = $true; Json = $null; Err = $null })
$abVer = New-Object System.Windows.Forms.Label
$abVer.AutoSize = $true; $abVer.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 6); $abVer.ForeColor = [System.Drawing.Color]::Silver
$abVer.Text = 'الإصدار: ' + $script:AppVersion
$abBtnChk = New-Object System.Windows.Forms.Button
$abBtnChk.Text = 'افحص التحديثات'; $abBtnChk.Width = 240; $abBtnChk.Height = 46; $abBtnChk.FlatStyle = 'Flat'; $abBtnChk.FlatAppearance.BorderSize = 0
$abBtnChk.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 190); $abBtnChk.ForeColor = [System.Drawing.Color]::White
$abBtnChk.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$abBtnUpd = New-Object System.Windows.Forms.Button
$abBtnUpd.Text = 'حدّث البرنامج الآن'; $abBtnUpd.Width = 240; $abBtnUpd.Height = 46; $abBtnUpd.FlatStyle = 'Flat'; $abBtnUpd.FlatAppearance.BorderSize = 0
$abBtnUpd.BackColor = [System.Drawing.Color]::FromArgb(0, 190, 215); $abBtnUpd.ForeColor = [System.Drawing.Color]::White
$abBtnUpd.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold); $abBtnUpd.Visible = $false
$abBtnUpd.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$abUpdStatus = New-Object System.Windows.Forms.Label
$abUpdStatus.AutoSize = $false; $abUpdStatus.Width = 700; $abUpdStatus.Height = 50; $abUpdStatus.ForeColor = $script:D.Good
$abUpdStatus.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)

$abBtnUninstall = New-Object System.Windows.Forms.Button
$abBtnUninstall.Text = 'إلغاء تثبيت البرنامج'; $abBtnUninstall.Width = 240; $abBtnUninstall.Height = 46; $abBtnUninstall.FlatStyle = 'Flat'; $abBtnUninstall.FlatAppearance.BorderSize = 0
$abBtnUninstall.BackColor = [System.Drawing.Color]::FromArgb(160, 50, 50); $abBtnUninstall.ForeColor = [System.Drawing.Color]::White
$abBtnUninstall.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$abBtnUninstall.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
$abBtnUninstall.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show('بيتم حذف البرنامج بالكامل من جهازك مع الاختصارات، وما ينرجع إلا بإعادة تثبيته من جديد. تكمل؟', 'إلغاء تثبيت Murn Interface', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $programsPath = [Environment]::GetFolderPath('Programs')
            foreach ($nm in @('Murn Interface.lnk', 'واجهة مرن.lnk')) {
                Remove-Item -LiteralPath (Join-Path $desktopPath $nm) -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath (Join-Path $programsPath $nm) -Force -ErrorAction SilentlyContinue
            }
            $dir = $script:AppDir
            $cmd = "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$dir' -Recurse -Force -ErrorAction SilentlyContinue"
            Invoke-PlainScript $cmd -Hidden
        } catch {
            [System.Windows.Forms.MessageBox]::Show('صار خطأ أثناء إلغاء التثبيت: ' + $_.Exception.Message, 'Murn Interface', 'OK', 'Error') | Out-Null
            return
        }
        [System.Windows.Forms.Application]::Exit()
    })

$abDesc.Height = 190
foreach ($c in $abVer, $abBtnChk, $abBtnUpd, $abUpdStatus, $abBtnUninstall) { $abFlow.Controls.Add($c) }

function Get-UpdateBase {
    $p = Join-Path $script:AppDir 'update-url.txt'
    if (Test-Path -LiteralPath $p) { ([IO.File]::ReadAllText($p)).Trim().TrimEnd('/') } else { '' }
}
function Start-UpdateBg($code, $vars) {
    $script:UpdBox.Done = $false; $script:UpdBox.Json = $null; $script:UpdBox.Err = $null
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $rs.SessionStateProxy.SetVariable('Box', $script:UpdBox)
    foreach ($k in $vars.Keys) { $rs.SessionStateProxy.SetVariable($k, $vars[$k]) }
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($code); [void]$ps.BeginInvoke()
    $updTimer.Start()
}
function Start-UpdateCheck($silent) {
    $base = Get-UpdateBase
    if (-not $base) { if (-not $silent) { $abUpdStatus.ForeColor = [System.Drawing.Color]::Orange; $abUpdStatus.Text = 'رابط التحديثات غير مضبوط بهذي النسخة' }; return }
    $script:UpdSilent = $silent; $script:UpdPhase = 'check'
    if (-not $silent) { $abUpdStatus.ForeColor = $script:D.Good; $abUpdStatus.Text = 'جاري فحص التحديثات...' }
    $abBtnChk.Enabled = $false
    Start-UpdateBg '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $Box.Json = $wc.DownloadString($Url) } catch { $Box.Err = $_.Exception.Message }; $Box.Done = $true' @{ Url = ($base + '/version.json?t=' + [DateTime]::UtcNow.Ticks) }
}
function Start-UpdateDownload {
    $j = $script:UpdInfo; $base = Get-UpdateBase
    $exeUrl = if ($j.url) { [string]$j.url } else { $base + '/Murn Interface.exe' }
    $ps1Url = if ($j.ps1_url) { [string]$j.ps1_url } else { $base + '/Murn1.ps1' }
    $icoUrl = if ($j.ico_url) { [string]$j.ico_url } else { '' }
    $pngUrl = if ($j.png_url) { [string]$j.png_url } else { '' }
    if ($exeUrl -notmatch '^https://' -or $ps1Url -notmatch '^https://') { $abUpdStatus.ForeColor = [System.Drawing.Color]::Orange; $abUpdStatus.Text = 'رابط التحديث لازم يكون https'; return }
    $script:UpdPhase = 'download'; $abBtnUpd.Enabled = $false; $abBtnChk.Enabled = $false
    $abUpdStatus.ForeColor = $script:D.Good; $abUpdStatus.Text = 'جاري تنزيل التحديث...'
    $tmp = Join-Path $env:TEMP 'murn-update'
    $dlCode = '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { if (Test-Path $Tmp) { Remove-Item $Tmp -Recurse -Force }; New-Item -ItemType Directory $Tmp | Out-Null; $ze = Join-Path $Tmp "new.exe"; $zp = Join-Path $Tmp "new.ps1"; (New-Object Net.WebClient).DownloadFile($ExeUrl, $ze); (New-Object Net.WebClient).DownloadFile($Ps1Url, $zp); $he = (Get-FileHash $ze -Algorithm SHA256).Hash; $hp = (Get-FileHash $zp -Algorithm SHA256).Hash; $hi = ""; $hg = ""; if ($IcoUrl) { $zi = Join-Path $Tmp "new.ico"; (New-Object Net.WebClient).DownloadFile($IcoUrl, $zi); $hi = (Get-FileHash $zi -Algorithm SHA256).Hash }; if ($PngUrl) { $zg = Join-Path $Tmp "new.png"; (New-Object Net.WebClient).DownloadFile($PngUrl, $zg); $hg = (Get-FileHash $zg -Algorithm SHA256).Hash }; $Box.Json = "$he|$hp|$hi|$hg" } catch { $Box.Err = $_.Exception.Message }; $Box.Done = $true'
    Start-UpdateBg $dlCode @{ ExeUrl = $exeUrl; Ps1Url = $ps1Url; IcoUrl = $icoUrl; PngUrl = $pngUrl; Tmp = $tmp }
}
function Install-Update {
    $tmp = Join-Path $env:TEMP 'murn-update'; $newExe = Join-Path $tmp 'new.exe'; $newPs1 = Join-Path $tmp 'new.ps1'
    if (-not (Test-Path -LiteralPath $newExe) -or -not (Test-Path -LiteralPath $newPs1)) { throw 'ملف التحديث ناقص' }
    $parts = ([string]$script:UpdBox.Json) -split '\|'
    $gotExeHash = $parts[0]; $gotPs1Hash = $parts[1]
    $gotIcoHash = if ($parts.Count -gt 2) { $parts[2] } else { '' }
    $gotPngHash = if ($parts.Count -gt 3) { $parts[3] } else { '' }
    $expExeHash = [string]$script:UpdInfo.sha256
    $expPs1Hash = [string]$script:UpdInfo.ps1_sha256
    $expIcoHash = [string]$script:UpdInfo.ico_sha256
    $expPngHash = [string]$script:UpdInfo.png_sha256
    if ($expExeHash -and ($expExeHash.ToUpper() -ne $gotExeHash.ToUpper())) { throw 'ملف exe تالف أو مو مطابق' }
    if ($expPs1Hash -and ($expPs1Hash.ToUpper() -ne $gotPs1Hash.ToUpper())) { throw 'ملف Murn1.ps1 تالف أو مو مطابق' }
    if ($expIcoHash -and $gotIcoHash -and ($expIcoHash.ToUpper() -ne $gotIcoHash.ToUpper())) { throw 'ملف الأيقونة تالف أو مو مطابق' }
    if ($expPngHash -and $gotPngHash -and ($expPngHash.ToUpper() -ne $gotPngHash.ToUpper())) { throw 'ملف الشعار تالف أو مو مطابق' }
    $target = $env:MURN_EXE
    if (-not $target -or -not (Test-Path -LiteralPath $target)) {
        $target = (Get-ChildItem -LiteralPath $script:AppDir -Filter '*.exe' | Where-Object { $_.Name -notlike '*(*)*' } | Select-Object -First 1).FullName
    }
    if (-not $target) { throw 'ما قدرت ألقى ملف البرنامج الحالي عشان أستبدله' }
    $targetPs1 = Join-Path (Split-Path $target -Parent) 'Murn1.ps1'
    $targetIco = Join-Path (Split-Path $target -Parent) 'falcon.ico'
    $targetPng = Join-Path (Split-Path $target -Parent) 'falcon.png'
    $newIco = Join-Path $tmp 'new.ico'; $newPng = Join-Path $tmp 'new.png'
    $hasIco = (Test-Path -LiteralPath $newIco); $hasPng = (Test-Path -LiteralPath $newPng)
    $apply = Join-Path $tmp 'apply.ps1'
    $code = @'
param($ProcId, $NewExe, $Target, $NewPs1, $TargetPs1, $NewIco, $TargetIco, $HasIco, $NewPng, $TargetPng, $HasPng)
try { Wait-Process -Id $ProcId -Timeout 40 -ErrorAction SilentlyContinue } catch {}
for ($i = 0; $i -lt 20; $i++) {
    try {
        Copy-Item -LiteralPath $NewPs1 -Destination $TargetPs1 -Force -ErrorAction Stop
        Copy-Item -LiteralPath $NewExe -Destination $Target -Force -ErrorAction Stop
        if ($HasIco -eq 'True') { Copy-Item -LiteralPath $NewIco -Destination $TargetIco -Force -ErrorAction SilentlyContinue }
        if ($HasPng -eq 'True') { Copy-Item -LiteralPath $NewPng -Destination $TargetPng -Force -ErrorAction SilentlyContinue }
        break
    } catch { Start-Sleep -Milliseconds 500 }
}
Start-Process $Target
'@
    [IO.File]::WriteAllText($apply, $code, (New-Object Text.UTF8Encoding $true))
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$apply`"", $PID, "`"$newExe`"", "`"$target`"", "`"$newPs1`"", "`"$targetPs1`"", "`"$newIco`"", "`"$targetIco`"", $hasIco, "`"$newPng`"", "`"$targetPng`"", $hasPng
    $form.Close()
}
$updTimer = New-Object System.Windows.Forms.Timer; $updTimer.Interval = 400
$updTimer.Add_Tick({
    if (-not $script:UpdBox.Done) { return }
    $updTimer.Stop(); $abBtnChk.Enabled = $true
    try {
        if ($script:UpdBox.Err) { throw $script:UpdBox.Err }
        if ($script:UpdPhase -eq 'check') {
            $j = $script:UpdBox.Json | ConvertFrom-Json
            if ([version]$j.version -gt [version]$script:AppVersion) {
                $script:UpdInfo = $j; $abBtnUpd.Visible = $true; $abBtnUpd.Enabled = $true
                $abUpdStatus.ForeColor = [System.Drawing.Color]::Gold
                $abUpdStatus.Text = 'يوجد إصدار جديد: ' + $j.version + $(if ($j.notes) { "`r`n" + $j.notes } else { '' })
                if ($script:UpdSilent) { Start-UpdateDownload }
            } elseif (-not $script:UpdSilent) { $abUpdStatus.ForeColor = $script:D.Good; $abUpdStatus.Text = 'عندك آخر إصدار ✓' }
        } else {
            $abUpdStatus.Text = 'تم التنزيل، البرنامج بيقفل ويرجع يفتح محدّث...'
            Install-Update
        }
    } catch {
        $abBtnUpd.Enabled = $true
        if (-not $script:UpdSilent -or $script:UpdPhase -eq 'download') { $abUpdStatus.ForeColor = [System.Drawing.Color]::Tomato; $abUpdStatus.Text = 'ما قدرت أحدّث: ' + $_.Exception.Message }
    }
})
$abBtnChk.Add_Click({ Start-UpdateCheck $false })
$abBtnUpd.Add_Click({ Start-UpdateDownload })
if (-not $env:MURN_TEST) {
    $form.Add_Shown({ $script:FirstUpd = New-Object System.Windows.Forms.Timer; $script:FirstUpd.Interval = 4000; $script:FirstUpd.Add_Tick({ $script:FirstUpd.Stop(); Start-UpdateCheck $true }); $script:FirstUpd.Start() })
}
if ($env:MURN_TEST -and $env:MURN_UPD) { $form.Add_Shown({ Start-UpdateCheck $false }) }


# ---------- 3D model (WPF Viewport3D hosted in the form) ----------
$script:ChipBrush = $null; $script:ChipRot = $null; $script:Chip3D = $false
try {
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, WindowsFormsIntegration
    function New-Box([double]$cx, [double]$cy, [double]$cz, [double]$sx, [double]$sy, [double]$sz, $brush) {
        $m = New-Object System.Windows.Media.Media3D.MeshGeometry3D
        $h = @(($sx / 2), ($sy / 2), ($sz / 2)); $c = @($cx, $cy, $cz)
        foreach ($ax in 0..2) {
            $u = ($ax + 1) % 3; $v = ($ax + 2) % 3
            foreach ($s in 1, -1) {
                $corners = @(@(-1, -1), @(1, -1), @(1, 1), @(-1, 1))
                if ($s -lt 0) { [array]::Reverse($corners) }
                $base = $m.Positions.Count
                foreach ($q in $corners) {
                    $p = New-Object double[] 3
                    $p[$ax] = $c[$ax] + $s * $h[$ax]; $p[$u] = $c[$u] + $q[0] * $h[$u]; $p[$v] = $c[$v] + $q[1] * $h[$v]
                    $m.Positions.Add((New-Object System.Windows.Media.Media3D.Point3D $p[0], $p[1], $p[2]))
                    $n = New-Object double[] 3; $n[$ax] = $s
                    $m.Normals.Add((New-Object System.Windows.Media.Media3D.Vector3D $n[0], $n[1], $n[2]))
                }
                foreach ($i in 0, 1, 2, 0, 2, 3) { $m.TriangleIndices.Add($base + $i) }
            }
        }
        $gm = New-Object System.Windows.Media.Media3D.GeometryModel3D
        $gm.Geometry = $m
        $gm.Material = New-Object System.Windows.Media.Media3D.DiffuseMaterial $brush
        $gm.BackMaterial = $gm.Material
        $gm
    }
    function New-Col($r, $g, $b) { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb($r, $g, $b)) }

    $grp = New-Object System.Windows.Media.Media3D.Model3DGroup
    $amb = New-Object System.Windows.Media.Media3D.AmbientLight ([System.Windows.Media.Color]::FromRgb(100, 100, 112))
    $dl = New-Object System.Windows.Media.Media3D.DirectionalLight ([System.Windows.Media.Colors]::White), (New-Object System.Windows.Media.Media3D.Vector3D -1, -2, -1.5)
    $dl2 = New-Object System.Windows.Media.Media3D.DirectionalLight ([System.Windows.Media.Color]::FromRgb(80, 120, 200)), (New-Object System.Windows.Media.Media3D.Vector3D 2, 1, 1)
    $dl3 = New-Object System.Windows.Media.Media3D.DirectionalLight ([System.Windows.Media.Color]::FromRgb(200, 160, 100)), (New-Object System.Windows.Media.Media3D.Vector3D -1, 1, 2)
    $grp.Children.Add($amb); $grp.Children.Add($dl); $grp.Children.Add($dl2); $grp.Children.Add($dl3)

    $cpuBrush = New-Col 255 179 64     # orange - matches the CPU accent in the reference model
    $gpuBrush = New-Col 77 225 255     # cyan - GPU accent
    $ramBrush = New-Col 199 125 255    # purple - RAM accent
    $gold = New-Col 217 169 58
    $script:ChipBrush = $cpuBrush      # CPU top color reacts to system load (set in Update-View)

    # ---------- board + CPU socket (center, static) ----------
    $grp.Children.Add((New-Box 0 -0.62 0 7.8 0.12 4.0 (New-Col 24 60 52)))
    $grp.Children.Add((New-Box 0 -0.35 0 2.6 0.42 2.6 (New-Col 46 50 62)))
    $grp.Children.Add((New-Box 0 -0.08 0 2.2 0.12 2.2 (New-Col 70 76 92)))
    $grp.Children.Add((New-Box 0 0.1 0 1.2 0.26 1.2 $cpuBrush))
    foreach ($i in -3..3) {
        $o = $i * 0.3
        $grp.Children.Add((New-Box $o -0.4 1.5 0.12 0.1 0.44 $gold)); $grp.Children.Add((New-Box $o -0.4 -1.5 0.12 0.1 0.44 $gold))
        $grp.Children.Add((New-Box 1.5 -0.4 $o 0.44 0.1 0.12 $gold)); $grp.Children.Add((New-Box -1.5 -0.4 $o 0.44 0.1 0.12 $gold))
    }

    # ---------- GPU card (its own group so it can detach/slide out) ----------
    $gpuBaseX = -3.15; $gpuBaseY = 0; $gpuBaseZ = 0
    $gpuLocal = New-Object System.Windows.Media.Media3D.Model3DGroup
    $gpuBody = New-Col 16 18 22
    $gpuLocal.Children.Add((New-Box 0 0.15 0 0.46 0.9 2.5 $gpuBody))
    $gpuLocal.Children.Add((New-Box -0.25 0.15 0 0.05 0.9 2.5 $gpuBrush))
    foreach ($i in -3..3) {
        $gpuLocal.Children.Add((New-Box 0.26 -0.33 ($i * 0.32) 0.4 0.26 0.05 (New-Col 170 176 186)))
    }
    $gpuLocal.Children.Add((New-Box 0 -0.62 0 0.5 0.1 2.6 (New-Col 20 22 26)))

    $fanRots = New-Object System.Collections.ArrayList
    function Add-Fan($parentGrp, $fy, $fz) {
        $hubGrp = New-Object System.Windows.Media.Media3D.Model3DGroup
        $hubGrp.Children.Add((New-Box 0 0 0 0.08 0.18 0.18 (New-Col 10 11 14)))
        foreach ($a in 0, 60, 120, 180, 240, 300) {
            $bladeGrp = New-Object System.Windows.Media.Media3D.Model3DGroup
            $bladeGrp.Children.Add((New-Box 0 0.24 0 0.05 0.42 0.17 (New-Col 60 66 78)))
            $rot = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D (New-Object System.Windows.Media.Media3D.Vector3D 1, 0, 0), $a
            $bladeGrp.Transform = New-Object System.Windows.Media.Media3D.RotateTransform3D $rot
            $hubGrp.Children.Add($bladeGrp)
        }
        $spinRot = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D (New-Object System.Windows.Media.Media3D.Vector3D 1, 0, 0), 0
        $spinGrp = New-Object System.Windows.Media.Media3D.Model3DGroup
        $spinGrp.Children.Add($hubGrp)
        $spinGrp.Transform = New-Object System.Windows.Media.Media3D.RotateTransform3D $spinRot
        $mountGrp = New-Object System.Windows.Media.Media3D.Model3DGroup
        $mountGrp.Children.Add($spinGrp)
        $mountGrp.Transform = New-Object System.Windows.Media.Media3D.TranslateTransform3D 0.27, $fy, $fz
        $mountGrp.Children.Add((New-Box 0.07 0 0 0.04 0.56 0.56 (New-Col 10 11 14)))
        $parentGrp.Children.Add($mountGrp)
        [void]$fanRots.Add($spinRot)
    }
    Add-Fan $gpuLocal 0.15 -0.68
    Add-Fan $gpuLocal 0.15 0.68

    $gpuTranslate = New-Object System.Windows.Media.Media3D.TranslateTransform3D $gpuBaseX, $gpuBaseY, $gpuBaseZ
    $gpuGroup = New-Object System.Windows.Media.Media3D.Model3DGroup
    $gpuGroup.Children.Add($gpuLocal)
    $gpuGroup.Transform = $gpuTranslate
    $grp.Children.Add($gpuGroup)

    # ---------- RAM sticks (each its own group so it can lift and spread) ----------
    $ramBody = New-Col 18 20 26
    $ramBasePos = @(); $ramTranslates = New-Object System.Collections.ArrayList
    foreach ($rz in -0.75, -0.25, 0.25, 0.75) {
        $ramLocal = New-Object System.Windows.Media.Media3D.Model3DGroup
        $ramLocal.Children.Add((New-Box 0 0 0 0.95 1.15 0.2 $ramBody))
        $ramLocal.Children.Add((New-Box 0 0.6 0 0.95 0.08 0.2 $ramBrush))
        $t = New-Object System.Windows.Media.Media3D.TranslateTransform3D 3.15, 0.3, $rz
        $ramLocal.Transform = $t
        $grp.Children.Add($ramLocal)
        $ramBasePos += , (New-Object System.Windows.Media.Media3D.Point3D 3.15, 0.3, $rz)
        [void]$ramTranslates.Add($t)
    }

    $script:ChipRot = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D (New-Object System.Windows.Media.Media3D.Vector3D 0, 1, 0), 30
    $tilt = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D (New-Object System.Windows.Media.Media3D.Vector3D 1, 0, 0), 22
    $tg = New-Object System.Windows.Media.Media3D.Transform3DGroup
    $tg.Children.Add((New-Object System.Windows.Media.Media3D.RotateTransform3D $script:ChipRot)); $tg.Children.Add((New-Object System.Windows.Media.Media3D.RotateTransform3D $tilt))
    $grp.Transform = $tg
    $vis = New-Object System.Windows.Media.Media3D.ModelVisual3D; $vis.Content = $grp
    $cam = New-Object System.Windows.Media.Media3D.PerspectiveCamera (New-Object System.Windows.Media.Media3D.Point3D 0, 0.2, 15), (New-Object System.Windows.Media.Media3D.Vector3D 0, 0, -1), (New-Object System.Windows.Media.Media3D.Vector3D 0, 1, 0), 38
    $vp = New-Object System.Windows.Controls.Viewport3D
    $vp.Camera = $cam; $vp.ClipToBounds = $true
    $vp.Children.Add($vis)
    $bg = New-Object System.Windows.Controls.Grid
    $bg.Background = New-Object System.Windows.Media.RadialGradientBrush ([System.Windows.Media.Color]::FromRgb(40, 46, 66)), ([System.Windows.Media.Color]::FromRgb(20, 22, 28))
    $bg.Children.Add($vp)
    $script:ChipDrag = $null
    $bg.Background = $bg.Background
    $vp.Add_MouseLeftButtonDown({ $script:ChipDrag = [System.Windows.Input.Mouse]::GetPosition($vp); [void]$vp.CaptureMouse() })
    $vp.Add_MouseLeftButtonUp({ $script:ChipDrag = $null; $vp.ReleaseMouseCapture() })
    $vp.Add_MouseMove({
        if ($script:ChipDrag) {
            $p = [System.Windows.Input.Mouse]::GetPosition($vp)
            $script:ChipRot.Angle += ($p.X - $script:ChipDrag.X) * 0.8; $script:ChipDrag = $p
        }
    })
    $monTopRow = New-Object System.Windows.Forms.Panel
    $monTopRow.Dock = 'Top'; $monTopRow.Height = 140; $monTopRow.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $monTopRow.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
    Set-DB $monTopRow; $monTopRow.Add_Paint({ param($s, $e) Paint-SurfacePanel $s $e }); $monTopRow.Add_Resize({ param($s, $e) $s.Invalidate() })
    $chipHost = New-Object System.Windows.Forms.Integration.ElementHost
    $chipHost.Dock = 'Left'; $chipHost.Width = 420; $chipHost.Height = 140; $chipHost.Child = $bg
    $script:MonSummary = New-Object System.Windows.Forms.Label
    $script:MonSummary.Dock = 'Fill'; $script:MonSummary.TextAlign = 'MiddleRight'
    $script:MonSummary.Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 10)
    $script:MonSummary.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $script:MonSummary.ForeColor = $script:Pal.SubText
    $script:MonSummary.Text = 'جاري التحقق من حالة الجهاز...'
    $monTopRow.Controls.Add($script:MonSummary); $monTopRow.Controls.Add($chipHost)
    $script:MonTopRow = $monTopRow; $script:ChipHost = $chipHost; $script:Chip3DBg = $bg
    $tabMon.Controls.Add($monTopRow)

    $script:Ex3T = 0.0; $script:FanSpeed = 0.0
    $chipTimer = New-Object System.Windows.Forms.Timer; $chipTimer.Interval = 55
    $chipTimer.Add_Tick({
        if ($tabs.SelectedTab -eq $tabMon) {
            $dt = 0.04; $script:Ex3T += $dt
            if (-not $script:ChipDrag) { $script:ChipRot.Angle = 30 + 12 * [Math]::Sin($script:Ex3T * 0.3) }
            $cyc = 9.0; $t = $script:Ex3T % $cyc
            if ($t -lt 3.0) { $ex = 0.0; $fanTarget = 1.0 }
            elseif ($t -lt 4.2) { $f = ($t - 3.0) / 1.2; $ex = $f; $fanTarget = 1.0 - $f }
            elseif ($t -lt 5.2) { $ex = 1.0; $fanTarget = 0.0 }
            elseif ($t -lt 7.4) { $f = ($t - 5.2) / 2.2; $ex = 1.0 - $f; $fanTarget = 0.0 }
            else { $f = ($t - 7.4) / 1.6; $ex = 0.0; $fanTarget = $f }
            $ex = $ex * $ex * (3 - 2 * $ex)
            $gpuTranslate.OffsetX = $gpuBaseX - $ex * 1.3
            $gpuTranslate.OffsetY = $gpuBaseY + $ex * 0.35
            for ($k = 0; $k -lt $ramTranslates.Count; $k++) {
                $b = $ramBasePos[$k]
                $ramTranslates[$k].OffsetX = $b.X
                $ramTranslates[$k].OffsetY = $b.Y + $ex * 1.1
                $ramTranslates[$k].OffsetZ = $b.Z + ($k - 1.5) * $ex * 0.32
            }
            $script:FanSpeed = $script:FanSpeed + ($fanTarget * 16 - $script:FanSpeed) * 0.08
            foreach ($fr in $fanRots) { $fr.Angle += $script:FanSpeed }
        }
    })
    $chipTimer.Start()
    $script:Chip3D = $true
} catch { $script:Chip3D = $false; $script:Chip3DErr = $_.Exception.ToString(); if ($env:MURN_TEST) { Set-Content (Join-Path $env:MURN_TEST 'err3d.txt') $script:Chip3DErr } }

# ---------- hide scrollbars (wheel still works) ----------
$script:ScrollHosts = New-Object System.Collections.ArrayList
function Fit-Scroll($h) {
    $d = $h.Tag; $c = $d.C
    $sw = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
    $shh = [System.Windows.Forms.SystemInformation]::HorizontalScrollBarHeight
    $w = $h.ClientSize.Width; $hh = $h.ClientSize.Height
    $barV = ($c.Width - $c.ClientSize.Width) -ge ($sw - 2)
    $barH = ($c.Height - $c.ClientSize.Height) -ge ($shh - 2)
    $extraW = if ($barV) { $sw } else { 0 }
    $extraH = if ($barH) { $shh } else { 0 }
    $x = if ($d.S -eq 'L') { -$extraW } else { 0 }
    if ($c.Left -ne $x -or $c.Width -ne ($w + $extraW) -or $c.Top -ne 0 -or $c.Height -ne ($hh + $extraH)) { $c.SetBounds($x, 0, $w + $extraW, $hh + $extraH) }
}
function Hide-Scroll($c, $side) {
    $p = $c.Parent; $i = $p.Controls.GetChildIndex($c)
    $h = New-Object System.Windows.Forms.Panel
    $h.Dock = 'Fill'; $h.BackColor = $c.BackColor
    $p.Controls.Remove($c); $c.Dock = 'None'; $h.Controls.Add($c)
    $p.Controls.Add($h); $p.Controls.SetChildIndex($h, $i)
    $h.Tag = @{ C = $c; S = $side }
    $h.Add_Resize({ param($s, $e) Fit-Scroll $s })
    $c.SetBounds(0, 0, $h.ClientSize.Width, $h.ClientSize.Height)
    [void]$script:ScrollHosts.Add($h)
}
$scrollTimer = New-Object System.Windows.Forms.Timer; $scrollTimer.Interval = 400
$scrollTimer.Add_Tick({ foreach ($h in $script:ScrollHosts) { if ($h.Visible) { Fit-Scroll $h } } })
$scrollTimer.Start()
Hide-Scroll $lvT 'L'
Hide-Scroll $stFlow 'R'
Hide-Scroll $gFlow 'R'
Hide-Scroll $rpFlow 'R'
Hide-Scroll $dpFlow 'R'
Hide-Scroll $tlFlow 'R'
Hide-Scroll $flow 'L'
Hide-Scroll $cvFlow 'R'
Hide-Scroll $ytFlow 'R'
Hide-Scroll $abFlow 'R'

# ---------- live stats (background runspace, so the window never lags) ----------
$script:StatsBox = [hashtable]::Synchronized(@{ Rows = $null; Stop = $false; Active = $true })
$bgScript = "function Get-LhmTemp {`n" + ${function:Get-LhmTemp}.ToString().Replace('$script:', '$global:') + "`n}`nfunction Get-Stats {`n" + ${function:Get-Stats}.ToString().Replace('$script:', '$global:') + "`n}`n" +
    '$global:Lhm = $Lhm; $global:DiskTemps = @{}; $global:DiskTick = 99; $gcTick = 0; while (-not $Box.Stop) { if (-not $Box.Active) { Start-Sleep -Milliseconds 400; continue }; try { $Box.Rows = @(Get-Stats) } catch {}; $gcTick++; if ($gcTick -ge 25) { $gcTick = 0; [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers() }; Start-Sleep -Milliseconds 2000 }'
$script:BgRs = [runspacefactory]::CreateRunspace(); $script:BgRs.ApartmentState = 'MTA'; $script:BgRs.Open()
$script:BgRs.SessionStateProxy.SetVariable('Box', $script:StatsBox)
$script:BgRs.SessionStateProxy.SetVariable('Lhm', $script:Lhm)
$script:BgPs = [powershell]::Create(); $script:BgPs.Runspace = $script:BgRs
[void]$script:BgPs.AddScript($bgScript)
[void]$script:BgPs.BeginInvoke()

function Get-RowIconKey($name) {
    if ($name -like 'المعالج*') { 'cpu' } elseif ($name -like 'الرام*') { 'ram' } elseif ($name -like 'كرت*') { 'gpu' } else { 'disk' }
}

function Update-View {
    $rows = $script:StatsBox.Rows
    if ($rows -and -not [object]::ReferenceEquals($rows, $script:LastRows)) { $script:LastRows = $rows; try { Record-History $rows; Update-StatusLine $rows } catch {} }
    try { if ($script:D.StatusBar) { $script:StatusBar.Invalidate() }; if ($script:D.Shell -eq 'toolbar') { $script:Header.Invalidate() } } catch {}
    if ($tabs.SelectedTab -ne $tabMon) { return }
    if (-not $rows) { return }
    $gFlow.SuspendLayout()
    while ($script:GaugeList.Count -lt $rows.Count) { $c = New-Gauge; [void]$script:GaugeList.Add($c); $gFlow.Controls.Add($c) }
    while ($script:GaugeList.Count -gt $rows.Count) { $c = $script:GaugeList[$script:GaugeList.Count - 1]; $gFlow.Controls.Remove($c); $c.Dispose(); $script:GaugeList.RemoveAt($script:GaugeList.Count - 1) }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]; $c = $script:GaugeList[$i]
        $c.Tag = @{ Pct = [int]$r.Pct; Temp = $r.Temp; Name = ($r.Name -replace ': ', '  ·  '); Usage = [string]$r.Usage; Kind = $r.Kind; Key = [string]$r.Name }
        $c.Invalidate()
    }
    $gFlow.ResumeLayout()
    if ($script:GaugeList.Count -ne $script:LastGaugeCount) { $script:LastGaugeCount = $script:GaugeList.Count; Center-Gauges }
    if ($script:MonSummary) {
        $hot = @($rows | Where-Object { ($null -ne $_.Temp -and $_.Temp -ge 85) -or ([int]$_.Pct -ge 90) })
        $warm = @($rows | Where-Object { ($null -ne $_.Temp -and $_.Temp -ge 70 -and $_.Temp -lt 85) -or ([int]$_.Pct -ge 75 -and [int]$_.Pct -lt 90) })
        $cpuRow = $rows | Where-Object { $_.Kind -eq 'cpu' } | Select-Object -First 1
        $ramRow = $rows | Where-Object { $_.Kind -eq 'ram' } | Select-Object -First 1
        $lines = New-Object System.Collections.ArrayList
        if ($hot.Count -gt 0) { [void]$lines.Add("⚠ فيه $($hot.Count) عنصر يحتاج انتباه (حرارة/استخدام مرتفع)") }
        elseif ($warm.Count -gt 0) { [void]$lines.Add("كل شي طبيعي تقريباً، $($warm.Count) عنصر بحمل متوسط") }
        else { [void]$lines.Add('كل مؤشرات جهازك طبيعية ✓') }
        if ($cpuRow) { [void]$lines.Add("المعالج: $($cpuRow.Usage)") }
        if ($ramRow) { [void]$lines.Add("الرام: $($ramRow.Usage)") }
        [void]$lines.Add("عدد العناصر المراقَبة: $($rows.Count)")
        $script:MonSummary.Text = ($lines -join "`r`n")
    }
    if ($script:Chip3D -and $rows.Count) {
        $mx = [int](($rows | ForEach-Object { [int]$_.Pct } | Measure-Object -Maximum).Maximum)
        $col = if ($mx -ge 90) { [System.Windows.Media.Color]::FromRgb(235, 70, 60) } elseif ($mx -ge 75) { [System.Windows.Media.Color]::FromRgb(240, 150, 30) } else { [System.Windows.Media.Color]::FromRgb($script:Accent.R, $script:Accent.G, $script:Accent.B) }
        $script:ChipBrush.Color = $col
    }
}

# =====================================================================================
# ---------- Murn Design System v2: five complete designs (layout + palette + painters) ----------
#   1) nexus   : Futuristic Gaming   - icon rail, HUD header, segmented neon arc gauges
#   2) royal   : Premium Black & Gold - brand sidebar with sections, serif numerals, watch-ring gauges
#   3) fluent  : Windows 11 Fluent    - navigation pane, page header, bar cards (follows system light/dark)
#   4) control : Hardware Control Center - toolbar tiles, live status bar, history chart tiles
#   5) minimal : Modern Minimalist    - top text navigation, big numbers, light + dark modes
# All controls are built once in the canonical palette; every design is applied by remapping
# each control's ORIGINAL colors/fonts, so switching back and forth is lossless.
# =====================================================================================

# ---------- DPI ----------
$script:S = 1.0
try { $gS = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:S = [math]::Max(1.0, [double]$gS.DpiX / 96.0); $gS.Dispose() } catch {}
function Dpx([double]$v) { [int][math]::Round($v * $script:S) }

# ---------- fonts ----------
$script:FontNames = @{}
try { foreach ($ff in (New-Object System.Drawing.Text.InstalledFontCollection).Families) { $script:FontNames[$ff.Name] = $true } } catch {}
function Pick-Font([string[]]$names) { foreach ($n in $names) { if ($script:FontNames.ContainsKey($n)) { return $n } }; 'Segoe UI' }
$script:FontCache = @{}
function Get-PxFont([string]$fam, [double]$px, $style = 'Regular') {
    $k = "px|$fam|$px|$style"
    if (-not $script:FontCache.ContainsKey($k)) {
        try { $script:FontCache[$k] = New-Object System.Drawing.Font($fam, [single]$px, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel) }
        catch { $script:FontCache[$k] = New-Object System.Drawing.Font('Segoe UI', [single]$px, [System.Drawing.FontStyle]$style, [System.Drawing.GraphicsUnit]::Pixel) }
    }
    $script:FontCache[$k]
}
function Get-PtFont([string]$fam, [double]$pt, $style = 'Regular') {
    $pt = [math]::Round($pt, 1)
    $k = "pt|$fam|$pt|$style"
    if (-not $script:FontCache.ContainsKey($k)) {
        try { $script:FontCache[$k] = New-Object System.Drawing.Font($fam, [single]$pt, [System.Drawing.FontStyle]$style) }
        catch { $script:FontCache[$k] = New-Object System.Drawing.Font('Segoe UI', [single]$pt, [System.Drawing.FontStyle]$style) }
    }
    $script:FontCache[$k]
}
$fUI = 'Segoe UI'
$fSemi = Pick-Font @('Segoe UI Semibold', 'Segoe UI')
$fLight = Pick-Font @('Segoe UI Light', 'Segoe UI')
$fNum = Pick-Font @('Bahnschrift', 'Segoe UI Semibold', 'Segoe UI')
$fVar = Pick-Font @('Segoe UI Variable Display', 'Segoe UI Semibold', 'Segoe UI')
$fLux = Pick-Font @('Sakkal Majalla', 'Traditional Arabic', 'Segoe UI')
$fSerif = Pick-Font @('Georgia', 'Cambria', 'Times New Roman', 'Segoe UI')
$fMono = Pick-Font @('Cascadia Mono', 'Cascadia Code', 'Consolas')

# ---------- icon glyphs (Segoe Fluent Icons / MDL2 Assets, verified per glyph; symbol fallback) ----------
$script:IconFont = $null; $script:IconMap = $null
foreach ($c in @(@{ N = 'Segoe Fluent Icons'; F = 'SegoeIcons.ttf' }, @{ N = 'Segoe MDL2 Assets'; F = 'segmdl2.ttf' })) {
    if ($script:FontNames.ContainsKey($c.N)) {
        $script:IconFont = $c.N
        try {
            Add-Type -AssemblyName PresentationCore -ErrorAction Stop
            $fp = Join-Path $env:windir ('Fonts\' + $c.F)
            if (Test-Path -LiteralPath $fp) { $script:IconMap = (New-Object System.Windows.Media.GlyphTypeface (New-Object System.Uri $fp)).CharacterToGlyphMap }
        } catch {}
        break
    }
}
$script:GlyphCand = @{
    mon = @(0xE9D9, 0xE80F); fix = @(0xE90F, 0xE713); tweaks = @(0xE9E9, 0xE713); startup = @(0xE7E8)
    procs = @(0xE71D, 0xE7C4); display = @(0xE7F4, 0xE7F8); yt = @(0xE896, 0xE118); conv = @(0xE714, 0xE8B2)
    tools = @(0xEA99, 0xE74D); shield = @(0xEA18, 0xE72E); update = @(0xE895, 0xE72C); about = @(0xE946)
    cpu = @(0xE950, 0xE9F5, 0xE964, 0xE713); ram = @(0xE964, 0xEEA0, 0xE8F1); gpu = @(0xE7FC); disk = @(0xEDA2, 0xE8B7)
    mrt = @(0xE721); palette = @(0xE790, 0xE771); sun = @(0xE706); moon = @(0xE708)
}
$script:GlyphSym = @{
    mon = [string][char]0x2302; fix = [string][char]0x271A; tweaks = [string][char]0x2630; startup = [string][char]0x25C9
    procs = [string][char]0x25A6; display = [string][char]0x25AD; yt = [string][char]0x2B07; conv = [string][char]0x25B6
    tools = [string][char]0x2726; shield = [string][char]0x25C8; update = [string][char]0x27F3; about = [string][char]0x2139
    cpu = [string][char]0x25A3; ram = [string][char]0x25A4; gpu = [string][char]0x25C8; disk = [string][char]0x25CD
    mrt = [string][char]0x2315; palette = [string][char]0x25D0; sun = [string][char]0x2600; moon = [string][char]0x263E
}
$script:GlyphCache = @{}
function Get-Glyph($key) {
    if (-not $key) { return $null }
    if ($script:GlyphCache.ContainsKey($key)) { return $script:GlyphCache[$key] }
    $res = $null
    if ($script:IconFont -and $script:GlyphCand.ContainsKey($key)) {
        foreach ($cp in $script:GlyphCand[$key]) {
            if (-not $script:IconMap -or $script:IconMap.ContainsKey([int]$cp)) { $res = @{ T = [string][char]$cp; F = $script:IconFont }; break }
        }
    }
    if (-not $res -and $script:GlyphSym.ContainsKey($key)) { $res = @{ T = $script:GlyphSym[$key]; F = 'Segoe UI Symbol' } }
    $script:GlyphCache[$key] = $res
    $res
}
function Draw-Glyph($g, $key, [double]$x, [double]$y, [double]$w, [double]$h, $color, [double]$px) {
    $gl = Get-Glyph $key; if (-not $gl) { return }
    $br = New-Object System.Drawing.SolidBrush $color
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $old = $g.TextRenderingHint; $g.TextRenderingHint = 'AntiAlias'
    $g.DrawString($gl.T, (Get-PxFont $gl.F $px), $br, (New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single]$w), ([single]$h)), $sf)
    $g.TextRenderingHint = $old; $br.Dispose(); $sf.Dispose()
}

# ---------- drawing helpers ----------
function Mix-Color($a, $b, [double]$t) {
    [System.Drawing.Color]::FromArgb(255, [int]($a.R + ($b.R - $a.R) * $t), [int]($a.G + ($b.G - $a.G) * $t), [int]($a.B + ($b.B - $a.B) * $t))
}
function With-Alpha($c, [int]$a) { [System.Drawing.Color]::FromArgb([math]::Max(0, [math]::Min(255, $a)), $c.R, $c.G, $c.B) }
function Get-OnColor($c) { if ((0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B) -gt 160) { C 16 16 16 } else { [System.Drawing.Color]::White } }
function New-RectF([double]$x, [double]$y, [double]$w, [double]$h) { New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single][math]::Max(1, $w)), ([single][math]::Max(1, $h)) }
function New-ShapePath([double]$x, [double]$y, [double]$w, [double]$h, [string]$shape, [double]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $w = [math]::Max(2.0, $w); $h = [math]::Max(2.0, $h)
    if ($shape -eq 'pill') { $shape = 'round'; $r = $h / 2 }
    if ($shape -eq 'chamfer' -and $r -gt 0) {
        $c = [math]::Min($r, [math]::Min($w, $h) / 2)
        $pts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF ([single]$x), ([single]$y)),
            (New-Object System.Drawing.PointF ([single]($x + $w - $c)), ([single]$y)),
            (New-Object System.Drawing.PointF ([single]($x + $w)), ([single]($y + $c))),
            (New-Object System.Drawing.PointF ([single]($x + $w)), ([single]($y + $h))),
            (New-Object System.Drawing.PointF ([single]($x + $c)), ([single]($y + $h))),
            (New-Object System.Drawing.PointF ([single]$x), ([single]($y + $h - $c))))
        $p.AddPolygon($pts)
    } elseif ($shape -eq 'round' -and $r -gt 0.5) {
        $d = [single][math]::Min(2 * $r, [math]::Min($w, $h))
        $xs = [single]$x; $ys = [single]$y; $xr = [single]($x + $w - $d); $yb = [single]($y + $h - $d)
        $p.AddArc($xs, $ys, $d, $d, [single]180, [single]90); $p.AddArc($xr, $ys, $d, $d, [single]270, [single]90)
        $p.AddArc($xr, $yb, $d, $d, [single]0, [single]90); $p.AddArc($xs, $yb, $d, $d, [single]90, [single]90)
        $p.CloseFigure()
    } else { $p.AddRectangle((New-RectF $x $y $w $h)) }
    $p
}
function Fill-Shape($g, $color, [double]$x, [double]$y, [double]$w, [double]$h, [string]$shape = 'square', [double]$r = 0) {
    $p = New-ShapePath $x $y $w $h $shape $r; $b = New-Object System.Drawing.SolidBrush $color; $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
}
function Stroke-Shape($g, $color, [double]$width, [double]$x, [double]$y, [double]$w, [double]$h, [string]$shape = 'square', [double]$r = 0) {
    $p = New-ShapePath $x $y $w $h $shape $r; $pen = New-Object System.Drawing.Pen $color, ([single]$width); $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
}
function Draw-Line($g, $color, [double]$width, [double]$x1, [double]$y1, [double]$x2, [double]$y2) {
    $pen = New-Object System.Drawing.Pen $color, ([single]$width); $g.DrawLine($pen, [single]$x1, [single]$y1, [single]$x2, [single]$y2); $pen.Dispose()
}
# align: Right / Left / Center (visual); rtl = Arabic run direction
function Draw-Text($g, [string]$txt, $font, $color, [double]$x, [double]$y, [double]$w, [double]$h, [string]$align = 'Center', [bool]$rtl = $true) {
    if (-not $txt) { return }
    $sf = New-Object System.Drawing.StringFormat
    if ($align -eq 'Center') { $sf.Alignment = 'Center' }
    elseif (($align -eq 'Right') -xor (-not $rtl)) { $sf.Alignment = 'Near' } else { $sf.Alignment = 'Far' }
    $sf.LineAlignment = 'Center'; $sf.Trimming = 'EllipsisCharacter'
    $sf.FormatFlags = if ($rtl) { [System.Drawing.StringFormatFlags]'NoWrap, DirectionRightToLeft' } else { [System.Drawing.StringFormatFlags]'NoWrap' }
    $br = New-Object System.Drawing.SolidBrush $color
    $g.DrawString($txt, $font, $br, (New-RectF $x $y $w $h), $sf)
    $br.Dispose(); $sf.Dispose()
}
$script:LogoImg = $null
try { $lp = Join-Path $script:AppDir 'falcon.png'; if (Test-Path -LiteralPath $lp) { $script:LogoImg = [System.Drawing.Image]::FromFile($lp) } } catch {}
function Draw-Logo($g, [double]$x, [double]$y, [double]$size) {
    if ($script:LogoImg) { $g.DrawImage($script:LogoImg, (New-RectF $x $y $size $size)); return }
    Fill-Shape $g $script:D.Accent $x $y $size $size 'round' ($size / 2)
    Draw-Text $g 'M' (Get-PxFont $fSemi ($size * 0.55) 'Bold') $script:D.OnAccent $x $y $size $size 'Center' $false
}

# ---------- the designs ----------
function Merge-Design($base, $over) { $h = @{}; foreach ($k in $base.Keys) { $h[$k] = $base[$k] }; foreach ($k in $over.Keys) { $h[$k] = $over[$k] }; $h }
$script:Designs = @{}
$script:Designs['nexus'] = @{
    Id = 'nexus'; Name = 'نكسس — الألعاب المستقبلية'; Sub = 'Futuristic Gaming'; Shell = 'rail'; Gauge = 'arc'; CardStyle = 'hud'
    Dark = $true; Corner = 1; WinBorder = (C 0 150 190)
    Bg = (C 6 10 20); Surface = (C 8 13 26); Header = (C 7 12 24); Card = (C 12 20 38); CardTop = (C 16 28 52); CardBot = (C 10 16 31)
    Border = (C 26 54 92); Track = (C 20 34 60); Tick = (C 46 84 132); Input = (C 5 9 18)
    Text = (C 232 246 255); Muted = (C 118 148 184); NavText = (C 128 160 198); LogText = (C 140 205 235); Caption = (C 90 200 240)
    Good = (C 60 240 170); Accent = (C 0 229 255); Accent2 = (C 41 121 255); OnAccent = (C 2 10 22)
    Btn2 = (C 18 34 64); Btn2Text = (C 190 225 255); BtnLine = (C 30 70 120); Info = (C 41 121 255); Danger = (C 255 64 96); Warn = (C 255 166 0)
    Hover = (C 14 30 58); SelBg = (C 6 38 64)
    Radius = 12; BtnShape = 'chamfer'; BtnRadius = 9; BtnStyle = 'fill'
    Font = $fUI; Head = $fUI; HeadScale = 1.0; HeadStyle = 'Bold'; Num = $fNum; Mono = 'Consolas'
    NavW = 76; BrandH = 70; HeaderH = 62; MonH = 150; GaugeSize = @(184, 226)
    Glow3D = @((C 14 44 78), (C 6 10 20))
}
$script:Designs['royal'] = @{
    Id = 'royal'; Name = 'رويال — الأسود والذهبي'; Sub = 'Premium Black & Gold'; Shell = 'sidebar'; Gauge = 'ring'; CardStyle = 'lux'
    Dark = $true; Corner = 1; WinBorder = (C 120 96 40)
    Bg = (C 9 9 11); Surface = (C 13 13 15); Header = (C 9 9 11); Card = (C 17 17 20); CardTop = (C 21 21 24); CardBot = (C 15 15 18)
    Border = (C 52 44 28); Track = (C 38 35 30); Tick = (C 96 80 48); Input = (C 12 12 14)
    Text = (C 242 236 224); Muted = (C 150 144 132); NavText = (C 168 160 146); LogText = (C 190 178 150); Caption = (C 201 168 98)
    Good = (C 156 204 140); Accent = (C 212 175 55); Accent2 = (C 240 216 150); OnAccent = (C 18 14 4)
    Btn2 = (C 24 23 21); Btn2Text = (C 226 210 168); BtnLine = (C 70 58 34); Info = (C 200 168 96); Danger = (C 210 86 70); Warn = (C 222 148 64)
    Hover = (C 22 21 18); SelBg = (C 30 26 15)
    Radius = 0; BtnShape = 'square'; BtnRadius = 0; BtnStyle = 'outline'
    Font = $fUI; Head = $fLux; HeadScale = 1.45; HeadStyle = 'Bold'; Num = $fSerif; Mono = 'Consolas'
    NavW = 236; BrandH = 104; HeaderH = 76; MonH = 150; GaugeSize = @(200, 236)
    Glow3D = @((C 46 38 20), (C 9 9 11))
}
$script:Designs['fluent-dark'] = @{
    Id = 'fluent'; Name = 'فلونت — ويندوز 11'; Sub = 'Windows 11 Fluent'; Shell = 'pane'; Gauge = 'bar'; CardStyle = 'fluent'
    Dark = $true; Corner = 2; WinBorder = $null
    Bg = (C 39 39 39); Surface = (C 32 32 32); Header = (C 32 32 32); Card = (C 45 45 45); CardTop = (C 45 45 45); CardBot = (C 43 43 43)
    Border = (C 60 60 60); Track = (C 72 72 72); Tick = (C 90 90 90); Input = (C 30 30 30)
    Text = (C 255 255 255); Muted = (C 170 170 170); NavText = (C 225 225 225); LogText = (C 200 200 200); Caption = (C 205 205 205)
    Good = (C 108 203 95); Accent = (C 96 205 255); Accent2 = (C 96 205 255); OnAccent = (C 0 0 0)
    Btn2 = (C 55 55 55); Btn2Text = (C 255 255 255); BtnLine = (C 70 70 70); Info = (C 96 205 255); Danger = (C 240 110 120); Warn = (C 255 180 60)
    Hover = (C 50 50 50); SelBg = (C 54 54 54)
    Radius = 8; BtnShape = 'round'; BtnRadius = 5; BtnStyle = 'fill'
    Font = $fUI; Head = $fSemi; HeadScale = 1.0; HeadStyle = 'Regular'; Num = $fVar; Mono = 'Consolas'
    NavW = 252; BrandH = 56; HeaderH = 0; MonH = 144; GaugeSize = @(272, 122)
    Glow3D = @((C 58 58 58), (C 39 39 39))
}
$script:Designs['fluent-light'] = Merge-Design $script:Designs['fluent-dark'] @{
    Dark = $false
    Bg = (C 249 249 249); Surface = (C 243 243 243); Header = (C 243 243 243); Card = (C 255 255 255); CardTop = (C 255 255 255); CardBot = (C 253 253 253)
    Border = (C 229 229 229); Track = (C 214 214 214); Tick = (C 200 200 200); Input = (C 255 255 255)
    Text = (C 27 27 27); Muted = (C 96 96 96); NavText = (C 40 40 40); LogText = (C 60 60 60); Caption = (C 70 70 70)
    Good = (C 15 123 15); Accent = (C 0 103 192); Accent2 = (C 0 103 192); OnAccent = (C 255 255 255)
    Btn2 = (C 251 251 251); Btn2Text = (C 27 27 27); BtnLine = (C 220 220 220); Info = (C 0 103 192); Danger = (C 196 43 28); Warn = (C 157 93 0)
    Hover = (C 234 234 234); SelBg = (C 233 233 233)
    Glow3D = @((C 255 255 255), (C 232 232 232))
}
$script:Designs['control'] = @{
    Id = 'control'; Name = 'مركز التحكم — مراقبة العتاد'; Sub = 'Hardware Control Center'; Shell = 'toolbar'; Gauge = 'chart'; CardStyle = 'panel'
    Dark = $true; Corner = 1; WinBorder = (C 90 70 20)
    Bg = (C 16 18 20); Surface = (C 22 25 28); Header = (C 12 14 16); Card = (C 22 25 28); CardTop = (C 28 32 36); CardBot = (C 20 23 26)
    Border = (C 42 47 53); Track = (C 34 38 43); Tick = (C 48 54 61); Input = (C 11 13 15)
    Text = (C 216 222 228); Muted = (C 126 136 147); NavText = (C 150 160 170); LogText = (C 110 225 140); Caption = (C 255 176 0)
    Good = (C 80 220 120); Accent = (C 255 176 0); Accent2 = (C 0 210 150); OnAccent = (C 22 14 0)
    Btn2 = (C 32 36 41); Btn2Text = (C 216 222 228); BtnLine = (C 52 58 65); Info = (C 70 160 240); Danger = (C 232 72 60); Warn = (C 255 128 0)
    Hover = (C 30 34 38); SelBg = (C 38 34 22)
    Radius = 2; BtnShape = 'square'; BtnRadius = 2; BtnStyle = 'strip'
    Font = $fUI; Head = $fUI; HeadScale = 0.85; HeadStyle = 'Bold'; Num = $fMono; Mono = $fMono
    NavW = 0; BrandH = 0; HeaderH = 40; MonH = 132; GaugeSize = @(330, 156); StatusBar = $true
    Glow3D = @((C 36 40 44), (C 16 18 20))
}
$script:Designs['minimal-light'] = @{
    Id = 'minimal-light'; Name = 'البسيط — فاتح'; Sub = 'Modern Minimalist · Light'; Shell = 'topnav'; Gauge = 'big'; CardStyle = 'flat'
    Dark = $false; Corner = 2; WinBorder = $null
    Bg = (C 247 247 245); Surface = (C 247 247 245); Header = (C 247 247 245); Card = (C 255 255 255); CardTop = (C 255 255 255); CardBot = (C 255 255 255)
    Border = (C 230 230 227); Track = (C 232 232 229); Tick = (C 210 210 206); Input = (C 255 255 255)
    Text = (C 20 20 20); Muted = (C 120 120 116); NavText = (C 125 125 121); LogText = (C 80 80 78); Caption = (C 90 90 88)
    Good = (C 24 140 76); Accent = (C 20 20 20); Accent2 = (C 20 20 20); OnAccent = (C 255 255 255)
    Btn2 = (C 236 236 233); Btn2Text = (C 20 20 20); BtnLine = $null; Info = (C 37 99 235); Danger = (C 205 45 45); Warn = (C 196 120 0)
    Hover = (C 240 240 237); SelBg = (C 236 236 233)
    Radius = 12; BtnShape = 'pill'; BtnRadius = 0; BtnStyle = 'fill'
    Font = $fUI; Head = $fLight; HeadScale = 1.1; HeadStyle = 'Regular'; Num = $fLight; Mono = 'Consolas'
    NavW = 0; BrandH = 0; HeaderH = 64; MonH = 140; GaugeSize = @(240, 140)
    Glow3D = @((C 255 255 255), (C 236 236 233))
}
$script:Designs['minimal-dark'] = Merge-Design $script:Designs['minimal-light'] @{
    Id = 'minimal-dark'; Name = 'البسيط — داكن'; Sub = 'Modern Minimalist · Dark'; Dark = $true
    Bg = (C 15 15 16); Surface = (C 15 15 16); Header = (C 15 15 16); Card = (C 24 24 26); CardTop = (C 24 24 26); CardBot = (C 24 24 26)
    Border = (C 40 40 43); Track = (C 44 44 47); Tick = (C 60 60 64); Input = (C 20 20 22)
    Text = (C 238 238 236); Muted = (C 140 140 145); NavText = (C 135 135 140); LogText = (C 190 190 190); Caption = (C 170 170 170)
    Good = (C 90 205 135); Accent = (C 238 238 236); Accent2 = (C 238 238 236); OnAccent = (C 15 15 16)
    Btn2 = (C 34 34 37); Btn2Text = (C 238 238 236); Info = (C 96 150 255); Danger = (C 240 90 90); Warn = (C 240 170 60)
    Hover = (C 28 28 31); SelBg = (C 34 34 37)
    Glow3D = @((C 34 34 37), (C 15 15 16))
}
# 6) fluentcc : Windows 11 + Control Center - the Fluent shell with live history charts and the status bar
$ccOver = @{ Id = 'fluentcc'; Name = 'ويندوز 11 + مركز التحكم'; Sub = 'Windows 11 Control Center'; Gauge = 'chart'; StatusBar = $true; Mono = $fMono; MonH = 132; GaugeSize = @(330, 156) }
$script:Designs['fluentcc-dark'] = Merge-Design $script:Designs['fluent-dark'] $ccOver
$script:Designs['fluentcc-light'] = Merge-Design $script:Designs['fluent-light'] $ccOver
$script:DesignOrder = @('fluentcc', 'nexus', 'royal', 'fluent', 'control', 'minimal')
function Get-SystemLight { try { [int](Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 1 } catch { $false } }
function Resolve-DesignKey([string]$id) {
    switch ($id) {
        'fluent' { if (Get-SystemLight) { 'fluent-light' } else { 'fluent-dark' } }
        'fluentcc' { if (Get-SystemLight) { 'fluentcc-light' } else { 'fluentcc-dark' } }
        'minimal' { if ($script:DesignId -like 'minimal-*') { $script:DesignId } else { 'minimal-light' } }
        default { $id }
    }
}

# ---------- canonical color tokens (the colors every page is originally built with) ----------
$script:CanonMap = @{}
function Add-Canon($col, $tok) { $script:CanonMap[$col.ToArgb()] = $tok }
Add-Canon (C 10 17 27) 'Bg'; Add-Canon (C 16 26 40) 'Card'; Add-Canon (C 8 13 21) 'Input'; Add-Canon (C 45 48 58) 'Input'
Add-Canon ([System.Drawing.Color]::White) 'Text'; Add-Canon (C 225 225 230) 'Text'
Add-Canon ([System.Drawing.Color]::Silver) 'Muted'; Add-Canon ([System.Drawing.Color]::Gray) 'Muted'
Add-Canon ([System.Drawing.Color]::Gainsboro) 'NavText'; Add-Canon ([System.Drawing.Color]::LightGray) 'LogText'; Add-Canon ($script:D.Good) 'Good'
Add-Canon (C 0 214 240) 'Accent'; Add-Canon (C 0 190 215) 'Accent'; Add-Canon (C 60 66 80) 'Btn2'; Add-Canon (C 0 120 190) 'Info'
Add-Canon (C 160 50 50) 'Danger'; Add-Canon (C 150 55 55) 'Danger'; Add-Canon (C 176 100 30) 'Warn'; Add-Canon (C 190 90 0) 'Warn'
Add-Canon (C 40 60 80) 'Border'; Add-Canon (C 30 50 72) 'Border'; Add-Canon (C 6 14 22) 'OnAccent'; Add-Canon (C 150 190 220) 'Caption'

# per-control state (original colors/fonts, hover, role); weak table so disposed controls are freed
$script:Orig = New-Object 'System.Runtime.CompilerServices.ConditionalWeakTable[System.Windows.Forms.Control,System.Collections.Hashtable]'
$bfNP = [Reflection.BindingFlags]'Instance,NonPublic'
$script:MiShB = [System.Windows.Forms.Control].GetMethod('ShouldSerializeBackColor', $bfNP)
$script:MiShF = [System.Windows.Forms.Control].GetMethod('ShouldSerializeForeColor', $bfNP)
$script:MiShFn = [System.Windows.Forms.Control].GetMethod('ShouldSerializeFont', $bfNP)
function Get-St($c) { $v = $null; if (-not $script:Orig.TryGetValue($c, [ref]$v)) { $v = @{}; $script:Orig.Add($c, $v) }; $v }
function Test-Explicit($ctrl, $mi) { if (-not $mi) { return $true }; try { [bool]$mi.Invoke($ctrl, $null) } catch { $true } }
function Capture-Orig($ctrl) {
    $st = Get-St $ctrl
    if (-not $st.Cap) {
        $st.Cap = $true
        $st.B = if (Test-Explicit $ctrl $script:MiShB) { $ctrl.BackColor } else { $null }
        $st.F = if (Test-Explicit $ctrl $script:MiShF) { $ctrl.ForeColor } else { $null }
        $st.Fn = if (Test-Explicit $ctrl $script:MiShFn) { $ctrl.Font } else { $null }
    }
    foreach ($c in @($ctrl.Controls)) { Capture-Orig $c }
}
function Map-Col($col) {
    if ($null -eq $col) { return $null }
    $tok = $script:CanonMap[$col.ToArgb()]
    if ($tok -and $script:D.ContainsKey($tok) -and $null -ne $script:D[$tok]) { return $script:D[$tok] }
    $col
}
function Map-Font($f, [bool]$isLabel) {
    $fam = $f.FontFamily.Name; $sz = $f.SizeInPoints; $stl = $f.Style
    if ($fam -eq 'Consolas') { return Get-PtFont $script:D.Mono $sz $stl }
    if ($fam -like 'Segoe UI*') {
        if ($isLabel -and $sz -ge 15) { return Get-PtFont $script:D.Head ($sz * $script:D.HeadScale) $script:D.HeadStyle }
        return Get-PtFont $script:D.Font $sz $stl
    }
    $f
}
function Apply-Orig($ctrl) {
    $st = Get-St $ctrl
    if (-not $st.Skip) {
        if ($ctrl -is [System.Windows.Forms.Button]) { Style-Button $ctrl $st }
        else {
            if ($null -ne $st.B) { try { $ctrl.BackColor = Map-Col $st.B } catch {} }
            if ($null -ne $st.F) { try { $ctrl.ForeColor = Map-Col $st.F } catch {} }
        }
        if ($null -ne $st.Fn) { try { $ctrl.Font = Map-Font $st.Fn ($ctrl -is [System.Windows.Forms.Label]) } catch {} }
    }
    foreach ($c in @($ctrl.Controls)) { Apply-Orig $c }
}
function Theme-Subtree($c) { if ($c) { Capture-Orig $c; Apply-Orig $c } }

# ---------- buttons: every button is fully custom-painted per design ----------
function Get-EffBack($c) { while ($c) { if ($c.BackColor.A -eq 255) { return $c.BackColor }; $c = $c.Parent }; $script:D.Bg }
function Set-BtnIcon($b, $key) { if ($b) { (Get-St $b).Icon = $key; $b.Image = $null; $b.Invalidate() } }
function Style-Button($b, $st) {
    if (-not $st.Role) {
        $tok = if ($null -ne $st.B) { $script:CanonMap[$st.B.ToArgb()] } else { $null }
        $st.Role = switch ($tok) { 'Accent' { 'primary' } 'Info' { 'info' } 'Danger' { 'danger' } 'Warn' { 'warn' } 'Card' { 'tile' } 'Input' { 'field' } default { 'secondary' } }
    }
    if (-not $st.Hooked) {
        $st.Hooked = $true
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0; $b.Cursor = 'Hand'
        Set-DB $b
        $b.Add_Paint({ param($s, $e) Paint-Button $s $e })
        $b.Add_MouseEnter({ param($s, $e) (Get-St $s).H = $true; $s.Invalidate() })
        $b.Add_MouseLeave({ param($s, $e) $t = Get-St $s; $t.H = $false; $t.P = $false; $s.Invalidate() })
        $b.Add_MouseDown({ param($s, $e) (Get-St $s).P = $true; $s.Invalidate() })
        $b.Add_MouseUp({ param($s, $e) (Get-St $s).P = $false; $s.Invalidate() })
        $b.Add_EnabledChanged({ param($s, $e) $s.Invalidate() })
    }
    try { $b.BackColor = Get-EffBack $b.Parent } catch {}
    $b.Invalidate()
}
function Paint-Button($s, $e) {
    $D = $script:D; $st = Get-St $s; $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    $pb = Get-EffBack $s.Parent
    $g.Clear($pb)
    $w = $s.Width; $h = $s.Height
    $role = $st.Role; $strong = $role -in @('primary', 'info', 'danger', 'warn')
    $rc = switch ($role) { 'info' { $D.Info } 'danger' { $D.Danger } 'warn' { $D.Warn } default { $D.Accent } }
    $style = $D.BtnStyle; $line = $null
    if ($strong) {
        if ($style -eq 'outline') { $fill = Mix-Color $D.Card $rc 0.08; $fg = $rc; $line = $rc }
        elseif ($style -eq 'strip') { $fill = $D.Btn2; $fg = $D.Text; $line = $D.BtnLine }
        else { $fill = $rc; $fg = if ($role -eq 'primary') { $D.OnAccent } else { Get-OnColor $rc } }
    } elseif ($role -eq 'tile') { $fill = $D.Card; $fg = $D.Text; $line = $D.Border }
    elseif ($role -eq 'field') { $fill = $D.Input; $fg = $D.Text; $line = $D.Border }
    else { $fill = $D.Btn2; $fg = $D.Btn2Text; $line = $D.BtnLine }
    if (-not $s.Enabled) { $fill = Mix-Color $fill $pb 0.5; $fg = Mix-Color $fg $pb 0.55; if ($line) { $line = Mix-Color $line $pb 0.5 } }
    elseif ($st.P) { $fill = Mix-Color $fill $fg 0.22 }
    elseif ($st.H) { $fill = Mix-Color $fill $fg 0.12; if ($line -and -not $strong) { $line = $D.Accent } }
    $shape = $D.BtnShape; $rad = $D.BtnRadius
    if ($shape -eq 'pill' -and $h -gt 50) { $shape = 'round'; $rad = 14 }
    $path = New-ShapePath 0.5 0.5 ($w - 1.5) ($h - 1.5) $shape $rad
    $fb = New-Object System.Drawing.SolidBrush $fill; $g.FillPath($fb, $path); $fb.Dispose()
    if ($line) { $lp = New-Object System.Drawing.Pen $line, 1; $g.DrawPath($lp, $path); $lp.Dispose() }
    $path.Dispose()
    $strip = 0
    if ($style -eq 'strip') {
        $strip = 4
        $sc = if ($strong) { $rc } elseif ($role -eq 'tile') { $D.Accent } else { $D.Muted }
        if (-not $s.Enabled) { $sc = Mix-Color $sc $pb 0.5 }
        Fill-Shape $g $sc ($w - 4) 0 4 $h
    }
    if ($D.CardStyle -eq 'hud' -and $strong -and $s.Enabled -and $style -eq 'fill') {
        Draw-Line $g (With-Alpha ([System.Drawing.Color]::White) 70) 1 10 1.5 ($w - 12) 1.5
    }
    # content (icon at the right = start of the Arabic line)
    $pad = 12; $right = $w - $pad - $strip; $left = $pad
    if ($st.Icon) {
        $isz = [math]::Min(30, [int]($h * 0.48))
        $icol = if ($role -eq 'tile' -or $style -eq 'strip') { $D.Accent } else { $fg }
        Draw-Glyph $g $st.Icon ($right - $isz) (($h - $isz) / 2) $isz $isz $icol ($isz * 0.72)
        $right -= ($isz + 10)
    }
    $lines = @($s.Text -split "`r?`n" | Where-Object { $_ -ne '' })
    if (-not $lines.Count) { return }
    $al = [string]$s.TextAlign
    $hf = if ($al -like '*Right') { 'Right' } elseif ($al -like '*Left') { 'Left' } else { 'HorizontalCenter' }
    if ($st.Icon -and $hf -eq 'HorizontalCenter' -and ($right - $left) -gt 60) { $hf = 'HorizontalCenter' }
    $flags = [System.Windows.Forms.TextFormatFlags]"RightToLeft, $hf, VerticalCenter, SingleLine, EndEllipsis"
    $tw = [math]::Max(10, $right - $left)
    if ($lines.Count -ge 2) {
        $f1 = Get-PtFont $s.Font.FontFamily.Name $s.Font.SizeInPoints 'Bold'
        $f2 = Get-PtFont $s.Font.FontFamily.Name ([math]::Max(7.5, $s.Font.SizeInPoints * 0.8)) 'Regular'
        $h1 = $f1.Height; $h2 = $f2.Height; $top = [int](($h - $h1 - $h2 - 2) / 2)
        $sub = if ($role -eq 'tile') { $D.Muted } else { Mix-Color $fg $fill 0.3 }
        [System.Windows.Forms.TextRenderer]::DrawText($g, $lines[0], $f1, (New-Object System.Drawing.Rectangle ([int]$left), $top, ([int]$tw), $h1), $fg, $flags)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $lines[1], $f2, (New-Object System.Drawing.Rectangle ([int]$left), ($top + $h1 + 2), ([int]$tw), $h2), $sub, $flags)
    } else {
        [System.Windows.Forms.TextRenderer]::DrawText($g, $lines[0], $s.Font, (New-Object System.Drawing.Rectangle ([int]$left), 0, ([int]$tw), $h), $fg, $flags)
    }
}

# ---------- cards ----------
function Draw-Card($g, [double]$x, [double]$y, [double]$w, [double]$h, $P = $null) {
    if (-not $P) { $P = $script:D }
    switch ($P.CardStyle) {
        'hud' {
            $path = New-ShapePath $x $y $w $h 'chamfer' $P.Radius
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF $x $y $w $h), $P.CardTop, $P.CardBot, ([single]90)
            $g.FillPath($br, $path); $br.Dispose()
            $pen = New-Object System.Drawing.Pen $P.Border, 1; $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
            $L = [math]::Min(16, [math]::Min($w, $h) / 4)
            Draw-Line $g $P.Accent 2 ($x + 1) ($y + 1) ($x + 1 + $L) ($y + 1); Draw-Line $g $P.Accent 2 ($x + 1) ($y + 1) ($x + 1) ($y + 1 + $L)
            Draw-Line $g $P.Accent 2 ($x + $w - 1) ($y + $h - 1) ($x + $w - 1 - $L) ($y + $h - 1); Draw-Line $g $P.Accent 2 ($x + $w - 1) ($y + $h - 1) ($x + $w - 1) ($y + $h - 1 - $L)
        }
        'lux' {
            Fill-Shape $g $P.Card $x $y $w $h
            Stroke-Shape $g $P.Border 1 $x $y $w $h
            if ($w -gt 20 -and $h -gt 20) { Stroke-Shape $g (With-Alpha $P.Accent 46) 1 ($x + 4) ($y + 4) ($w - 8) ($h - 8) }
        }
        'fluent' { Fill-Shape $g $P.Card $x $y $w $h 'round' $P.Radius; Stroke-Shape $g $P.Border 1 $x $y $w $h 'round' $P.Radius }
        'panel' { Fill-Shape $g $P.Card $x $y $w $h; Stroke-Shape $g $P.Border 1 $x $y $w $h }
        default { Fill-Shape $g $P.Card $x $y $w $h 'round' $P.Radius; if (-not $P.Dark) { Stroke-Shape $g $P.Border 1 $x $y $w $h 'round' $P.Radius } }
    }
}
function Paint-SurfacePanel($s, $e) {
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $g.Clear((Get-EffBack $s.Parent))
    Draw-Card $g 1 1 ($s.Width - 3) ($s.Height - 3)
    if ($script:D.CardStyle -eq 'panel') { Fill-Shape $g $script:D.Accent ($s.Width - 5) 1 3 ($s.Height - 3) }
}
function Hook-CardPanel($p) {
    if (-not $p) { return }
    $st = Get-St $p
    if (-not $st.CardHooked) { $st.CardHooked = $true; Set-DB $p; $p.Add_Paint({ param($s, $e) Paint-SurfacePanel $s $e }); $p.Add_Resize({ param($s, $e) $s.Invalidate() }) }
    try { $p.BackColor = Get-EffBack $p.Parent } catch {}
    Style-CardChildren $p
    $p.Invalidate()
}
function Style-CardChildren($p) {
    foreach ($c in @($p.Controls)) {
        if ($c -is [System.Windows.Forms.Button] -or $c.GetType().Name -eq 'ElementHost') { continue }
        if ($c -is [System.Windows.Forms.Label] -or $c -is [System.Windows.Forms.CheckBox] -or $c -is [System.Windows.Forms.PictureBox] -or $c.GetType() -eq [System.Windows.Forms.Panel]) {
            try { $c.BackColor = [System.Drawing.Color]::Transparent } catch {}
            if ($c.GetType() -eq [System.Windows.Forms.Panel]) { Style-CardChildren $c }
        } else { try { $c.BackColor = $script:D.Card } catch {} }
    }
}
function Paint-RowCard($s, $e) {
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $g.Clear((Get-EffBack $s.Parent))
    Draw-Card $g 0.5 0.5 ($s.Width - 1.5) ($s.Height - 1.5)
    if ($script:D.CardStyle -in @('panel', 'lux')) { Fill-Shape $g $script:D.Accent ($s.Width - 4) 1 3 ($s.Height - 2) }
}
function Style-ListRows($flow) {
    foreach ($row in @($flow.Controls)) {
        $st = Get-St $row
        if (-not $st.RowHooked) { $st.RowHooked = $true; Set-DB $row; $row.Add_Paint({ param($s, $e) Paint-RowCard $s $e }) }
        $row.BackColor = $script:D.Bg
        $row.Padding = New-Object System.Windows.Forms.Padding(2, 2, 6, 2)
        foreach ($c in @($row.Controls)) {
            if ($c -is [System.Windows.Forms.Button]) { continue }
            try { $c.BackColor = [System.Drawing.Color]::Transparent } catch {}
            foreach ($cc in @($c.Controls)) { if ($cc -isnot [System.Windows.Forms.Button]) { try { $cc.BackColor = [System.Drawing.Color]::Transparent } catch {} } }
        }
        $row.Invalidate()
    }
}

# ---------- toggle switches (startup apps / night light) ----------
function Get-ToggleBitmap($on) {
    $D = $script:D
    $w = 64; $h = 28
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
    $shape = switch ($D.BtnShape) { 'chamfer' { 'chamfer' } 'square' { 'square' } default { 'pill' } }
    $tr = if ($on) { $D.Accent } else { $D.Track }
    Fill-Shape $g $tr 6 3 ($w - 12) ($h - 6) $shape 7
    if (-not $on) { Stroke-Shape $g $D.Border 1 6 3 ($w - 12) ($h - 6) $shape 7 }
    $kd = $h - 12; $ky = 6; $kx = if ($on) { $w - 12 - $kd } else { 12 }
    $kc = if ($on) { Get-OnColor $tr } else { $D.Muted }
    if ($shape -eq 'pill') { $gb = New-Object System.Drawing.SolidBrush $kc; $g.FillEllipse($gb, [single]$kx, [single]$ky, [single]$kd, [single]$kd); $gb.Dispose() }
    else { Fill-Shape $g $kc $kx $ky $kd $kd }
    $g.Dispose()
    $bmp
}

# ---------- gauges (five different painters) ----------
function Get-Level($st) {
    $D = $script:D; $pct = [math]::Min(100, [math]::Max(0, [int]$st.Pct))
    if ($null -ne $st.Temp) { $lv = [double]$st.Temp; $hi = 85; $mid = 70 } else { $lv = $pct; $hi = 90; $mid = 75 }
    if ($lv -ge $hi) { @{ C = $D.Danger; T = 'حرج'; P = $pct } } elseif ($lv -ge $mid) { @{ C = $D.Warn; T = 'مرتفع'; P = $pct } } else { @{ C = $D.Accent; T = 'طبيعي'; P = $pct } }
}
function Get-KindCode($k) { switch ($k) { 'cpu' { 'CPU' } 'ram' { 'RAM' } 'gpu' { 'GPU' } default { 'DISK' } } }
function Get-GaugeValue($st) { if ($null -ne $st.Temp) { '{0:N0}°' -f $st.Temp } else { '{0}%' -f ([math]::Min(100, [math]::Max(0, [int]$st.Pct))) } }
function Get-GaugeSub($st) { if ($null -ne $st.Temp) { 'الحرارة' } else { 'الاستخدام' } }
$script:Hist = @{}
function Record-History($rows) {
    foreach ($r in $rows) {
        $k = [string]$r.Name
        if (-not $script:Hist.ContainsKey($k)) { $script:Hist[$k] = New-Object 'System.Collections.Generic.List[double]' }
        $v = if ($null -ne $r.Temp -and [int]$r.Pct -eq 0) { [double]$r.Temp } else { [double]$r.Pct }
        $l = $script:Hist[$k]; $l.Add($v); if ($l.Count -gt 60) { $l.RemoveAt(0) }
    }
}
$script:StatusText = 'CPU --   RAM --'
function Update-StatusLine($rows) {
    $parts = New-Object System.Collections.ArrayList
    $cpu = $rows | Where-Object { $_.Kind -eq 'cpu' } | Select-Object -First 1
    $ram = $rows | Where-Object { $_.Kind -eq 'ram' } | Select-Object -First 1
    $gpu = $rows | Where-Object { $_.Kind -eq 'gpu' } | Select-Object -First 1
    if ($cpu) { [void]$parts.Add(('CPU {0,3}%' -f [int]$cpu.Pct) + $(if ($null -ne $cpu.Temp) { '  {0:N0}°C' -f $cpu.Temp } else { '' })) }
    if ($ram) { [void]$parts.Add(('RAM {0,3}%  {1}' -f [int]$ram.Pct, $ram.Usage)) }
    if ($gpu) { [void]$parts.Add(('GPU {0,3}%' -f [int]$gpu.Pct) + $(if ($null -ne $gpu.Temp) { '  {0:N0}°C' -f $gpu.Temp } else { '' })) }
    $dt = @($rows | Where-Object { $_.Kind -eq 'disk' -and $null -ne $_.Temp } | ForEach-Object { [double]$_.Temp })
    if ($dt.Count) { [void]$parts.Add(('DISK max {0:N0}°C' -f ($dt | Measure-Object -Maximum).Maximum)) }
    $script:StatusText = ($parts -join '    |    ')
}

function Paint-GaugeArc($g, $st, $w, $h) {
    $D = $script:D; $lv = Get-Level $st
    Draw-Card $g 3 3 ($w - 6) ($h - 6)
    $cx = $w / 2; $cy = 98; $r = 62
    $rect = New-RectF ($cx - $r) ($cy - $r) (2 * $r) (2 * $r)
    $dp = New-Object System.Drawing.Pen (With-Alpha $D.Tick 140), 1; $dp.DashStyle = 'Dot'
    $g.DrawEllipse($dp, [single]($cx - $r - 13), [single]($cy - $r - 13), [single](2 * $r + 26), [single](2 * $r + 26)); $dp.Dispose()
    $n = 30; $lit = [math]::Round($lv.P * $n / 100)
    $pT = New-Object System.Drawing.Pen $D.Track, 9; $pL = New-Object System.Drawing.Pen $lv.C, 9; $pG = New-Object System.Drawing.Pen (With-Alpha $lv.C 55), 16
    for ($i = 0; $i -lt $n; $i++) {
        $a = [single](135 + $i * 9)
        if ($i -lt $lit) { $g.DrawArc($pG, $rect, $a, [single]7); $g.DrawArc($pL, $rect, $a, [single]7) } else { $g.DrawArc($pT, $rect, $a, [single]7) }
    }
    $pT.Dispose(); $pL.Dispose(); $pG.Dispose()
    $ip = New-Object System.Drawing.Pen (With-Alpha $D.Border 220), 1; $g.DrawEllipse($ip, [single]($cx - 48), [single]($cy - 48), [single]96, [single]96); $ip.Dispose()
    Draw-Text $g (Get-GaugeValue $st) (Get-PxFont $D.Num 30 'Bold') $D.Text ($cx - 60) ($cy - 24) 120 38 'Center' $false
    Draw-Text $g (Get-GaugeSub $st) (Get-PxFont $D.Font 11) $D.Muted ($cx - 60) ($cy + 12) 120 18 'Center' $true
    $db = New-Object System.Drawing.SolidBrush $lv.C; $g.FillEllipse($db, [single]14, [single]15, [single]7, [single]7); $db.Dispose()
    Draw-Text $g $lv.T (Get-PxFont $D.Font 11 'Bold') $lv.C 24 8 70 20 'Left' $true
    Draw-Text $g (Get-KindCode $st.Kind) (Get-PxFont $D.Num 11 'Bold') (With-Alpha $D.Accent 200) ($w - 80) 8 66 20 'Right' $false
    Draw-Text $g $st.Name (Get-PxFont $D.Font 12.5 'Bold') $D.Text 10 170 ($w - 20) 20 'Center' $true
    Draw-Text $g $st.Usage (Get-PxFont $D.Font 11) $D.Muted 10 192 ($w - 20) 18 'Center' $true
}
function Paint-GaugeRing($g, $st, $w, $h) {
    $D = $script:D; $lv = Get-Level $st
    Draw-Card $g 3 3 ($w - 6) ($h - 6)
    $code = ((Get-KindCode $st.Kind).ToCharArray() -join ' ')
    Draw-Text $g $code (Get-PxFont $D.Num 10) $D.Accent 10 12 ($w - 20) 16 'Center' $false
    $cx = $w / 2; $cy = 102; $r = 54
    for ($i = 0; $i -lt 12; $i++) {
        $a = $i * [math]::PI / 6
        Draw-Line $g $D.Tick 1 ($cx + ($r + 7) * [math]::Cos($a)) ($cy + ($r + 7) * [math]::Sin($a)) ($cx + ($r + 11) * [math]::Cos($a)) ($cy + ($r + 11) * [math]::Sin($a))
    }
    $tp = New-Object System.Drawing.Pen $D.Track, 2; $g.DrawEllipse($tp, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $tp.Dispose()
    if ($lv.P -gt 0) {
        $pp = New-Object System.Drawing.Pen $lv.C, 3; $pp.StartCap = 'Round'; $pp.EndCap = 'Round'
        $g.DrawArc($pp, (New-RectF ($cx - $r) ($cy - $r) (2 * $r) (2 * $r)), [single]-90, [single]($lv.P * 3.6)); $pp.Dispose()
        $ea = (-90 + $lv.P * 3.6) * [math]::PI / 180
        $ex = $cx + $r * [math]::Cos($ea); $ey = $cy + $r * [math]::Sin($ea)
        $hb = New-Object System.Drawing.SolidBrush (With-Alpha $lv.C 60); $g.FillEllipse($hb, [single]($ex - 7), [single]($ey - 7), [single]14, [single]14); $hb.Dispose()
        $eb = New-Object System.Drawing.SolidBrush $lv.C; $g.FillEllipse($eb, [single]($ex - 3.5), [single]($ey - 3.5), [single]7, [single]7); $eb.Dispose()
    }
    Draw-Text $g (Get-GaugeValue $st) (Get-PxFont $D.Num 30) $D.Text ($cx - 54) ($cy - 24) 108 36 'Center' $false
    Draw-Text $g (Get-GaugeSub $st) (Get-PxFont $D.Head 17) $D.Muted ($cx - 54) ($cy + 10) 108 20 'Center' $true
    Draw-Line $g (With-Alpha $D.Accent 170) 1 ($cx - 22) 176 ($cx + 22) 176
    Draw-Text $g $st.Name (Get-PxFont $D.Font 12 'Bold') $D.Text 12 182 ($w - 24) 20 'Center' $true
    Draw-Text $g $st.Usage (Get-PxFont $D.Font 11) $D.Muted 12 203 ($w - 24) 18 'Center' $true
}
function Paint-GaugeBar($g, $st, $w, $h) {
    $D = $script:D; $lv = Get-Level $st
    Draw-Card $g 2 2 ($w - 4) ($h - 4)
    Fill-Shape $g (With-Alpha $D.Accent 34) ($w - 52) 16 36 36 'round' 6
    $ik = if ($st.Kind) { $st.Kind } else { 'disk' }
    Draw-Glyph $g $ik ($w - 52) 16 36 36 $D.Accent 18
    Draw-Text $g $st.Name (Get-PxFont $D.Font 13 'Bold') $D.Text 16 14 ($w - 80) 20 'Right' $true
    Draw-Text $g $st.Usage (Get-PxFont $D.Font 11) $D.Muted 16 34 ($w - 80) 18 'Right' $true
    Draw-Text $g (Get-GaugeValue $st) (Get-PxFont $D.Num 26 'Bold') $D.Text 16 56 130 34 'Left' $false
    $db = New-Object System.Drawing.SolidBrush $lv.C; $g.FillEllipse($db, [single]($w - 24), [single]69, [single]8, [single]8); $db.Dispose()
    Draw-Text $g ($lv.T + '  ·  ' + (Get-GaugeSub $st)) (Get-PxFont $D.Font 11) $D.Muted 150 60 ($w - 180) 26 'Right' $true
    $bw = $w - 32
    Fill-Shape $g $D.Track 16 ($h - 24) $bw 6 'round' 3
    $fw = $bw * $lv.P / 100
    if ($fw -ge 2) { Fill-Shape $g $lv.C (16 + $bw - $fw) ($h - 24) $fw 6 'round' 3 }
}
function Paint-GaugeChart($g, $st, $w, $h) {
    $D = $script:D; $lv = Get-Level $st
    Draw-Card $g 1 1 ($w - 2) ($h - 2)
    $rr = if ($D.CardStyle -eq 'fluent') { 4 } else { 0 }
    if ($rr -eq 0) { Fill-Shape $g $D.CardTop 2 2 ($w - 4) 24 }
    Draw-Line $g $D.Border 1 2 26 ($w - 2) 26
    Draw-Text $g (Get-KindCode $st.Kind) (Get-PxFont $D.Mono 11 'Bold') $D.Accent 10 2 50 24 'Left' $false
    $lb = New-Object System.Drawing.SolidBrush (With-Alpha $lv.C 70); $g.FillEllipse($lb, [single]56, [single]8, [single]12, [single]12); $lb.Dispose()
    $lb2 = New-Object System.Drawing.SolidBrush $lv.C; $g.FillEllipse($lb2, [single]59, [single]11, [single]6, [single]6); $lb2.Dispose()
    Draw-Text $g $lv.T (Get-PxFont $D.Font 10.5) $lv.C 72 2 60 24 'Left' $true
    Draw-Text $g $st.Name (Get-PxFont $D.Font 11) $D.Text 134 2 ($w - 144) 24 'Right' $true
    $isTemp = ($null -ne $st.Temp)
    Draw-Text $g (Get-GaugeValue $st) (Get-PxFont $D.Mono 26 'Bold') $D.Text 10 32 110 34 'Left' $false
    Draw-Text $g $(if ($isTemp) { 'TEMP  °C' } else { 'LOAD  %' }) (Get-PxFont $D.Mono 9.5) $D.Muted 10 66 110 14 'Left' $false
    Draw-Text $g $st.Usage (Get-PxFont $D.Font 10.5) $D.Muted 10 84 110 18 'Left' $true
    $hist = $null; if ($st.Key -and $script:Hist.ContainsKey($st.Key)) { $hist = $script:Hist[$st.Key] }
    if ($hist -and $hist.Count) {
        $mn = ($hist | Measure-Object -Minimum).Minimum; $mx = ($hist | Measure-Object -Maximum).Maximum
        Draw-Text $g ('MIN {0:N0}  MAX {1:N0}' -f $mn, $mx) (Get-PxFont $D.Mono 9.5) $D.Muted 10 ($h - 26) 112 16 'Left' $false
    }
    $cx = 126; $cy = 34; $cw = $w - 136; $ch = $h - 46
    Fill-Shape $g $D.Input $cx $cy $cw $ch $(if ($rr) { 'round' } else { 'square' }) $rr
    for ($i = 1; $i -le 3; $i++) { $gp = New-Object System.Drawing.Pen $D.Tick, 1; $gp.DashStyle = 'Dash'; $yy = [single]($cy + $ch * $i / 4); $g.DrawLine($gp, [single]$cx, $yy, [single]($cx + $cw), $yy); $gp.Dispose() }
    for ($i = 1; $i -le 5; $i++) { $xx = $cx + $cw * $i / 6; Draw-Line $g (With-Alpha $D.Tick 120) 1 $xx $cy $xx ($cy + $ch) }
    Stroke-Shape $g $D.Border 1 $cx $cy $cw $ch $(if ($rr) { 'round' } else { 'square' }) $rr
    $lc = if ($lv.T -eq 'طبيعي') { $D.Accent2 } else { $lv.C }
    if ($hist -and $hist.Count -ge 2) {
        $n = $hist.Count; $step = $cw / 59.0
        $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -lt $n; $i++) {
            $v = [math]::Min(100, [math]::Max(0, $hist[$i]))
            $pts.Add((New-Object System.Drawing.PointF ([single]($cx + $cw - ($n - 1 - $i) * $step)), ([single]($cy + $ch - 1 - ($v / 100) * ($ch - 2)))))
        }
        $area = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        $area.Add((New-Object System.Drawing.PointF $pts[0].X, ([single]($cy + $ch)))); $area.AddRange($pts); $area.Add((New-Object System.Drawing.PointF $pts[$n - 1].X, ([single]($cy + $ch))))
        $ab = New-Object System.Drawing.SolidBrush (With-Alpha $lc 46); $g.FillPolygon($ab, $area.ToArray()); $ab.Dispose()
        $lp = New-Object System.Drawing.Pen $lc, 1.6; $g.DrawLines($lp, $pts.ToArray()); $lp.Dispose()
        $last = $pts[$n - 1]; $eb = New-Object System.Drawing.SolidBrush $lc; $g.FillEllipse($eb, [single]($last.X - 3), [single]($last.Y - 3), [single]6, [single]6); $eb.Dispose()
    } else { Draw-Text $g 'جاري جمع البيانات...' (Get-PxFont $D.Font 10.5) $D.Muted $cx $cy $cw $ch 'Center' $true }
    Draw-Text $g '100' (Get-PxFont $D.Mono 8.5) $D.Muted ($cx + 3) ($cy + 1) 30 12 'Left' $false
}
function Paint-GaugeBig($g, $st, $w, $h) {
    $D = $script:D; $lv = Get-Level $st
    Draw-Card $g 1 1 ($w - 2) ($h - 2)
    Draw-Text $g $st.Name (Get-PxFont $D.Font 12) $D.Muted 34 12 ($w - 52) 20 'Right' $true
    $db = New-Object System.Drawing.SolidBrush $lv.C; $g.FillEllipse($db, [single]18, [single]19, [single]7, [single]7); $db.Dispose()
    Draw-Text $g (Get-GaugeValue $st) (Get-PxFont $D.Num 46) $D.Text 18 32 ($w - 36) 58 'Right' $false
    Draw-Text $g $st.Usage (Get-PxFont $D.Font 11) $D.Muted 18 92 ($w - 36) 18 'Right' $true
    $bw = $w - 36
    Fill-Shape $g $D.Track 18 ($h - 20) $bw 2
    $fw = $bw * $lv.P / 100
    if ($fw -ge 1) { Fill-Shape $g $lv.C (18 + $bw - $fw) ($h - 20) $fw 2 }
}
function Paint-Gauge($s, $e) {
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($script:D.Bg)
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk; $st = $s.Tag
    try {
        switch ($script:D.Gauge) {
            'ring' { Paint-GaugeRing $g $st $w $h }
            'bar' { Paint-GaugeBar $g $st $w $h }
            'chart' { Paint-GaugeChart $g $st $w $h }
            'big' { Paint-GaugeBig $g $st $w $h }
            default { Paint-GaugeArc $g $st $w $h }
        }
    } catch {}
}
function New-Gauge {
    $p = New-Object System.Windows.Forms.Panel
    $sz = $script:D.GaugeSize
    $p.Width = Dpx $sz[0]; $p.Height = Dpx $sz[1]; $p.Margin = New-Object System.Windows.Forms.Padding((Dpx 5))
    $p.BackColor = $script:D.Bg
    Set-DB $p
    $p.Tag = @{ Pct = 0; Temp = $null; Name = ''; Usage = ''; Kind = $null; Key = '' }
    $p.Cursor = 'Hand'
    (Get-St $p).Skip = $true
    $p.Add_Paint({ param($s, $e) Paint-Gauge $s $e })
    $p.Add_MouseUp({ param($s, $e) if ($e.Button -eq 'Right') { Show-GaugeMenu $s } })
    $p
}
function Restyle-Gauges {
    $sz = $script:D.GaugeSize
    $gFlow.BackColor = $script:D.Bg
    foreach ($c in $script:GaugeList) { $c.Size = New-Object System.Drawing.Size((Dpx $sz[0]), (Dpx $sz[1])); $c.BackColor = $script:D.Bg; $c.Invalidate() }
    Center-Gauges
}
function Restyle-Monitor {
    $D = $script:D
    if ($script:MonTopRow) {
        $script:MonTopRow.Height = Dpx $D.MonH
        $script:MonTopRow.Padding = New-Object System.Windows.Forms.Padding((Dpx 12), (Dpx 10), (Dpx 12), (Dpx 10))
        $script:MonTopRow.BackColor = $D.Bg
        $script:MonTopRow.Invalidate()
    }
    if ($script:MonSummary) {
        $script:MonSummary.BackColor = [System.Drawing.Color]::Transparent; $script:MonSummary.ForeColor = $D.Text
        $script:MonSummary.Font = if ($D.Gauge -eq 'chart') { Get-PtFont $D.Font 10 } else { Get-PtFont $D.Font 11 }
    }
    if ($script:Chip3DBg) {
        try {
            $c1 = [System.Windows.Media.Color]::FromRgb($D.Glow3D[0].R, $D.Glow3D[0].G, $D.Glow3D[0].B)
            $c2 = [System.Windows.Media.Color]::FromRgb($D.Glow3D[1].R, $D.Glow3D[1].G, $D.Glow3D[1].B)
            $script:Chip3DBg.Background = New-Object System.Windows.Media.RadialGradientBrush $c1, $c2
            $script:ChipBrush.Color = [System.Windows.Media.Color]::FromRgb($D.Accent.R, $D.Accent.G, $D.Accent.B)
        } catch {}
    }
    if ($script:ChipHost) { $script:ChipHost.BackColor = $D.Card }
}

# ---------- application shell (header, navigation, page header, status bar) ----------
$tabs.Appearance = 'FlatButtons'; $tabs.ItemSize = New-Object System.Drawing.Size(0, 1); $tabs.SizeMode = 'Fixed'
$tabs.Padding = New-Object System.Drawing.Point(0, 0)
$form.Controls.Remove($tabs)

$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'; $content.BackColor = $form.BackColor
$tabs.Dock = 'None'
$tabHost = New-Object System.Windows.Forms.Panel
$tabHost.Dock = 'Fill'; $tabHost.BackColor = $form.BackColor
$tabHost.Controls.Add($tabs)
$tabHost.Add_Resize({ $tabs.SetBounds(-4, -5, $tabHost.Width + 8, $tabHost.Height + 9) })

function New-ShellPanel { $p = New-Object System.Windows.Forms.Panel; Set-DB $p; (Get-St $p).Skip = $true; $p.Add_Resize({ param($s, $e) $s.Invalidate() }); $p }
$script:Header = New-ShellPanel; $script:Header.Dock = 'Top'
$script:PageHead = New-ShellPanel; $script:PageHead.Dock = 'Top'
$script:StatusBar = New-ShellPanel; $script:StatusBar.Dock = 'Bottom'
$script:NavPanel = New-ShellPanel
$script:NavBrand = New-ShellPanel; $script:NavBrand.Dock = 'Top'
$script:NavFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$script:NavFlow.Dock = 'Fill'; $script:NavFlow.RightToLeft = 'No'; (Get-St $script:NavFlow).Skip = $true; Set-DB $script:NavFlow
$script:NavPanel.Controls.Add($script:NavFlow); $script:NavPanel.Controls.Add($script:NavBrand)
$script:NavTip = New-Object System.Windows.Forms.ToolTip

function New-IconButton($key, $tip) {
    $p = New-ShellPanel; $p.Dock = 'Left'; $p.Width = Dpx 42; $p.Cursor = 'Hand'; $p.BackColor = [System.Drawing.Color]::Transparent
    $p.Tag = @{ Icon = $key }
    $p.Add_Paint({ param($s, $e) Paint-IconBtn $s $e })
    $p.Add_MouseEnter({ param($s, $e) (Get-St $s).H = $true; $s.Invalidate() })
    $p.Add_MouseLeave({ param($s, $e) (Get-St $s).H = $false; $s.Invalidate() })
    $script:NavTip.SetToolTip($p, $tip)
    $p
}
$script:DesignBtn = New-IconButton 'palette' 'تغيير التصميم (Ctrl+1 … Ctrl+6)'
$script:ModeBtn = New-IconButton 'moon' 'الوضع الفاتح / الداكن'
$script:DesignBtn.Add_Click({ param($s, $e) Show-DesignMenu $s })
$script:ModeBtn.Add_Click({ Apply-Design $(if ($script:DesignId -eq 'minimal-dark') { 'minimal-light' } else { 'minimal-dark' }) $true })

$script:Header.Add_Paint({ param($s, $e) Paint-Header $s $e })
$script:PageHead.Add_Paint({ param($s, $e) Paint-PageHead $s $e })
$script:StatusBar.Add_Paint({ param($s, $e) Paint-StatusBar $s $e })
$script:NavBrand.Add_Paint({ param($s, $e) Paint-NavBrand $s $e })
$script:NavPanel.Add_Paint({ param($s, $e) Paint-NavPanel $s $e })
$script:NavPanel.Add_Resize({ Fit-TopNav })

$script:NavItems = New-Object System.Collections.ArrayList
$navIcons = @{
    'الرئيسية' = 'mon'; 'أدوات التصليح' = 'fix'; 'تويكات ويندوز' = 'tweaks'; 'تطبيقات بدء التشغيل' = 'startup'
    'البرامج الشغالة' = 'procs'; 'الشاشات' = 'display'
    'تحميل من المنصات' = 'yt'; 'تحويل الفيديو' = 'conv'; 'أدوات التنظيف' = 'tools'
    'فحص الجهاز' = 'shield'; 'تحديث ويندوز' = 'update'; 'واجهة مرن' = 'about'
}
$navOrder = @('الرئيسية', 'أدوات التصليح', 'تويكات ويندوز', 'تطبيقات بدء التشغيل', 'البرامج الشغالة', 'الشاشات', 'تحميل من المنصات', 'تحويل الفيديو', 'أدوات التنظيف', 'فحص الجهاز', 'تحديث ويندوز', 'واجهة مرن')
$navSections = @{ 'الرئيسية' = 'النظام والأداء'; 'تحميل من المنصات' = 'الوسائط والصيانة'; 'واجهة مرن' = 'البرنامج' }
function New-NavItem($tag) {
    $p = New-Object System.Windows.Forms.Panel
    Set-DB $p; $p.Tag = $tag; (Get-St $p).Skip = $true
    $p.Add_Paint({ param($s, $e) Paint-NavItem $s $e })
    if (-not $tag.Header) {
        $p.Cursor = 'Hand'
        $p.Add_MouseEnter({ param($s, $e) (Get-St $s).H = $true; $s.Invalidate() })
        $p.Add_MouseLeave({ param($s, $e) (Get-St $s).H = $false; $s.Invalidate() })
        $p.Add_Click({ param($s, $e) $tabs.SelectedTab = $s.Tag.Page })
        $script:NavTip.SetToolTip($p, $tag.Page.Text)
    }
    $script:NavFlow.Controls.Add($p); [void]$script:NavItems.Add($p)
}
$allTabs = @($tabs.TabPages)
foreach ($name in $navOrder) {
    $tp = $allTabs | Where-Object { $_.Text -eq $name } | Select-Object -First 1
    if (-not $tp) { continue }
    if ($navSections.ContainsKey($name)) { New-NavItem @{ Header = $navSections[$name] } }
    New-NavItem @{ Page = $tp; Icon = $navIcons[$name] }
}
foreach ($tp in $allTabs) { if ($navOrder -notcontains $tp.Text) { New-NavItem @{ Page = $tp; Icon = 'about' } } }

function Fit-TopNav {
    if ($script:D.Shell -notin @('toolbar', 'topnav')) { return }
    $nf = $script:NavFlow
    $avail = $script:NavPanel.ClientSize.Width - $nf.Padding.Horizontal - 2
    if ($avail -lt 50) { return }
    $items = @($script:NavItems | Where-Object { $_.Visible })
    if (-not $items.Count) { return }
    $mh = $items[0].Margin.Horizontal
    $maxNat = ($items | ForEach-Object { [int](Get-St $_).NW } | Measure-Object -Maximum).Maximum
    # smallest number of equal rows where every label still fits its cell
    $rows = 1
    while ($rows -lt $items.Count) {
        $per = [math]::Ceiling($items.Count / $rows)
        if ([math]::Floor($avail / $per) - $mh -ge $maxNat) { break }
        $rows++
    }
    $per = [math]::Ceiling($items.Count / $rows)
    $cw = [math]::Max(40, [math]::Floor($avail / $per) - $mh)
    foreach ($n in $items) { if ($n.Width -ne $cw) { $n.Width = $cw } }
    $h = $rows * ($items[0].Height + $items[0].Margin.Vertical) + $nf.Padding.Vertical + 1
    if ($script:NavPanel.Height -ne $h) { $script:NavPanel.Height = $h }
}
# repair-tool tiles fill the page width in 1-3 equal columns (no empty side, no ragged edge)
function Fit-ToolTiles {
    if (-not $flow) { return }
    $avail = $flow.ClientSize.Width - $flow.Padding.Horizontal - 2
    if ($avail -lt 200) { return }
    $m = Dpx 12
    $cols = [math]::Max(1, [math]::Min(3, [math]::Floor($avail / ((Dpx 330) + $m))))
    $w = [int][math]::Floor($avail / $cols) - $m
    foreach ($b in @($flow.Controls)) { if ($b -is [System.Windows.Forms.Button] -and $b.Width -ne $w) { $b.Width = $w } }
}
$flow.Add_Resize({ Fit-ToolTiles })
function Center-Gauges {
    if (-not $gFlow -or $script:D.Id -eq 'canonical') { return }
    $sz = $script:D.GaugeSize; $m = Dpx 5
    $unit = (Dpx $sz[0]) + 2 * $m
    $avail = $gFlow.ClientSize.Width
    if ($avail -lt $unit) { return }
    $per = [math]::Max(1, [math]::Floor(($avail - 2 * (Dpx 12)) / $unit))
    $cnt = [math]::Max(1, $script:GaugeList.Count)
    $per = [math]::Min($per, $cnt)
    $side = [math]::Max((Dpx 12), [int][math]::Floor(($avail - $per * $unit) / 2))
    $pad = New-Object System.Windows.Forms.Padding($side, (Dpx 10), $side, (Dpx 4))
    if ($gFlow.Padding -ne $pad) { $gFlow.Padding = $pad }
}
$gFlow.Add_Resize({ Center-Gauges })

function Build-Shell {
    $D = $script:D; $sh = $D.Shell
    $content.SuspendLayout()
    $hdr = $script:Header; $np = $script:NavPanel; $nf = $script:NavFlow
    $hdr.Visible = ($sh -ne 'pane'); $hdr.Height = [math]::Max(1, (Dpx $D.HeaderH)); $hdr.BackColor = $D.Header
    $hdr.Padding = New-Object System.Windows.Forms.Padding((Dpx 10), 0, 0, 0)
    $script:PageHead.Visible = ($sh -eq 'pane'); $script:PageHead.Height = Dpx 66; $script:PageHead.BackColor = $D.Bg
    $script:PageHead.Padding = New-Object System.Windows.Forms.Padding((Dpx 16), (Dpx 12), 0, (Dpx 10))
    $script:StatusBar.Visible = [bool]$D.StatusBar; $script:StatusBar.Height = Dpx 26; $script:StatusBar.BackColor = $D.Header
    $btnHost = if ($sh -eq 'pane') { $script:PageHead } else { $hdr }
    foreach ($x in @($script:ModeBtn, $script:DesignBtn)) { if ($x.Parent -ne $btnHost) { if ($x.Parent) { $x.Parent.Controls.Remove($x) }; $btnHost.Controls.Add($x) } }
    $script:ModeBtn.Visible = ($script:DesignId -like 'minimal*')
    $script:ModeBtn.Tag.Icon = if ($script:DesignId -eq 'minimal-dark') { 'sun' } else { 'moon' }
    $np.BackColor = $D.Surface; $nf.BackColor = $D.Surface; $script:NavBrand.BackColor = $D.Surface
    if ($sh -in @('rail', 'sidebar', 'pane')) {
        $np.Dock = 'Right'; $np.Width = Dpx $D.NavW
        $np.Padding = New-Object System.Windows.Forms.Padding(1, 0, 0, 0)
        $script:NavBrand.Visible = $true; $script:NavBrand.Height = Dpx $D.BrandH
        $nf.FlowDirection = 'TopDown'; $nf.WrapContents = $false; $nf.AutoScroll = $true
        $nf.Padding = if ($sh -eq 'rail') { New-Object System.Windows.Forms.Padding((Dpx 8), (Dpx 4), (Dpx 8), (Dpx 4)) } else { New-Object System.Windows.Forms.Padding((Dpx 8), (Dpx 4), (Dpx 8), (Dpx 8)) }
    } else {
        $np.Dock = 'Top'; $np.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 1)
        $script:NavBrand.Visible = $false
        $nf.AutoScroll = $false; $nf.FlowDirection = 'RightToLeft'; $nf.WrapContents = $true
        $nf.Padding = if ($sh -eq 'toolbar') { New-Object System.Windows.Forms.Padding((Dpx 6), (Dpx 4), (Dpx 6), (Dpx 4)) } else { New-Object System.Windows.Forms.Padding((Dpx 18), 0, (Dpx 18), 0) }
    }
    $navW = Dpx $D.NavW
    foreach ($n in $script:NavItems) {
        $isHdr = [bool]$n.Tag.Header
        $n.Visible = (-not $isHdr) -or ($sh -eq 'sidebar')
        if ($isHdr -and $sh -ne 'sidebar') { continue }
        switch ($sh) {
            'rail' { $n.Size = New-Object System.Drawing.Size((Dpx 58), (Dpx 46)); $n.Margin = New-Object System.Windows.Forms.Padding(0, (Dpx 2), 0, (Dpx 2)) }
            'sidebar' { $n.Size = New-Object System.Drawing.Size(($navW - (Dpx 18)), $(if ($isHdr) { Dpx 24 } else { Dpx 34 })); $n.Margin = New-Object System.Windows.Forms.Padding(0, (Dpx 1), 0, (Dpx 1)) }
            'pane' { $n.Size = New-Object System.Drawing.Size(($navW - (Dpx 18)), (Dpx 38)); $n.Margin = New-Object System.Windows.Forms.Padding(0, (Dpx 2), 0, (Dpx 2)) }
            'toolbar' {
                $tw = [System.Windows.Forms.TextRenderer]::MeasureText($n.Tag.Page.Text, (Get-PtFont $D.Font 8.5)).Width
                $n.Size = New-Object System.Drawing.Size([math]::Max((Dpx 74), $tw + (Dpx 20)), (Dpx 56)); $n.Margin = New-Object System.Windows.Forms.Padding((Dpx 1)); (Get-St $n).NW = $n.Width
            }
            'topnav' {
                $tw = [System.Windows.Forms.TextRenderer]::MeasureText($n.Tag.Page.Text, (Get-PtFont $D.Font 10 'Bold')).Width
                $n.Size = New-Object System.Drawing.Size(($tw + (Dpx 26)), (Dpx 40)); $n.Margin = New-Object System.Windows.Forms.Padding(0); (Get-St $n).NW = $n.Width
            }
        }
        $n.Invalidate()
    }
    # docking order: highest child index docks first
    $ctl = $content.Controls
    foreach ($x in @($tabHost, $script:StatusBar, $script:PageHead, $hdr, $np)) { if (-not $ctl.Contains($x)) { $ctl.Add($x) } }
    $ctl.SetChildIndex($tabHost, 0); $ctl.SetChildIndex($script:StatusBar, 1); $ctl.SetChildIndex($script:PageHead, 2)
    if ($sh -in @('rail', 'sidebar', 'pane')) { $ctl.SetChildIndex($hdr, 3); $ctl.SetChildIndex($np, 4) } else { $ctl.SetChildIndex($np, 3); $ctl.SetChildIndex($hdr, 4) }
    $content.BackColor = $D.Bg; $tabHost.BackColor = $D.Bg
    $content.ResumeLayout($true)
    Fit-TopNav
    foreach ($x in @($hdr, $np, $script:NavBrand, $script:PageHead, $script:StatusBar, $script:DesignBtn, $script:ModeBtn)) { $x.Invalidate() }
}

function Paint-IconBtn($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $w = $s.Width; $h = $s.Height; $b = [math]::Min($w, $h) - (Dpx 10)
    $x = ($w - $b) / 2; $y = ($h - $b) / 2
    if ((Get-St $s).H) { Fill-Shape $g $D.Hover $x $y $b $b $(if ($D.BtnShape -eq 'chamfer') { 'chamfer' } elseif ($D.BtnShape -eq 'square') { 'square' } else { 'round' }) 6 }
    Draw-Glyph $g $s.Tag.Icon $x $y $b $b $D.Text (16 * $script:S)
}

function Paint-NavPanel($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.Clear($D.Surface)
    if ($D.Shell -in @('rail', 'sidebar', 'pane')) {
        $lc = switch ($D.Shell) { 'rail' { With-Alpha $D.Accent 110 } 'sidebar' { $D.Border } default { $D.Surface } }
        Draw-Line $g $lc 1 0 0 0 $s.Height
    } else { Draw-Line $g $D.Border 1 0 ($s.Height - 1) $s.Width ($s.Height - 1) }
}

function Paint-NavItem($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $g.Clear($D.Surface)
    $t = $s.Tag; $w = $s.Width; $h = $s.Height; $sk = $script:S
    if ($t.Header) {
        $fl = [System.Windows.Forms.TextFormatFlags]'RightToLeft, Right, Bottom, SingleLine'
        [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Header, (Get-PtFont $D.Font 8 'Bold'), (New-Object System.Drawing.Rectangle 0, 0, ($w - (Dpx 10)), ($h - (Dpx 4))), (With-Alpha $D.Caption 255), $fl)
        return
    }
    $sel = ($t.Page -eq $tabs.SelectedTab); $hov = [bool](Get-St $s).H
    $txt = $t.Page.Text
    $fR = [System.Windows.Forms.TextFormatFlags]'RightToLeft, Right, VerticalCenter, SingleLine, EndEllipsis'
    $fC = [System.Windows.Forms.TextFormatFlags]'RightToLeft, HorizontalCenter, VerticalCenter, SingleLine, EndEllipsis'
    switch ($D.Shell) {
        'rail' {
            if ($sel -or $hov) { Fill-Shape $g $(if ($sel) { $D.SelBg } else { $D.Hover }) 3 2 ($w - 6) ($h - 4) 'chamfer' 9 }
            if ($sel) {
                Fill-Shape $g (With-Alpha $D.Accent 60) ($w - 7) ($h * 0.18) 7 ($h * 0.64)
                Fill-Shape $g $D.Accent ($w - 3) ($h * 0.18) 3 ($h * 0.64)
                Draw-Glyph $g $t.Icon 0 0 $w $h (With-Alpha $D.Accent 70) (24 * $sk)
            }
            $ic = if ($sel) { $D.Accent } elseif ($hov) { $D.Text } else { $D.NavText }
            Draw-Glyph $g $t.Icon 0 0 $w $h $ic (20 * $sk)
        }
        'sidebar' {
            if ($sel) {
                $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF 0 0 $w $h), (With-Alpha $D.Accent 0), (With-Alpha $D.Accent 40), ([single]0)
                $g.FillRectangle($lg, 0, 0, $w, $h); $lg.Dispose()
                Fill-Shape $g $D.Accent ($w - 2) 4 2 ($h - 8)
            } elseif ($hov) { Fill-Shape $g $D.Hover 0 0 $w $h }
            $ix = $w - (Dpx 34)
            Draw-Glyph $g $t.Icon $ix 0 (Dpx 22) $h $(if ($sel) { $D.Accent } else { $D.Muted }) (15 * $sk)
            if ($sel) {
                $cy = $h / 2; $dx = Dpx 14
                $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([single]$dx), ([single]($cy - 4))), (New-Object System.Drawing.PointF ([single]($dx + 4)), ([single]$cy)), (New-Object System.Drawing.PointF ([single]$dx), ([single]($cy + 4))), (New-Object System.Drawing.PointF ([single]($dx - 4)), ([single]$cy)))
                $db = New-Object System.Drawing.SolidBrush $D.Accent; $g.FillPolygon($db, $pts); $db.Dispose()
            }
            $tcol = if ($sel) { $D.Accent2 } elseif ($hov) { $D.Text } else { $D.NavText }
            [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, (Get-PtFont $D.Font 10 $(if ($sel) { 'Bold' } else { 'Regular' })), (New-Object System.Drawing.Rectangle (Dpx 24), 0, ($ix - (Dpx 30)), $h), $tcol, $fR)
        }
        'pane' {
            if ($sel -or $hov) { Fill-Shape $g $(if ($sel) { $D.SelBg } else { $D.Hover }) 2 2 ($w - 4) ($h - 4) 'round' 5 }
            if ($sel) { Fill-Shape $g $D.Accent ($w - (Dpx 6)) ($h / 2 - (Dpx 8)) (Dpx 3) (Dpx 16) 'round' 1.5 }
            $ix = $w - (Dpx 42)
            Draw-Glyph $g $t.Icon $ix 0 (Dpx 24) $h $D.Text (16 * $sk)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, (Get-PtFont $D.Font 10), (New-Object System.Drawing.Rectangle (Dpx 6), 0, ($ix - (Dpx 10)), $h), $D.Text, $fR)
        }
        'toolbar' {
            if ($sel) { Fill-Shape $g $D.SelBg 0 0 $w $h; Fill-Shape $g $D.Accent 0 ($h - 3) $w 3 }
            elseif ($hov) { Fill-Shape $g $D.Hover 0 0 $w $h }
            Draw-Line $g $D.Border 1 0 (Dpx 10) 0 ($h - (Dpx 10))
            Draw-Glyph $g $t.Icon 0 (Dpx 6) $w (Dpx 26) $(if ($sel) { $D.Accent } else { $D.NavText }) (18 * $sk)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, (Get-PtFont $D.Font 8.5), (New-Object System.Drawing.Rectangle 2, (Dpx 32), ($w - 4), (Dpx 20)), $(if ($sel) { $D.Text } else { $D.NavText }), $fC)
        }
        default {
            $f = Get-PtFont $D.Font 10 $(if ($sel) { 'Bold' } else { 'Regular' })
            [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, $f, (New-Object System.Drawing.Rectangle 0, 0, $w, ($h - (Dpx 4))), $(if ($sel -or $hov) { $D.Text } else { $D.NavText }), $fC)
            if ($sel) { $tw = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $f).Width - (Dpx 8); Fill-Shape $g $D.Accent (($w - $tw) / 2) ($h - (Dpx 7)) $tw (Dpx 2) }
        }
    }
}

function Paint-NavBrand($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($D.Surface)
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk
    switch ($D.Shell) {
        'rail' {
            $cx = $w / 2
            $gp = New-Object System.Drawing.Pen (With-Alpha $D.Accent 40), 6; $g.DrawEllipse($gp, [single]($cx - 24), [single]12, [single]48, [single]48); $gp.Dispose()
            $rp = New-Object System.Drawing.Pen (With-Alpha $D.Accent 200), 1.5; $g.DrawEllipse($rp, [single]($cx - 24), [single]12, [single]48, [single]48); $rp.Dispose()
            Draw-Logo $g ($cx - 17) 19 34
        }
        'sidebar' {
            Draw-Logo $g (($w - 40) / 2) 12 40
            Draw-Text $g 'واجهة مرن' (Get-PxFont $D.Head 30 'Bold') $D.Text 0 54 $w 32 'Center' $true
            Draw-Text $g 'M U R N    I N T E R F A C E' (Get-PxFont $D.Num 9) $D.Accent 0 86 $w 14 'Center' $false
            $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF 20 106 ($w / 2 - 20) 1), (With-Alpha $D.Accent 0), $D.Accent, ([single]0)
            $g.FillRectangle($lg, [single]20, [single]106, [single]($w / 2 - 20), [single]1); $lg.Dispose()
            $lg2 = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF ($w / 2) 106 ($w / 2 - 20) 1), $D.Accent, (With-Alpha $D.Accent 0), ([single]0)
            $g.FillRectangle($lg2, [single]($w / 2), [single]106, [single]($w / 2 - 20), [single]1); $lg2.Dispose()
        }
        default {
            Draw-Logo $g ($w - 38) 18 20
            Draw-Text $g 'واجهة مرن' (Get-PxFont $D.Font 13) $D.Text 10 14 ($w - 56) 28 'Right' $true
        }
    }
}

function Paint-Header($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($D.Header)
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk
    $page = if ($tabs.SelectedTab) { $tabs.SelectedTab.Text } else { '' }
    $ver = 'v' + $script:AppVersion
    $lx = 110  # left area reserved for the design / mode buttons
    switch ($D.Shell) {
        'rail' {
            $hud = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([single]$w), 0), (New-Object System.Drawing.PointF ([single]($w - 420)), 0), (New-Object System.Drawing.PointF ([single]($w - 452)), ([single]$h)), (New-Object System.Drawing.PointF ([single]$w), ([single]$h)))
            $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF ($w - 460) 0 460 $h), (With-Alpha $D.Accent 0), (With-Alpha $D.Accent 38), ([single]0)
            $g.FillPolygon($lg, $hud); $lg.Dispose()
            Draw-Line $g (With-Alpha $D.Accent 60) 4 0 ($h - 2) $w ($h - 2)
            Draw-Line $g (With-Alpha $D.Accent 210) 1 0 ($h - 1) $w ($h - 1)
            Draw-Text $g $page (Get-PxFont $D.Font 21 'Bold') $D.Text $lx 6 ($w - $lx - 22) 32 'Right' $true
            Draw-Text $g ('MURN  //  INTERFACE   ' + $ver) (Get-PxFont $D.Num 11) $D.Accent $lx 37 ($w - $lx - 22) 16 'Right' $false
            for ($i = 0; $i -lt 6; $i++) { Fill-Shape $g (With-Alpha $D.Accent (40 + $i * 30)) ($lx + $i * 9) ($h / 2 - 2) 5 4 }
        }
        'sidebar' {
            Draw-Text $g $page (Get-PxFont $D.Head 36 'Bold') $D.Text $lx 4 ($w - $lx - 30) 46 'Right' $true
            $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-RectF ($w - 190) 54 160 1), (With-Alpha $D.Accent 0), $D.Accent, ([single]0)
            $g.FillRectangle($lg, [single]($w - 190), [single]54, [single]160, [single]1); $lg.Dispose()
            Draw-Text $g ('MURN INTERFACE   ·   ' + $ver) (Get-PxFont $D.Num 10 'Italic') $D.Caption $lx 58 ($w - $lx - 30) 14 'Right' $false
            Draw-Line $g $D.Border 1 0 ($h - 1) $w ($h - 1)
        }
        'toolbar' {
            Draw-Logo $g ($w - 34) (($h - 22) / 2) 22
            $f1 = Get-PxFont $D.Font 13 'Bold'
            $bw = $g.MeasureString('واجهة مرن', $f1).Width
            Draw-Text $g 'واجهة مرن' $f1 $D.Text ($w - 42 - $bw - 4) 0 ($bw + 4) $h 'Right' $true
            Draw-Text $g ('‹  ' + $page) (Get-PxFont $D.Font 13) $D.Accent ($lx + 120) 0 ($w - 46 - $bw - $lx - 128) $h 'Right' $true
            Draw-Text $g 'MURN  CONTROL  CENTER' (Get-PxFont $D.Mono 11) $D.Muted 0 0 $w $h 'Center' $false
            Draw-Text $g (Get-Date -Format 'HH:mm:ss') (Get-PxFont $D.Mono 13 'Bold') $D.Accent $lx 0 110 $h 'Left' $false
            Draw-Line $g $D.Border 1 0 ($h - 1) $w ($h - 1)
        }
        default {
            Draw-Logo $g ($w - 50) (($h - 26) / 2) 26
            $f1 = Get-PxFont $D.Head 26
            $bw = $g.MeasureString('مرن', $f1).Width
            Draw-Text $g 'مرن' $f1 $D.Text ($w - 60 - $bw - 4) 0 ($bw + 4) $h 'Right' $true
            $db = New-Object System.Drawing.SolidBrush $D.Accent; $g.FillEllipse($db, [single]($w - 66 - $bw - 6), [single]($h / 2 + 6), [single]5, [single]5); $db.Dispose()
            Draw-Text $g $page (Get-PxFont $D.Font 13) $D.Muted $lx 0 ($w - 84 - $bw - $lx) $h 'Right' $true
            Draw-Text $g $ver (Get-PxFont $D.Font 11) $D.Muted $lx 0 80 $h 'Left' $false
        }
    }
}
function Paint-PageHead($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($D.Bg)
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk
    $page = if ($tabs.SelectedTab) { $tabs.SelectedTab.Text } else { '' }
    Draw-Text $g $page (Get-PxFont $D.Head 28) $D.Text 110 8 ($w - 140) 44 'Right' $true
}
function Paint-StatusBar($s, $e) {
    $D = $script:D; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear($D.Header)
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk
    Draw-Line $g $D.Border 1 0 0 $w 0
    Draw-Text $g $script:StatusText (Get-PxFont $D.Mono 11) $D.Text 12 1 ($w - 200) ($h - 1) 'Left' $false
    $db = New-Object System.Drawing.SolidBrush $D.Good; $g.FillEllipse($db, [single]($w - 22), [single]($h / 2 - 3), [single]6, [single]6); $db.Dispose()
    Draw-Text $g ('مراقبة حية   ' + $(Get-Date -Format 'HH:mm')) (Get-PxFont $D.Font 11) $D.Muted ($w - 180) 1 150 ($h - 1) 'Right' $true
}

# ---------- design selector: header menu, About-page gallery, keyboard shortcuts ----------
function Show-DesignMenu($anchor) {
    $cm = New-Object System.Windows.Forms.ContextMenuStrip
    $cm.RightToLeft = 'Yes'; $cm.Font = Get-PtFont 'Segoe UI' 10
    $i = 0
    foreach ($id in $script:DesignOrder) {
        $i++
        $def = $script:Designs[(Resolve-DesignKey $id)]
        $nm = if ($id -eq 'minimal') { 'البسيط — فاتح / داكن' } else { $def.Name }
        $it = New-Object System.Windows.Forms.ToolStripMenuItem ("$nm     ($($def.Sub.Split('·')[0].Trim()))")
        $it.Checked = ($script:DesignId -eq $id) -or ($id -eq 'minimal' -and $script:DesignId -like 'minimal*')
        $it.ShortcutKeyDisplayString = 'Ctrl+' + @{ nexus = 1; royal = 2; fluent = 3; control = 4; minimal = 5; fluentcc = 6 }[$id]
        $it.Tag = $id
        $it.Add_Click({ param($s, $e) Apply-Design ([string]$s.Tag) $true })
        [void]$cm.Items.Add($it)
    }
    $cm.Show($anchor, (New-Object System.Drawing.Point(0, $anchor.Height)))
}
function Paint-DesignCard($s, $e) {
    $D = $script:D; $id = [string]$s.Tag
    $P = $script:Designs[(Resolve-DesignKey $id)]
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear((Get-EffBack $s.Parent))
    $sk = $script:S; if ($sk -ne 1) { $g.ScaleTransform([single]$sk, [single]$sk) }
    $w = $s.Width / $sk; $h = $s.Height / $sk
    $sel = if ($id -eq 'minimal') { $script:DesignId -like 'minimal*' } else { $script:DesignId -eq $id }
    $hov = [bool](Get-St $s).H
    Fill-Shape $g $D.Card 1 1 ($w - 3) ($h - 3) 'round' 8
    Stroke-Shape $g $(if ($sel) { $D.Accent } elseif ($hov) { With-Alpha $D.Accent 140 } else { $D.Border }) $(if ($sel) { 2 } else { 1 }) 1 1 ($w - 3) ($h - 3) 'round' 8
    # mini preview of the layout in the design's own palette
    $px = 9; $py = 9; $pw = $w - 18; $ph = $h - 54
    Fill-Shape $g $P.Bg $px $py $pw $ph 'round' 4
    $ax = $px + 4; $ay = $py + 4; $aw = $pw - 8; $ah = $ph - 8
    switch ($P.Shell) {
        'rail' { Fill-Shape $g $P.Surface ($px + $pw - 13) $py 13 $ph; for ($i = 0; $i -lt 5; $i++) { Fill-Shape $g $(if ($i -eq 0) { $P.Accent } else { $P.NavText }) ($px + $pw - 9) ($py + 8 + $i * 10) 5 5 'chamfer' 2 }; Fill-Shape $g $P.Accent $px ($py + 11) ($pw - 13) 1; $aw -= 13; $ay += 12; $ah -= 12 }
        'sidebar' { Fill-Shape $g $P.Surface ($px + $pw - 34) $py 34 $ph; Fill-Shape $g $P.Accent ($px + $pw - 24) ($py + 4) 14 4; for ($i = 0; $i -lt 5; $i++) { Fill-Shape $g $(if ($i -eq 0) { $P.Accent } else { $P.NavText }) ($px + $pw - 30) ($py + 14 + $i * 8) (18 - $i % 2 * 4) 2 }; $aw -= 34; $ay += 8; $ah -= 8 }
        'pane' { Fill-Shape $g $P.Surface ($px + $pw - 36) $py 36 $ph; Fill-Shape $g $P.SelBg ($px + $pw - 33) ($py + 12) 30 7 'round' 2; Fill-Shape $g $P.Accent ($px + $pw - 5) ($py + 13) 2 5; for ($i = 1; $i -lt 5; $i++) { Fill-Shape $g $P.NavText ($px + $pw - 28) ($py + 14 + $i * 8) 18 2 }; Fill-Shape $g $P.Text ($ax + $aw - 70) $ay 34 5; $aw -= 36; $ay += 10; $ah -= 10 }
        'toolbar' { Fill-Shape $g $P.Header $px $py $pw 6; Fill-Shape $g $P.Surface $px ($py + 6) $pw 12; for ($i = 0; $i -lt 7; $i++) { Fill-Shape $g $(if ($i -eq 0) { $P.Accent } else { $P.NavText }) ($px + $pw - 12 - $i * 15) ($py + 9) 6 6 }; Fill-Shape $g $P.Accent ($px + $pw - 16) ($py + 16) 14 2; Fill-Shape $g $P.Header $px ($py + $ph - 6) $pw 6; $ay += 18; $ah -= 24 }
        default { for ($i = 0; $i -lt 6; $i++) { Fill-Shape $g $P.NavText ($px + $pw - 18 - $i * 18) ($py + 9) 12 2 }; Fill-Shape $g $P.Accent ($px + $pw - 18) ($py + 14) 12 1; Fill-Shape $g $P.Text ($px + $pw - 20) ($py + 3) 14 3; $ay += 14; $ah -= 14 }
    }
    $gw = ($aw - 8) / 3
    for ($i = 0; $i -lt 3; $i++) {
        $gx = $ax + $aw - ($i + 1) * $gw - $i * 4; $gy = $ay + 2; $gh = [math]::Min($ah - 2, 44)
        $pct = @(0.72, 0.45, 0.9)[$i]
        Draw-Card $g $gx $gy $gw $gh $P
        $col = if ($i -eq 2) { $P.Warn } else { $P.Accent }
        switch ($P.Gauge) {
            'arc' { $r = [math]::Min($gw, $gh) / 2 - 6; $cx = $gx + $gw / 2; $cy = $gy + $gh / 2 + 2; $pt = New-Object System.Drawing.Pen $P.Track, 3; $g.DrawArc($pt, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]135, [single]270); $pt.Dispose(); $pa = New-Object System.Drawing.Pen $col, 3; $g.DrawArc($pa, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]135, [single](270 * $pct)); $pa.Dispose() }
            'ring' { $r = [math]::Min($gw, $gh) / 2 - 7; $cx = $gx + $gw / 2; $cy = $gy + $gh / 2; $pt = New-Object System.Drawing.Pen $P.Track, 1; $g.DrawEllipse($pt, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $pt.Dispose(); $pa = New-Object System.Drawing.Pen $col, 2; $g.DrawArc($pa, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]-90, [single](360 * $pct)); $pa.Dispose() }
            'bar' { Fill-Shape $g $P.Text ($gx + 4) ($gy + 6) 12 4; Fill-Shape $g $P.Track ($gx + 4) ($gy + $gh - 9) ($gw - 8) 3 'round' 1.5; Fill-Shape $g $col ($gx + 4 + ($gw - 8) * (1 - $pct)) ($gy + $gh - 9) (($gw - 8) * $pct) 3 'round' 1.5 }
            'chart' { $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'; for ($k = 0; $k -lt 8; $k++) { $pts.Add((New-Object System.Drawing.PointF ([single]($gx + 3 + $k * ($gw - 6) / 7)), ([single]($gy + $gh - 5 - ($gh - 12) * (0.3 + 0.5 * [math]::Abs([math]::Sin($k * 1.3 + $i))))))) }; $lp = New-Object System.Drawing.Pen $(if ($i -eq 2) { $P.Warn } else { $P.Accent2 }), 1.2; $g.DrawLines($lp, $pts.ToArray()); $lp.Dispose(); Fill-Shape $g $P.CardTop ($gx + 1) ($gy + 1) ($gw - 2) 5 }
            default { Draw-Text $g ('{0}' -f [int]($pct * 100)) (Get-PxFont $P.Num 15) $P.Text $gx ($gy + 4) ($gw - 4) 22 'Right' $false; Fill-Shape $g $P.Track ($gx + 4) ($gy + $gh - 6) ($gw - 8) 1; Fill-Shape $g $col ($gx + 4 + ($gw - 8) * (1 - $pct)) ($gy + $gh - 6) (($gw - 8) * $pct) 1 }
        }
    }
    $nm = if ($id -eq 'minimal') { 'البسيط — فاتح / داكن' } else { $P.Name }
    Draw-Text $g $nm (Get-PxFont $D.Font 12 'Bold') $D.Text 8 ($h - 44) ($w - 16) 20 'Right' $true
    Draw-Text $g $P.Sub.Split('·')[0].Trim() (Get-PxFont $D.Font 10.5) $D.Muted 8 ($h - 25) ($w - 16) 16 'Right' $false
    if ($sel) {
        Fill-Shape $g $D.Accent ($w - 30) ($h - 66) 18 18 'round' 9
        Draw-Text $g ([string][char]0x2713) (Get-PxFont 'Segoe UI Symbol' 12 'Bold') $D.OnAccent ($w - 30) ($h - 66) 18 18 'Center' $false
    }
}
function Build-Gallery {
    $abThemeRow.SuspendLayout()
    foreach ($c in @($abThemeRow.Controls)) { $abThemeRow.Controls.Remove($c); $c.Dispose() }
    $abThemeRow.MaximumSize = New-Object System.Drawing.Size((Dpx 680), 0)
    foreach ($id in $script:DesignOrder) {
        $c = New-Object System.Windows.Forms.Panel
        $c.Size = New-Object System.Drawing.Size((Dpx 214), (Dpx 170)); $c.Margin = New-Object System.Windows.Forms.Padding((Dpx 4))
        $c.Cursor = 'Hand'; Set-DB $c; $c.Tag = $id; (Get-St $c).Skip = $true
        $c.Add_Paint({ param($s, $e) Paint-DesignCard $s $e })
        $c.Add_MouseEnter({ param($s, $e) (Get-St $s).H = $true; $s.Invalidate() })
        $c.Add_MouseLeave({ param($s, $e) (Get-St $s).H = $false; $s.Invalidate() })
        $c.Add_Click({ param($s, $e) Apply-Design ([string]$s.Tag) $true })
        $abThemeRow.Controls.Add($c)
    }
    $abThemeRow.ResumeLayout()
}
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and -not $e.Alt -and -not $e.Shift) {
        $map = @{ D1 = 'nexus'; D2 = 'royal'; D3 = 'fluent'; D4 = 'control'; D5 = 'minimal'; D6 = 'fluentcc'; NumPad1 = 'nexus'; NumPad2 = 'royal'; NumPad3 = 'fluent'; NumPad4 = 'control'; NumPad5 = 'minimal'; NumPad6 = 'fluentcc' }
        $k = [string]$e.KeyCode
        if ($map.ContainsKey($k)) { Apply-Design $map[$k] $true; $e.Handled = $true; $e.SuppressKeyPress = $true }
    }
})

# ---------- window chrome (Windows 11 caption colour, corners, border) ----------
try { Add-Type -Namespace Murn -Name Dwm -ErrorAction SilentlyContinue -MemberDefinition '[System.Runtime.InteropServices.DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);' } catch {}
function ColorRef($c) { [int]($c.R -bor ($c.G -shl 8) -bor ($c.B -shl 16)) }
function Set-WindowChrome {
    if (-not $form.IsHandleCreated) { return }
    $D = $script:D
    try {
        $v = [int]$(if ($D.Dark) { 1 } else { 0 }); [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4)
        $v = [int]$D.Corner; [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 33, [ref]$v, 4)
        $v = if ($D.WinBorder) { ColorRef $D.WinBorder } else { -1 }; [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 34, [ref]$v, 4)
        $v = ColorRef $D.Header; [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 35, [ref]$v, 4)
        $v = ColorRef $D.Text; [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 36, [ref]$v, 4)
    } catch {}
}
function Set-Redraw([bool]$on) {
    if (-not $form.IsHandleCreated) { return }
    try { [void][MurnUi]::SendMessage($form.Handle, 0x000B, [IntPtr]$(if ($on) { 1 } else { 0 }), [IntPtr]::Zero) } catch {}
}

# ---------- lists that are rebuilt at runtime get the current design automatically ----------
${function:Update-StartupCore} = ${function:Update-Startup}
function Update-Startup { Update-StartupCore; Theme-Subtree $stFlow; Style-ListRows $stFlow }
${function:Update-RunningProgsCore} = ${function:Update-RunningProgs}
function Update-RunningProgs { Update-RunningProgsCore; Theme-Subtree $rpFlow; Style-ListRows $rpFlow }
${function:Update-DisplaysCore} = ${function:Update-Displays}
function Update-Displays { Update-DisplaysCore; Theme-Subtree $dpFlow; foreach ($c in @($dpFlow.Controls)) { Hook-CardPanel $c } }

# ---------- apply a design ----------
function Update-Nav {
    foreach ($n in $script:NavItems) { $n.Invalidate() }
    $script:Header.Invalidate(); $script:PageHead.Invalidate()
    $script:StatsBox.Active = ($tabs.SelectedTab -eq $tabMon) -or [bool]$script:D.StatusBar
    if ($script:Chip3D) { if ($tabs.SelectedTab -eq $tabMon) { $chipTimer.Start() } else { $chipTimer.Stop() } }
}
$script:DesignApplying = $false
function Apply-Design([string]$id, [bool]$save = $true) {
    if ($script:DesignApplying) { return }
    $script:DesignApplying = $true
    try {
        if ($id -eq 'minimal') { $id = if ($script:DesignId -like 'minimal-*') { $script:DesignId } else { 'minimal-light' } }
        $key = Resolve-DesignKey $id
        if (-not $script:Designs.ContainsKey($key)) { $id = 'nexus'; $key = 'nexus' }
        $script:DesignId = $id
        $D = $script:Designs[$key]; $script:D = $D
        $script:Accent = $D.Accent
        $script:Pal = @{ Bg = $D.Bg; Card = $D.Card; CardTop = $D.CardTop; CardBot = $D.CardBot; CardBorder = $D.Border; Track = $D.Track; Tick = $D.Tick; Input = $D.Input
            TitleBar = $D.Header; Side = $D.Surface; NavHover = $D.Hover; NavActive = $D.SelBg; Text = $D.Text; SubText = $D.Muted; NavText = $D.NavText; LogText = $D.LogText; Good = $D.Good; DarkMode = $D.Dark }
        $script:CardRadius = $D.Radius
        $script:IcoCache = @{}
        Set-Redraw $false
        try {
            $form.SuspendLayout()
            Capture-Orig $form
            Apply-Orig $form
            Build-Shell
            Restyle-Gauges
            Fit-ToolTiles
            Restyle-Monitor
            Hook-CardPanel $ramCard
            if ($script:MonTopRow) { Style-CardChildren $script:MonTopRow }
            if ($script:MonSummary) { $script:MonSummary.BackColor = [System.Drawing.Color]::Transparent }
            if ($script:TweaksLoaded) { Update-TweakStates }
            if ($script:StartupLoaded) { Update-Startup }
            if ($script:RunProgsLoaded) { Update-RunningProgs }
            if ($script:DisplaysLoaded) { Update-Displays }
            foreach ($c in @($abThemeRow.Controls)) { $c.Invalidate() }
            if ($form.IsHandleCreated) { Apply-DarkInputFixups }
            $form.ResumeLayout($true)
        } finally { Set-Redraw $true }
        Set-WindowChrome
        if ($save) { try { [IO.File]::WriteAllText($script:ThemeFile, $id, (New-Object Text.UTF8Encoding($false))) } catch {} }
        Update-Nav
        $form.Refresh()
    } finally { $script:DesignApplying = $false }
}

$tabs.Add_SelectedIndexChanged({ Update-Nav })
$form.Controls.Add($content)
$form.Add_Shown({ Set-WindowChrome; Fit-TopNav })

# ---------- نمط البطاقة لصفحات النماذج (تحميل يوتيوب / تحويل الفيديو) على طريقة مداد ----------
function Wrap-Input($tb) {
    $parent = $tb.Parent; if (-not $parent) { return }
    $idx = $parent.Controls.GetChildIndex($tb)
    $box = New-Object System.Windows.Forms.Panel
    $box.BackColor = $script:Pal.Input; $box.Margin = $tb.Margin
    $box.Dock = $tb.Dock
    $box.Padding = if ($tb.Multiline) { New-Object System.Windows.Forms.Padding(10, 8, 10, 8) } else { New-Object System.Windows.Forms.Padding(10, 6, 10, 2) }
    $box.Size = New-Object System.Drawing.Size ($tb.Width), $(if ($tb.Multiline) { $tb.Height } else { [math]::Max(32, $tb.Height + 8) })
    $box.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen $script:Pal.CardBorder, 1; $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1); $pen.Dispose() })
    $parent.Controls.Remove($tb)
    $tb.BorderStyle = 'None'; $tb.Dock = 'Fill'; $tb.BackColor = $script:Pal.Input; $tb.ForeColor = $script:Pal.Text
    $box.Controls.Add($tb)
    $parent.Controls.Add($box); $parent.Controls.SetChildIndex($box, $idx)
}
function Style-FormPage($tab, $flow) {
    $tab.BackColor = $script:Pal.Bg; $tab.Padding = New-Object System.Windows.Forms.Padding(16, 14, 16, 14)
    $flow.BackColor = $script:Pal.Card; $flow.ForeColor = $script:Pal.Text
    $flow.Padding = New-Object System.Windows.Forms.Padding(26, 16, 26, 16)
    $capFont = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    foreach ($c in @($flow.Controls)) {
        if ($c.Width -eq 740) { $c.Width = 690 }
        if ($c -is [System.Windows.Forms.Label] -and $c.AutoSize -and $c.ForeColor.ToArgb() -eq $flow.ForeColor.ToArgb()) {
            $c.ForeColor = (C 150 190 220); $c.Font = $capFont
        }
        elseif ($c -is [System.Windows.Forms.CheckBox]) { $c.ForeColor = $script:Pal.Text }
        elseif ($c -is [System.Windows.Forms.TextBox]) { Wrap-Input $c }
        elseif ($c -is [System.Windows.Forms.ComboBox]) {
            [void]$script:DarkInputCtrls.Remove($c)
            $c.DrawMode = 'OwnerDrawFixed'; $c.ItemHeight = 24; $c.FlatStyle = 'Flat'
            $c.BackColor = $script:Pal.Input; $c.ForeColor = $script:Pal.Text
            $c.Add_DrawItem({
                param($s, $e)
                if ($e.Index -lt 0) { return }
                $hot = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -and -not ($e.State -band [System.Windows.Forms.DrawItemState]::ComboBoxEdit)
                $bg = if ($hot) { $script:D.SelBg } else { $script:Pal.Input }
                $b = New-Object System.Drawing.SolidBrush $bg; $e.Graphics.FillRectangle($b, $e.Bounds); $b.Dispose()
                $tb = New-Object System.Drawing.SolidBrush $script:Pal.Text
                $f = New-Object System.Drawing.StringFormat; $f.LineAlignment = 'Center'; $f.FormatFlags = 'DirectionRightToLeft'; $f.Alignment = 'Near'
                $r = New-Object System.Drawing.RectangleF ([single]($e.Bounds.X + 6)), ([single]$e.Bounds.Y), ([single]($e.Bounds.Width - 12)), ([single]$e.Bounds.Height)
                $e.Graphics.DrawString([string]$s.Items[$e.Index], $s.Font, $tb, $r, $f); $tb.Dispose(); $f.Dispose()
            })
        }
        elseif ($c -is [System.Windows.Forms.ProgressBar]) {
            foreach ($d in $script:DarkProgressCtrls) { if ($d.Bar -eq $c) { $d.Track = $script:Pal.Track } }
        }
        if ($c -is [System.Windows.Forms.Panel]) {
            $c.BackColor = $flow.BackColor
            foreach ($m in @($c.Controls)) {
                if ($m -is [System.Windows.Forms.TextBox]) { Wrap-Input $m }
                elseif ($m -is [System.Windows.Forms.Button] -and $m.FlatAppearance.BorderSize -ne 0) {
                    $m.BackColor = $script:Pal.Input; $m.ForeColor = $script:Pal.Text; $m.FlatAppearance.BorderColor = $script:Accent
                }
            }
        }
    }
}
Style-FormPage $tabYt $ytFlow
Style-FormPage $tabCv $cvFlow
foreach ($b in $btnDl, $btnCv) { $b.ForeColor = [System.Drawing.Color]::FromArgb(6, 14, 22) }
foreach ($m in $YtStatus, $CvStatus) { $m.ForeColor = $script:Pal.SubText }

# ---------- apply the saved design (skipped for command-line mode) ----------
Build-Gallery
Set-BtnIcon $btnScan 'mrt'; Set-BtnIcon $btnDef 'shield'; Set-BtnIcon $btnSec 'shield'; Set-BtnIcon $btnWuChk 'update'
Set-BtnIcon $btnTlGo 'tools'; Set-BtnIcon $btnRamClean 'ram'; Set-BtnIcon $btnDl 'yt'; Set-BtnIcon $btnCv 'conv'; Set-BtnIcon $abBtnChk 'update'
Set-BtnIcon $btnApply 'tweaks'; Set-BtnIcon $btnMinScan 'cpu'; Set-BtnIcon $btnWuOpen 'update'; Set-BtnIcon $btnTlDisk 'disk'
if (-not $script:CliMode) { Apply-Design $script:DesignId $false }

$BtnClean.Add_Click({ Invoke-Clean })
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-View })
$form.Add_Shown({ Update-View; $timer.Start(); Apply-DarkInputFixups })
$form.Add_FormClosed({
    $script:StatsBox.Stop = $true
    try { $script:BgPs.Stop(); $script:BgRs.Close() } catch {}
    $script:Notify.Visible = $false; $script:Notify.Dispose(); $timer.Stop()
    if ($script:Lhm) { $script:Lhm.Close() }
})

function Test-UpdateAtStartup {
    $base = Get-UpdateBase
    if (-not $base) { return $null }
    try {
        $box = [hashtable]::Synchronized(@{ Done = $false; Json = $null; Err = $null })
        $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
        $rs.SessionStateProxy.SetVariable('Box', $box)
        $rs.SessionStateProxy.SetVariable('Url', ($base + '/version.json?t=' + [DateTime]::UtcNow.Ticks))
        $ps = [powershell]::Create(); $ps.Runspace = $rs
        [void]$ps.AddScript('[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $Box.Json = $wc.DownloadString($Url) } catch { $Box.Err = $_.Exception.Message }; $Box.Done = $true')
        [void]$ps.BeginInvoke()
        $sw0 = [Diagnostics.Stopwatch]::StartNew()
        while (-not $box.Done -and $sw0.Elapsed.TotalSeconds -lt 5) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
        try { $ps.Dispose(); $rs.Close() } catch {}
        if ($box.Json) {
            $j = $box.Json | ConvertFrom-Json
            if ([version]$j.version -gt [version]$script:AppVersion) { return $j }
        }
    } catch {}
    $null
}

# ---------- CLI command execution (no GUI shown) ----------
function Cli-Help {
    @"
Murn Interface - $script:AppVersion
الاستخدام: Murn Interface.exe [أمر] [قيمة]

--help, -h                     عرض هذه المساعدة
--version, -v                  عرض رقم الإصدار
--scan                         عرض حالة الجهاز (معالج/رام/أقراص)
--clean-list                   عرض حجم عناصر التنظيف بدون حذف
--clean [--recycle-bin]        تنظيف الملفات المؤقتة والكاش (يحتاج صلاحيات مدير)
--clean-ram                    تفريغ ذاكرة الرام (يحتاج صلاحيات مدير)
--tweak-list                   عرض كل التويكات وحالتها
--tweak-apply "اسم التويك"      تطبيق تويك (يحتاج صلاحيات مدير)
--tweak-undo "اسم التويك"       التراجع عن تويك (يحتاج صلاحيات مدير)
--startup-list                 عرض برامج بدء التشغيل
--startup-enable "الاسم"        تفعيل برنامج بدء تشغيل (يحتاج صلاحيات مدير)
--startup-disable "الاسم"       تعطيل برنامج بدء تشغيل (يحتاج صلاحيات مدير)
--update-check                 فحص توفر تحديث جديد
--update-install               تنزيل وتثبيت آخر تحديث (يحتاج صلاحيات مدير)
"@ | Write-Host
}

function Invoke-CliCommand {
    $cmd = $script:CliCmd
    $cliRest = @($script:CliArgs | Select-Object -Skip 1)
    switch ($cmd) {
        { $_ -in '--help', '-h', '/?' } { Cli-Help }
        { $_ -in '--version', '-v' } { Write-Host $script:AppVersion }
        '--clean-list' {
            foreach ($t in Get-CleanTargets) { Write-Host ("{0}: {1} MB" -f $t.N, (Get-SizeMB $t.P)) }
        }
        '--clean' {
            Write-Host 'بدأ التنظيف...'
            $total = 0
            Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
            foreach ($t in Get-CleanTargets) {
                $before = Get-SizeMB $t.P
                if (-not $before) { continue }
                Remove-Paths $t.P
                $freed = [math]::Max(0, [math]::Round($before - (Get-SizeMB $t.P), 1))
                $total += $freed
                Write-Host ("  {0}: تم تحرير {1} MB" -f $t.N, $freed)
            }
            Start-Service wuauserv, bits -ErrorAction SilentlyContinue
            if ($cliRest -contains '--recycle-bin') { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host '  تم تفريغ سلة المحذوفات' }
            Write-Host ("انتهى. المساحة المحررة: {0} MB" -f [math]::Round($total, 1))
        }
        '--clean-ram' {
            Write-Host "تم تنظيف الرام ✓  تحرر تقريباً $(Clean-Ram) MB"
        }
        '--scan' {
            Get-Stats | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Name, $_.Usage) + $(if ($_.Temp) { "  ({0}°)" -f $_.Temp } else { '' }) }
        }
        '--tweak-list' {
            foreach ($t in $tweaks) {
                $state = Get-TweakState $t
                $txt = if ($null -eq $state) { '—' } elseif ($state) { 'مطبّق' } else { 'غير مطبّق' }
                Write-Host ("[{0}] {1} - {2}" -f $txt, $t.N, $t.D)
            }
        }
        { $_ -in '--tweak-apply', '--tweak-undo' } {
            $name = $cliRest[0]
            $t = $tweaks | Where-Object { $_.N -eq $name } | Select-Object -First 1
            if (-not $t) { Write-Host "ما لقيت تويك بهذا الاسم: $name" -ForegroundColor Red; exit 1 }
            try { & $(if ($cmd -eq '--tweak-undo') { $t.U } else { $t.A }); Write-Host "تم: $($t.N)" }
            catch { Write-Host "فشل: $($t.N) - $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        }
        '--startup-list' {
            foreach ($x in Get-StartupItems) { Write-Host ("[{0}] {1} ({2})" -f $(if ($x.Enabled) { 'مفعّل' } else { 'معطّل' }), $x.Name, $x.Src) }
        }
        { $_ -in '--startup-enable', '--startup-disable' } {
            $name = $cliRest[0]
            $x = Get-StartupItems | Where-Object { $_.Name -eq $name } | Select-Object -First 1
            if (-not $x) { Write-Host "ما لقيت برنامج بدء تشغيل بهذا الاسم: $name" -ForegroundColor Red; exit 1 }
            $enable = $cmd -eq '--startup-enable'
            try {
                if ($x.Kind -eq 'Task') {
                    if ($enable) { Enable-ScheduledTask -TaskName $x.Task.TaskName -TaskPath $x.Task.TaskPath -ErrorAction Stop | Out-Null }
                    else { Disable-ScheduledTask -TaskName $x.Task.TaskName -TaskPath $x.Task.TaskPath -ErrorAction Stop | Out-Null }
                } else { Set-ApprState $x.Hive $x.Sub $x.Name $enable }
                Write-Host "تم: $name -> $(if ($enable) { 'مفعّل' } else { 'معطّل' })"
            } catch { Write-Host "فشل: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        }
        '--update-check' {
            $base = Get-UpdateBase
            if (-not $base) { Write-Host 'رابط التحديثات غير مضبوط بهذي النسخة' -ForegroundColor Yellow; return }
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
                $j = $wc.DownloadString($base + '/version.json?t=' + [DateTime]::UtcNow.Ticks) | ConvertFrom-Json
                if ([version]$j.version -gt [version]$script:AppVersion) { Write-Host "يوجد إصدار جديد: $($j.version)"; if ($j.notes) { Write-Host $j.notes } }
                else { Write-Host 'عندك آخر إصدار ✓' }
            } catch { Write-Host "ما قدرت أفحص التحديثات: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        }
        '--update-install' {
            try {
                $base = Get-UpdateBase
                if (-not $base) { throw 'رابط التحديثات غير مضبوط بهذي النسخة' }
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
                $j = $wc.DownloadString($base + '/version.json?t=' + [DateTime]::UtcNow.Ticks) | ConvertFrom-Json
                if ([version]$j.version -le [version]$script:AppVersion) { Write-Host 'عندك آخر إصدار ✓'; return }
                $script:UpdInfo = $j
                Write-Host "جاري تنزيل الإصدار $($j.version)..."
                Start-UpdateDownload
                $sw = [Diagnostics.Stopwatch]::StartNew()
                while (-not $script:UpdBox.Done -and $sw.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 200 }
                if ($script:UpdBox.Err) { throw $script:UpdBox.Err }
                Install-Update
                Write-Host 'تم تثبيت التحديث، البرنامج بيعيد التشغيل.'
            } catch { Write-Host "فشل التحديث: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        }
        default { Write-Host "أمر غير معروف: $cmd" -ForegroundColor Red; Cli-Help; exit 1 }
    }
}
if ($script:CliMode) { Invoke-CliCommand; exit }

# ---------- pre-launch update check (shown before the user can use the app) ----------
if (-not $env:MURN_TEST -or $env:MURN_SPLASH) {
    $splash = New-Object System.Windows.Forms.Form
    $splash.FormBorderStyle = 'None'; $splash.StartPosition = 'CenterScreen'
    $splash.Size = New-Object System.Drawing.Size(420, 150)
    $splash.BackColor = [System.Drawing.Color]::FromArgb(10, 17, 27); $splash.TopMost = $true
    if ($form.Icon) { $splash.Icon = $form.Icon }
    $spLine = New-Object System.Windows.Forms.Panel
    $spLine.Dock = 'Top'; $spLine.Height = 3; $spLine.BackColor = $script:Accent
    $splash.Controls.Add($spLine)
    $logoPath2 = Join-Path $script:AppDir 'falcon.png'
    if (Test-Path $logoPath2) {
        $spLogo = New-Object System.Windows.Forms.PictureBox
        $spLogo.Image = [System.Drawing.Image]::FromFile($logoPath2); $spLogo.SizeMode = 'Zoom'
        $spLogo.Size = New-Object System.Drawing.Size(40, 40); $spLogo.Location = New-Object System.Drawing.Point(190, 18)
        $splash.Controls.Add($spLogo)
    }
    $spLbl = New-Object System.Windows.Forms.Label
    $spLbl.Text = 'جاري التحقق من وجود تحديث...'
    $spLbl.ForeColor = [System.Drawing.Color]::Gainsboro
    $spLbl.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $spLbl.TextAlign = 'MiddleCenter'; $spLbl.Dock = 'Bottom'; $spLbl.Height = 90
    $splash.Controls.Add($spLbl)
    $splash.Show(); [System.Windows.Forms.Application]::DoEvents()

    if ($env:MURN_TEST -and $env:MURN_SPLASH) {
        $bmp0 = New-Object System.Drawing.Bitmap $splash.Width, $splash.Height
        $splash.DrawToBitmap($bmp0, (New-Object System.Drawing.Rectangle 0, 0, $splash.Width, $splash.Height))
        $bmp0.Save((Join-Path $env:MURN_TEST 'splash_checking.png')); $bmp0.Dispose()
    }

    $launchUpdate = Test-UpdateAtStartup

    if ($launchUpdate) {
        $spLbl.Text = "يوجد إصدار جديد: $($launchUpdate.version)"
        [System.Windows.Forms.Application]::DoEvents()
        if ($env:MURN_TEST -and $env:MURN_SPLASH) {
            $bmp1 = New-Object System.Drawing.Bitmap $splash.Width, $splash.Height
            $splash.DrawToBitmap($bmp1, (New-Object System.Drawing.Rectangle 0, 0, $splash.Width, $splash.Height))
            $bmp1.Save((Join-Path $env:MURN_TEST 'splash_found.png')); $bmp1.Dispose()
        } else {
            # تحديث تلقائي بدون سؤال المستخدم: يبين له إشعار بوجود تحديث وينزّله مباشرة
            $spLbl.Text = "يوجد تحديث جديد ($($launchUpdate.version)) - جاري التحديث تلقائياً..."
            [System.Windows.Forms.Application]::DoEvents()
            $script:UpdInfo = $launchUpdate
            Start-UpdateDownload
            $dsw = [Diagnostics.Stopwatch]::StartNew()
            while ($dsw.Elapsed.TotalSeconds -lt 60 -and -not $form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
        }
    }
    try { if (-not $splash.IsDisposed) { $splash.Close() } } catch {}
    if ($env:MURN_TEST -and $env:MURN_SPLASH) { exit }
}

if ($env:MURN_TEST) {
    $form.Show(); [System.Windows.Forms.Application]::DoEvents()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $warmup = if ($env:MURN_WARMUP) { [double]$env:MURN_WARMUP } else { 6 }
    while ($sw.Elapsed.TotalSeconds -lt $warmup) { [System.Windows.Forms.Application]::DoEvents(); Update-View; Start-Sleep -Milliseconds 200 }
    $designList = if ($env:MURN_DESIGNS) { @($env:MURN_DESIGNS -split ',') } else { @('') }
    foreach ($dz in $designList) {
        if ($dz) { Apply-Design $dz $false; [System.Windows.Forms.Application]::DoEvents() }
        $i = 0
        foreach ($tp in @($tabs.TabPages)) {
            $tabs.SelectedTab = $tp; Start-Sleep -Milliseconds 350; [System.Windows.Forms.Application]::DoEvents(); Update-View
            $bmp = New-Object System.Drawing.Bitmap $form.Width, $form.Height
            $form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle 0, 0, $form.Width, $form.Height))
            $pfx = if ($dz) { $dz + '_' } else { '' }
            $bmp.Save((Join-Path $env:MURN_TEST ('{0}page{1:D2}.png' -f $pfx, $i))); $bmp.Dispose(); $i++
        }
    }
    if ($env:MURN_HOLD) { $tabs.SelectedTab = $tabYt; while (-not $form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 30 } } else { $form.Close(); exit }
}

if (-not $form.IsDisposed) { [void]$form.ShowDialog() }
