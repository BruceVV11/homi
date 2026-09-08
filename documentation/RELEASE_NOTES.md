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

### Local compile checkpoint - Java 25 compatibility fixes

- The first local `signingReport` attempt reached the generated Android host but failed before project evaluation because the machine launched Gradle 8.14 with Java `25.0.3`.
- Gradle 8.14 supports running on Java up to 24; Java 25 is officially supported for running Gradle from 9.1.0 onward.
- Homi keeps Flutter 3.41.5's generated Gradle/Android toolchain rather than forcing an unsafe Gradle 9 migration.
- Added `scripts/configure-gradle-jdk.ps1` to discover a compatible installed JDK, prefer JDK 21, persist it for this project in `android/gradle.properties`, verify the Gradle JVM, and optionally run `signingReport`.
- Updated `scripts/bootstrap-android.ps1` so future Android-host setup checks Gradle/JDK compatibility automatically.
- Fixed the JDK discovery probe for Windows PowerShell: `java -version` writes normal version output to STDERR, which was being promoted to `NativeCommandError` under the script's strict error mode. The probe now captures process stdout/stderr directly and checks the real exit code instead.

### Compile/device checkpoint still required

The source pass is not yet claimed as an installed device build.

Next local checkpoint:

1. `git pull` the latest JDK compatibility fix;
2. run `scripts\configure-gradle-jdk.ps1 -RunSigningReport`;
3. register the resulting SHA-1/SHA-256 in Firebase;
4. download the refreshed `google-services.json`;
5. run `scripts\enable-firebase-android.ps1`;
6. run `flutter analyze`, `flutter test`, and `flutter run` on the real Android device.
