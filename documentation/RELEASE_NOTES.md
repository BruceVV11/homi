# Homi Release Notes

## 0.1.0 - First installable source pass

### Cloud foundation complete - 2026-09-08

- Locked Firebase / Google Cloud project to `homi-ee80a` (`883068189841`).
- Locked Android application ID to `za.co.theconceptlab.homi`.
- Linked Concept Lab Internal billing.
- Enabled required Firebase, Google Maps/Places, Drive and Google Cloud runtime APIs.
- Registered the Homi Android Firebase app.
- Verified Firestore `(default)` in `africa-south1` (Johannesburg).
- Created keyless backend runtime identity `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`.
- Applied initial Firestore and FCM runtime roles.
- Created no downloadable service-account private key.
- Firebase Email/Password and Google sign-in providers configured.
- Google Auth Platform remains in External / Testing state with the development account added.

### Application source pass - 2026-09-08

- Locked the approved Option 4 Homi logo and app icon as the brand source of truth.
- Added launcher-icon generation for legacy, adaptive and monochrome/themed Android icons.
- Added branded native splash generation.
- Applied the approved coral / peach / sage / cream / slate design system and Nunito typography.
- Added three-step onboarding with home name and home type.
- Preserved local-only use without forcing account creation.
- Added email/password sign-in, account creation, verification email trigger and password reset.
- Added Google sign-in integration.
- Added branded loading/auth states and explicit local validation/error placement.
- Added the five-destination Homi shell: Today, Home, Routines, Supplies, People.
- Added persistent local Quick Add reminders on Today.
- Added working 10-minute and 30-minute time-boxed chore suggestion sheets.
- Added guarded Firestore-rules deployment tooling.
- Added predictive-back behavior from secondary tabs back to Today.
- Added foreground location and battery capture on the People page.
- Added private signed-in Firestore sync for the user's current location/battery snapshot.
- Added App Check debug provider for debug builds and Play Integrity for release builds.
- Added local Android-host bootstrap and Firebase Gradle integration scripts.
- Added first-installable setup documentation and a basic location model test.

### Local compile checkpoint - Java/Gradle resolved

- The first local `signingReport` attempt reached the generated Android host but failed before project evaluation because the machine launched Gradle 8.14 with Java `25.0.3`.
- Homi keeps Flutter 3.41.5's generated Gradle/Android toolchain rather than forcing a Gradle 9 migration.
- Added `scripts/configure-gradle-jdk.ps1` to discover a compatible installed JDK, prefer JDK 21, persist it for this project in `android/gradle.properties`, verify the Gradle JVM, and optionally run `signingReport`.
- Fixed the Windows PowerShell Java-version probe so normal `java -version` STDERR output is not treated as a failure.
- Local Gradle is now verified on JDK 21 from Android Studio's bundled JetBrains Runtime.
- `signingReport` completed successfully with Gradle 8.14.
- Debug SHA-1: `9D:D7:92:98:5C:1C:88:88:97:E7:E4:AC:6F:FD:1B:E4:09:BE:EE:19`.
- Debug SHA-256: `F3:F8:12:F2:B0:16:6B:C1:53:07:76:0C:CE:FC:56:92:25:36:77:D5:24:24:D9:C3:58:1D:23:7C:06:55:46:80`.
- Added `scripts/register-firebase-android-certs.sh` to register both fingerprints against the correct Firebase Android app and refresh `google-services.json` automatically from Cloud Shell.
- Firebase Android certificate registration completed successfully and refreshed `/home/brucevanvliet5/homi-google-services.json`.
- The first Maps/Places key was created with the correct Android package, SHA-1 and API restrictions, but the helper then incorrectly treated the create operation resource name as the key resource name when calling `get-key-string`.
- Fixed `scripts/create-android-maps-key.sh` to resolve the final key resource after the long-running operation and retrieve the key by actual key ID.
- A second troubleshooting run showed that this Cloud SDK writes the create operation result, including the generated key string, to stderr even when stdout is redirected. The helper now captures both stdout and stderr into a temporary file, prints that log only on failure, and deletes the log immediately on success.
- Any Maps key whose value appeared in troubleshooting output must be deleted before local use. The next recreated key should only be written to mode-600 `~/homi-secrets.properties` and must not appear in terminal output.

### Compile/device checkpoint still required

The source pass is not yet claimed as an installed device build.

Next checkpoint:

1. delete the currently exposed development Maps key and recreate it with the latest helper;
2. confirm the recreated key value is not printed anywhere in Cloud Shell;
3. download the fresh `~/homi-secrets.properties` and refreshed `homi-google-services.json` to the local project;
4. run `scripts\enable-firebase-android.ps1` and sync the Maps secret;
5. run `flutter analyze`, `flutter test`, and `flutter run` on the real Android device;
6. register the App Check debug token after the first debug launch.
