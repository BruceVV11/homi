# Homi v0.1.0 - Start Here

## Authoritative project identities

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`

`homi-508000` is not used.

## Completed cloud setup

The cloud bootstrap has completed successfully:

- Firebase exists on `homi-ee80a`;
- Concept Lab Internal billing is linked;
- required APIs are enabled;
- Homi Android is registered as `za.co.theconceptlab.homi`;
- Firestore `(default)` is in Johannesburg (`africa-south1`);
- keyless runtime service account exists;
- Email/Password and Google Firebase Authentication are enabled;
- Google Auth Platform is External / Testing with the development account added.

## Current step - create the real Android host

First update the repository and extract the supplied `homi-v0.1.0-installable-pass-patch.zip` directly into:

`C:\ConceptLab\Projects\homi`

The ZIP contents sit directly at the project root. Do not create another wrapper folder.

Then open PowerShell:

```powershell
cd C:\ConceptLab\Projects\homi
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-android.ps1
```

Expected result:

- `android\` is created using the Flutter SDK installed on your PC;
- package is generated under the Concept Lab namespace;
- Flutter dependencies install;
- the approved Homi launcher icon is generated;
- the approved Homi splash screen is generated;
- foreground Android location permissions are added.

## Certificate fingerprints

After the Android host is generated:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Find the **debug** variant and record:

- SHA-1
- SHA-256

Add both in:

**Firebase Console -> Project settings -> General -> Homi Android -> SHA certificate fingerprints**

Then download a fresh `google-services.json` and save it exactly here:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

## Enable Firebase in the Android Gradle host

After the refreshed JSON exists:

```powershell
cd C:\ConceptLab\Projects\homi
powershell -ExecutionPolicy Bypass -File .\scripts\enable-firebase-android.ps1
flutter clean
flutter pub get
```

## Restricted Maps / Places key

Back in Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/create-android-maps-key.sh 'YOUR:DEBUG:SHA1'
```

Create this local file:

`C:\ConceptLab\Projects\homi\secrets.properties`

```properties
MAPS_API_KEY=the_key_returned_by_cloud_shell
PLACES_API_KEY=the_same_restricted_key
```

Then:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-android-secrets.ps1
```

The v0.1.0 People page does not require a map key to capture foreground GPS/battery status. The key is prepared for the next live map/Places pass.

## App Check

Debug builds use the App Check debug provider. Release builds are configured for Play Integrity.

On the first Firebase-enabled debug launch, Android Studio Logcat will print the App Check debug token. Add that token in:

**Firebase Console -> App Check -> Homi Android -> Manage debug tokens**

Keep enforcement OFF until valid requests are visible.

## Build checkpoint

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

Expected APK location:

`C:\ConceptLab\Projects\homi\build\app\outputs\flutter-apk\app-debug.apk`

## What should be visible in v0.1.0

- real Homi launcher icon;
- Homi cream/coral native splash;
- three-step Homi onboarding;
- home name/type setup;
- optional local-only mode;
- email/password and Google account flow;
- branded Today/Home/Routines/Supplies/People navigation;
- current foreground location and battery status on People;
- private current-status Firestore sync when signed in.
