[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRepo,
    [Parameter(Mandatory)][string]$ReferencePack,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$GodotPath = $env:ROX_GODOT_EXE,
    [string]$JavaHome = $env:JAVA_HOME,
    [switch]$Publish,
    [switch]$InitializeChannel
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
$payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM -NoNewline
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
