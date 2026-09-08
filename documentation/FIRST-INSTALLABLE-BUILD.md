# Homi v0.1.0 - First installable Android pass

## Product state in this pass

This pass turns the repository foundation into a device-ready Flutter application source with the approved Homi identity locked in.

Implemented:

- approved Homi master logo lockup and app-icon artwork;
- coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E` design tokens;
- Nunito UI via Google Fonts;
- branded native splash generation configuration;
- adaptive Android launcher icon, legacy icon and monochrome/themed-icon source;
- first-run onboarding with home name/type;
- local-first use without an account;
- email/password account creation and sign-in;
- Google sign-in integration;
- password reset and email verification trigger on account creation;
- five-destination app shell: Today, Home, Routines, Supplies, People;
- Android predictive-back behavior from secondary tabs to Today;
- foreground device location + battery status capture in People;
- private sync of the signed-in user's latest foreground location snapshot to Firestore;
- App Check debug provider for debug builds and Play Integrity provider for release builds;
- Android host bootstrap scripts that preserve the user's installed Flutter/Gradle template.

Not yet enabled in v0.1.0:

- continuous/background location sharing;
- trusted-person invitations and mutual sharing;
- map UI and Places alerts;
- Drive document upload/backup UI;
- full household CRUD modules;
- subscriptions/payments.

These are deliberately subsequent passes rather than placeholder controls that pretend to work.

## Why the Android host is generated locally

The repository did not yet contain an `android/` host. Homi's bootstrap script generates that host using the Flutter version installed on the development PC, so Gradle/Kotlin/Android plugin versions match the user's real Android Studio environment instead of committing a guessed template.

Run from PowerShell:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-android.ps1
```

The script keeps the approved app source and assets intact, creates only the missing Android host, installs packages, generates launcher resources and generates the native splash.

## Fingerprint checkpoint

After the host exists:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Add the debug SHA-1 and SHA-256 in Firebase Project settings for `za.co.theconceptlab.homi`.

Then download the refreshed `google-services.json` to:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

Then run:

```powershell
cd C:\ConceptLab\Projects\homi
powershell -ExecutionPolicy Bypass -File .\scripts\enable-firebase-android.ps1
flutter clean
flutter pub get
```

## Maps key checkpoint

After SHA-1 exists, create the restricted key using the existing Cloud Shell script, place it in root `secrets.properties`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-android-secrets.ps1
```

The first v0.1.0 screen does not require the map key yet; location status uses Android location services directly. The key is prepared now for the next People/map pass.

## Build

From the project root:

```powershell
flutter analyze
flutter test
flutter run
```

For a debug APK:

```powershell
flutter build apk --debug
```

Expected APK path:

`build\app\outputs\flutter-apk\app-debug.apk`
