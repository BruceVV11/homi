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
- Any Maps key whose value appeared in troubleshooting output was rotated before local use.
- A fresh Android-restricted Maps/Places development key is now stored only in the local `secrets.properties` flow.
- Refreshed Firebase `google-services.json` is now in `android/app/`.
- `scripts/enable-firebase-android.ps1` completed successfully and enabled the Google Services Gradle plugin.
- `scripts/sync-android-secrets.ps1` completed successfully and generated the Android Maps key resource from the ignored local secret file.
- `flutter test` completed successfully.
- `flutter analyze` identified the deprecated App Check `androidProvider` argument. The first migration changed only the parameter name and exposed a provider-type mismatch during the first Android Studio compile.
- Corrected App Check activation to use typed `AndroidDebugProvider()` in debug builds and `AndroidPlayIntegrityProvider()` in release builds with the new `providerAndroid` API.
- The next Android Studio debug build reached `:app:mergeExtDexDebug` but D8 failed with `java.lang.OutOfMemoryError: Java heap space`.
- The development PC has approximately 11.9 GB RAM while Flutter 3.41.5 generated an 8 GB Gradle heap. No global Gradle override exists.
- Added `scripts/tune-gradle-memory.ps1` to apply a RAM-aware Gradle profile, reduce heap pressure on sub-16 GB development machines, limit worker concurrency, disable parallel project execution and stop stale Gradle daemons before retrying the build.
- Daemon inspection then showed the actual Gradle process was still launching with the default `-Xmx512m`, despite `android/gradle.properties` displaying `-Xmx4G`.
- Root cause: Windows PowerShell 5.1 `Set-Content -Encoding UTF8` writes a UTF-8 BOM. Because `org.gradle.jvmargs` was the first property, the BOM became part of that key and Gradle ignored it, falling back to the 512 MB default heap.
- Updated both `scripts/tune-gradle-memory.ps1` and `scripts/configure-gradle-jdk.ps1` to write `android/gradle.properties` as UTF-8 without BOM so Gradle recognises the first property reliably.

### Compile/device checkpoint still required

The source pass is not yet claimed as an installed device build.

Next checkpoint:

1. pull the BOM-safe Gradle helper updates;
2. rerun `scripts\tune-gradle-memory.ps1` so `android/gradle.properties` is rewritten without BOM and stale daemons are stopped;
3. run Homi again from Android Studio on the real Android device;
4. if needed, verify the new Gradle daemon reports `-Xmx4G` rather than `-Xmx512m`;
5. capture/register the Firebase App Check debug token from the first successful debug launch;
6. verify onboarding, launcher icon/splash, email/password auth, Google sign-in, navigation, location permission and foreground location/battery sync on the real device.
