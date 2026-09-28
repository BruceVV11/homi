param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$androidRoot = Join-Path $ProjectRoot "android"
$resRoot = Join-Path $androidRoot "app\src\main\res"
$drawableIcon = Join-Path $resRoot "drawable\homi_notification.png"
$rawDir = Join-Path $resRoot "raw"
$keepFile = Join-Path $rawDir "keep.xml"
$manifest = Join-Path $androidRoot "app\src\main\AndroidManifest.xml"

if (-not (Test-Path $androidRoot)) {
    throw "Android host project is missing: $androidRoot"
}

if (-not (Test-Path $drawableIcon)) {
    throw "Required Homi notification icon is missing: $drawableIcon"
}

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

@'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/homi_notification" />
'@ | Set-Content -Path $keepFile -Encoding UTF8

if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml is missing: $manifest"
}

$manifestText = Get-Content -Path $manifest -Raw
$metadataName = "com.google.firebase.messaging.default_notification_icon"

if ($manifestText -notmatch [regex]::Escape($metadataName)) {
    $metadata = @'
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/homi_notification" />
'@

    if ($manifestText -notmatch "</application>") {
        throw "Could not locate </application> in AndroidManifest.xml"
    }

    $replacement = $metadata + [Environment]::NewLine + "    </application>"
    $manifestText = $manifestText -replace "</application>", $replacement
    Set-Content -Path $manifest -Value $manifestText -Encoding UTF8
}

Write-Host "Homi Android notification release resources prepared."
Write-Host "keep.xml: $keepFile"
Write-Host "default FCM icon metadata: present"
