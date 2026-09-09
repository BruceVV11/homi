$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml'
$SecretsXml = Join-Path $ProjectRoot 'android\app\src\main\res\values\homi_secrets.xml'

if (-not (Test-Path $Manifest)) {
    throw "AndroidManifest.xml was not found at $Manifest"
}

if (-not (Test-Path $SecretsXml)) {
    throw "Homi Android secrets resource is missing. Run scripts\sync-android-secrets.ps1 first."
}

$xml = [System.IO.File]::ReadAllText($Manifest)

$permissions = @(
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_LOCATION',
    'android.permission.POST_NOTIFICATIONS'
)

foreach ($permission in $permissions) {
    if ($xml -notmatch [regex]::Escape($permission)) {
        $line = "    <uses-permission android:name=`"$permission`" />"
        $xml = $xml -replace '(\s*<application\b)', "`r`n$line`r`n`$1"
    }
}

$mapsMetaName = 'com.google.android.geo.API_KEY'
if ($xml -notmatch [regex]::Escape($mapsMetaName)) {
    $applicationPattern = '(?s)(<application\b.*?>)'
    $metadata = @"

        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="@string/google_maps_key" />
"@
    $xml = [regex]::Replace(
        $xml,
        $applicationPattern,
        { param($match) $match.Groups[1].Value + $metadata },
        1
    )
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Manifest, $xml, $utf8NoBom)

$updated = [System.IO.File]::ReadAllText($Manifest)
foreach ($permission in $permissions) {
    if ($updated -notmatch [regex]::Escape($permission)) {
        throw "Android permission patch failed for $permission"
    }
}
if ($updated -notmatch [regex]::Escape($mapsMetaName)) {
    throw 'Google Maps API-key metadata was not added to AndroidManifest.xml.'
}

Write-Host 'Homi Android location/Maps host integration enabled.' -ForegroundColor Green
Write-Host 'Added/verified background location, foreground location service, notifications and Maps metadata.'
Write-Host 'No API key value was printed or changed.'
