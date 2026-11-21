$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'keep-latest-release.ps1'
$global:retentionDeleted = [Collections.Generic.List[int]]::new()
$global:retentionAssets = @{}
$global:retentionMissingPair = $false
function Asset($id,$name) { [pscustomobject]@{id=$id;name=$name;size=100;state='uploaded'} }
function Release($id,$tag,$draft=$false) { [pscustomobject]@{id=$id;tag_name=$tag;draft=$draft;published_at='2026-11-08T00:00:00Z';assets=@()} }
function global:gh {
    $global:LASTEXITCODE = 0
    $arguments = @($args)
    if ($arguments -contains 'DELETE') {
        $global:retentionDeleted.Add([int]($arguments[-1] -split '/')[-1]); return
    }
    $endpoint = [string]$arguments[1]
    if ($endpoint -match '/releases\?') {
        # Two pages exercise --paginate/--slurp rather than only the first page.
        return ConvertTo-Json -InputObject @(@($global:retentionReleases[0]),@($global:retentionReleases | Select-Object -Skip 1)) -Depth 10 -Compress
    }
    if ($endpoint -match '/releases/(\d+)/assets') {
        $id = [int]$Matches[1]
        $assets = @($global:retentionAssets[$id])
        if ($global:retentionMissingPair -and $id -eq 2 -and $global:retentionReadCount -gt 0) { $assets=@($assets | Select-Object -First 1) }
        if ($id -eq 2) { $global:retentionReadCount++ }
        return ConvertTo-Json -InputObject (, $assets) -Depth 10 -Compress
    }
    throw "Unexpected mock API request: $endpoint"
}
function global:Invoke-RestMethod {
    param($Uri)
    $bytes=[Text.Encoding]::UTF8.GetBytes(($global:retentionChannelPayload | ConvertTo-Json -Compress))
    return [pscustomobject]@{payload=[Convert]::ToBase64String($bytes);signature='fixture'}
}
try {
    $global:retentionReleases = @((Release 1 'v0.1.58'),(Release 2 'v0.1.59'),(Release 3 'v0.1.60'),(Release 4 'draft' $true),(Release 5 'pck-test-0.1.58-to-0.1.59'),(Release 6 'android-patch-base'))
    $global:retentionAssets = @{
        1=@((Asset 11 'RoxHistory-0.1.58-cloud-test.apk'),(Asset 12 'Roxhistory_0.1.58.exe'),(Asset 13 'source.zip'))
        2=@((Asset 21 'Roxhistory_0.1.59.apk'),(Asset 22 'Roxhistory_0.1.59.exe'),(Asset 23 'SHA256SUMS.txt'))
        3=@((Asset 31 'Roxhistory_0.1.60.apk'))
        4=@((Asset 41 'Roxhistory_0.1.57.apk'))
        5=@((Asset 51 'Roxhistory_0.1.58.apk'),(Asset 52 'Roxhistory_0.1.58_to_0.1.59.pck'))
        6=@((Asset 61 'Roxhistory_0.1.58.apk'))
    }
    $global:retentionReadCount=0
    & $script | Out-Null
    if ($global:retentionDeleted.Count) { throw 'Dry run deleted assets.' }
    $global:retentionReadCount=0
    & $script -Apply | Out-Null
    if (($global:retentionDeleted -join ',') -ne '11,12') { throw 'Cleanup did not preserve the latest pair, newer partial upload, draft, PCK test, and non-binary files.' }
    $global:retentionDeleted.Clear(); $global:retentionMissingPair=$true; $global:retentionReadCount=0
    $stopped=$false
    try { & $script -Apply | Out-Null } catch { $stopped=$true }
    if (-not $stopped -or $global:retentionDeleted.Count) { throw 'Cleanup failed to stop when latest pair disappeared.' }
    $global:retentionMissingPair=$false; $global:retentionReadCount=0
    $global:retentionAssets[2]=@((Asset 21 'Roxhistory_0.1.59.apk'))
    $global:retentionAssets[1]=@((Asset 11 'RoxHistory-0.1.58-cloud-test.apk'))
    & $script -Apply | Out-Null
    if ($global:retentionDeleted.Count) { throw 'Cleanup deleted files without any complete pair.' }
    $global:retentionAssets[1]=@((Asset 11 'Roxhistory_0.1.58.apk'),(Asset 12 'Roxhistory_0.1.58.exe'))
    $global:retentionAssets[2]=@((Asset 21 'Roxhistory_0.1.59.apk'),(Asset 22 'Roxhistory_0.1.59.exe'))
    $global:retentionReleases+=Release 7 'android-apk-channel'
    $global:retentionAssets[7]=@((Asset 71 'apk-latest.json'))
    $global:retentionChannelPayload=@{schema=1;kind='apk';version='0.1.58';tag='v0.1.58';file='Roxhistory_0.1.58.apk'}
    $global:retentionReadCount=0
    & $script -Apply | Out-Null
    if (($global:retentionDeleted -join ',') -ne '12') { throw 'Required native APK target was not preserved.' }
    $global:retentionDeleted.Clear();$global:retentionReadCount=0
    $global:retentionChannelPayload=@{schema=1;kind='apk';package='com.roxhistory.demo';version='0.1.59';update_available=$false;reason='compatible_pck_available';patch_base='0.2.174';patch_runtime='godot-4.5.1-android-pck-2'}
    & $script -Apply | Out-Null
    if (($global:retentionDeleted -join ',') -ne '11,12') { throw 'Patch-only policy did not retain only the latest complete pair.' }
    $global:retentionDeleted.Clear();$global:retentionReadCount=0
    $global:retentionChannelPayload.reason='unknown'
    $stopped=$false
    try { & $script -Apply | Out-Null } catch { $stopped=$true }
    if (-not $stopped -or $global:retentionDeleted.Count) { throw 'Unknown policy did not stop cleanup safely.' }
    Write-Output 'Retention checks passed: pagination, dry run, latest pair, newer incomplete release, drafts, PCK test assets, source assets, concurrent removal, and no complete pair.'
    Write-Output 'APK-policy checks passed: required native target retained, patch-only latest pair retained, unknown policy rejected.'
} finally {
    Remove-Item Function:\gh
    Remove-Item Function:\Invoke-RestMethod
    Remove-Variable retentionChannelPayload -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable retentionDeleted,retentionAssets,retentionMissingPair,retentionReadCount,retentionReleases -Scope Global -ErrorAction SilentlyContinue
}
