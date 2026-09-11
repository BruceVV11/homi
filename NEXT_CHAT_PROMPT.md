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

## Proven 0.9.2 baseline

- Broken `flutter_google_places_sdk` removed; `google_places_sdk_plus 1.1.0` resolved with Android 1.1.4 and lock committed.
- 0.9.2 backend governed deployment previously passed Firestore emulator 13/13 and deployed 24 Functions/rules, including saved-place functions.
- Google Places requires Android Studio Additional run arg `--dart-define=HOMI_PLACES_API_KEY=<private value>`; never ask Bruce to share the value. A development key appeared in a screenshot and must be rotated before production.

## 0.10.0+14 purpose

Commercial cost guardrails + Homi+ plan contract + international Emergency region foundation.

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

0.10 changes now deployed:

- client Firestore cloud-write floor: 90 seconds;
- Firestore server update floor: 90 seconds;
- protected `setLocationShare` maximum: 5 active outbound viewers;
- disabling a viewer bypasses activation connection/rate-limit checks so stop-sharing remains reliable;
- normal trusted-connection limit remains separate.

### Emergency regions

- offline source-controlled catalog;
- onboarding includes Emergency region confirmation;
- device locale may suggest a supported region without location permission;
- user can change region from Safety;
- Safety emergency cards and full-map emergency controls use the same region;
- leading-zero numbers are strings (`000` remains `000`);
- regions without one universal number do not get an invented SOS button;
- unsupported regions have no South Africa fallback;
- emergency action remains external `tel:` only, no silent call/dispatch/location transmission;
- every public launch country must be release-reviewed against ITU-T E.129 and/or national official source.

Google Places Home/Work autocomplete follows the selected Emergency region country instead of hardcoded South Africa.

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

## Proven 0.10 Windows validation

Bruce's Windows Flutter toolchain fully passed the client gate on exact app/runtime source:

`11df198bfc5801257cef45dc4bba64e9d37772d7`

Evidence:

- `flutter pub get` succeeded;
- `flutter analyze` -> **No issues found**;
- `flutter test` -> **41/41 passed**;
- no tracked local source drift was reported.

Later deployment-tool/documentation commits do not alter Flutter app source, Functions runtime source, Firestore rules or the validated dependency graph. Do not ask Bruce to rerun the Windows gate solely because those tooling/docs commits moved `main`.

## Proven 0.10 backend deployment

The accepted refresh-safe Cloud Shell worker deployed from exact source/tooling SHA:

`fba7479a8304aec30a964f32cfd8b3e268b6c78e`

Proven:

- Node `v22.23.2`;
- project `homi-ee80a` / `883068189841`;
- exactly 24 Homi Function exports validated after dependency installation;
- Firestore emulator security suite **13/13 passed**, including the 90-second location update boundary;
- Firestore rules compiled/released and indexes deployed successfully;
- all 24 Node 22 Gen2 Functions deployed in five controlled batches;
- `setLocationShare(africa-south1)` successfully updated;
- final `setLocationShare` state **ACTIVE**;
- worker final status **PASS**.

The recurring `GOOGLE_CLOUD_QUOTA_PROJECT is not usable when uploading source for Cloud Functions` warning was non-fatal; source uploads and all deployment batches succeeded.

The two earlier workers failed during release-tooling preflight and never reached deployment. Do not rerun them.

## Immediate next step: S25 Ultra acceptance

Bruce should pull current `main` (current post-deployment commits are documentation-only), keep the existing private Places dart-define in the Android Studio Flutter run configuration, and launch Homi on the S25 Ultra.

Focused 0.10 acceptance:

1. app launches with existing local/account data retained;
2. normal Homi shell/nav and People map remain visually unchanged except the intended new emergency-region behavior;
3. Google Places Home/Work autocomplete still works;
4. Safety & check-ins shows the selected Emergency region and regional emergency numbers;
5. changing Emergency region updates Safety/full-map emergency controls immediately;
6. representative ZA/AU/US dialer handoff uses 112/10111/10177, `000`, 911 as applicable; do not complete emergency calls;
7. People/live location, hearts, check-ins and exact Home/Work privacy remain healthy;
8. when enough test accounts exist, five active live viewers succeed and a sixth is rejected cleanly; deactivation always works.

## Next major product work after 0.10 device acceptance

1. Canonical shared Household identity/membership/sync for Home, Tasks, Routines, Supplies and supported activity/history.
2. Google Play subscription products/base plans.
3. Official Flutter Play Billing client.
4. Backend purchase verification + authoritative entitlements.
5. RTDN/Pub/Sub lifecycle handling.
6. Internal Testing purchase/cancel/restore/grace/hold/expiry/refund proof.
7. Then activate paid continuous-sender gating and Household premium capability checks.

Remaining production gates: background-location policy, multi-hour/reboot/battery tests, release signing/Play App Signing fingerprints, Play-installed Google Sign-In, production Maps/Places restrictions, Play Integrity App Check, later Firestore enforcement after valid metrics, billing alerts, public Privacy/Terms/deletion URLs, Data Safety/content rating/audience/app-access/store assets and country-by-country emergency-number verification.
