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
$xmlDir = Join-Path $resRoot "xml"
$backupRulesFile = Join-Path $xmlDir "backup_rules.xml"
$dataExtractionRulesFile = Join-Path $xmlDir "data_extraction_rules.xml"
$manifest = Join-Path $androidRoot "app\src\main\AndroidManifest.xml"

if (-not (Test-Path $androidRoot)) {
    throw "Android host project is missing: $androidRoot"
}

if (-not (Test-Path $drawableIcon)) {
    throw "Required Homi notification icon is missing: $drawableIcon"
}

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $xmlDir | Out-Null

@'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/homi_notification" />
'@ | Set-Content -Path $keepFile -Encoding UTF8

# Homi intentionally treats SharedPreferences/local household state, cached
# location/check-in state and device registration state as device-local. Do not
# copy those stores through Android cloud backup or device-to-device transfer.
@'
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
</full-backup-content>
'@ | Set-Content -Path $backupRulesFile -Encoding UTF8

@'
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup disableIfNoEncryptionCapabilities="true">
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
        <exclude domain="device_root" path="." />
        <exclude domain="device_file" path="." />
        <exclude domain="device_database" path="." />
        <exclude domain="device_sharedpref" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
        <exclude domain="device_root" path="." />
        <exclude domain="device_file" path="." />
        <exclude domain="device_database" path="." />
        <exclude domain="device_sharedpref" path="." />
    </device-transfer>
</data-extraction-rules>
'@ | Set-Content -Path $dataExtractionRulesFile -Encoding UTF8

if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml is missing: $manifest"
}

$manifestText = Get-Content -Path $manifest -Raw

function Set-HomiApplicationAttribute {
    param(
        [string]$Text,
        [string]$Name,
        [string]$Value
    )

    $qualified = "android:$Name"
    $pattern = [regex]::Escape($qualified) + '\s*=\s*"[^"]*"'

    if ($Text -match $pattern) {
        $replacement = $qualified + '="' + $Value + '"'
        return [regex]::Replace($Text, $pattern, $replacement, 1)
    }

    if ($Text -notmatch '<application\b') {
        throw "Could not locate <application> in AndroidManifest.xml"
    }

    $attribute = [Environment]::NewLine + '        ' + $qualified + '="' + $Value + '"'
    return [regex]::Replace(
        $Text,
        '<application\b',
        '<application' + $attribute,
        1
    )
}

$manifestText = Set-HomiApplicationAttribute -Text $manifestText -Name "allowBackup" -Value "false"
$manifestText = Set-HomiApplicationAttribute -Text $manifestText -Name "fullBackupContent" -Value "@xml/backup_rules"
$manifestText = Set-HomiApplicationAttribute -Text $manifestText -Name "dataExtractionRules" -Value "@xml/data_extraction_rules"

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
}

Set-Content -Path $manifest -Value $manifestText -Encoding UTF8

Write-Host "Homi Android release hardening prepared."
Write-Host "keep.xml: $keepFile"
Write-Host "backup rules: $backupRulesFile"
Write-Host "Android 12+ data extraction rules: $dataExtractionRulesFile"
Write-Host "allowBackup=false: present"
Write-Host "default FCM icon metadata: present"
