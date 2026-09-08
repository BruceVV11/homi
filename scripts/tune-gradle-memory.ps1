$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'
$GradleProperties = Join-Path $AndroidDir 'gradle.properties'

if (-not (Test-Path $GradleProperties)) {
    throw "Missing $GradleProperties. Run scripts\bootstrap-android.ps1 first."
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    # Windows PowerShell 5.1 writes a UTF-8 BOM when Set-Content -Encoding UTF8
    # is used. A BOM on the first line of gradle.properties becomes part of the
    # first property key, so Gradle can miss org.gradle.jvmargs entirely and
    # fall back to its small default heap. Write UTF-8 explicitly without BOM.
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

$totalRamGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

# Homi is currently built on a development machine with ~12 GB RAM. Flutter
# 3.41.5's generated Android template reserves an 8 GB Gradle heap, which is
# too aggressive once Windows + Android Studio are also resident. D8 then
# failed during mergeExtDexDebug with Java heap pressure. For machines under
# 16 GB, use a smaller heap and a single Gradle worker to reduce concurrent
# dexing memory. Larger machines keep a more permissive profile.
if ($totalRamGb -lt 16) {
    $jvmArgs = '-Xmx4G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError'
    $workers = '1'
} elseif ($totalRamGb -lt 24) {
    $jvmArgs = '-Xmx6G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError'
    $workers = '2'
} else {
    $jvmArgs = '-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError'
    $workers = '4'
}

$lines = Get-Content $GradleProperties
$filtered = $lines | Where-Object {
    $_ -notmatch '^\s*org\.gradle\.jvmargs\s*=' -and
    $_ -notmatch '^\s*org\.gradle\.workers\.max\s*=' -and
    $_ -notmatch '^\s*org\.gradle\.parallel\s*='
}

$updated = @()
$updated += "org.gradle.jvmargs=$jvmArgs"
$updated += "org.gradle.workers.max=$workers"
$updated += 'org.gradle.parallel=false'
$updated += $filtered
Write-Utf8NoBom -Path $GradleProperties -Lines $updated

Write-Host "Homi Gradle memory profile applied." -ForegroundColor Green
Write-Host "Detected RAM: $totalRamGb GB"
Write-Host "Gradle heap: $jvmArgs"
Write-Host "Gradle workers: $workers"
Write-Host "Parallel project execution: false"

Push-Location $AndroidDir
try {
    & .\gradlew.bat --stop | Out-Host
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Old Gradle daemons stopped. Return to Android Studio and click Run again.' -ForegroundColor Green
