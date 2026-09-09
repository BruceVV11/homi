# Homi Release Notes

## 0.3.0 - Navigation identity, Quick Reset and profile controls

### Device feedback incorporated - 2026-09-09

- Reworked the custom bottom navigation from the detached raised-circle treatment after the 0.2.0 Samsung S25 Ultra review.
- The navigation bar now has a shaped top edge that rises into the selected destination, closer to the integrated active-button reference approved in the device feedback.
- Reordered the five primary destinations to **Overview, Routines, Home, Supplies, People**, putting Home in the centre.
- The centre Home destination continues to use the exact approved Homi mark rather than a generic house icon.
- Renamed the former Today destination to **Overview** in navigation because the page is the at-a-glance home status and quick-action surface rather than a calendar-style Today screen.

### Overview and Quick Reset

- Removed remaining placeholder attention examples from the Overview so its cards are now driven only by real local routines, supply attention and quick reminders.
- Renamed the leading section to `What needs attention` and added a real empty state when nothing currently needs attention.
- Renamed the loose capture action to **Quick add** with launch-ready wording.
- Turned `When you have time` into a real **Quick Reset** feature rather than a fixed demonstration list.
- Quick Reset now uses incomplete saved routines first and respects a per-routine estimated duration so a 10- or 30-minute plan stays within the selected time budget.
- When a plan has spare time, Homi can fill it with small household suggestions such as refilling pet water, wiping kitchen counters or emptying recycling.
- Completing a saved routine inside Quick Reset updates the real persisted Routine record. One-off Homi suggestions are checked only for the current Quick Reset session.
- Added a user-facing `How it works` explanation so the feature can be understood without setup knowledge.

### Routines

- Added an `estimatedMinutes` field to Routine records, with a safe 10-minute default for existing locally stored routines created before 0.3.0.
- Added a `Usually takes` selector when creating a Routine.
- Replaced generic `Useful categories` cards with tappable real-world examples such as feeding pets, taking bins out, changing bed linen and watering indoor plants.
- Example cards prefill the Routine editor and can be adjusted before saving.
- Simplified Routine metadata presentation to a single readable line containing category, frequency and approximate duration.
- Refined Routine wording so the page reads as finished product UI rather than implementation guidance.

### Supplies

- Replaced the rounded status chips on Supply cards with a quieter status line using a small semantic dot and text.
- Renamed the normal state from `All good` to **In stock** and `Eat soon` to **Use soon**.
- Expiry dates now contribute automatically to supply attention: an otherwise in-stock item becomes `Use soon` within three days of expiry, and past dates display `Expired`.
- `Use soon` is therefore derived from the expiry date instead of being a manual stock-status choice.
- Overview and Supplies summary counts both use the same expiry-aware status logic.

### Account and profile

- Expanded the persistent profile control into a useful account sheet showing the signed-in identity, email-verification state and sign-in provider.
- Added a **Profile settings** destination from that account sheet.
- Profile settings now supports changing the Firebase display name, seeing the account email, seeing whether the account uses Google or email/password, checking email-verification status and refreshing that status.
- Email/password accounts can resend the verification email and request a password reset from Profile settings.
- Google-authenticated accounts show a Google provider mark beside the displayed account name and in the sign-in-method row so the user can recognise how the account was created.
- The persistent profile control uses the Firebase profile photo when one is available and falls back to the Homi person icon otherwise.
- Google cancellation now returns cleanly to the sign-in screen instead of being presented as an error.

### Launch-copy pass

- Removed developer-facing wording such as references to `this build`, future passes and implementation foundations from visible People/Auth/Overview UI.
- Reworded People privacy information as stable product behaviour: location sharing is opt-in, connecting with someone does not enable sharing automatically, current-location features use the latest status, and location history is not retained by default.
- Reworded empty and explanatory states across the affected pages to address the user rather than describe development progress.

### Data model and tests

- Added `QuickResetPlanner` and deterministic Quick Reset task/source models.
- Added tests for Routine duration persistence and migration defaults.
- Added tests for expiry-derived Supply attention and expired labels.
- Added tests confirming Quick Reset prioritises saved routines that fit the requested time budget and never exceeds that budget.
- Bumped the Flutter application version to `0.3.0+3`.

### 0.3.0 verification checkpoint

This source pass is implemented in GitHub but has not yet been compiled or device-reviewed on the local Flutter/Android toolchain.

Required checkpoint:

1. pull the latest `main` locally;
2. run `flutter analyze` and resolve any analyzer issues;
3. run `flutter test` and resolve any failing tests;
4. run Homi from Android Studio on the Samsung S25 Ultra;
5. review the shaped bottom navigation in every selected state, especially the centred Homi Home destination;
6. verify Overview attention states, Quick Add and both 10- and 30-minute Quick Reset flows;
7. verify Routine creation with duration, example prefills and persistence after restart;
8. verify expiry-driven Supply status and the quieter status-line styling;
9. verify email/password and Google account sheets, provider indicator, verification state and Profile settings;
10. recheck horizontal swipe navigation, Android Back, local-only use and People location capture.

