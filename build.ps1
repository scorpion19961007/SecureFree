# SecureFree build script
#   javac(stubs) -> javac(module) -> jar -> d8 -> aapt2 link -> inject -> zipalign -> apksigner
# No Gradle / Android Studio needed. Requires JDK 17 + Android SDK build-tools.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
# Optional overrides:
#   -JdkBin   <dir with javac.exe>        -BuildTools <dir with aapt2.exe>
#   -AndroidJar <path to android.jar>
[CmdletBinding()]
param(
    [string]$JdkBin,
    [string]$BuildTools,
    [string]$AndroidJar
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Fail($msg) { throw $msg }

# ---------- locate JDK ----------
if (-not $JdkBin) {
    $cands = @()
    if ($env:JAVA_HOME) { $cands += (Join-Path $env:JAVA_HOME "bin") }
    $cands += @(
        "C:\Program Files\Android\Android Studio\jbr\bin",
        "C:\Program Files\Eclipse Adoptium\jdk-17\bin",
        "C:\Program Files\Java\jdk-17\bin"
    )
    foreach ($c in $cands) { if ($c -and (Test-Path (Join-Path $c "javac.exe"))) { $JdkBin = $c; break } }
}
if (-not $JdkBin) {
    $cmd = Get-Command javac -ErrorAction SilentlyContinue
    if ($cmd) { $JdkBin = Split-Path -Parent $cmd.Source }
}
if (-not $JdkBin) { Fail "Cannot find javac. Install JDK 17 or pass -JdkBin <dir>." }
$env:JAVA_HOME = (Split-Path -Parent $JdkBin)

# ---------- locate Android SDK ----------
$sdkRoots = @()
if ($env:ANDROID_HOME)     { $sdkRoots += $env:ANDROID_HOME }
if ($env:ANDROID_SDK_ROOT) { $sdkRoots += $env:ANDROID_SDK_ROOT }
$sdkRoots += @(
    (Join-Path $env:LOCALAPPDATA "Android\Sdk"),
    "C:\Android\Sdk"
)
$sdk = $null
foreach ($r in $sdkRoots) {
    if ($r -and (Test-Path (Join-Path $r "build-tools"))) { $sdk = $r; break }
}
if (-not $sdk -and -not $BuildTools) { Fail "Cannot find Android SDK. Set ANDROID_HOME or pass -BuildTools/-AndroidJar." }

# ---------- locate build-tools (highest version) ----------
if (-not $BuildTools) {
    $btDirs = Get-ChildItem (Join-Path $sdk "build-tools") -Directory |
              Sort-Object { [version]($_.Name -replace '[^0-9\.].*$','') } -Descending
    foreach ($d in $btDirs) {
        if (Test-Path (Join-Path $d.FullName "aapt2.exe")) { $BuildTools = $d.FullName; break }
    }
}
if (-not $BuildTools) { Fail "No usable build-tools (aapt2.exe) found. Pass -BuildTools <dir>." }

# ---------- locate android.jar (highest platform) ----------
if (-not $AndroidJar) {
    $platDirs = Get-ChildItem (Join-Path $sdk "platforms") -Directory |
                Sort-Object { [int]($_.Name -replace '[^0-9]','') } -Descending
    foreach ($d in $platDirs) {
        $jar = Join-Path $d.FullName "android.jar"
        if (Test-Path $jar) { $AndroidJar = $jar; break }
    }
}
if (-not $AndroidJar -or -not (Test-Path $AndroidJar)) { Fail "android.jar not found. Pass -AndroidJar <path>." }

$javac     = Join-Path $JdkBin "javac.exe"
$jarTool   = Join-Path $JdkBin "jar.exe"
$keytool   = Join-Path $JdkBin "keytool.exe"
$d8        = Join-Path $BuildTools "d8.bat"
$d8Unix    = Join-Path $BuildTools "d8"
$aapt2     = Join-Path $BuildTools "aapt2.exe"
$zipalign  = Join-Path $BuildTools "zipalign.exe"
$apksigner = Join-Path $BuildTools "apksigner.bat"
if (-not (Test-Path $d8)) { $d8 = $d8Unix }

Write-Host "JDK         : $JdkBin"
Write-Host "build-tools : $BuildTools"
Write-Host "android.jar : $AndroidJar"

# ---------- directories ----------
$build  = Join-Path $root "build"
$outDir = Join-Path $root "out"
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
$stubClasses = Join-Path $build "stub-classes"
$modClasses  = Join-Path $build "classes"
$dexDir      = Join-Path $build "dex"
New-Item -ItemType Directory -Force -Path $stubClasses, $modClasses, $dexDir, $outDir | Out-Null

# ---------- 1. compile xposed api stubs (compile only, never packed into dex) ----------
Write-Host ""
Write-Host "[1/6] compiling API stubs ..."
$stubFiles = Get-ChildItem -Path (Join-Path $root "stubs") -Recurse -Filter *.java | ForEach-Object { $_.FullName }
& $javac -encoding UTF-8 --release 8 -nowarn -d $stubClasses $stubFiles
if ($LASTEXITCODE -ne 0) { Fail "javac failed on stubs" }

# ---------- 2. compile module ----------
Write-Host ""
Write-Host "[2/6] compiling module ..."
$srcFiles = Get-ChildItem -Path (Join-Path $root "src") -Recurse -Filter *.java | ForEach-Object { $_.FullName }
& $javac -encoding UTF-8 --release 8 -nowarn -classpath "$AndroidJar;$stubClasses" -d $modClasses $srcFiles
if ($LASTEXITCODE -ne 0) { Fail "javac failed on module sources" }

# ---------- 3. jar + d8 ----------
Write-Host ""
Write-Host "[3/6] d8 ..."
$classesJar = Join-Path $build "classes.jar"
& $jarTool --create --file $classesJar -C $modClasses .
if ($LASTEXITCODE -ne 0) { Fail "jar failed" }

& $d8 --release --min-api 31 --lib $AndroidJar --output $dexDir $classesJar
if ($LASTEXITCODE -ne 0) { Fail "d8 failed" }
if (-not (Test-Path (Join-Path $dexDir "classes.dex"))) { Fail "classes.dex not produced" }

# ---------- 4. aapt2 link ----------
Write-Host ""
Write-Host "[4/6] aapt2 link ..."
$baseApk = Join-Path $build "base.apk"
& $aapt2 link -o $baseApk -I $AndroidJar --manifest (Join-Path $root "AndroidManifest.xml") `
    --min-sdk-version 31 --target-sdk-version 35
if ($LASTEXITCODE -ne 0) { Fail "aapt2 link failed" }

# ---------- 5. inject classes.dex + assets/xposed_init ----------
Write-Host ""
Write-Host "[5/6] injecting classes.dex and assets/xposed_init ..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$zip = [System.IO.Compression.ZipFile]::Open($baseApk, 'Update')
try {
    foreach ($e in @($zip.Entries | Where-Object { $_.FullName -eq 'classes.dex' })) { $e.Delete() }
    # store uncompressed: faster load, and lets you byte-verify the dex inside the APK
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, (Join-Path $dexDir "classes.dex"), "classes.dex",
        [System.IO.Compression.CompressionLevel]::NoCompression)

    foreach ($e in @($zip.Entries | Where-Object { $_.FullName -eq 'assets/xposed_init' })) { $e.Delete() }
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, (Join-Path $root "assets\xposed_init"), "assets/xposed_init",
        [System.IO.Compression.CompressionLevel]::Optimal)
}
finally { $zip.Dispose() }

# ---------- 6. zipalign + sign ----------
Write-Host ""
Write-Host "[6/6] zipalign + apksigner ..."
$alignedApk = Join-Path $build "aligned.apk"
& $zipalign -f -p 4 $baseApk $alignedApk
if ($LASTEXITCODE -ne 0) { Fail "zipalign failed" }

$ks = Join-Path $root "securefree.keystore"
if (-not (Test-Path $ks)) {
    Write-Host "generating signing key (change it before publishing your own build) ..."
    & $keytool -genkeypair -keystore $ks -alias securefree -keyalg RSA -keysize 2048 `
        -validity 10000 -storepass securefree -keypass securefree `
        -dname "CN=SecureFree, OU=local, O=local, L=Local, C=CN"
    if ($LASTEXITCODE -ne 0) { Fail "keytool failed" }
}

$finalApk = Join-Path $outDir "SecureFree-signed.apk"
if (Test-Path $finalApk) { Remove-Item $finalApk -Force }
& $apksigner sign --ks $ks --ks-key-alias securefree `
    --ks-pass pass:securefree --key-pass pass:securefree `
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true `
    --out $finalApk $alignedApk
if ($LASTEXITCODE -ne 0) { Fail "apksigner failed" }

& $apksigner verify --print-certs $finalApk | Select-Object -First 5

Write-Host ""
Write-Host "BUILD OK -> $finalApk"
Write-Host ("size: {0:N0} bytes" -f (Get-Item $finalApk).Length)
