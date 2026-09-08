$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'
$TempRoot = Join-Path $env:TEMP ('homi-flutter-host-' + [guid]::NewGuid().ToString('N'))

Write-Host '==> Checking Flutter'
flutter --version

if (-not (Test-Path $AndroidDir)) {
    Write-Host '==> Generating Android host with your installed Flutter version'
    flutter create --platforms=android --org za.co.theconceptlab --project-name homi --android-language kotlin $TempRoot
    Copy-Item -Path (Join-Path $TempRoot 'android') -Destination $AndroidDir -Recurse
    if (-not (Test-Path (Join-Path $ProjectRoot '.metadata'))) {
        Copy-Item -Path (Join-Path $TempRoot '.metadata') -Destination (Join-Path $ProjectRoot '.metadata')
    }
} else {
    Write-Host '==> Android host already exists; preserving it'
}

Write-Host '==> Installing Flutter packages'
Push-Location $ProjectRoot
try {
    flutter pub get
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
} finally {
    Pop-Location
}

$Manifest = Join-Path $AndroidDir 'app\src\main\AndroidManifest.xml'
if (Test-Path $Manifest) {
    $xml = Get-Content $Manifest -Raw
    $permissions = @"
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
"@
    if ($xml -notmatch 'ACCESS_FINE_LOCATION') {
        $xml = $xml -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', "<manifest xmlns:android=`"http://schemas.android.com/apk/res/android`">`r`n$permissions"
    }
    Set-Content -Path $Manifest -Value $xml -Encoding UTF8
}

$SecretsXml = Join-Path $AndroidDir 'app\src\main\res\values\homi_secrets.xml'
$SecretsDir = Split-Path -Parent $SecretsXml
New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null
if (-not (Test-Path $SecretsXml)) {
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="google_maps_key" translatable="false"></string>
</resources>
'@ | Set-Content -Path $SecretsXml -Encoding UTF8
}

if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }

$GradleJdkHelper = Join-Path $PSScriptRoot 'configure-gradle-jdk.ps1'
if (Test-Path $GradleJdkHelper) {
    Write-Host '==> Checking Gradle JDK compatibility'
    & powershell -ExecutionPolicy Bypass -File $GradleJdkHelper
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle JDK compatibility setup failed with exit code $LASTEXITCODE"
    }
}

Write-Host ''
Write-Host 'Android host is ready.' -ForegroundColor Green
Write-Host 'Next command:'
Write-Host "  cd $ProjectRoot"
Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\configure-gradle-jdk.ps1 -RunSigningReport'
