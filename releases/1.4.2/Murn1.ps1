# واجهة مرن - أدوات تصليح + تنظيف مباشر + مراقبة حرارة المعالج / الرام / كرت الشاشة / الهاردسكات
# لقراءة حرارة المعالج (Ryzen) حط الملفين LibreHardwareMonitorLib.dll و HidSharp.dll بنفس المجلد.

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $env:MURN_TEST) {
    Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$script:AppDir = if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE) -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $env:MURN_EXE) 'Murn1.ps1'))) { Split-Path -Parent $env:MURN_EXE } else { $PSScriptRoot }
$script:ThemeMode = 'dark'
$script:AppVersion = '1.4.2'
Add-Type -AssemblyName System.Drawing
function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$script:Accent = (C 0 214 240)   # سماوي مثل مداد
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
$script:Pal = if ($script:ThemeMode -eq 'light') { $script:PalLight } else { $script:PalDark }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# own taskbar identity so the taskbar shows the falcon, not the PowerShell icon
try { Add-Type -Namespace Murn -Name Shell -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern void SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string id);'; [Murn.Shell]::SetCurrentProcessExplicitAppUserModelID('Murn.Waja.App') } catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Installer (first run only) ----------
function Show-InstallWizard {
    $icoPath = Join-Path $script:AppDir 'falcon.ico'
    $wizForm = New-Object System.Windows.Forms.Form
    $wizForm.Text = 'تثبيت واجهة مرن'
    $wizForm.Size = New-Object System.Drawing.Size(480, 300)
    $wizForm.StartPosition = 'CenterScreen'
    $wizForm.FormBorderStyle = 'FixedDialog'
    $wizForm.MaximizeBox = $false; $wizForm.MinimizeBox = $false
    $wizForm.RightToLeft = 'Yes'; $wizForm.RightToLeftLayout = $true
    $wizForm.BackColor = $script:Pal.Bg
    $wizForm.ForeColor = $script:Pal.Text
    if (Test-Path -LiteralPath $icoPath) { try { $wizForm.Icon = New-Object System.Drawing.Icon($icoPath) } catch {} }

    $saudiBadge = New-Object System.Windows.Forms.Panel
    $saudiBadge.Size = New-Object System.Drawing.Size(108, 50)
    $saudiBadge.Location = New-Object System.Drawing.Point(20, 155)
    $saudiBadge.BackColor = $wizForm.BackColor

    $saudiIconPath = Join-Path $script:AppDir 'saudi_badge.png'
    $saudiPic = New-Object System.Windows.Forms.PictureBox
    $saudiPic.Size = New-Object System.Drawing.Size(32, 32)
    $saudiPic.Location = New-Object System.Drawing.Point((108 - 32 - 12), 9)
    $saudiPic.SizeMode = 'Zoom'
    $saudiPic.BackColor = [System.Drawing.Color]::Transparent
    if (Test-Path -LiteralPath $saudiIconPath) { try { $saudiPic.Image = [System.Drawing.Image]::FromFile($saudiIconPath) } catch {} }
    $saudiBadge.Controls.Add($saudiPic)

    $saudiTxt = New-Object System.Windows.Forms.Label
    $saudiTxt.Text = "SAUDI`r`nMADE"
    $saudiTxt.RightToLeft = 'No'
    $saudiTxt.TextAlign = 'MiddleRight'
    $saudiTxt.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)
    $saudiTxt.ForeColor = $script:Pal.Text
    $saudiTxt.BackColor = [System.Drawing.Color]::Transparent
    $saudiTxt.Location = New-Object System.Drawing.Point(0, 0)
    $saudiTxt.Size = New-Object System.Drawing.Size((108 - 32 - 16), 50)
    $saudiBadge.Controls.Add($saudiTxt)

    $wizForm.Controls.Add($saudiBadge)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'اختر المكان اللي تبي تثبت فيه ملفات البرنامج:'
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $wizForm.Controls.Add($lbl)

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Text = 'C:\واجهة مرن'
    $pathBox.Location = New-Object System.Drawing.Point(20, 50)
    $pathBox.Size = New-Object System.Drawing.Size(320, 24)
    $pathBox.BackColor = $script:Pal.Input
    $pathBox.ForeColor = $script:Pal.Text
    $pathBox.BorderStyle = 'FixedSingle'
    $wizForm.Controls.Add($pathBox)

    $browseBtn = New-Object System.Windows.Forms.Button
    $browseBtn.Text = 'استعراض...'
    $browseBtn.Location = New-Object System.Drawing.Point(350, 48)
    $browseBtn.Size = New-Object System.Drawing.Size(100, 26)
    $browseBtn.Add_Click({
            $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($fbd.ShowDialog() -eq 'OK') {
                $chosen = $fbd.SelectedPath
                if ((Split-Path $chosen -Leaf) -ne 'واجهة مرن') { $chosen = Join-Path $chosen 'واجهة مرن' }
                $pathBox.Text = $chosen
            }
        })
    $wizForm.Controls.Add($browseBtn)

    $chkDesktop = New-Object System.Windows.Forms.CheckBox
    $chkDesktop.Text = 'إنشاء اختصار على سطح المكتب'
    $chkDesktop.Checked = $true
    $chkDesktop.AutoSize = $true
    $chkDesktop.Location = New-Object System.Drawing.Point(20, 95)
    $wizForm.Controls.Add($chkDesktop)

    $chkStart = New-Object System.Windows.Forms.CheckBox
    $chkStart.Text = 'إضافة البرنامج لقائمة ابدأ'
    $chkStart.Checked = $true
    $chkStart.AutoSize = $true
    $chkStart.Location = New-Object System.Drawing.Point(20, 125)
    $wizForm.Controls.Add($chkStart)

    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Text = ''
    $statusLbl.ForeColor = [System.Drawing.Color]::Orange
    $statusLbl.AutoSize = $true
    $statusLbl.MaximumSize = New-Object System.Drawing.Size(430, 60)
    $statusLbl.Location = New-Object System.Drawing.Point(20, 160)
    $wizForm.Controls.Add($statusLbl)

    $installBtn = New-Object System.Windows.Forms.Button
    $installBtn.Text = 'تثبيت'
    $installBtn.Location = New-Object System.Drawing.Point(260, 215)
    $installBtn.Size = New-Object System.Drawing.Size(100, 32)
    $installBtn.BackColor = $script:Accent
    $installBtn.ForeColor = [System.Drawing.Color]::Black
    $wizForm.Controls.Add($installBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = 'إلغاء'
    $cancelBtn.Location = New-Object System.Drawing.Point(150, 215)
    $cancelBtn.Size = New-Object System.Drawing.Size(100, 32)
    $wizForm.Controls.Add($cancelBtn)
    $cancelBtn.Add_Click({ $wizForm.Tag = 'cancel'; $wizForm.Close() })

    $installBtn.Add_Click({
            $target = $pathBox.Text.Trim()
            if (-not $target) { $statusLbl.Text = 'لازم تحدد مسار'; return }
            $installBtn.Enabled = $false; $statusLbl.ForeColor = [System.Drawing.Color]::LightGreen; $statusLbl.Text = 'جاري التثبيت...'
            $wizForm.Refresh()
            try {
                function NormP($p) { ([IO.Path]::GetFullPath($p)).TrimEnd('\') }
                $sameDir = (NormP $target) -ieq (NormP $script:AppDir)
                if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
                if (-not $sameDir) {
                    $exclude = @('installed.marker', 'update-token.secret')
                    Get-ChildItem -LiteralPath $script:AppDir -Force | Where-Object { $_.Name -notin $exclude -and $_.Extension -ne '.zip' } | ForEach-Object {
                        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Recurse -Force
                    }
                }
                $targetExe = Join-Path $target 'واجهة مرن.exe'
                if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE) -and ((NormP $env:MURN_EXE) -ne (NormP $targetExe))) {
                    Copy-Item -LiteralPath $env:MURN_EXE -Destination $targetExe -Force
                }

                Set-Content -LiteralPath (Join-Path $target 'installed.marker') (Get-Date -Format 'o') -Encoding utf8
                try { Set-Content -LiteralPath (Join-Path $script:AppDir 'installed.marker') (Get-Date -Format 'o') -Encoding utf8 } catch {}

                $iconPath = Join-Path $target 'falcon.ico'
                $wsh = New-Object -ComObject WScript.Shell
                if ($chkDesktop.Checked) {
                    $desktopPath = [Environment]::GetFolderPath('Desktop')
                    $sc = $wsh.CreateShortcut((Join-Path $desktopPath 'واجهة مرن.lnk'))
                    $sc.TargetPath = $targetExe
                    $sc.WorkingDirectory = $target
                    if (Test-Path -LiteralPath $iconPath) { $sc.IconLocation = $iconPath }
                    $sc.Save()
                }
                if ($chkStart.Checked) {
                    $programsPath = [Environment]::GetFolderPath('Programs')
                    $sc2 = $wsh.CreateShortcut((Join-Path $programsPath 'واجهة مرن.lnk'))
                    $sc2.TargetPath = $targetExe
                    $sc2.WorkingDirectory = $target
                    if (Test-Path -LiteralPath $iconPath) { $sc2.IconLocation = $iconPath }
                    $sc2.Save()
                }

                if ($sameDir) {
                    $wizForm.Tag = 'continue'
                } else {
                    Start-Process -FilePath $targetExe
                    $wizForm.Tag = 'relaunched'
                }
                $wizForm.Close()
            } catch {
                $statusLbl.ForeColor = [System.Drawing.Color]::Orange
                $statusLbl.Text = 'صار خطأ: ' + $_.Exception.Message
                $installBtn.Enabled = $true
            }
        })

    [void]$wizForm.ShowDialog()
    $wizForm.Tag
}