## 0.2.0 - Shell refinement and local household tools

### Device baseline confirmed - 2026-09-09

- The first Homi Android build launched successfully on the real Samsung S25 Ultra.
- The verified Gradle daemon now starts on JDK 21 with a 4 GB heap, one worker and parallel project execution disabled on the current ~12 GB development PC.
- The previously observed D8 `Java heap space` failure was caused by Gradle falling back to a 512 MB daemon heap because the first `gradle.properties` key was not being recognised. The self-verifying memory helper now confirms the effective daemon heap before device builds.

### Shell and navigation refinement

- Moved the exact Homi logo into a single persistent shell header at the top-left, aligned with the persistent account/profile control at the top-right.
- Removed the duplicate in-page logo from Today so the greeting now begins directly below the persistent shell header.
- Replaced the fixed `IndexedStack` shell with a `PageView` so the five primary destinations can be changed by horizontal swipe while the top shell remains intact.
- Preserved Android Back behavior so Back from a secondary primary destination returns to Today before normal root exit behavior.
- Reworked page scrolling to use clamped physics and normal bottom content padding instead of the previous large 120 px tail, removing the unnecessary blank-scroll area on short pages.
- Replaced the stock Material `NavigationBar` with a custom Homi bottom navigation treatment using a raised animated active bubble, persistent labels and brand colors.
- The exact Homi mark is now used as the Home destination icon with the Home label retained.

### Functional expansion

- Added a real local-first Routine model with stable UUID identity, title, category, frequency, completion state and last-completed timestamp.
- Added local Routine create, complete/reopen and remove flows with branded sheets and destructive confirmation.
- Added a real local-first Supply model with stable UUID identity, category, status and optional expiry date.
- Added Supply create, status update, optional expiry-date selection and remove flows.
- Routine and Supply records persist through SharedPreferences and survive app restarts without requiring an account.
- Today now surfaces real open-Routine and Supply-attention counts when the user has created data, with direct navigation into the relevant page.
- Added JSON round-trip unit coverage for the new Routine and Supply local models.

### People refinement

- Removed the large location/privacy callout that previously dominated the top of People.
- Added a compact opt-in disclosure below the current-device location card.
- The disclosure opens a fuller privacy/location bottom sheet explaining that sharing is explicit, invitations do not start tracking, the current build stores only the latest location/battery snapshot, and future continuous sharing must remain easy to stop.
- Existing foreground location/battery capture and latest-snapshot private Firestore sync remain unchanged.

### Documentation and continuity

- Bumped the Flutter app version to `0.2.0+2`.
- Added top-level `NEXT_CHAT_PROMPT.md` as the handoff prompt for the next development chat and established that it should be refreshed every pass.
- Updated architecture notes to reflect local Routine/Supply persistence and the persistent PageView shell.

### 0.2.0 verification checkpoint

This source pass has been implemented in GitHub but must still be compiled and reviewed on the local Flutter/Android toolchain before it is called device-verified.

Required checkpoint:

1. pull `main` locally;
2. run `flutter analyze` and resolve any analyzer issues;
3. run `flutter test` and resolve any failing tests;
4. run Homi on the Samsung S25 Ultra;
5. verify the persistent header, horizontal swiping, custom bottom navigation, no blank-scroll tail, Routine persistence, Supply persistence, Android Back behavior and People location disclosure;
6. re-check local-only and signed-in behavior plus current location/battery capture.

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
- Root cause investigation identified the UTF-8 BOM risk on the first Gradle property, but the first BOM-safe helper revision itself failed in Windows PowerShell because its mandatory string-array parameter rejected an empty line already present in `gradle.properties`; therefore the file was never rewritten and the fresh daemon correctly remained at `-Xmx512m`.
- Reworked both `scripts/tune-gradle-memory.ps1` and `scripts/configure-gradle-jdk.ps1` to write the complete file directly with `.NET WriteAllText` using UTF-8 without BOM, avoiding PowerShell array binding entirely.
- The memory tuner now removes irrelevant blank lines, verifies the file does not start with BOM bytes, stops stale daemons, starts a fresh Gradle daemon itself, reads the newest daemon log, and fails unless the real daemon reports the requested heap such as `-Xmx4G`.
- The corrected tuner completed successfully on the development PC. `gradle.properties` begins with bytes `6F 72 67`, confirming no UTF-8 BOM, and a fresh Gradle 8.14 daemon started on JDK 21 with `-Xmx4G`, 2 GB metaspace, one worker and parallel project execution disabled.
- The verification build completed successfully and the daemon log explicitly reported `Starting build in new daemon [memory: 4 GiB]`.
- The first real Homi Android build subsequently launched successfully on the Samsung S25 Ultra.
