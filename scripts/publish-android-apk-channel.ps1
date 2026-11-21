[CmdletBinding()]
param(
    [string]$GodotPath = $env:ROX_GODOT_EXE,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$OutputDirectory,
    [switch]$Publish,
    [switch]$RequireNativeUpdate,
    [string]$PatchDirectory
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$repository = 'byungho-cho/roxhistory'
$channel = 'android-apk-channel'
$build = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $repo 'build' }
$dir = (New-Item -ItemType Directory -Force (Join-Path $build 'android-apk-channel')).FullName
if ($RequireNativeUpdate) {
    $manifest = Get-Content -Raw (Join-Path $build 'release-manifest.json') | ConvertFrom-Json
    $version = $manifest.version
    if ($version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$') { throw 'Invalid APK version.' }
    $name = "Roxhistory_$version.apk"
    $tag = "v$version"
    $apk = Join-Path $build $name
    $entry = @($manifest.files | Where-Object name -CEQ $name)
    if ($entry.Count -ne 1 -or (Get-FileHash -LiteralPath $apk).Hash -ne $entry[0].sha256) { throw 'APK does not match the build manifest.' }
    $tools = Join-Path $AndroidSdkPath 'build-tools/35.0.0'
    $badging = & (Join-Path $tools 'aapt.exe') dump badging $apk
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata.' }
    $package = [regex]::Match(($badging -join "`n"),"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'")
    $minimum = [regex]::Match(($badging -join "`n"),"sdkVersion:'(\d+)'")
    $architectures = [regex]::Match(($badging -join "`n"),'(?m)^native-code:\s*(.+)$')
    $abis = @([regex]::Matches($architectures.Groups[1].Value,"'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    if (!$package.Success -or !$minimum.Success -or !$abis.Count -or $package.Groups[1].Value -cne 'com.roxhistory.demo' -or $package.Groups[3].Value -cne $version) {
        throw 'APK metadata is inconsistent.'
    }
    $certs = & (Join-Path $tools 'apksigner.bat') verify --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $signer = [regex]::Match(($certs -join "`n"),'(?m)^Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]{64})')
    if (!$signer.Success) { throw 'APK signer is missing.' }
    $payloadPath = Join-Path $dir "apk-$version.json"
    $payload = [ordered]@{ schema=1; kind='apk'; package='com.roxhistory.demo'; version=$version; code=[long]$package.Groups[2].Value
        commit=$manifest.commit; tag=$tag; file=$name; size=$entry[0].size; sha256=$entry[0].sha256
        min_sdk=[int]$minimum.Groups[1].Value; abis=$abis; signer=$signer.Groups[1].Value.ToLowerInvariant() }
    $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM -NoNewline
} else {
    # Legacy clients treat a signed catalog with no installable artifact as
    # no native upgrade, and proceed to their existing compatible PCK check.
    $project = Get-Content -Raw (Join-Path $repo 'game/project.godot')
    $version = [regex]::Match($project,'(?m)^config/version="([0-9.]+)"').Groups[1].Value
    if (!$version) { throw 'Project version is missing.' }
    if (!$PatchDirectory) {
        $PatchDirectory = Join-Path $build ("patch-" + ([version]$version).Build)
        $manifestPath = Join-Path $PatchDirectory "manifest-$version.json"
    } else {
        $manifests = @(Get-ChildItem -LiteralPath $PatchDirectory -Filter 'manifest-*.json')
        if ($manifests.Count -ne 1) { throw 'Select a patch directory containing exactly one release manifest.' }
        $manifestPath = $manifests[0].FullName
    }
    $patch = Get-Content -Raw $manifestPath | ConvertFrom-Json
    $version = $patch.version
    if ($version -notmatch '^\d{1,4}\.\d{1,4}\.\d{1,4}$') { throw 'Invalid patch version.' }
    $bootstrap = Get-Content -Raw (Join-Path $repo 'game/patch_test/bootstrap.gd')
    $base = [regex]::Match($bootstrap,'const BASE_VERSION := "([0-9.]+)"').Groups[1].Value
    $runtime = [regex]::Match($bootstrap,'const RUNTIME := "([^"]+)"').Groups[1].Value
    if ($patch.version -ne $version -or $patch.base -ne $base -or $patch.runtime -ne $runtime -or
        $patch.commit -notmatch '^[0-9a-f]{40}$' -or $patch.sha256 -notmatch '^[0-9a-f]{64}$') {
        throw 'Publish a compatible signed PCK before enabling patch-only updates.'
    }
    $indexPath = Join-Path $PatchDirectory 'latest.json'
    $signedIndex = Get-Content -Raw $indexPath | ConvertFrom-Json
    $indexed = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($signedIndex.payload)) | ConvertFrom-Json
    foreach ($field in @('version','commit','base','base_commit','runtime','file','size','sha256')) {
        if ($indexed.$field -cne $patch.$field) { throw 'PCK manifest and signed index disagree.' }
    }
    $payload = [ordered]@{ schema=1; kind='apk'; package='com.roxhistory.demo'; version=$version
        commit=$patch.commit; update_available=$false; reason='compatible_pck_available'
        patch_base=$base; patch_runtime=$runtime }
    $payloadPath = Join-Path $dir "patch-only-$version.json"
    $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM -NoNewline
}
$settings = Get-Content -Raw (Join-Path (Split-Path $GodotPath) 'editor_data/editor_settings-4.5.tres')
function Read-Setting([string]$name) {
    $match = [regex]::Match($settings, '(?m)^' + [regex]::Escape($name) + ' = (".*")\r?$')
    if ($match.Success) { return ConvertFrom-Json $match.Groups[1].Value }
}
$signing = @{
    ROX_PATCH_STORE_PATH = Read-Setting 'export/android/debug_keystore'
    ROX_PATCH_STORE_PASSWORD = Read-Setting 'export/android/debug_keystore_pass'
    ROX_PATCH_STORE_ALIAS = Read-Setting 'export/android/debug_keystore_user'
}
if (-not $signing.ROX_PATCH_STORE_ALIAS) { $signing.ROX_PATCH_STORE_ALIAS='androiddebugkey' }
if (-not $signing.ROX_PATCH_STORE_PATH -or -not $signing.ROX_PATCH_STORE_PASSWORD) { throw 'Existing signing settings are required.' }
$previous = @{}
try {
    foreach ($key in $signing.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key,$signing[$key])
    }
    $signature = & (Join-Path $JavaHome 'bin/java.exe') (Join-Path $PSScriptRoot 'PatchSignature.java') sign $payloadPath
    if ($LASTEXITCODE -ne 0 -or $signature -notmatch '^[A-Za-z0-9+/]+=*$') { throw 'APK catalog signing failed.' }
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key,$previous[$key]) }
    $settings=$null
    $signing=$null
}
$catalog = Join-Path $dir 'apk-latest.json'
@{ payload=[Convert]::ToBase64String([IO.File]::ReadAllBytes($payloadPath)); signature=$signature } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $catalog -Encoding utf8NoBOM
if (-not $Publish) { Write-Output "Ready: $catalog"; return }
if ($RequireNativeUpdate) {
    $release = & gh release view $tag -R $repository --json isDraft,assets | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $release.isDraft) { throw 'Publish the APK release first.' }
    $asset = @($release.assets | Where-Object name -CEQ $name)
    $commit = & gh api "repos/$repository/commits/$tag" --jq '.sha'
    if ($LASTEXITCODE -ne 0 -or $commit -ne $payload.commit -or $asset.Count -ne 1 -or
        $asset[0].size -ne $payload.size -or $asset[0].digest -ne "sha256:$($payload.sha256)") {
        throw 'Published APK digest or source tag does not match.'
    }
} else {
    $pckRelease = & gh release view "android-patches-$base" -R $repository --json isDraft,assets | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $pckRelease.isDraft) { throw 'Publish the PCK channel first.' }
    $pck = @($pckRelease.assets | Where-Object name -CEQ $patch.file)
    $latest = @($pckRelease.assets | Where-Object name -CEQ 'latest.json')
    $indexPath = Join-Path $PatchDirectory 'latest.json'
    if ($pck.Count -ne 1 -or $pck[0].digest -ne "sha256:$($patch.sha256)" -or $pck[0].size -ne $patch.size -or
        $latest.Count -ne 1 -or $latest[0].digest -ne "sha256:$((Get-FileHash $indexPath).Hash.ToLowerInvariant())") {
        throw 'The compatible PCK and signed index must be published and hash-verified first.'
    }
}
& gh release view $channel -R $repository --json assets *> $null
if ($LASTEXITCODE -ne 0) {
    & gh release create $channel -R $repository --target $payload.commit --title 'RoxHistory Android APK update channel' --prerelease --latest=false
    if ($LASTEXITCODE -ne 0) { throw 'APK channel release creation failed.' }
}
& gh release upload $channel $catalog --clobber -R $repository
if ($LASTEXITCODE -ne 0) { throw 'APK catalog upload failed.' }
$index = & gh release view $channel -R $repository --json assets | ConvertFrom-Json
$actual = @($index.assets | Where-Object name -CEQ 'apk-latest.json')
$digest = (Get-FileHash -LiteralPath $catalog).Hash.ToLowerInvariant()
if ($LASTEXITCODE -ne 0 -or $actual.Count -ne 1 -or $actual[0].digest -ne "sha256:$digest") { throw 'Remote APK catalog verification failed.' }
if ($RequireNativeUpdate) { Write-Output "Required native APK catalog published for $version." }
else { Write-Output "Patch-only update policy published for $version; no automatic full APK download." }