if (-not $env:MURN_TEST -and -not (Test-Path -LiteralPath (Join-Path $script:AppDir 'installed.marker'))) {
    $wizResult = Show-InstallWizard
    if ($wizResult -ne 'continue') { exit }
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
        default   { $null }
    }
    if (-not $img -and $key -in 'mon', 'fix', 'tweaks', 'startup', 'apps', 'tools', 'shield', 'mrt', 'ram', 'disk', 'procs', 'display') { $img = New-GlyphIcon ([string][char]0x2699) 180 184 192 $size }
    $script:IcoCache[$ck] = $img
    $img
}


$L = $env:LOCALAPPDATA; $R = $env:APPDATA; $W = $env:windir
$script:Lhm = $null

# ---------- LibreHardwareMonitor (اختياري) ----------
$dll = Join-Path $script:AppDir 'LibreHardwareMonitorLib.dll'
if (Test-Path $dll) {
    try {
        $hid = Join-Path $script:AppDir 'HidSharp.dll'
        if (Test-Path $hid) { Add-Type -Path $hid }
        Add-Type -Path $dll
        $c = New-Object LibreHardwareMonitor.Hardware.Computer
        $c.IsCpuEnabled = $true; $c.IsGpuEnabled = $true; $c.IsMemoryEnabled = $true; $c.IsStorageEnabled = $true
        $c.Open()
        $script:Lhm = $c
    } catch { $script:Lhm = $null }
}

