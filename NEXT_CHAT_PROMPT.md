# Homi — Next Chat Prompt

Continue **Homi** from GitHub `main`. GitHub is the tracked source of truth.

Use **mobile-app-development** first. For Firebase/Cloud Shell/release work also use **concept-lab-release-integrity**. Diagnose from source/log evidence before asking Bruce to rerun anything. Preserve approved design and privacy behavior.

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
- Never request/expose Maps/Places keys, App Check debug tokens, signing secrets or private Firebase credentials.
- Deleted project `homi-508000` must never be used.
- Safety stash `stash@{0}: On main: Homi pre-0.5.0 local tracked changes` must not be popped/deleted automatically.

## Approved design/product baseline

Brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito, exact assets under `assets/brand/`.

Primary nav: **Overview · Tasks · Home · Supplies · People**, with persistent header/profile and exact centered Homi Home mark.

People remains the approved **map-first** experience.

Local-first use remains available. Do not claim full Household sync until it actually exists.

## Proven 0.9.2 state

- Windows `flutter analyze` clean after Places migration.
- Windows `flutter test` -> 32 tests passed.
- Broken `flutter_google_places_sdk` removed; `google_places_sdk_plus 1.1.0` resolved with Android 1.1.4 and lock committed.
- 0.9.2 backend governed deployment previously passed Firestore emulator 13/13 and deployed 24 Functions/rules, including saved-place functions.
- Backend deployment source: `d8fb786269feea43223c673e84b2b5a6c499a91f`.
- Last proven source before 0.10 implementation: `e4bbe3f152e03f1b870a404c3ebd92332c894bb7`.
- Google Places requires Android Studio Additional run arg `--dart-define=HOMI_PLACES_API_KEY=<private value>`; never ask Bruce to share the value. A development key appeared in a screenshot and must be rotated before production.

## 0.10.0+14 source candidate

Purpose: commercial cost guardrails + Homi+ plan contract + international Emergency region foundation.

### Homi+ approved commercial contract

Core rule once billing enforcement exists:

**Receiving live location is free. Continuously sending your own location requires one Homi+ sender seat. Every paid sender may share with up to five active trusted viewers.**

Plans:

- Free R0: local Homi, account/connections, receive live location, arrival check-ins, emergency, hearts, privacy/delete controls; no paid continuous sender seat after enforcement activates.
- Personal R19.99/month: 1 sender seat.
- Duo R34.99/month: 2 sender seats under one payer; second person does not have to live in the same home; target 7-day seat reassignment cooldown.
- Household R49.99/month or R499.99/year: up to 4 members, each with a sender seat, plus the future full shared-Household product.
- Every sender seat gets max 5 active viewers.
- Friends who only receive do not consume Household seats.
- Privacy/stop-sharing/check-in disable/exact-place revoke/erase/account deletion never paywalled.

Source contract: `lib/src/domain/homi_plus_plan.dart` + `documentation/MONETIZATION.md`.

0.10 does **not** activate paid entitlement yet. Actual billing requires Play products, official Flutter Billing flow, server Play Developer API verification, authoritative entitlement state, RTDN/Pub/Sub and Internal Testing lifecycle proof. Never unlock from a client purchase callback alone.

### Continuous-location cost guardrails

Existing Android stream stays ~2 minutes / 100 m movement.

0.10 source changes:

- client Firestore cloud-write floor: 90 seconds;
- Firestore update rule floor: 90 seconds;
- protected `setLocationShare` maximum: 5 active outbound viewers;
- disabling a viewer bypasses activation connection/rate-limit checks so stop-sharing remains reliable;
- normal trusted-connection limit remains separate.

Backend/rules changed, so 0.10 requires a governed backend deployment **after** the Windows Flutter gate passes.

### Emergency regions

- offline source-controlled catalog;
- onboarding now includes Emergency region confirmation;
- device locale may suggest a supported region without location permission;
- user can change region from Safety;
- Safety emergency cards and full-map emergency controls use the same region;
- leading-zero numbers are strings (`000` remains `000`);
- regions without one universal number do not get an invented SOS button;
- unsupported regions have no South Africa fallback;
- emergency action remains external `tel:` only, no silent call/dispatch/location transmission;
- every public launch country must be release-reviewed against ITU-T E.129 and/or national official source.

