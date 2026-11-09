[CmdletBinding()]
param(
    [string]$GodotPath = $env:ROX_GODOT_EXE,
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$EditorSettingsPath,
    [switch]$AndroidOnly
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = Join-Path $repo 'build'
$logs = Join-Path $repo '.work/release-logs'
if (-not $GodotPath) {
    $GodotPath = (Get-Command 'Godot_v4.5.1-stable_win64_console.exe' -ErrorAction Stop).Source
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Godot executable is missing.' }
if (-not $EditorSettingsPath) {
    $EditorSettingsPath = Join-Path (Split-Path $GodotPath) 'editor_data/editor_settings-4.5.tres'
}
function Read-Setting([string]$name) {
    $match = [regex]::Match($script:settings, '(?m)^' + [regex]::Escape($name) + ' = (".*")\r?$')
    if (-not $match.Success) { return $null }
    return ConvertFrom-Json $match.Groups[1].Value
}
$settings = Get-Content -Raw -LiteralPath $EditorSettingsPath
$key = Read-Setting 'export/android/debug_keystore'
$keyPassword = Read-Setting 'export/android/debug_keystore_pass'
$keyUser = Read-Setting 'export/android/debug_keystore_user'
if (-not $keyUser) { $keyUser = 'androiddebugkey' }
if (-not $key -or -not (Test-Path -LiteralPath $key -PathType Leaf) -or -not $keyPassword) {
    throw 'An existing keystore and signing settings are required. No key will be generated.'
}
$keyHash = (Get-FileHash -LiteralPath $key).Hash
$project = Get-Content -Raw (Join-Path $repo 'game/project.godot')
$version = [regex]::Match($project, '(?m)^config/version="(\d+\.\d+\.\d+)"').Groups[1].Value
if (-not $version) { throw 'Project version is missing.' }
$tools = Join-Path $AndroidSdkPath 'build-tools/35.0.0'
foreach ($tool in @('apksigner.bat', 'zipalign.exe', 'aapt.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $tools $tool))) { throw "Missing SDK tool: $tool" }
}
if (-not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin/keytool.exe'))) { throw 'JDK is missing.' }
New-Item -ItemType Directory -Path $output, $logs -Force | Out-Null
$apk = Join-Path $output "Roxhistory_$version.apk"
$exe = Join-Path $output "Roxhistory_$version.exe"
$pendingApk = Join-Path $output "Roxhistory_$version.pending.apk"
$pendingExe = Join-Path $output "Roxhistory_$version.pending.exe"
$releaseFiles = @($apk)
$exports = @(@{ preset='Android'; path=$pendingApk; log='android' })
if (-not $AndroidOnly) {
    $releaseFiles += $exe
    $exports += @{ preset='Windows Desktop'; path=$pendingExe; log='windows' }
}
function Assert-Replaceable {
    foreach ($path in $releaseFiles) {
        if (Test-Path -LiteralPath $path) {
            try {
                $handle = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
                $handle.Dispose()
            } catch { throw 'A release file is in use. Save progress and close the game before rebuilding.' }
        }
    }
}
Assert-Replaceable
$variableNames = @('JAVA_HOME','GODOT_ANDROID_KEYSTORE_DEBUG_PATH','GODOT_ANDROID_KEYSTORE_DEBUG_USER','GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
$savedEnvironment = @{}
foreach ($name in $variableNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    $env:JAVA_HOME = $JavaHome
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $key
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = $keyUser
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = $keyPassword
    foreach ($platform in $exports) {
        & $GodotPath --headless --path (Join-Path $repo 'game') --export-debug $platform.preset $platform.path *> (Join-Path $logs "$($platform.log)-export.log")
        if ($LASTEXITCODE -ne 0) { throw "$($platform.preset) export failed; existing release files have been preserved." }
    }
    & (Join-Path $tools 'apksigner.bat') verify --verbose --print-certs $pendingApk *> (Join-Path $logs 'android-signature.log')
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & (Join-Path $tools 'zipalign.exe') -c -P 16 4 $pendingApk *> (Join-Path $logs 'android-alignment.log')
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
    $metadata = & (Join-Path $tools 'aapt.exe') dump badging $pendingApk
    if ($LASTEXITCODE -ne 0 -or -not ($metadata -match "versionName='$([regex]::Escape($version))'")) { throw 'APK version verification failed.' }
    $signatureLog = Get-Content -Raw (Join-Path $logs 'android-signature.log')
    & (Join-Path $JavaHome 'bin/keytool.exe') -exportcert -keystore $key -alias $keyUser -storepass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD -file (Join-Path $logs 'signer-certificate.der') *> (Join-Path $logs 'certificate-export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Public signing certificate export failed.' }
    $fingerprint = (Get-FileHash (Join-Path $logs 'signer-certificate.der')).Hash
    $signer = [regex]::Match($signatureLog, '(?m)^Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)\r?$')
    if (-not $signer.Success -or $signer.Groups[1].Value -ne $fingerprint) { throw 'APK signer does not match the existing key.' }
    if (-not $AndroidOnly) {
        # The app's test mode uses a separate save/preferences directory. A smoke
        # launch must never migrate or finish jobs in the player's live save.
        $process = Start-Process -FilePath $pendingExe -ArgumentList @('--headless','--quit-after','120','--log-file',(Join-Path $logs 'windows-runtime.log'),'--','--test-ui') -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw 'Windows runtime smoke check failed.' }
    }
    if ((Get-FileHash -LiteralPath $key).Hash -ne $keyHash) { throw 'Signing key unexpectedly changed.' }
    Assert-Replaceable
    Move-Item -LiteralPath $pendingApk -Destination $apk -Force
    if (-not $AndroidOnly) { Move-Item -LiteralPath $pendingExe -Destination $exe -Force }
    $commit = & git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot record source commit.' }
    $manifest = [ordered]@{ version=$version; commit=$commit; mode='debug'; files=@() }
    foreach ($file in $releaseFiles) {
        $manifest.files += @{ name=[IO.Path]::GetFileName($file); sha256=(Get-FileHash -LiteralPath $file).Hash.ToLower(); size=(Get-Item -LiteralPath $file).Length }
    }
    $manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $output 'release-manifest.json') -Encoding utf8
    # Only remove generated sidecars for this build; source/history/older releases are not touched here.
    $sidecar = "$pendingApk.idsig"
    if (Test-Path -LiteralPath $sidecar) { Remove-Item -LiteralPath $sidecar }
    foreach ($file in $releaseFiles) { Write-Output "Ready: $file" }
} finally {
    foreach ($name in $variableNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    $settings=$null; $keyPassword=$null
}