function Get-LhmTemp($type) {
    # returns max temperature of the hardware type, or $null
    if (-not $script:Lhm) { return $null }
    $max = $null
    foreach ($hw in $script:Lhm.Hardware) {
        if ($hw.HardwareType.ToString() -notlike $type) { continue }
        $hw.Update()
        foreach ($s in $hw.Sensors) {
            if ($s.SensorType -eq 'Temperature' -and $null -ne $s.Value) {
                if ($null -eq $max -or $s.Value -gt $max) { $max = [double]$s.Value }
            }
        }
    }
    $max
}

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
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = $os.TotalVisibleMemorySize / 1MB
    $usedGB = $totalGB - ($os.FreePhysicalMemory / 1MB)
    [void]$rows.Add([pscustomobject]@{ Name = 'الرام'; Usage = ('{0:N1} / {1:N1} GB' -f $usedGB, $totalGB); Temp = (Get-LhmTemp 'Memory'); Pct = [int](100 * $usedGB / $totalGB); Kind = 'ram' })

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
    $browserPaths = foreach ($r in $browserRoots) { foreach ($x in $b) { "$r\*\$x" }; "$r\ShaderCache"; "$r\GrShaderCache" }
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
$form.Text = 'واجهة مرن'
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
    foreach ($d in $script:DarkProgressCtrls) { Set-DarkProgress $d.Bar $d.Track $d.Fill }
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

function Paint-Gauge($s, $e) {
    $st = $s.Tag; $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $w = $s.Width; $h = $s.Height
    $shB = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(45, 0, 0, 0))
    $g.FillRectangle($shB, 4, 6, ($w - 7), ($h - 7)); $shB.Dispose()
    $cardRect = New-Object System.Drawing.Rectangle 0, 0, ($w - 5), ($h - 6)
    $cardPath = Get-RoundRectPath $cardRect 16
    $cardGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $cardRect, $script:Pal.CardTop, $script:Pal.CardBot, 90
    $g.FillPath($cardGrad, $cardPath); $cardGrad.Dispose()
    $cardHl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 0, 214, 240)), 1
    $g.DrawLine($cardHl, $cardRect.X + 16, $cardRect.Y + 1, $cardRect.Right - 16, $cardRect.Y + 1); $cardHl.Dispose()
    $cardBp = New-Object System.Drawing.Pen $script:Pal.CardBorder, 1
    $g.DrawPath($cardBp, $cardPath); $cardBp.Dispose()
    $cardPath.Dispose()
    $pct = [math]::Min(100, [math]::Max(0, [int]$st.Pct))
    $rect = New-Object System.Drawing.RectangleF 18, 16, 140, 140
    $track = New-Object System.Drawing.Pen $script:Pal.Track, 12
    $track.StartCap = 'Round'; $track.EndCap = 'Round'
    $g.DrawArc($track, $rect, 135, 270); $track.Dispose()
    $tick = New-Object System.Drawing.Pen $script:Pal.Tick, 2
    foreach ($i in 0..10) {
        $a = (135 + 27 * $i) * [math]::PI / 180
        $g.DrawLine($tick, [single](88 + 78 * [math]::Cos($a)), [single](86 + 78 * [math]::Sin($a)), [single](88 + 84 * [math]::Cos($a)), [single](86 + 84 * [math]::Sin($a)))
    }
    $tick.Dispose()
    $col = Get-GaugeColor $pct
    if ($pct -gt 0) {
        $pen = New-Object System.Drawing.Pen $col, 12
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawArc($pen, $rect, 135, [single](270 * $pct / 100)); $pen.Dispose()
    }
    $fmt = $script:GFmt
    if ($null -ne $st.Temp) {
        $tc = if ($st.Temp -ge 85) { [System.Drawing.Color]::FromArgb(235, 70, 60) } elseif ($st.Temp -ge 70) { [System.Drawing.Color]::FromArgb(240, 150, 30) } else { $script:Accent }
        $br = New-Object System.Drawing.SolidBrush $tc
        $g.DrawString(('{0:N0}°' -f $st.Temp), $script:GFontBig, $br, (New-Object System.Drawing.RectangleF 18, 58, 140, 42), $script:GFmtL); $br.Dispose()
        $subBr = New-Object System.Drawing.SolidBrush $script:Pal.SubText
        $g.DrawString('الحرارة', $script:GFontSub, $subBr, (New-Object System.Drawing.RectangleF 18, 100, 140, 18), $fmt); $subBr.Dispose()
    } else {
        $br = New-Object System.Drawing.SolidBrush $col
        $g.DrawString(('{0}%' -f $pct), $script:GFontBig, $br, (New-Object System.Drawing.RectangleF 18, 58, 140, 42), $script:GFmtL); $br.Dispose()
        $subBr = New-Object System.Drawing.SolidBrush $script:Pal.SubText
        $g.DrawString('الاستخدام', $script:GFontSub, $subBr, (New-Object System.Drawing.RectangleF 18, 100, 140, 18), $fmt); $subBr.Dispose()
    }
    # شارة الحالة (شكل "جاهز للعب" في مداد)
    $lvl = if ($null -ne $st.Temp) { $st.Temp } else { $pct }
    $hi = if ($null -ne $st.Temp) { 85 } else { 90 }; $mid = if ($null -ne $st.Temp) { 70 } else { 75 }
    $pTxt = if ($lvl -ge $hi) { 'حرج' } elseif ($lvl -ge $mid) { 'مرتفع' } else { 'طبيعي' }
    $pCol = $col
    $pillRect = New-Object System.Drawing.Rectangle ($w - 5 - 58), 8, 50, 18
    $pillPath = Get-RoundRectPath $pillRect 8
    $pillBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, $pCol.R, $pCol.G, $pCol.B))
    $g.FillPath($pillBg, $pillPath); $pillBg.Dispose()
    $pillPen = New-Object System.Drawing.Pen $pCol, 1
    $g.DrawPath($pillPen, $pillPath); $pillPen.Dispose(); $pillPath.Dispose()
    $pillBr = New-Object System.Drawing.SolidBrush $pCol
    $g.DrawString($pTxt, $script:GFontSub, $pillBr, (New-Object System.Drawing.RectangleF ([single]$pillRect.X), ([single]$pillRect.Y), ([single]$pillRect.Width), ([single]$pillRect.Height)), $script:GFmtL); $pillBr.Dispose()
    $nameBr = New-Object System.Drawing.SolidBrush $script:Pal.Text
    $g.DrawString($st.Name,$script:GFontName, $nameBr, (New-Object System.Drawing.RectangleF 4, 158, 168, 34), $fmt); $nameBr.Dispose()
    $subBr2 = New-Object System.Drawing.SolidBrush $script:Pal.SubText
    $g.DrawString($st.Usage, $script:GFontSub, $subBr2, (New-Object System.Drawing.RectangleF 4, 190, 168, 28), $script:GFmtL); $subBr2.Dispose()
}

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

