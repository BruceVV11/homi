# Homi — Next Chat Prompt

Continue **Homi** from GitHub `main`. GitHub is the source of truth for tracked source/docs.

Use **mobile-app-development** first. For Firebase/Cloud Shell release work also use **concept-lab-release-integrity**. Preserve approved design/behaviour and diagnose from source/log evidence before asking Bruce to rerun anything.

Never claim compiled/deployed/on-device success without Bruce's actual toolchain/provider/device evidence.

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
- `android/` intentionally remains local/untracked.
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
- Google Places API (New) autocomplete for Home/Work plus **Set from here**;
- arrival recipients shown as profile photo/initial + name;
- People auth lifecycle recovery and one protected-callable token refresh/retry for `unauthenticated`;
- product-friendly error wording instead of raw backend codes.

## Proven Flutter/backend state

Bruce previously completed the 0.9.2 Windows static gate before the first Android build:

- `flutter analyze` → **No issues found**;
- `flutter test` → **32 tests passed**;
- application `pubspec.lock` committed.

Bruce then completed the governed 0.9.2 backend deployment successfully:

- backend deployment source: `d8fb786269feea43223c673e84b2b5a6c499a91f`;
- Node 22;
- Firestore emulator security suite **13/13 passed**;
- Firestore rules/indexes deployed;
- all 24 Functions deployed in batches;
- `onHomiUserSharedPlacesDeleted` created;
- `setSharedArrivalPlace` created;
- final status **PASS** / `Homi backend deployment completed.`

The later Places dependency/client-source changes do **not** change Functions, Firestore rules/indexes or the backend contract. **Do not redeploy Firebase for the Places client correction.**

## Android Places dependency failure history

The first S25 Ultra Gradle build failed inside third-party:

`flutter_google_places_sdk_android-0.2.2/android/.../FlutterGooglePlacesSdkPlugin.kt`

with unresolved Kotlin references including `address`, `latLng`, `name`, `nameLanguageCode`, `phoneNumber`, `userRatingsTotal` and `placeTypes`.

This is the same failure reported upstream in `matanshukry/flutter_google_places_sdk` issue #137.

An attempted fix then pinned `flutter_google_places_sdk_android 0.2.3`, because the upstream changelog said to skip 0.2.2 and use 0.2.3. Bruce's Windows resolver proved that artifact is **not published**:

`Because homi depends on flutter_google_places_sdk_android 0.2.3 which doesn't match any versions, version solving failed.`

Upstream issue #136 independently confirms that the advertised 0.2.3 Android artifact is unavailable. That failed resolver attempt did not modify `pubspec.lock`, run analysis/tests or start an Android build.

## Maintained Places SDK migration — current source

Do not restore the broken original package or the invalid 0.2.3 override.

Homi now uses:

```yaml
google_places_sdk_plus: 1.1.0
```

This is an independently maintained fork of the original plugin. It uses native Places SDKs on Android/iOS, supports Places API (New), and version 1.1.0 declares Dart >=3.11.0 / Flutter >=3.41.0, matching Homi's Dart 3.11.3 / Flutter 3.41.5 environment.

The maintained Android implementation currently has a 1.1.x line and is automatically included by the root package. Do not pin a transitive Android version unless a proven resolver/build issue requires it; let Bruce's regenerated `pubspec.lock` record the exact compatible version.

### Homi client API migration already implemented

`lib/src/services/google_places_service.dart` now:

- imports `package:google_places_sdk_plus/google_places_sdk_plus.dart`;
- constructs `FlutterGooglePlacesSdk(apiKey)` without the obsolete `useNewApi` argument;
- uses `PlaceField.Id`, `PlaceField.FormattedAddress` and `PlaceField.Location`;
- handles nullable prediction `placeId`, `primaryText`, `secondaryText` and `fullText` safely;
- preserves South Africa autocomplete restriction and session-token behaviour.

`lib/src/features/people/safety_check_in_page.dart` now imports the maintained package and uses `FlutterGooglePlacesSdk.assetPoweredByGoogleOnWhite` for Google attribution.

The app SDK lower bound is now Dart `>=3.11.0`, consistent with the maintained package and Bruce's installed Dart 3.11.3.

## Google Places local key

The private Places key remains local in:

`C:\ConceptLab\Projects\homi\secrets.properties`

with `PLACES_API_KEY=...`.

Android Studio → **Run → Edit Configurations…** → Homi Flutter configuration → **Additional run args** must include:

`--dart-define=HOMI_PLACES_API_KEY=<private local value>`

Never paste/share the real key or a generated Flutter command containing it.

See `documentation/GOOGLE_PLACES_SETUP.md`.

## Immediate next gate

The current client dependency migration has not yet been proven by Bruce's Windows resolver. Run exactly once after pulling current `main`:

```powershell
cd C:\ConceptLab\Projects\homi
git pull --ff-only
flutter clean
flutter pub get
flutter pub deps | Select-String "google_places_sdk_plus|flutter_google_places_sdk"
flutter analyze
flutter test
git status --short -- pubspec.lock
```

Expected:

- dependency resolution succeeds;
- output includes `google_places_sdk_plus 1.1.0` plus its maintained federated packages;
- output must **not** include the old `flutter_google_places_sdk` package family;
- analyzer → **No issues found**;
- tests → **All tests passed**;
- `pubspec.lock` should show modified because the dependency graph changed.

If the gate is green, commit/push only the regenerated lock:

```powershell
git add pubspec.lock
git commit -m "Lock maintained Google Places SDK dependencies"
git push
```

Then confirm the private `HOMI_PLACES_API_KEY` run argument locally and use Android Studio's normal Run button on the S25 Ultra.

**No Cloud Shell step follows this dependency-only migration.**

If the dependency resolver/analyzer/test/build fails, inspect the full output and all related source/package contracts before another Bruce rerun.

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

Real arrival delivery still requires a second trusted account/device plus a genuine outside→inside transition.

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
