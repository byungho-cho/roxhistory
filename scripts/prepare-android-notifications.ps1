param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$AndroidSdkPath,
    [Parameter(Mandatory)][string]$JavaHome
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$android = Join-Path $repo 'game/android'
$gradle = Join-Path $android 'build'
$templateVersion = '4.5.1.stable'
$template = Join-Path (Split-Path $GodotPath) "editor_data/export_templates/$templateVersion/android_source.zip"
if (-not (Test-Path -LiteralPath $template)) {
    $template = Join-Path $env:APPDATA "Godot/export_templates/$templateVersion/android_source.zip"
}
if (-not (Test-Path -LiteralPath (Join-Path $gradle 'gradlew.bat'))) {
    if (-not (Test-Path -LiteralPath $template)) { throw "Install the Godot $templateVersion Android Gradle build template." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($template, $gradle)
}
$versionFile = Join-Path $android '.build_version'
if (-not (Test-Path -LiteralPath $versionFile)) {
    Set-Content -LiteralPath $versionFile -Value $templateVersion -Encoding ascii
}
$properties = Join-Path $gradle 'gradle.properties'
if (-not (Select-String -LiteralPath $properties -Pattern '^org\.gradle\.daemon=false$' -Quiet)) {
    Add-Content -LiteralPath $properties -Value "`norg.gradle.daemon=false" -Encoding ascii
}
$source = Join-Path $PSScriptRoot 'android-notifications'
$work = Join-Path $repo '.work/android-notifications'
$classes = Join-Path $work 'classes'
$addons = Join-Path $repo 'game/addons'
New-Item -ItemType Directory -Path $classes, $addons -Force | Out-Null
$platform = Join-Path $AndroidSdkPath 'platforms/android-35/android.jar'
& (Join-Path $JavaHome 'bin/javac.exe') -encoding UTF-8 -source 8 -target 8 -classpath $platform -d $classes (Join-Path $source 'VillageAlarm.java') (Join-Path $source 'GameApkUpdate.java')
if ($LASTEXITCODE -ne 0) { throw 'Android notification bridge compilation failed.' }
$jar = Join-Path $JavaHome 'bin/jar.exe'
& $jar --create --file (Join-Path $work 'classes.jar') -C $classes .
if ($LASTEXITCODE -ne 0) { throw 'Android notification bridge JAR packaging failed.' }
& $jar --create --file (Join-Path $addons 'roxhistory_notifications.aar') -C $work 'classes.jar' -C $source 'AndroidManifest.xml' -C $source 'res'
if ($LASTEXITCODE -ne 0) { throw 'Android notification bridge AAR packaging failed.' }