function New-Gauge {
    $p = New-Object System.Windows.Forms.Panel
    $p.Width = 176; $p.Height = 222; $p.Margin = New-Object System.Windows.Forms.Padding(4)
    $p.BackColor = $script:Pal.Bg
    $p.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($p, $true, $null)
    $p.Tag = @{ Pct = 0; Temp = $null; Name = ''; Usage = ''; Kind = $null }
    $p.Cursor = 'Hand'
    $p.Add_Paint({ param($s, $e) Paint-Gauge $s $e })
    $p.Add_MouseUp({ param($s, $e) if ($e.Button -eq 'Right') { Show-GaugeMenu $s } })
    $p
}

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
Get-AppxPackage -Name '*Copilot*' | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName }
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
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
       C = 'Enable-ComputerRestore -Drive "C:\"; Checkpoint-Computer -Description "واجهة مرن" -RestorePointType MODIFY_SETTINGS' },
    @{ N = 'تحديث كل البرامج (winget)'; D = 'يحدّث كل البرامج المثبتة عندك دفعة وحدة. ياخذ شوي'; Confirm = $true
       C = 'winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements' },
    @{ N = 'إيقاف Edge و Copilot'; D = 'يوقف تشغيل Edge التلقائي والشريط الجانبي ويحذف تطبيق Copilot'; Confirm = $true; C = $edgeCmd }
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
        if (Test-Path -LiteralPath $x.M) { Remove-Item -LiteralPath $x.M -Force -ErrorAction SilentlyContinue; Show-Done ('تم الانتهاء من: ' + $x.N) }
        else { $left += $x }
    }
    $script:FixPending = $left
    if (-not $left.Count) { $fixTimer.Stop() }
})
function Start-Tool($tool) {
    if ($tool.Confirm) {
        $r = [System.Windows.Forms.MessageBox]::Show("$($tool.N)`r`n`r`n$($tool.D)`r`n`r`nتكمل؟", 'واجهة مرن', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
    }
    $marker = Join-Path $env:TEMP ('murn_done_' + [guid]::NewGuid().ToString('N'))
    $cmd = $tool.C + "; Write-Host ''; Write-Host 'انتهى. تقدر تقفل هذي النافذة.' -ForegroundColor Green; New-Item -ItemType File -Path '$marker' -Force | Out-Null"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-EncodedCommand', $enc
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
    $r = [System.Windows.Forms.MessageBox]::Show("$verb $($sel.Count) تويك؟", 'واجهة مرن', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    if (-not $undo) { try { Checkpoint-Computer -Description 'واجهة مرن tweaks' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; $tLog.AppendText("تم إنشاء نقطة استعادة`r`n") } catch { $tLog.AppendText("ما انعملت نقطة استعادة (يسمح بوحدة كل 24 ساعة)`r`n") } }
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
        $it.ForeColor = if ($null -eq $s) { [System.Drawing.Color]::Gray } elseif ($s) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::White }
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
        $k = Get-Item $s.Key
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

function Get-ToggleBitmap($on) {
    $w = 64; $h = 28
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(16, 26, 40))
    $trackOn = [System.Drawing.Color]::FromArgb(20, 180, 110)
    $trackOff = [System.Drawing.Color]::FromArgb(150, 60, 60)
    $rect = New-Object System.Drawing.Rectangle(1, 1, ($w - 2), ($h - 2))
    $radius = $rect.Height
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($rect.X, $rect.Y, $radius, $radius, 90, 180)
    $path.AddArc(($rect.Right - $radius), $rect.Y, $radius, $radius, -90, 180)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush($(if ($on) { $trackOn } else { $trackOff }))
    $g.FillPath($brush, $path)
    $knobD = $rect.Height - 8
    $knobY = $rect.Y + 4
    $knobX = if ($on) { $rect.Right - $knobD - 4 } else { $rect.X + 4 }
    $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 0, 0, 0))
    $g.FillEllipse($shadow, $knobX, ($knobY + 1), $knobD, $knobD)
    $g.FillEllipse([System.Drawing.Brushes]::White, $knobX, $knobY, $knobD, $knobD)
    $pen = New-Object System.Drawing.Pen($(if ($on) { [System.Drawing.Color]::FromArgb(0, 190, 215) } else { [System.Drawing.Color]::FromArgb(120, 45, 45) }), 2)
    $cx = $knobX + $knobD * 0.5; $cy = $knobY + $knobD * 0.5
    if ($on) {
        $g.DrawLines($pen, @(
            (New-Object System.Drawing.PointF(($cx - $knobD * 0.22), $cy)),
            (New-Object System.Drawing.PointF(($cx - $knobD * 0.05), ($cy + $knobD * 0.18))),
            (New-Object System.Drawing.PointF(($cx + $knobD * 0.25), ($cy - $knobD * 0.2)))
        ))
    } else {
        $o = $knobD * 0.18
        $g.DrawLine($pen, ($cx - $o), ($cy - $o), ($cx + $o), ($cy + $o))
        $g.DrawLine($pen, ($cx - $o), ($cy + $o), ($cx + $o), ($cy - $o))
    }
    $pen.Dispose(); $shadow.Dispose(); $brush.Dispose(); $path.Dispose(); $g.Dispose()
    $bmp
}
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
                $selfExePath = if ($env:MURN_EXE -and (Test-Path -LiteralPath $env:MURN_EXE)) { $env:MURN_EXE } else { Join-Path $script:AppDir 'واجهة مرن.exe' }
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
        $dispName = if ($isSelf) { 'واجهة مرن' } else { $x.ProcessName }
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
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($full))
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc
}