Google Places Home/Work autocomplete now follows the selected Emergency region country instead of hardcoded South Africa.

See `documentation/EMERGENCY_REGIONS.md`.

## Privacy/location contracts that must not regress

- connection != location share;
- live/background requires explicit opt-in + visible Android foreground notification;
- latest/current location only by default; no route history;
- check-in-only background samples do not refresh cloud latest location unless Live updates independently active;
- fresh first arrival sample primes state; only outside->inside sends;
- exit hysteresis radius +100 m; one-hour local cooldown;
- arrival callable/push contains no saved Home/Work coordinate/address;
- exact Home/Work visibility separately opt-in and requires selected viewer + accepted connection + active owner->viewer location share;
- turning place sharing off removes cloud copy but preserves local arrival setup;
- disconnect cleanup removes stale exact-place viewer;
- privacy/revoke/delete controls never paywalled.

## Latest Windows validation evidence

Bruce pulled `9ee7fe0e2d18f185e53b0ad210c703bdd1510c29` on Windows and ran the requested gate.

Proven on that exact source:

- `flutter pub get` -> succeeded;
- `flutter test` -> **41/41 passed**;
- `pubspec.lock` did not appear as modified;
- local `git status --short` showed only established untracked local files/directories (`.metadata`, PSD, `android/`, `assets/`, `play_store_assets/`, device logcat), not tracked source drift.

The first `flutter analyze` run found four static findings only in the new emergency-region client code:

1. unused `emergency_region.dart` import in `people_map_page.dart`;
2. two nullable accesses to `region.countryName` / `region.contacts` because the mutable local variable lost null promotion when captured by the bottom-sheet closure;
3. redundant `dart:ui` import in `emergency_region_service.dart`.

Those findings have now been corrected in GitHub source:

- the region value is a final local before the closure, preserving null-safety promotion;
- the unused emergency-region import is removed;
- the redundant `dart:ui` import is removed.

No backend/rules behavior changed in this corrective patch. The corrected exact head must still be proven by Bruce's Windows analyzer/test gate before Firebase deployment.

## Immediate next validation

Bruce should now pull the corrected source and run only the gate that needs re-proving:

```powershell
cd C:\ConceptLab\Projects\homi
git pull --ff-only
flutter analyze
flutter test
git status --short
```

Expected: analyzer clean; all tests pass. Do not claim compiled/device-accepted before this.

If that corrected Windows gate is green, use the governed Cloud Shell backend helper because Firestore rules and the `setLocationShare` implementation changed in the underlying 0.10 pass. It must run Node 22 and the Firestore emulator gate before deploying.

After deployment, S25 Ultra acceptance should cover:

1. existing local/account data retained;
2. normal Homi shell/nav/People map unchanged;
3. Places autocomplete still works with private dart-define;
4. Emergency region onboarding on fresh install;
5. existing install gets supported locale suggestion and can change region from Safety;
6. ZA 112/10111/10177; AU `000`; US 911; service-specific country behavior without invented SOS;
7. full-map emergency controls update after region change;
8. do not complete test emergency calls;
9. five active live viewers succeed, sixth denied cleanly;
10. removing/deactivating a viewer always works;
11. live location, hearts, check-ins and exact Home/Work privacy remain healthy.

## Next major product work after 0.10 acceptance

1. Canonical shared Household identity/membership/sync for Home, Tasks, Routines, Supplies and supported activity/history.
2. Google Play subscription products/base plans.
3. Official Flutter Play Billing client.
4. Backend purchase verification + authoritative entitlements.
5. RTDN/Pub/Sub lifecycle handling.
6. Internal Testing purchase/cancel/restore/grace/hold/expiry/refund proof.
7. Then activate paid continuous-sender gating and Household premium capability checks.

Remaining production gates: background-location policy, multi-hour/reboot/battery tests, release signing/Play App Signing fingerprints, Play-installed Google Sign-In, production Maps/Places restrictions, Play Integrity App Check, later Firestore enforcement after valid metrics, billing alerts, public Privacy/Terms/deletion URLs, Data Safety/content rating/audience/app-access/store assets and country-by-country emergency-number verification.
