$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'
$GoogleServices = Join-Path $AndroidDir 'app\google-services.json'

if (-not (Test-Path $AndroidDir)) { throw 'Run scripts\bootstrap-android.ps1 first.' }
if (-not (Test-Path $GoogleServices)) { throw "Missing $GoogleServices" }

$SettingsKts = Join-Path $AndroidDir 'settings.gradle.kts'
$SettingsGroovy = Join-Path $AndroidDir 'settings.gradle'
$AppKts = Join-Path $AndroidDir 'app\build.gradle.kts'
$AppGroovy = Join-Path $AndroidDir 'app\build.gradle'

if (Test-Path $SettingsKts) {
    $text = Get-Content $SettingsKts -Raw
    if ($text -notmatch 'com.google.gms.google-services') {
        $replacement = '$1' + "`r`n    id(`"com.google.gms.google-services`") version `"4.4.4`" apply false"
        $text = $text -replace '(plugins\s*\{)', $replacement
        Set-Content $SettingsKts $text -Encoding UTF8
    }
} elseif (Test-Path $SettingsGroovy) {
    $text = Get-Content $SettingsGroovy -Raw
    if ($text -notmatch 'com.google.gms.google-services') {
        $replacement = '$1' + "`r`n    id 'com.google.gms.google-services' version '4.4.4' apply false"
        $text = $text -replace '(plugins\s*\{)', $replacement
        Set-Content $SettingsGroovy $text -Encoding UTF8
    }
}

if (Test-Path $AppKts) {
    $text = Get-Content $AppKts -Raw
    if ($text -notmatch 'com.google.gms.google-services') {
        $replacement = '$1' + "`r`n    id(`"com.google.gms.google-services`")"
        $text = $text -replace '(plugins\s*\{)', $replacement
        Set-Content $AppKts $text -Encoding UTF8
    }
} elseif (Test-Path $AppGroovy) {
    $text = Get-Content $AppGroovy -Raw
    if ($text -notmatch 'com.google.gms.google-services') {
        $replacement = '$1' + "`r`n    id 'com.google.gms.google-services'"
        $text = $text -replace '(plugins\s*\{)', $replacement
        Set-Content $AppGroovy $text -Encoding UTF8
    }
}

Write-Host 'Firebase Android Gradle integration enabled.' -ForegroundColor Green
Write-Host 'Run flutter clean, flutter pub get, then build/run Homi.'