function Get-YtDlp {
    if (Test-Path $ytExe) { return $ytExe }
    $r = [System.Windows.Forms.MessageBox]::Show("التحميل يحتاج أداة مساعدة صغيرة (حوالي 18 ميجا).`r`nتحمّلها الحين؟", 'واجهة مرن', 'YesNo', 'Question')
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
$YtFolder.Dock = 'Fill'; $YtFolder.RightToLeft = 'No'; $YtFolder.Text = Join-Path $env:USERPROFILE 'Downloads'
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
$YtInfo.ForeColor = [System.Drawing.Color]::LightGreen; $YtInfo.Text = ' '
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
        $r = [System.Windows.Forms.MessageBox]::Show("التحميل يحتاج أداة مساعدة صغيرة عشان يشتغل.`r`nأثبّتها لك؟", 'واجهة مرن', 'YesNo', 'Question')
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
$CvInfo.ForeColor = [System.Drawing.Color]::LightGreen; $CvInfo.Text = ' '
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
        $r = [System.Windows.Forms.MessageBox]::Show("التحويل يحتاج أداة مساعدة مجانية وغير مثبتة عندك.`r`nأثبّتها لك؟ (مرة وحدة بس)", 'واجهة مرن', 'YesNo', 'Question')
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
    $os = Get-CimInstance Win32_OperatingSystem
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
    $tlStatus.ForeColor = [System.Drawing.Color]::LightGreen
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
    $btnTlGo.Enabled = $false; $tlStatus.ForeColor = [System.Drawing.Color]::LightGreen; $tlStatus.Text = 'جاري التنظيف...'
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
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true
    $script:DefProc = [System.Diagnostics.Process]::Start($psi)
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
    $btnMinScan.Enabled = $false; $minStatus.ForeColor = [System.Drawing.Color]::LightGreen; $minStatus.Text = 'جاري الفحص...'
    [System.Windows.Forms.Application]::DoEvents()
    $minList.Items.Clear()
    $res = @(Get-MinerSuspects)
    $script:MinerHits = $res
    foreach ($r in $res) { [void]$minList.Items.Add("$($r.Name)  —  $($r.Reason)") }
    $n = $res.Count
    $minStatus.ForeColor = if ($n -eq 0) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::FromArgb(235, 70, 60) }
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
$wuStatus.AutoSize = $true; $wuStatus.ForeColor = [System.Drawing.Color]::LightGreen; $wuStatus.Text = 'اضغط فحص التحديثات'
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
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $script:WuProc = [System.Diagnostics.Process]::Start($psi)
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
$abFlow.Controls.Add($abTitle); $abFlow.Controls.Add($abDesc)
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
$abUpdStatus.AutoSize = $false; $abUpdStatus.Width = 700; $abUpdStatus.Height = 50; $abUpdStatus.ForeColor = [System.Drawing.Color]::LightGreen
$abUpdStatus.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)

