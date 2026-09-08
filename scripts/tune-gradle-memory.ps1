$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'
$GradleProperties = Join-Path $AndroidDir 'gradle.properties'

if (-not (Test-Path $GradleProperties)) {
    throw "Missing $GradleProperties. Run scripts\bootstrap-android.ps1 first."
}

$totalRamGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

# Homi is currently built on a development machine with ~12 GB RAM. Flutter
# 3.41.5's generated Android template reserves an 8 GB Gradle heap, which is
# too aggressive once Windows + Android Studio are also resident. Keep dexing
# concurrency low on sub-16 GB machines and use a balanced Gradle heap.
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

$lines = @(Get-Content $GradleProperties)
$filtered = @($lines | Where-Object {
    $_ -notmatch '^\s*org\.gradle\.jvmargs\s*=' -and
    $_ -notmatch '^\s*org\.gradle\.workers\.max\s*=' -and
    $_ -notmatch '^\s*org\.gradle\.parallel\s*=' -and
    $_ -notmatch '^\s*$'
})

$updated = @(
    "org.gradle.jvmargs=$jvmArgs",
    "org.gradle.workers.max=$workers",
    'org.gradle.parallel=false'
)
$updated += $filtered

# Windows PowerShell 5.1's Set-Content -Encoding UTF8 writes a BOM. If the BOM
# lands before org.gradle.jvmargs, Gradle can treat it as part of the property
# name and silently fall back to its default 512 MB heap. Write the complete
# file explicitly as UTF-8 without BOM. WriteAllText also avoids PowerShell's
# mandatory-array parameter binding issue when the source file contains blank
# lines.
$encoding = New-Object System.Text.UTF8Encoding($false)
$text = [string]::Join([Environment]::NewLine, [string[]]$updated) + [Environment]::NewLine
[System.IO.File]::WriteAllText($GradleProperties, $text, $encoding)

$bytes = [System.IO.File]::ReadAllBytes($GradleProperties)
if ($bytes.Length -lt 3) {
    throw 'gradle.properties was unexpectedly empty after writing.'
}
$prefix = ($bytes[0..2] | ForEach-Object { $_.ToString('X2') }) -join ' '
if ($prefix -eq 'EF BB BF') {
    throw 'gradle.properties still contains a UTF-8 BOM; refusing to continue.'
}

Write-Host 'Homi Gradle memory profile written.' -ForegroundColor Green
Write-Host "Detected RAM: $totalRamGb GB"
Write-Host "Gradle heap: $jvmArgs"
Write-Host "Gradle workers: $workers"
Write-Host 'Parallel project execution: false'
Write-Host "File prefix bytes: $prefix (expected 6F 72 67 for 'org')"

# Stop all old daemons, then deliberately start one fresh Gradle 8.14 daemon so
# we can prove that the JVM picked up the requested heap before Android Studio
# is allowed to build Homi again.
Push-Location $AndroidDir
try {
    & .\gradlew.bat --stop | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle daemon stop failed with exit code $LASTEXITCODE"
    }

    Write-Host ''
    Write-Host 'Starting a fresh Gradle daemon for verification...'
    & .\gradlew.bat help | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle verification build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$daemonRoot = Join-Path $env:USERPROFILE '.gradle\daemon'
$latestLog = Get-ChildItem $daemonRoot -Recurse -Filter 'daemon-*.out.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -eq $latestLog) {
    throw "Could not locate a Gradle daemon log under $daemonRoot."
}

$daemonLine = Select-String -Path $latestLog.FullName -Pattern 'daemonOpts=' |
    Select-Object -Last 1

if ($null -eq $daemonLine) {
    throw "Could not find daemonOpts in $($latestLog.FullName)."
}

$heapMatch = [regex]::Match($jvmArgs, '-Xmx\S+')
if (-not $heapMatch.Success) {
    throw "Could not determine the requested Gradle heap from: $jvmArgs"
}
$expectedHeap = $heapMatch.Value

if ($daemonLine.Line -notlike "*$expectedHeap*") {
    Write-Host ''
    Write-Host 'Gradle memory verification FAILED.' -ForegroundColor Red
    Write-Host "Expected daemon heap: $expectedHeap"
    Write-Host "Daemon log: $($latestLog.FullName)"
    Write-Host $daemonLine.Line
    throw 'The fresh Gradle daemon did not use the Homi heap setting. Do not run Android Studio yet.'
}

Write-Host ''
Write-Host 'Gradle memory verification PASSED.' -ForegroundColor Green
Write-Host "Effective daemon heap: $expectedHeap"
Write-Host "Daemon log: $($latestLog.FullName)"
Write-Host 'You can now return to Android Studio and click Run.' -ForegroundColor Green
