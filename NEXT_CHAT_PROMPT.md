# Homi — Next Chat Prompt

Continue **Homi** from GitHub `main`. GitHub is source of truth for tracked source/docs.

Use **mobile-app-development** first. For Firebase/Cloud Shell release work also use **concept-lab-release-integrity**. Preserve approved design/behaviour and diagnose from source/log evidence before asking Bruce to rerun anything.

## Permanent project context

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android package: `za.co.theconceptlab.homi`
- Firebase/GCP: `homi-ee80a`
- Project number: `883068189841`
- Firestore/Functions region: `africa-south1`
- Flutter 3.41.5 / Dart 3.11.3
- JDK 21 / Gradle 8.14
- Functions Node 22
- Device: Samsung S25 Ultra / SM S938B
- `android/` is intentionally local/untracked.
- Never request or expose Maps/Places keys, App Check debug tokens, signing secrets or Firebase private credentials.
- Deleted project `homi-508000` must never be used.
- Safety stash `stash@{0}: On main: Homi pre-0.5.0 local tracked changes` must not be popped/deleted automatically.

## Approved product/UI baseline

Brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito, exact assets under `assets/brand/`.

Primary nav remains **Overview · Tasks · Home · Supplies · People** with persistent Homi header/profile row and centered exact Homi Home mark.

People remains the approved **map-first** experience. Do not replace it with a lightweight hub or separate manager page.

## Current source release

Current release line: **0.9.2+13**.

0.9.2 includes:

- full-map reachable **SOS · 112** and emergency-number controls;
- Person Details with Latest location + Home + Work;
- Home/Work exact visibility only with explicit per-place sharing + selected viewer + accepted connection + active owner→viewer location share;
- Safety/check-ins using one Notifications-style persistent ON/OFF toggle card;
- no large green passive help/status boxes and no redundant check-ins-on success box;
- `How it works` with information icon and bottom-sheet education;
- Google Places autocomplete for Home/Work plus **Set from here**;
- arrival recipients shown as profile photo/initial + name;
- People auth lifecycle recovery and one protected-callable token refresh/retry for `unauthenticated`;
- product-friendly error wording instead of raw backend codes.

## Proven Flutter/backend state

Bruce completed the Windows static gate before device build:

- `flutter analyze` → **No issues found**;
- `flutter test` → **32 tests passed**;
- `pubspec.lock` committed.

Bruce then completed the governed 0.9.2 backend deployment successfully:

- Node 22;
- Firestore emulator security suite **13/13 passed**;
- Firestore rules/indexes deployed;
- 24 Functions deployed in batches;
- new `onHomiUserSharedPlacesDeleted` created;
- new `setSharedArrivalPlace` created;
- final status **PASS** / `Homi backend deployment completed.`

Backend deployment source was `d8fb786269feea43223c673e84b2b5a6c499a91f`. Later dependency/docs commits are client/local only. **Do not redeploy Firebase for the Android Places dependency correction.**

## Current Android build failure and fix

First S25 Ultra Gradle build after backend deployment failed inside the third-party package:

`flutter_google_places_sdk_android-0.2.2/android/.../FlutterGooglePlacesSdkPlugin.kt`

with unresolved Kotlin references including:

- `address`
- `latLng`
- `name`
- `nameLanguageCode`
- `phoneNumber`
- `userRatingsTotal`
- `placeTypes`

This is an upstream package failure, not Homi app code. The publisher's changelog explicitly says Android `0.2.2` has build errors and to skip it/use `0.2.3`.

Homi now keeps `flutter_google_places_sdk 0.4.3` but pins:

```yaml
dependency_overrides:
  flutter_google_places_sdk_android: 0.2.3
```

This source fix is **pending Bruce's real Windows resolver/analyzer/test/device-build validation**. The lock file still needs to be regenerated locally so it changes from Android `0.2.2` to `0.2.3`, then committed.

## Important Google Places local-run finding

Bruce's failed Android Studio Flutter command did **not** contain:

`--dart-define=HOMI_PLACES_API_KEY=...`

It only showed Flutter's inspector define. Therefore the Android Studio run configuration has not yet proven it is supplying the private Places key.

Before judging autocomplete behaviour:

1. open `C:\ConceptLab\Projects\homi\secrets.properties` locally;
2. copy only the private `PLACES_API_KEY` value;
3. Android Studio → **Run → Edit Configurations…** → Homi Flutter `lib\main.dart` configuration;
4. **Additional run args** must contain:

   `--dart-define=HOMI_PLACES_API_KEY=<private local value>`

5. Apply/save. Keep this configuration local and never share the resulting full command line publicly if it contains the real key.

See `documentation/GOOGLE_PLACES_SETUP.md`.

## Immediate next gate

Bruce should pull current `main` and run one validation block:

```powershell
cd C:\ConceptLab\Projects\homi
git pull --ff-only
flutter pub get
flutter analyze
flutter test
git status --short -- pubspec.lock
```

Expected dependency resolution must show `flutter_google_places_sdk_android 0.2.3`, not `0.2.2`.

Expected gates:

- analyzer: **No issues found**;
- tests: **All tests passed**;
- `pubspec.lock` modified because Android implementation changed.

If clean, commit/push only the regenerated lock file, then configure the private Places dart-define in Android Studio and run on the S25 Ultra.

No Cloud Shell step follows this dependency-only fix.

## S25 Ultra acceptance matrix

Once the app builds:

1. People opens map-first with normal Homi shell/header/nav.
2. No raw `UNAUTHENTICATED`; Homi code/connections/Edit/location sharing work.
3. Existing embedded map and live-location behaviour remain intact.
4. Full map has reachable SOS · 112 and Emergency numbers controls.
5. Verify 112/10111/10177 dialer targets without placing test emergency calls.
6. Person Details shows own Home/Work when configured.
7. Arrival screen has one toggle card in both ON/OFF states.
8. No large green help/status box and no redundant orange success box.
9. How it works has the info icon and bottom sheet.
10. Google Places autocomplete returns appropriate South African suggestions.
11. Set from here independently works.
12. Saved recipients show photo/initial + name.
13. Another person cannot see exact Home/Work without explicit exact-place sharing.
14. Exact-place sharing + active location share exposes only selected place(s).
15. Turning current-location share off blocks remote exact Home/Work.
16. Turning exact-place sharing off removes remote place without deleting local arrival setup.
17. Disconnect removes stale exact-place access.
18. People heart still works.
19. Task assignee photos/Household-only eligibility remain healthy.
20. Live updates and Arrival check-ins still independently own the shared foreground location stream.

Real arrival delivery still requires second trusted account/device plus a genuine outside→inside transition.

## Production gates still later

- multi-hour/screen-off/reboot/Samsung battery testing;
- Google Play background-location disclosure/review;
- Shared Household sync decision before household-wide marketing claims;
- release signing / Play App Signing SHA values;
- Play-installed Google Sign-In and production Maps/Places restrictions;
- Play Integrity App Check and later Firestore enforcement after valid metrics;
- billing alerts/monitoring;
- public Privacy Policy, Terms and external account-deletion page;
- Play Data Safety/content rating/audience/app access/assets;
- controlled broad developer notification;
- Homi+ only after actual premium shared-cloud value exists.

Pricing planning remains Free R0, Homi+ R49.99/month or R499.99/year. Privacy, stop-sharing, exact-place revoke, check-in disable and account deletion are never paywalled.
