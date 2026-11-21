[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRepo,
    [Parameter(Mandatory)][string]$ReferencePack,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$GodotPath = $env:ROX_GODOT_EXE,
    [string]$JavaHome = $env:JAVA_HOME,
    [switch]$Publish,
    [switch]$InitializeChannel,
    [string]$PreviousPack,
    [string]$PreviousManifest,
    [string]$PythonPath = 'python'
)
$ErrorActionPreference = 'Stop'
$repository = 'byungho-cho/roxhistory'
$bootstrap = Get-Content -Raw (Join-Path $GameRepo 'game/patch_test/bootstrap.gd')
$base = [regex]::Match($bootstrap,'const BASE_VERSION := "([0-9.]+)"').Groups[1].Value
$baseCommit = [regex]::Match($bootstrap,'const BASE_COMMIT := "([0-9a-f]{40})"').Groups[1].Value
$runtime = [regex]::Match($bootstrap,'const RUNTIME := "([^"]+)"').Groups[1].Value
$tag = "android-patches-$base"
$referenceHashes = @{
    '0.2.91' = '2A87A1D547551F76C858D2F70030DBA7C0F28C794C0BE3B41FF6CDAC67490644'
    '0.2.174' = 'DE8EE37DC8864F201C0B87876BCE599EE694B0C7F3BEED6D2C8CCE459FBD202F'
}
if (!$baseCommit -or !$runtime -or (Get-FileHash $ReferencePack).Hash -ne $referenceHashes[$base]) { throw 'Wrong reference PCK for this runtime.' }
if (& git -C $GameRepo status --porcelain -- game) { throw 'Commit the game resources before building a patch.' }
$commit = & git -C $GameRepo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source commit.' }
$project = Get-Content -Raw (Join-Path $GameRepo 'game/project.godot')
$version = [regex]::Match($project,'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"').Groups[1].Value
if (-not $version -or ($InitializeChannel -and $version -ne $base) -or (-not $InitializeChannel -and [version]$version -le [version]$base)) { throw 'Patch version must be newer than the baseline.' }
$directory = (New-Item -ItemType Directory -Path $OutputDirectory -Force).FullName
$name = "Roxhistory_${base}_to_${version}.pck"
$pack = Join-Path $directory $name
$payloadPath = Join-Path $directory "manifest-$version.json"
$payload = [ordered]@{ base=$base; base_commit=$baseCommit; runtime=$runtime; version=$version; commit=$commit }
if ($InitializeChannel) {
    $payload.patch_available = $false
} else {
    & $GodotPath --headless --path (Join-Path $GameRepo 'game') --export-patch Android $pack --patches (Resolve-Path $ReferencePack).Path *> (Join-Path $directory "export-$version.log")
    if ($LASTEXITCODE -ne 0) { throw 'PCK export failed.' }
    $sha = (Get-FileHash $pack).Hash.ToLowerInvariant()
    $size = (Get-Item $pack).Length
    $payload.file = $name
    $payload.size = $size
    $payload.sha256 = $sha
}
if ($PreviousPack -or $PreviousManifest) {
    if (!$PreviousPack -or !$PreviousManifest -or $InitializeChannel) { throw 'The predecessor pack and manifest must be supplied together.' }
    $next = [version]$version
    $parent = Split-Path $directory -Parent
    $deltas = @()
    $specifiedPrior = Get-Content -Raw -LiteralPath $PreviousManifest | ConvertFrom-Json
    if ($Publish) {
        $channel = gh release view $tag -R $repository --json assets | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'Cannot verify predecessor artifacts.' }
    }
    foreach ($distance in 1..3) {
        if ($next.Build -lt $distance) { continue }
        $expected = "$($next.Major).$($next.Minor).$($next.Build-$distance)"
        # A built-but-held version may occupy the intervening number. Never
        # publish a recipe based on that unpublished local pack. The supplied
        # predecessor is the last published head; all remote hash checks below
        # still apply before updating the signed catalog.
        if ([version]$expected -gt [version]$specifiedPrior.version) {
            Write-Output "Skipping unreleased predecessor $expected (published head $($specifiedPrior.version))."
            continue
        }
        $manifestPath = $PreviousManifest
        $sourcePack = $PreviousPack
        if ($expected -ne $specifiedPrior.version) {
            $priorDirectory = Join-Path $parent "patch-$($next.Build-$distance)"
            $manifestPath = Join-Path $priorDirectory "manifest-$expected.json"
            $sourcePack = Join-Path $priorDirectory "Roxhistory_${base}_to_$expected.pck"
            if (!(Test-Path -LiteralPath $manifestPath) -or !(Test-Path -LiteralPath $sourcePack)) {
                Write-Output "No cached cumulative pack for $expected; it will use the cumulative update."
                continue
            }
        }
        $prior = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        if ($prior.base -ne $base -or $prior.base_commit -ne $baseCommit -or $prior.runtime -ne $runtime -or
            $prior.version -ne $expected -or $prior.file -ne "Roxhistory_${base}_to_$expected.pck" -or
            $prior.commit -notmatch '^[a-f0-9]{40}$' -or (Get-FileHash -LiteralPath $sourcePack).Hash -ne $prior.sha256 -or
            (Get-Item -LiteralPath $sourcePack).Length -ne $prior.size) {
            throw "Invalid cumulative predecessor: $expected"
        }
        if ($Publish) {
            $published = @($channel.assets | Where-Object name -eq $prior.file)
            if ($published.Count -ne 1 -or $published[0].digest -ne "sha256:$($prior.sha256)" -or $published[0].size -ne $prior.size) {
                throw "The predecessor pack does not match the previously published artifact: $expected"
            }
        }
        $deltaName = "Roxhistory_${base}_${expected}_to_${version}.rdx"
        $deltaPath = Join-Path $directory $deltaName
        & $PythonPath (Join-Path $PSScriptRoot 'build_pack_delta.py') $sourcePack $pack $deltaPath
        if ($LASTEXITCODE -ne 0) { throw "Difference patch export failed: $expected" }
        $deltaSize = (Get-Item -LiteralPath $deltaPath).Length
        if ($deltaSize -gt $size * .8) { continue }
        $entry = [ordered]@{
            from_version=$prior.version; from_commit=$prior.commit; from_sha256=$prior.sha256
            file=$deltaName; size=$deltaSize; sha256=(Get-FileHash -LiteralPath $deltaPath).Hash.ToLowerInvariant()
        }
        $deltas += $entry
        # Older clients recognize only the immediately preceding version.
        if (!$payload.Contains('delta')) { $payload.delta = $entry }
        Write-Output "Difference patch $deltaName ($deltaSize bytes)"
    }
    if ($deltas.Count) { $payload.deltas = $deltas }
}
$payload | ConvertTo-Json -Depth 5 -Compress | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM -NoNewline
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
    if ($LASTEXITCODE -ne 0 -or $signature -notmatch '^[A-Za-z0-9+/]+=*$') { throw 'Patch signing failed.' }
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key,$previous[$key]) }
    $settings=$null
    $signing=$null
}
$index = Join-Path $directory 'latest.json'
@{ payload=[Convert]::ToBase64String([IO.File]::ReadAllBytes($payloadPath)); signature=$signature } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $index -Encoding utf8NoBOM
Write-Output "Patch $version ($size bytes), source $commit"

