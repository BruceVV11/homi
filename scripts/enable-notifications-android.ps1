$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml'
$GradleKts = Join-Path $ProjectRoot 'android\app\build.gradle.kts'
$GradleGroovy = Join-Path $ProjectRoot 'android\app\build.gradle'
$NotificationSource = Join-Path $ProjectRoot 'assets\brand\homi_monochrome.png'
$DrawableDir = Join-Path $ProjectRoot 'android\app\src\main\res\drawable'
$NotificationIcon = Join-Path $DrawableDir 'homi_notification.png'

if (-not (Test-Path $Manifest)) {
    throw "AndroidManifest.xml was not found at $Manifest"
}
if (-not (Test-Path $NotificationSource)) {
    throw "The approved Homi monochrome notification asset was not found at $NotificationSource"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$xml = [System.IO.File]::ReadAllText($Manifest)

$permissions = @(
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED'
)

foreach ($permission in $permissions) {
    if ($xml -notmatch [regex]::Escape($permission)) {
        $line = "    <uses-permission android:name=`"$permission`" />"
        $xml = $xml -replace '(\s*<application\b)', "`r`n$line`r`n`$1"
    }
}

$scheduledReceiver = 'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'
if ($xml -notmatch [regex]::Escape($scheduledReceiver)) {
    $receiverMarkup = @"

        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
"@
    $xml = [regex]::Replace(
        $xml,
        '(?s)(</application>)',
        { param($match) $receiverMarkup + "`r`n    " + $match.Groups[1].Value },
        1
    )
}

[System.IO.File]::WriteAllText($Manifest, $xml, $utf8NoBom)

if (-not (Test-Path $DrawableDir)) {
    New-Item -ItemType Directory -Path $DrawableDir -Force | Out-Null
}
Copy-Item -Path $NotificationSource -Destination $NotificationIcon -Force

$gradlePath = $null
if (Test-Path $GradleKts) {
    $gradlePath = $GradleKts
} elseif (Test-Path $GradleGroovy) {
    $gradlePath = $GradleGroovy
} else {
    throw 'No Android app Gradle file was found.'
}

$gradle = [System.IO.File]::ReadAllText($gradlePath)

if ($gradlePath.EndsWith('.kts')) {
    if ($gradle -notmatch 'isCoreLibraryDesugaringEnabled\s*=\s*true') {
        if ($gradle -match '(?s)compileOptions\s*\{') {
            $gradle = [regex]::Replace(
                $gradle,
                '(compileOptions\s*\{)',
                "`$1`r`n        isCoreLibraryDesugaringEnabled = true",
                1
            )
        } else {
            throw 'The Kotlin Gradle file has no compileOptions block to patch for notification desugaring.'
        }
    }

    if ($gradle -notmatch 'coreLibraryDesugaring\("com\.android\.tools:desugar_jdk_libs:') {
        if ($gradle -match '(?m)^dependencies\s*\{') {
            $gradle = [regex]::Replace(
                $gradle,
                '(?m)^(dependencies\s*\{)',
                "`$1`r`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs:2.1.5`")",
                1
            )
        } else {
            $gradle += @"


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
"@
        }
    }
} else {
    if ($gradle -notmatch 'coreLibraryDesugaringEnabled\s+true') {
        if ($gradle -match '(?s)compileOptions\s*\{') {
            $gradle = [regex]::Replace(
                $gradle,
                '(compileOptions\s*\{)',
                "`$1`r`n        coreLibraryDesugaringEnabled true",
                1
            )
        } else {
            throw 'The Groovy Gradle file has no compileOptions block to patch for notification desugaring.'
        }
    }

    if ($gradle -notmatch 'coreLibraryDesugaring\s+["'']com\.android\.tools:desugar_jdk_libs:') {
        if ($gradle -match '(?m)^dependencies\s*\{') {
            $gradle = [regex]::Replace(
                $gradle,
                '(?m)^(dependencies\s*\{)',
                "`$1`r`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'",
                1
            )
        } else {
            $gradle += @"


dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'
}
"@
        }
    }
}

[System.IO.File]::WriteAllText($gradlePath, $gradle, $utf8NoBom)

$updatedXml = [System.IO.File]::ReadAllText($Manifest)
foreach ($permission in $permissions) {
    if ($updatedXml -notmatch [regex]::Escape($permission)) {
        throw "Android notification permission patch failed for $permission"
    }
}
if ($updatedXml -notmatch [regex]::Escape($scheduledReceiver)) {
    throw 'Scheduled notification receiver was not added to AndroidManifest.xml.'
}
if (-not (Test-Path $NotificationIcon)) {
    throw 'Homi notification icon was not copied into Android resources.'
}

$updatedGradle = [System.IO.File]::ReadAllText($gradlePath)
if ($gradlePath.EndsWith('.kts')) {
    if ($updatedGradle -notmatch 'isCoreLibraryDesugaringEnabled\s*=\s*true' -or
        $updatedGradle -notmatch 'coreLibraryDesugaring\("com\.android\.tools:desugar_jdk_libs:2\.1\.5"\)') {
        throw 'Core library desugaring was not configured correctly in build.gradle.kts.'
    }
} else {
    if ($updatedGradle -notmatch 'coreLibraryDesugaringEnabled\s+true' -or
        $updatedGradle -notmatch 'com\.android\.tools:desugar_jdk_libs:2\.1\.5') {
        throw 'Core library desugaring was not configured correctly in build.gradle.'
    }
}

Write-Host 'Homi Android notification host integration enabled.' -ForegroundColor Green
Write-Host 'Added/verified notification permission, reboot rescheduling, exact Homi status icon and core-library desugaring.'
Write-Host 'No Firebase, Maps, signing or secret values were printed or changed.'
