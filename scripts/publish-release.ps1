[CmdletBinding()]
param([string]$Repository = 'byungho-cho/roxhistory', [string]$ReleaseNotesPath, [switch]$AndroidOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = Join-Path $repo 'build'
$manifest = Get-Content -Raw (Join-Path $output 'release-manifest.json') | ConvertFrom-Json
$version = $manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }
$files = @("Roxhistory_$version.apk")
$platforms = 'Android'
if (-not $AndroidOnly) {
    $files += "Roxhistory_$version.exe"
    $platforms = 'Android / Windows'
}
if (@($manifest.files).Count -ne $files.Count) { throw 'The build manifest does not match the requested platforms.' }
foreach ($name in $files) {
    $entry = @($manifest.files | Where-Object name -CEQ $name)
    $path = Join-Path $output $name
    if ($entry.Count -ne 1 -or -not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path).Hash -ne $entry[0].sha256) { throw "Missing or changed build: $name" }
}
$head = & git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $manifest.commit) { throw 'Rebuild the requested platforms from the current source commit before publishing.' }
if (& git -C $repo status --porcelain) { throw 'Commit source and release tooling before building and publishing.' }
& gh auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI login is required for release uploads.' }
$tag = "v$version"
$allReleasesText = & gh api "repos/$Repository/releases?per_page=100" --paginate --slurp
if ($LASTEXITCODE -ne 0) { throw 'Cannot list releases.' }
$allReleases = @(foreach ($page in (ConvertFrom-Json ($allReleasesText -join "`n"))) { foreach ($item in $page) { $item } })
$matchingReleases = @($allReleases | Where-Object tag_name -CEQ $tag)
if ($matchingReleases.Count -gt 1) { throw 'Multiple releases use this tag. Resolve them before publishing.' }
$exists = $matchingReleases.Count -eq 1
$notes = Join-Path $repo '.work/release-logs/release-notes.txt'
New-Item -ItemType Directory (Split-Path $notes) -Force | Out-Null
@"
RoxHistory $version — $platforms development build

Source commit: $($manifest.commit)
This Android APK uses the current MY-NUROX debug signing key. Older differently signed installations require reinstalling; uninstalling can erase saved progress.
Build and signature checks passed. Known legacy regression-test failures remain documented; this is not a full gameplay approval.
"@ | Set-Content -LiteralPath $notes -Encoding utf8
if ($ReleaseNotesPath) {
    Get-Content -Raw -LiteralPath $ReleaseNotesPath | Add-Content -LiteralPath $notes -Encoding utf8
}
if (-not $exists) {
    $created = & gh api --method POST "repos/$Repository/releases" -f "tag_name=$tag" -f "target_commitish=$($manifest.commit)" -f "name=RoxHistory $version" -F "body=@$notes" -F draft=true -F prerelease=true
    if ($LASTEXITCODE -ne 0) { throw 'Release creation failed.' }
    $matchingReleases = @((ConvertFrom-Json ($created -join "`n")))
}
if ($matchingReleases.Count -ne 1) { throw 'Cannot uniquely identify release.' }
$release = $matchingReleases[0]
if (-not $release.draft) {
    $unchanged = $true
    foreach ($entry in $manifest.files) {
        $existing = @($release.assets | Where-Object name -CEQ $entry.name)
        if ($existing.Count -ne 1 -or $existing[0].digest -ne "sha256:$($entry.sha256)") { $unchanged=$false }
    }
    if (-not $unchanged) { throw 'This version is already published. Use a new version instead of replacing a live release pair.' }
}
# Verify an existing tag rather than publishing a pair against unrelated source.
$tagCommit = & gh api "repos/$Repository/commits/$tag" --jq '.sha' 2>$null
if ($LASTEXITCODE -eq 0) {
    if ($tagCommit -ne $manifest.commit) { throw 'Release tag points to different source; preserve it and use a new version.' }
} elseif ($release.draft) {
    if ($release.target_commitish -ne $manifest.commit) {
        & gh api --method PATCH "repos/$Repository/releases/$($release.id)" -f target_commitish=$($manifest.commit) --silent
        if ($LASTEXITCODE -ne 0) { throw 'Cannot update unpublished draft source commit.' }
    }
} else {
    throw 'Cannot confirm the release source commit.'
}
if ($release.draft) {
    foreach ($name in $files) {
        foreach ($old in @($release.assets | Where-Object name -CEQ $name)) {
            & gh api --method DELETE "repos/$Repository/releases/assets/$($old.id)" --silent
            if ($LASTEXITCODE -ne 0) { throw 'Cannot replace unfinished draft asset.' }
        }
        $url = "https://uploads.github.com/repos/$Repository/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($name))"
        & gh api --method POST $url --header 'Content-Type: application/octet-stream' --input (Join-Path $output $name) --silent
        if ($LASTEXITCODE -ne 0) { throw 'Release asset upload failed. Previous releases have not been cleaned.' }
    }
}
$assetsText = & gh api "repos/$Repository/releases/$($release.id)/assets?per_page=100"
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify uploaded assets.' }
$assets = ConvertFrom-Json ($assetsText -join "`n")
foreach ($entry in $manifest.files) {
    $asset = @($assets | Where-Object name -CEQ $entry.name)
    if ($asset.Count -ne 1 -or $asset[0].state -ne 'uploaded' -or $asset[0].size -ne $entry.size -or $asset[0].digest -ne "sha256:$($entry.sha256)") { throw 'Uploaded asset checksum verification failed. No cleanup performed.' }
}
& gh api --method PATCH "repos/$Repository/releases/$($release.id)" -F draft=false -F prerelease=true -F "body=@$notes" --silent
if ($LASTEXITCODE -ne 0) { throw 'Publishing failed. No cleanup performed.' }
$tagCommit = & gh api "repos/$Repository/commits/$tag" --jq '.sha'
if ($LASTEXITCODE -ne 0 -or $tagCommit -ne $manifest.commit) { throw 'Published tag verification failed. No cleanup performed.' }
if (-not $AndroidOnly) {
    & (Join-Path $PSScriptRoot 'keep-latest-release.ps1') -Repository $Repository -Apply
    if (-not $?) { throw 'Release published, but old asset cleanup needs attention.' }
}
Write-Output "Published $platforms to https://github.com/$Repository/releases/tag/$tag"
