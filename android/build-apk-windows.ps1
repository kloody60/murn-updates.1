# Builds Murn-Downloader.apk on Windows with a temporary Android toolchain (nothing is installed system-wide).
# Everything goes to C:\MurnApk (JDK 17 + Android SDK + Gradle + Gradle cache). Nothing is installed system-wide,
# no environment variable is changed permanently (they only live inside this script's window). First run downloads about 1.5 GB and takes 10-20 minutes.
# Later runs are fast. Delete C:\MurnApk any time to remove it all.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$proj    = $PSScriptRoot                      # the android folder (has build.gradle.kts)
$work    = 'C:\MurnApk'
$desktop = [Environment]::GetFolderPath('Desktop')
$log     = Join-Path $desktop 'Murn-build-log.txt'
$outApk  = Join-Path $desktop 'Murn-Downloader.apk'

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Download($url, $dest) {
    Write-Host "   downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

try {
    if (-not (Test-Path (Join-Path $proj 'build.gradle.kts'))) { throw "build.gradle.kts not found. Keep this script inside the 'android' folder." }
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    # keep EVERYTHING inside C:\MurnApk: Gradle's cache too, so nothing touches an existing Java / Android Studio / Gradle setup
    $env:GRADLE_USER_HOME = Join-Path $work 'gradle-home'
    $env:ANDROID_USER_HOME = Join-Path $work 'android-home'

    # ---- JDK 17
    Step 'JDK 17'
    $jdkDir = Get-ChildItem $work -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $jdkDir) {
        $zip = Join-Path $work 'jdk17.zip'
        Download 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' $zip
        Expand-Archive -Path $zip -DestinationPath $work -Force
        Remove-Item $zip
        $jdkDir = Get-ChildItem $work -Directory -Filter 'jdk-17*' | Select-Object -First 1
    }
    $env:JAVA_HOME = $jdkDir.FullName
    $env:Path = "$($env:JAVA_HOME)\bin;$($env:Path)"
    Write-Host "   using $($env:JAVA_HOME)"

    # ---- Android command line tools + platform + build tools
    Step 'Android SDK'
    $sdk = Join-Path $work 'sdk'
    $sdkmanager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (-not (Test-Path $sdkmanager)) {
        $zip = Join-Path $work 'cmdline-tools.zip'
        Download 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' $zip
        $tmp = Join-Path $work 'cmdtmp'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'cmdline-tools') | Out-Null
        Move-Item (Join-Path $tmp 'cmdline-tools') (Join-Path $sdk 'cmdline-tools\latest')
        Remove-Item $tmp -Recurse -Force
        Remove-Item $zip
    }
    if (-not (Test-Path (Join-Path $sdk 'platforms\android-35')) -or -not (Test-Path (Join-Path $sdk 'build-tools\35.0.0'))) {
        Write-Host '   accepting licenses and installing platform-35 + build-tools-35 (about 200 MB)'
        $ErrorActionPreference = 'Continue'
        (1..80 | ForEach-Object { 'y' }) | & $sdkmanager "--sdk_root=$sdk" --licenses | Out-Null
        & $sdkmanager "--sdk_root=$sdk" 'platforms;android-35' 'build-tools;35.0.0'
        $ErrorActionPreference = 'Stop'
        if (-not (Test-Path (Join-Path $sdk 'platforms\android-35'))) { throw 'Android platform install failed' }
    }
    $env:ANDROID_HOME = $sdk
    # gradle reads the SDK location from local.properties (escape backslashes)
    ('sdk.dir=' + ($sdk -replace '\\', '\\')) | Set-Content -Path (Join-Path $proj 'local.properties') -Encoding ASCII

    # ---- Gradle
    Step 'Gradle'
    $gradle = Join-Path $work 'gradle-8.10.2\bin\gradle.bat'
    if (-not (Test-Path $gradle)) {
        $zip = Join-Path $work 'gradle.zip'
        Download 'https://services.gradle.org/distributions/gradle-8.10.2-bin.zip' $zip
        Expand-Archive -Path $zip -DestinationPath $work -Force
        Remove-Item $zip
    }

    # ---- signing key (kept, so a newer build can be installed over an older one)
    Step 'Signing key'
    $ks = Join-Path $work 'murn.keystore'
    if (-not (Test-Path $ks)) {
        & keytool -genkeypair -keystore $ks -alias murn -keyalg RSA -keysize 2048 -validity 36500 `
            -storepass murn-downloader -keypass murn-downloader -dname 'CN=Murn Downloader, O=Murn, C=SA' | Out-Null
    }
    Copy-Item $ks (Join-Path $proj 'murn.keystore') -Force   # build.gradle.kts looks for ../murn.keystore next to app/

    # ---- build
    Step 'Building APK (this is the long part, do not close the window)'
    Push-Location $proj
    $ErrorActionPreference = 'Continue'
    cmd /c "`"$gradle`" --no-daemon --console=plain assembleRelease > `"$log`" 2>&1"
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Pop-Location
    if ($code -ne 0) {
        Write-Host ''
        Write-Host 'BUILD FAILED. Last lines:' -ForegroundColor Red
        Get-Content $log -Tail 40
        Write-Host ''
        Write-Host "Full log saved to: $log" -ForegroundColor Yellow
        Write-Host 'Send that file (or the last lines above) to Claude and it will fix the code.' -ForegroundColor Yellow
        exit 1
    }

    $apk = Join-Path $proj 'app\build\outputs\apk\release\app-release.apk'
    if (-not (Test-Path $apk)) { throw 'Build finished but the APK file was not found.' }
    Copy-Item $apk $outApk -Force
    Remove-Item $log -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host "DONE: $outApk" -ForegroundColor Green
    Write-Host 'Send it to the phone (USB cable, Telegram/WhatsApp saved messages, Google Drive...), open it, allow "install unknown apps" if asked.'
    Start-Process explorer.exe "/select,`"$outApk`""
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