$abDesc.Height = 230
foreach ($c in $abVer, $abBtnChk, $abBtnUpd, $abUpdStatus) { $abFlow.Controls.Add($c) }

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
    if (-not $silent) { $abUpdStatus.ForeColor = [System.Drawing.Color]::LightGreen; $abUpdStatus.Text = 'جاري فحص التحديثات...' }
    $abBtnChk.Enabled = $false
    Start-UpdateBg '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; $Box.Json = $wc.DownloadString($Url) } catch { $Box.Err = $_.Exception.Message }; $Box.Done = $true' @{ Url = ($base + '/version.json?t=' + [DateTime]::UtcNow.Ticks) }
}
function Start-UpdateDownload {
    $j = $script:UpdInfo; $base = Get-UpdateBase
    $exeUrl = if ($j.url) { [string]$j.url } else { $base + '/واجهة مرن.exe' }
    $ps1Url = if ($j.ps1_url) { [string]$j.ps1_url } else { $base + '/Murn1.ps1' }
    $icoUrl = if ($j.ico_url) { [string]$j.ico_url } else { '' }
    $pngUrl = if ($j.png_url) { [string]$j.png_url } else { '' }
    if ($exeUrl -notmatch '^https://' -or $ps1Url -notmatch '^https://') { $abUpdStatus.ForeColor = [System.Drawing.Color]::Orange; $abUpdStatus.Text = 'رابط التحديث لازم يكون https'; return }
    $script:UpdPhase = 'download'; $abBtnUpd.Enabled = $false; $abBtnChk.Enabled = $false
    $abUpdStatus.ForeColor = [System.Drawing.Color]::LightGreen; $abUpdStatus.Text = 'جاري تنزيل التحديث...'
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
                if ($script:UpdSilent) {
                    $r = [System.Windows.Forms.MessageBox]::Show("يوجد إصدار جديد ($($j.version)). تبي تحدّث الحين؟", 'واجهة مرن', 'YesNo', 'Question')
                    if ($r -eq 'Yes') { Start-UpdateDownload }
                }
            } elseif (-not $script:UpdSilent) { $abUpdStatus.ForeColor = [System.Drawing.Color]::LightGreen; $abUpdStatus.Text = 'عندك آخر إصدار ✓' }
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
    $monTopRow.Dock = 'Top'; $monTopRow.Height = 140
    $chipHost = New-Object System.Windows.Forms.Integration.ElementHost
    $chipHost.Dock = 'Left'; $chipHost.Width = 420; $chipHost.Height = 140; $chipHost.Child = $bg
    $script:MonSummary = New-Object System.Windows.Forms.Label
    $script:MonSummary.Dock = 'Fill'; $script:MonSummary.TextAlign = 'MiddleRight'
    $script:MonSummary.Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 10)
    $script:MonSummary.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $script:MonSummary.ForeColor = $script:Pal.SubText
    $script:MonSummary.Text = 'جاري التحقق من حالة الجهاز...'
    $monTopRow.Controls.Add($script:MonSummary); $monTopRow.Controls.Add($chipHost)
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
    if ($tabs.SelectedTab -ne $tabMon) { return }
    $rows = $script:StatsBox.Rows
    if (-not $rows) { return }
    $gFlow.SuspendLayout()
    while ($script:GaugeList.Count -lt $rows.Count) { $c = New-Gauge; [void]$script:GaugeList.Add($c); $gFlow.Controls.Add($c) }
    while ($script:GaugeList.Count -gt $rows.Count) { $c = $script:GaugeList[$script:GaugeList.Count - 1]; $gFlow.Controls.Remove($c); $c.Dispose(); $script:GaugeList.RemoveAt($script:GaugeList.Count - 1) }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]; $c = $script:GaugeList[$i]
        $c.Tag = @{ Pct = [int]$r.Pct; Temp = $r.Temp; Name = ($r.Name -replace ': ', '  ·  '); Usage = [string]$r.Usage; Kind = $r.Kind }
        $c.Invalidate()
    }
    $gFlow.ResumeLayout()
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

# ---------- sidebar navigation ----------
$tabs.Appearance = 'FlatButtons'; $tabs.ItemSize = New-Object System.Drawing.Size(0, 1); $tabs.SizeMode = 'Fixed'
$tabs.Padding = New-Object System.Drawing.Point(0, 0)
$form.Controls.Remove($tabs)

$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'; $content.BackColor = $form.BackColor
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Dock = 'Top'; $titleBar.Height = 64; $titleBar.BackColor = [System.Drawing.Color]::FromArgb(16, 19, 26)
$titleBar.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $rect = New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(22, 27, 37), [System.Drawing.Color]::FromArgb(13, 16, 22), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $g.FillRectangle($brush, $rect)
    $pen = New-Object System.Drawing.Pen($script:Accent, 2)
    $g.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $brush.Dispose(); $pen.Dispose()
})

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Dock = 'Fill'; $titleLbl.TextAlign = 'MiddleRight'; $titleLbl.Padding = New-Object System.Windows.Forms.Padding(0, 0, 18, 0)
$titleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = [System.Drawing.Color]::White
$titleLbl.BackColor = [System.Drawing.Color]::Transparent

$verBadge = New-Object System.Windows.Forms.Panel
$verBadge.Dock = 'Right'; $verBadge.Width = 76
$verBadge.BackColor = [System.Drawing.Color]::Transparent
$verBadge.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    $w = 62; $h = 26
    $x = [int](($s.Width - $w) / 2); $y = [int](($s.Height - $h) / 2)
    $rect = New-Object System.Drawing.Rectangle($x, $y, $w, $h)
    $r = 5
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc($rect.X, $rect.Y, $r * 2, $r * 2, 180, 90)
    $gp.AddArc($rect.Right - $r * 2, $rect.Y, $r * 2, $r * 2, 270, 90)
    $gp.AddArc($rect.Right - $r * 2, $rect.Bottom - $r * 2, $r * 2, $r * 2, 0, 90)
    $gp.AddArc($rect.X, $rect.Bottom - $r * 2, $r * 2, $r * 2, 90, 90)
    $gp.CloseFigure()
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 220, 235), 1.4)
    $g.DrawPath($pen, $gp)
    $pen.Dispose(); $gp.Dispose()
})
$verLbl = New-Object System.Windows.Forms.Label
$verLbl.Dock = 'Fill'; $verLbl.TextAlign = 'MiddleCenter'
$verLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
$verLbl.ForeColor = [System.Drawing.Color]::FromArgb(140, 220, 235)
$verLbl.Text = 'v' + $script:AppVersion
$verLbl.BackColor = [System.Drawing.Color]::Transparent
$verBadge.Controls.Add($verLbl)

$brandLbl = New-Object System.Windows.Forms.Label
$brandLbl.Dock = 'Right'; $brandLbl.Width = 110; $brandLbl.TextAlign = 'MiddleRight'
$brandLbl.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$brandLbl.ForeColor = $script:Accent
$brandLbl.Text = 'واجهة مرن'
$brandLbl.Padding = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$brandLbl.BackColor = [System.Drawing.Color]::Transparent

$brandLogo = New-Object System.Windows.Forms.PictureBox
$brandLogo.Dock = 'Right'; $brandLogo.Width = 56; $brandLogo.SizeMode = 'CenterImage'
$brandLogo.BackColor = [System.Drawing.Color]::Transparent
$logoPath2 = Join-Path $script:AppDir 'falcon.png'
if (Test-Path $logoPath2) { $brandLogo.Image = [System.Drawing.Image]::FromFile($logoPath2) }

