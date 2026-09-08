param(
    [switch]$RunSigningReport
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'
$GradleProperties = Join-Path $AndroidDir 'gradle.properties'

if (-not (Test-Path $AndroidDir)) {
    throw "Android host not found at $AndroidDir. Run scripts\bootstrap-android.ps1 first."
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    # Windows PowerShell 5.1 writes a UTF-8 BOM with Set-Content -Encoding UTF8.
    # A BOM on the first gradle.properties key can make Gradle ignore that key,
    # including org.gradle.jvmargs. Always keep this file UTF-8 without BOM.
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Get-JavaMajor {
    param([Parameter(Mandatory = $true)][string]$JavaHome)

    $JavaExe = Join-Path $JavaHome 'bin\java.exe'
    if (-not (Test-Path $JavaExe)) {
        return $null
    }

    # java -version writes its version text to STDERR even when it succeeds.
    # Calling it directly while $ErrorActionPreference='Stop' can therefore be
    # surfaced by Windows PowerShell as NativeCommandError. Use Process APIs so
    # STDERR is captured as normal probe output instead of becoming a script
    # failure.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $JavaExe
    $startInfo.Arguments = '-version'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        return $null
    }

    $Output = "$stdout`n$stderr"
    $Match = [regex]::Match($Output, 'version\s+"(?<major>\d+)')
    if (-not $Match.Success) {
        $Match = [regex]::Match($Output, 'openjdk\s+(?<major>\d+)')
    }
    if (-not $Match.Success) {
        return $null
    }

    return [int]$Match.Groups['major'].Value
}

$candidatePaths = New-Object System.Collections.Generic.List[string]

function Add-Candidate {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if ((Test-Path $Path) -and -not $candidatePaths.Contains($Path)) {
        $candidatePaths.Add($Path)
    }
}

# Prefer common JDK 21 installations before the current JAVA_HOME. Gradle 8.14
# cannot reliably run on Java 25, while Java 21 is fully supported.
$patterns = @(
    'C:\Program Files\Eclipse Adoptium\jdk-21*',
    'C:\Program Files\Microsoft\jdk-21*',
    'C:\Program Files\Java\jdk-21*',
    'C:\Program Files\Amazon Corretto\jdk21*'
)

foreach ($pattern in $patterns) {
    Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object {
        Add-Candidate $_.FullName
    }
}

Add-Candidate 'C:\Program Files\Android\Android Studio\jbr'
Add-Candidate $env:JAVA_HOME

# Also consider other installed Java versions, but only if they are in the
# range Gradle 8.14 supports for running the daemon.
$otherPatterns = @(
    'C:\Program Files\Eclipse Adoptium\jdk-*',
    'C:\Program Files\Microsoft\jdk-*',
    'C:\Program Files\Java\jdk-*',
    'C:\Program Files\Amazon Corretto\jdk*'
)
foreach ($pattern in $otherPatterns) {
    Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object {
        Add-Candidate $_.FullName
    }
}

$compatible = @()
$inspected = @()
foreach ($candidate in $candidatePaths) {
    $major = Get-JavaMajor -JavaHome $candidate
    if ($null -eq $major) { continue }
    $inspected += [pscustomobject]@{ Home = $candidate; Major = $major }
    if ($major -ge 17 -and $major -le 24) {
        $priority = if ($major -eq 21) { 0 } elseif ($major -eq 17) { 1 } else { 2 + [math]::Abs(21 - $major) }
        $compatible += [pscustomobject]@{ Home = $candidate; Major = $major; Priority = $priority }
    }
}

if ($compatible.Count -eq 0) {
    Write-Host ''
    Write-Host 'No compatible JDK was found for this Gradle 8.14 project.' -ForegroundColor Red
    if ($inspected.Count -gt 0) {
        Write-Host 'Detected Java installations:'
        $inspected | Format-Table Major, Home -AutoSize
    }
    Write-Host ''
    Write-Host 'Homi should use JDK 21 for Gradle. Install a JDK 21 distribution, then rerun this script.' -ForegroundColor Yellow
    exit 2
}

$selected = $compatible | Sort-Object Priority, Major | Select-Object -First 1
$javaHome = $selected.Home
$javaHomeForGradle = $javaHome.Replace('\', '/')

Write-Host "==> Using JDK $($selected.Major) for Homi Gradle" -ForegroundColor Green
Write-Host "    $javaHome"

$existing = if (Test-Path $GradleProperties) { Get-Content $GradleProperties } else { @() }
$filtered = $existing | Where-Object { $_ -notmatch '^\s*org\.gradle\.java\.home\s*=' }
$updated = @($filtered)
if ($updated.Count -gt 0 -and $updated[-1] -ne '') { $updated += '' }
$updated += "org.gradle.java.home=$javaHomeForGradle"
Write-Utf8NoBom -Path $GradleProperties -Lines $updated

# Make the same JDK active for this PowerShell process so gradlew.bat itself
# is not launched by an unsupported Java 25 installation.
$env:JAVA_HOME = $javaHome
$env:Path = "$(Join-Path $javaHome 'bin');$env:Path"

Push-Location $AndroidDir
try {
    & .\gradlew.bat --stop | Out-Host
    Write-Host ''
    Write-Host '==> Verifying Gradle JVM'
    & .\gradlew.bat --version | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle verification failed with exit code $LASTEXITCODE"
    }

    if ($RunSigningReport) {
        Write-Host ''
        Write-Host '==> Generating Android signing fingerprints'
        & .\gradlew.bat signingReport | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "signingReport failed with exit code $LASTEXITCODE"
        }
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Compatible Gradle JDK configuration saved in android\gradle.properties.' -ForegroundColor Green
if (-not $RunSigningReport) {
    Write-Host 'Next command:'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\configure-gradle-jdk.ps1 -RunSigningReport'
}
