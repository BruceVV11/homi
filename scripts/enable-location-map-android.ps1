$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml'
$SecretsXml = Join-Path $ProjectRoot 'android\app\src\main\res\values\homi_secrets.xml'
$GradleKts = Join-Path $ProjectRoot 'android\app\build.gradle.kts'
$GradleGroovy = Join-Path $ProjectRoot 'android\app\build.gradle'

if (-not (Test-Path $Manifest)) {
    throw "AndroidManifest.xml was not found at $Manifest"
}

if (-not (Test-Path $SecretsXml)) {
    throw "Homi Android secrets resource is missing. Run scripts\sync-android-secrets.ps1 first."
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
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

[System.IO.File]::WriteAllText($Manifest, $xml, $utf8NoBom)

$gradlePath = $null
if (Test-Path $GradleKts) {
    $gradlePath = $GradleKts
} elseif (Test-Path $GradleGroovy) {
    $gradlePath = $GradleGroovy
}

if ($null -ne $gradlePath) {
    $gradle = [System.IO.File]::ReadAllText($gradlePath)
    if ($gradlePath.EndsWith('.kts')) {
        if ($gradle -match 'minSdk\s*=\s*flutter\.minSdkVersion') {
            $gradle = $gradle -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
        } elseif ($gradle -match 'minSdk\s*=\s*\d+') {
            $gradle = [regex]::Replace(
                $gradle,
                'minSdk\s*=\s*\d+',
                'minSdk = 24',
                1
            )
        }
    } else {
        if ($gradle -match 'minSdkVersion\s+flutter\.minSdkVersion') {
            $gradle = $gradle -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
        } elseif ($gradle -match 'minSdkVersion\s+\d+') {
            $gradle = [regex]::Replace(
                $gradle,
                'minSdkVersion\s+\d+',
                'minSdkVersion 24',
                1
            )
        }
    }
    [System.IO.File]::WriteAllText($gradlePath, $gradle, $utf8NoBom)
}

$updated = [System.IO.File]::ReadAllText($Manifest)
foreach ($permission in $permissions) {
    if ($updated -notmatch [regex]::Escape($permission)) {
        throw "Android permission patch failed for $permission"
    }
}
if ($updated -notmatch [regex]::Escape($mapsMetaName)) {
    throw 'Google Maps API-key metadata was not added to AndroidManifest.xml.'
}

if ($null -ne $gradlePath) {
    $updatedGradle = [System.IO.File]::ReadAllText($gradlePath)
    if ($updatedGradle -notmatch '(minSdk\s*=\s*24|minSdkVersion\s+24)') {
        throw 'Android min SDK was not set to 24 for Google Maps support.'
    }
}

Write-Host 'Homi Android location/Maps host integration enabled.' -ForegroundColor Green
Write-Host 'Added/verified background location, foreground location service, notifications, Maps metadata and min SDK 24.'
Write-Host 'No API key value was printed or changed.'