if (-not $Publish) { return }
$remote = & gh release view $tag -R $repository --json isDraft,assets 2>$null
if ($LASTEXITCODE -ne 0) {
    & gh release create $tag -R $repository --target $commit --title 'RoxHistory Android patches' --notes 'Install the patch-enabled Android APK once, then use the in-game update button.' --draft --latest=false
    if ($LASTEXITCODE -ne 0) { throw 'Could not create patch release.' }
    $remote = & gh release view $tag -R $repository --json isDraft,assets
    if ($LASTEXITCODE -ne 0) { throw 'Could not read patch release.' }
}
$release = $remote | ConvertFrom-Json
if (-not $InitializeChannel) {
$old = @($release.assets | Where-Object name -eq $name)
if (-not $old.Count) {
    & gh release upload $tag $pack -R $repository
    if ($LASTEXITCODE -ne 0) { throw 'Patch upload failed.' }
}
$remote = & gh release view $tag -R $repository --json isDraft,assets
if ($LASTEXITCODE -ne 0) { throw 'Could not verify patch release.' }
$release = $remote | ConvertFrom-Json
$asset = @($release.assets | Where-Object name -eq $name)
if ($asset.Count -ne 1 -or $asset[0].digest -ne "sha256:$sha" -or $asset[0].size -ne $size) { throw 'Remote patch hash mismatch.' }
} elseif ($release.assets | Where-Object name -eq "latest.json") { throw "Channel already initialized." }
if ($payload.deltas) {
    foreach ($entry in $payload.deltas) {
        if (-not ($release.assets | Where-Object name -eq $entry.file)) {
            & gh release upload $tag (Join-Path $directory $entry.file) -R $repository
            if ($LASTEXITCODE -ne 0) { throw "Difference patch upload failed: $($entry.file)" }
        }
    }
    $channel = gh release view $tag -R $repository --json assets | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot verify difference patch uploads.' }
    foreach ($entry in $payload.deltas) {
        $remoteDelta = @($channel.assets | Where-Object name -eq $entry.file)
        if ($remoteDelta.Count -ne 1 -or $remoteDelta[0].digest -ne "sha256:$($entry.sha256)" -or $remoteDelta[0].size -ne $entry.size) {
            throw "Remote difference patch hash mismatch: $($entry.file)"
        }
    }
}
& gh release upload $tag $index --clobber -R $repository
if ($LASTEXITCODE -ne 0) { throw 'Signed index upload failed.' }
$remote = & gh release view $tag -R $repository --json assets
if ($LASTEXITCODE -ne 0) { throw 'Could not verify signed index.' }
$remoteIndex = @(($remote | ConvertFrom-Json).assets | Where-Object name -eq 'latest.json')
$indexHash = (Get-FileHash $index).Hash.ToLowerInvariant()
if ($remoteIndex.Count -ne 1 -or $remoteIndex[0].digest -ne "sha256:$indexHash") { throw 'Remote signed index hash mismatch.' }
if ($release.isDraft) {
    & gh release edit $tag --draft=false --latest=false -R $repository
    if ($LASTEXITCODE -ne 0) { throw 'Patch publication failed.' }
}
