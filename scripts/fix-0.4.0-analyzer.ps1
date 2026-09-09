$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PeopleFile = Join-Path $ProjectRoot 'lib\src\features\people\people_page.dart'
$RoutinesFile = Join-Path $ProjectRoot 'lib\src\features\routines\routines_page.dart'
$LocationFile = Join-Path $ProjectRoot 'lib\src\services\location_status_service.dart'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Patch-File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Transform
    )

    if (-not (Test-Path $Path)) {
        throw "Required file not found: $Path"
    }

    $before = [System.IO.File]::ReadAllText($Path)
    $after = & $Transform $before

    if ($after -eq $before) {
        Write-Host "No change needed: $Path"
        return
    }

    [System.IO.File]::WriteAllText($Path, $after, $utf8NoBom)
    Write-Host "Patched: $Path" -ForegroundColor Green
}

Write-Host 'Applying Homi 0.4.0 analyzer hotfixes...'

Patch-File -Path $PeopleFile -Transform {
    param($text)
    $text = $text -replace "(?m)^import 'dart:typed_data';\r?\n", ''
    $text = $text -replace "(?m)^import 'package:flutter/painting.dart';\r?\n", ''
    $text = $text -replace 'textDirection: TextDirection\.ltr,', 'textDirection: ui.TextDirection.ltr,'
    return $text
}

Patch-File -Path $RoutinesFile -Transform {
    param($text)
    $text = $text -replace "(?m)^    this\.dayOfMonth,\r?\n", ''
    $text = $text -replace "(?m)^  final int\? dayOfMonth;\r?\n", ''
    $text = $text -replace "text: \(template\?\.dayOfMonth \?\? DateTime\.now\(\)\.day\)\.toString\(\),", 'text: DateTime.now().day.toString(),'
    return $text
}

Patch-File -Path $LocationFile -Transform {
    param($text)
    $text = $text -replace 'settings = const AndroidSettings\(', 'settings = AndroidSettings('
    return $text
}

Write-Host ''
Write-Host 'Running flutter analyze...'
Push-Location $ProjectRoot
try {
    & flutter analyze
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed with exit code $LASTEXITCODE"
    }

    Write-Host ''
    Write-Host 'Running flutter test...'
    & flutter test
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Homi 0.4.0 analyzer hotfix PASSED.' -ForegroundColor Green
Write-Host 'Next: review git diff, then commit/push these three source-file fixes.'
