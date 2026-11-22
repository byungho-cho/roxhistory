[CmdletBinding()]
param([string]$Repository = 'byungho-cho/roxhistory', [switch]$Apply, [switch]$ConfirmDelete)
$ErrorActionPreference = 'Stop'
# A historical tag may still invoke -Apply from an old workflow file. GitHub
# Actions must remain audit-only, and local deletion requires explicit intent.
$canDelete = $Apply -and $ConfirmDelete -and $env:GITHUB_ACTIONS -ne 'true'
if ($Apply -and -not $canDelete) {
    Write-Output 'Audit only: deletion requires explicit local -Apply -ConfirmDelete and is disabled in GitHub Actions.'
}
function Api([string]$endpoint) {
    $json = & gh api $endpoint --paginate --slurp
    if ($LASTEXITCODE -ne 0) { throw 'GitHub release inventory failed. Nothing will be removed.' }
    return @(foreach ($page in (ConvertFrom-Json ($json -join "`n"))) { foreach ($item in $page) { $item } })
}
$releases = @(Api "repos/$Repository/releases?per_page=100" | Where-Object {
    -not $_.draft -and $_.tag_name -notmatch '^pck-test-' -and $_.tag_name -ne 'android-patch-base'
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
$apkChannel = @($releases | Where-Object tag_name -CEQ 'android-apk-channel')
$protectedApkTag = ''
$protectedApkName = ''
if ($apkChannel.Count) {
    $pointer = Invoke-RestMethod "https://github.com/$Repository/releases/download/android-apk-channel/apk-latest.json"
    $payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pointer.payload)) | ConvertFrom-Json
    if ($payload.kind -cne 'apk' -or $payload.version -notmatch '^\d+\.\d+\.\d+$') {
        throw 'APK channel target cannot be identified. Cleanup stopped.'
    }
    if ($payload.update_available -is [bool] -and -not $payload.update_available) {
        # A verified compatible-PCK policy advertises no installable APK.
        # Keep the latest complete pair; there is no older native target to pin.
        if ($payload.schema -ne 1 -or $payload.package -cne 'com.roxhistory.demo' -or
            $payload.reason -cne 'compatible_pck_available' -or
            $payload.patch_base -notmatch '^\d+\.\d+\.\d+$' -or
            [string]::IsNullOrWhiteSpace($payload.patch_runtime) -or $payload.tag -or $payload.file) {
            throw 'Patch-only APK policy cannot be identified. Cleanup stopped.'
        }
    } else {
        if ($payload.tag -cne "v$($payload.version)" -or $payload.file -cne "Roxhistory_$($payload.version).apk") {
            throw 'APK channel target cannot be identified. Cleanup stopped.'
        }
        $protectedApkTag = $payload.tag
        $protectedApkName = $payload.file
    }
}
foreach ($release in $releases) {
    foreach ($asset in $release.assets) {
        if ($asset.state -ne 'uploaded' -or $asset.id -in $keep.ids) { continue }
        if ($release.tag_name -ceq $protectedApkTag -and $asset.name -ceq $protectedApkName) { continue }
        # The Android 295 full-install baseline is reached by direct link, not the global APK catalog.
        if ($release.tag_name -ceq 'v0.2.295' -and $asset.name -ceq 'Roxhistory_0.2.295.apk') { continue }
        if ($asset.name -notmatch '^Roxhistory[_-](\d+\.\d+\.\d+).*\.(apk|exe)$') { continue }
        # A newer release may still be uploading its second platform. Never delete it.
        if ([version]$Matches[1] -gt $keep.version) { continue }
        Write-Output "$(if($canDelete){'Remove'}else{'Would remove'}): $($release.tag_name)/$($asset.name)"
        if ($canDelete) {
            $deleteResponse = & gh api --method DELETE "repos/$Repository/releases/assets/$($asset.id)" 2>&1
            # A release event and local publish can reach the same asset concurrently.
            if ($LASTEXITCODE -ne 0 -and ($deleteResponse -join "`n") -notmatch 'HTTP 404|"status"\s*:\s*"?404') {
                throw 'Asset cleanup failed; release records and tags remain intact.'
            }
        }
    }
}
