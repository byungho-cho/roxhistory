[CmdletBinding()]
param([string]$Repository = 'byungho-cho/roxhistory', [switch]$Apply)
$ErrorActionPreference = 'Stop'
function Api([string]$endpoint) {
    $json = & gh api $endpoint --paginate --slurp
    if ($LASTEXITCODE -ne 0) { throw 'GitHub release inventory failed. Nothing will be removed.' }
    return @(foreach ($page in (ConvertFrom-Json ($json -join "`n"))) { foreach ($item in $page) { $item } })
}
$releases = @(Api "repos/$Repository/releases?per_page=100" | Where-Object {
    -not $_.draft -and $_.tag_name -notmatch '^pck-test-'
})
$pairs = @(foreach ($release in $releases) {
    $assets = @(Api "repos/$Repository/releases/$($release.id)/assets?per_page=100")
    $release.assets = $assets
    foreach ($apk in $assets) {
        if ($apk.state -ne 'uploaded' -or $apk.size -le 0 -or $apk.name -notmatch '^Roxhistory_(\d+\.\d+\.\d+)\.apk$') { continue }
        $version = $Matches[1]
        $exe = @($assets | Where-Object { $_.name -ceq "Roxhistory_$version.exe" -and $_.state -eq 'uploaded' -and $_.size -gt 0 })
        if ($exe.Count -eq 1) { [pscustomobject]@{ version=[version]$version; release=$release; ids=@($apk.id,$exe[0].id) } }
    }
})
if (-not $pairs.Count) { Write-Output 'No complete APK/EXE release pair exists. Existing assets preserved.'; return }
$keep = $pairs | Sort-Object version,@{Expression={$_.release.published_at}} -Descending | Select-Object -First 1
Write-Output "Keep APK/EXE pair: $($keep.release.tag_name), version $($keep.version)"
# Recheck the pair immediately before deletion to avoid cleaning after an interrupted upload.
$confirmed = @(Api "repos/$Repository/releases/$($keep.release.id)/assets?per_page=100")
foreach ($id in $keep.ids) {
    if (-not ($confirmed | Where-Object { $_.id -eq $id -and $_.state -eq 'uploaded' -and $_.size -gt 0 })) { throw 'Latest pair changed. Cleanup stopped.' }
}
foreach ($release in $releases) {
    foreach ($asset in $release.assets) {
        if ($asset.state -ne 'uploaded' -or $asset.id -in $keep.ids) { continue }
        if ($asset.name -notmatch '^Roxhistory[_-](\d+\.\d+\.\d+).*\.(apk|exe)$') { continue }
        # A newer release may still be uploading its second platform. Never delete it.
        if ([version]$Matches[1] -gt $keep.version) { continue }
        Write-Output "$(if($Apply){'Remove'}else{'Would remove'}): $($release.tag_name)/$($asset.name)"
        if ($Apply) {
            $deleteResponse = & gh api --method DELETE "repos/$Repository/releases/assets/$($asset.id)" 2>&1
            # A release event and local publish can reach the same asset concurrently.
            if ($LASTEXITCODE -ne 0 -and ($deleteResponse -join "`n") -notmatch 'HTTP 404|"status"\s*:\s*"?404') {
                throw 'Asset cleanup failed; release records and tags remain intact.'
            }
        }
    }
}