$titleBar.Controls.Add($titleLbl)
$titleBar.Controls.Add($verBadge)
$titleBar.Controls.Add($brandLbl)
$titleBar.Controls.Add($brandLogo)
$tabs.Dock = 'None'
$tabHost = New-Object System.Windows.Forms.Panel
$tabHost.Dock = 'Fill'; $tabHost.BackColor = $form.BackColor
$tabHost.Controls.Add($tabs)
$tabHost.Add_Resize({ $tabs.SetBounds(-4, -5, $tabHost.Width + 8, $tabHost.Height + 9) })

# ---------- top nav row (tabs as a horizontal strip under the title bar) + right-side vertical column ----------
$navBar = New-Object System.Windows.Forms.Panel
$navBar.Dock = 'Top'; $navBar.Height = 50; $navBar.BackColor = [System.Drawing.Color]::FromArgb(11, 14, 19)
$navBar.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(28, 34, 44), 1)
    $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $pen.Dispose()
})
$navFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$navFlow.Dock = 'Fill'; $navFlow.FlowDirection = 'LeftToRight'; $navFlow.WrapContents = $false; $navFlow.AutoScroll = $false
$navFlow.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6); $navFlow.BackColor = $navBar.BackColor
$navBar.Controls.Add($navFlow)

$navSideW = 150
$navSide = New-Object System.Windows.Forms.Panel
$navSide.Dock = 'Right'; $navSide.Width = $navSideW; $navSide.BackColor = [System.Drawing.Color]::FromArgb(11, 14, 19)
$navSide.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(28, 34, 44), 1)
    $e.Graphics.DrawLine($pen, 0, 0, 0, $s.Height)
    $pen.Dispose()
})
$navSideFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$navSideFlow.Dock = 'Fill'; $navSideFlow.FlowDirection = 'TopDown'; $navSideFlow.WrapContents = $false; $navSideFlow.AutoScroll = $true
$navSideFlow.Padding = New-Object System.Windows.Forms.Padding(8, 10, 8, 10); $navSideFlow.BackColor = $navSide.BackColor
$navSide.Controls.Add($navSideFlow)

$script:NavBtns = New-Object System.Collections.ArrayList
$navIcons = @{
    'الرئيسية' = 'mon'; 'أدوات التصليح' = 'fix'; 'تويكات ويندوز' = 'tweaks'; 'تطبيقات بدء التشغيل' = 'startup'
    'البرامج الشغالة' = 'procs'; 'الشاشات' = 'display'
    'تحميل من المنصات' = 'yt'; 'تحويل الفيديو' = 'conv'; 'أدوات التنظيف' = 'tools'
    'فحص الجهاز' = 'shield'; 'تحديث ويندوز' = 'update'; 'واجهة مرن' = 'about'
}
$navTopOrder = @('الرئيسية', 'أدوات التصليح', 'تويكات ويندوز', 'تطبيقات بدء التشغيل', 'البرامج الشغالة', 'الشاشات')
$navSideOrder = @('تحميل من المنصات', 'تحويل الفيديو', 'أدوات التنظيف', 'فحص الجهاز', 'تحديث ويندوز', 'واجهة مرن')
$allTabs = @($tabs.TabPages)
$orderedTabs = @($navTopOrder + $navSideOrder | ForEach-Object { $t = $_; $allTabs | Where-Object { $_.Text -eq $t } })
for ($i = 0; $i -lt $orderedTabs.Count; $i++) {
    $tp = $orderedTabs[$i]
    $inSide = $navSideOrder -contains $tp.Text
    $b = New-Object System.Windows.Forms.Button
    $b.Text = '  ' + $tp.Text
    $b.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 3)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0; $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(26, 30, 40)
    $b.BackColor = $navBar.BackColor; $b.ForeColor = [System.Drawing.Color]::Gainsboro; $b.RightToLeft = 'No'
    $b.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $b.TextAlign = 'MiddleRight'; $b.ImageAlign = 'MiddleRight'; $b.TextImageRelation = 'TextBeforeImage'
    $b.Padding = New-Object System.Windows.Forms.Padding(10, 0, 10, 0)
    $ik = $navIcons[$tp.Text]; if ($ik) { $b.Image = Get-Ico $ik 18 }
    $b.Tag = $tp
    $page = $tp
    $b.Add_Click({ $tabs.SelectedTab = $page }.GetNewClosure())
    if ($inSide) {
        $b.AutoSize = $false; $b.Height = 38; $b.Width = ($navSideW - 24)
        $navSideFlow.Controls.Add($b)
    } else {
        $b.AutoSize = $true; $b.Height = 38
        $navFlow.Controls.Add($b)
    }
    [void]$script:NavBtns.Add($b)
}
function Update-Nav {
    foreach ($b in $script:NavBtns) {
        $act = ($b.Tag -eq $tabs.SelectedTab)
        $b.BackColor = if ($act) { $script:Pal.NavActive } else { $navBar.BackColor }
        $b.ForeColor = if ($act) { $script:Accent } else { $script:Pal.NavText }
    }
    $titleLbl.Text = $tabs.SelectedTab.Text
    $script:StatsBox.Active = ($tabs.SelectedTab -eq $tabMon)
    if ($script:Chip3D) {
        if ($tabs.SelectedTab -eq $tabMon) { $chipTimer.Start() } else { $chipTimer.Stop() }
    }
}
$tabs.Add_SelectedIndexChanged({ Update-Nav })
$content.Controls.Add($tabHost); $content.Controls.Add($navSide); $content.Controls.Add($navBar); $content.Controls.Add($titleBar)
$form.Controls.Add($content)
Update-Nav

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
                $bg = if ($hot) { C 0 70 92 } else { $script:Pal.Input }
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

