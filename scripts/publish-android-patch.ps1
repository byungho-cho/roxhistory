[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameRepo,
    [Parameter(Mandatory)][string]$ReferencePack,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$GodotPath = $env:ROX_GODOT_EXE,
    [string]$JavaHome = $env:JAVA_HOME,
    [switch]$Publish
)
$ErrorActionPreference = 'Stop'
$repository = 'byungho-cho/roxhistory'
$tag = 'android-patches'
$base = '0.1.85'
$baseCommit = '8dbab7655bba5c535a95f26c308cbd784358af02'
$runtime = 'godot-4.5.1-android-pck-1'
if ((Get-FileHash $ReferencePack).Hash -ne 'A71E6E149EC6D586EDC50A6A136E1C68A932536A297CF39C618E7E25F9D35C0E') { throw 'Wrong reference PCK for this runtime.' }
if (& git -C $GameRepo status --porcelain -- game) { throw 'Commit the game resources before building a patch.' }
$commit = & git -C $GameRepo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source commit.' }
$project = Get-Content -Raw (Join-Path $GameRepo 'game/project.godot')
$version = [regex]::Match($project,'(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+)"').Groups[1].Value
if (-not $version -or [version]$version -le [version]$base) { throw 'Patch version must be newer than the baseline.' }
$directory = (New-Item -ItemType Directory -Path $OutputDirectory -Force).FullName
$name = "Roxhistory_${base}_to_${version}.pck"
$pack = Join-Path $directory $name
& $GodotPath --headless --path (Join-Path $GameRepo 'game') --export-patch Android $pack --patches (Resolve-Path $ReferencePack).Path *> (Join-Path $directory "export-$version.log")
if ($LASTEXITCODE -ne 0) { throw 'PCK export failed.' }
$sha = (Get-FileHash $pack).Hash.ToLowerInvariant()
$size = (Get-Item $pack).Length
$payloadPath = Join-Path $directory "manifest-$version.json"
[ordered]@{ base=$base; base_commit=$baseCommit; runtime=$runtime; version=$version; commit=$commit; file=$name; size=$size; sha256=$sha } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $payloadPath -Encoding utf8NoBOM -NoNewline

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
$old = @($release.assets | Where-Object name -eq $name)
if (-not $old.Count) {
    & gh release upload $tag $pack -R $repository
    if ($LASTEXITCODE -ne 0) { throw 'Patch upload failed.' }
}
$release = & gh api "repos/$repository/releases/tags/$tag" | ConvertFrom-Json
$asset = @($release.assets | Where-Object name -eq $name)
if ($asset.Count -ne 1 -or $asset[0].digest -ne "sha256:$sha" -or $asset[0].size -ne $size) { throw 'Remote patch hash mismatch.' }
& gh release upload $tag $index --clobber -R $repository
if ($LASTEXITCODE -ne 0) { throw 'Signed index upload failed.' }
if ($release.draft) {
    & gh release edit $tag --draft=false --latest=false -R $repository
    if ($LASTEXITCODE -ne 0) { throw 'Patch publication failed.' }
}
