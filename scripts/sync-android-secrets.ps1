$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SecretsFile = Join-Path $ProjectRoot 'secrets.properties'
$Output = Join-Path $ProjectRoot 'android\app\src\main\res\values\homi_secrets.xml'

if (-not (Test-Path $SecretsFile)) { throw "Missing $SecretsFile" }
$values = @{}
Get-Content $SecretsFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') { $values[$matches[1].Trim()] = $matches[2].Trim() }
}
$key = $values['MAPS_API_KEY']
if ([string]::IsNullOrWhiteSpace($key)) { throw 'MAPS_API_KEY is missing from secrets.properties' }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output) | Out-Null
@"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="google_maps_key" translatable="false">$key</string>
</resources>
"@ | Set-Content $Output -Encoding UTF8
Write-Host 'Android Maps key resource updated.' -ForegroundColor Green