# ---------- theme engine: Dark / Light, recolors every page including the native titlebar ----------
try {
    Add-Type -Namespace Murn -Name Dwm -ErrorAction SilentlyContinue -MemberDefinition '[System.Runtime.InteropServices.DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);'
} catch {}
$script:ThemePairs = @(
    @{ D = (C 10 17 27); L = (C 240 241 244) }, @{ D = (C 16 26 40); L = [System.Drawing.Color]::White }
    @{ D = (C 8 13 21); L = [System.Drawing.Color]::White }, @{ D = (C 12 20 32); L = [System.Drawing.Color]::White }
    @{ D = (C 8 14 22); L = (C 230 232 238) }, @{ D = (C 18 30 46); L = (C 218 221 230) }
    @{ D = (C 22 36 54); L = (C 246 247 249) }, @{ D = (C 14 40 56); L = (C 255 241 214) }
    @{ D = (C 30 50 72); L = (C 214 216 222) }, @{ D = (C 150 190 220); L = (C 70 80 95) }
    @{ D = [System.Drawing.Color]::White; L = (C 25 27 32) }
    @{ D = [System.Drawing.Color]::Gray; L = (C 90 92 100) }
    @{ D = [System.Drawing.Color]::Silver; L = (C 90 92 100) }
    @{ D = [System.Drawing.Color]::Gainsboro; L = (C 40 42 48) }
    @{ D = [System.Drawing.Color]::LightGray; L = (C 60 62 68) }
    @{ D = [System.Drawing.Color]::LightGreen; L = (C 20 140 80) }
)
function Remap-ThemeColor($col, $toLight) {
    foreach ($p in $script:ThemePairs) {
        if ($toLight -and $col.ToArgb() -eq $p.D.ToArgb()) { return $p.L }
        if (-not $toLight -and $col.ToArgb() -eq $p.L.ToArgb()) { return $p.D }
    }
    $col
}
function Walk-Theme($ctrl, $toLight) {
    try { $ctrl.BackColor = Remap-ThemeColor $ctrl.BackColor $toLight } catch {}
    # buttons keep white text on their own colored backgrounds (green/blue/red/orange/gray) in both themes
    if ($ctrl -isnot [System.Windows.Forms.Button]) {
        try { $ctrl.ForeColor = Remap-ThemeColor $ctrl.ForeColor $toLight } catch {}
    }
    foreach ($c in @($ctrl.Controls)) { Walk-Theme $c $toLight }
}
$script:ThemeApplied = 'dark'
function Set-Theme($mode, $save) {
    $toLight = ($mode -eq 'light')
    $script:ThemeMode = $mode
    $script:Pal = if ($toLight) { $script:PalLight } else { $script:PalDark }
    # التمرير على العناصر يلزم فقط عند التبديل بين الثيمين؛ عند الإقلاع بالداكن كان يحوّل كل نص أبيض إلى رمادي داكن
    if ($mode -ne $script:ThemeApplied) { Walk-Theme $form $toLight; $script:ThemeApplied = $mode }
    Update-Nav
    foreach ($c in @($gFlow.Controls)) { $c.BackColor = $script:Pal.Bg; $c.Invalidate() }
    $gFlow.BackColor = $script:Pal.Bg
    try {
        $v = if ($toLight) { 0 } else { 1 }
        [void][Murn.Dwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4)
    } catch {}
    $form.Refresh()
}
Set-Theme $script:ThemeMode $false

# icons on the scan / update buttons
$btnScan.Image = Get-Ico 'mrt' 40; $btnScan.ImageAlign = 'MiddleRight'; $btnScan.TextImageRelation = 'ImageBeforeText'
$btnDef.Image = Get-Ico 'shield' 40; $btnDef.ImageAlign = 'MiddleRight'; $btnDef.TextImageRelation = 'ImageBeforeText'
$btnSec.Image = Get-Ico 'shield' 28; $btnSec.ImageAlign = 'MiddleRight'; $btnSec.TextImageRelation = 'ImageBeforeText'
$btnWuChk.Image = Get-Ico 'update' 32; $btnWuChk.ImageAlign = 'MiddleRight'; $btnWuChk.TextImageRelation = 'ImageBeforeText'

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
            $r = [System.Windows.Forms.MessageBox]::Show($splash, "يوجد إصدار جديد ($($launchUpdate.version)).`r`n$($launchUpdate.notes)`r`n`r`nتبي تحدّث الحين؟", 'واجهة مرن', 'YesNo', 'Question')
            if ($r -eq 'Yes') {
                $script:UpdInfo = $launchUpdate
                $splash.Hide()
                Start-UpdateDownload
                $dsw = [Diagnostics.Stopwatch]::StartNew()
                while ($dsw.Elapsed.TotalSeconds -lt 60 -and -not $form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
            }
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
    $i = 0
    foreach ($tp in @($tabs.TabPages)) {
        $tabs.SelectedTab = $tp; Start-Sleep -Milliseconds 350; [System.Windows.Forms.Application]::DoEvents(); Update-View
        $bmp = New-Object System.Drawing.Bitmap $form.Width, $form.Height
        $form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle 0, 0, $form.Width, $form.Height))
        $bmp.Save((Join-Path $env:MURN_TEST ("page{0:D2}.png" -f $i))); $bmp.Dispose(); $i++
    }
    if ($env:MURN_HOLD) { $tabs.SelectedTab = $tabYt; while (-not $form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 30 } } else { $form.Close(); exit }
}

if (-not $form.IsDisposed) { [void]$form.ShowDialog() }
