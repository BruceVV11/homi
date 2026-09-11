# Homi — Release readiness

Date: 2026-09-11
Current source candidate: **0.10.0+14**

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

- **DONE (0.9.2)** Google Places dependency migrated to maintained `google_places_sdk_plus`; Windows dependency resolution succeeded.
- **DONE (0.9.2)** Windows analyzer clean and 32 Flutter tests passed after the Places migration.
- **DONE (0.10.0)** `flutter pub get` succeeded on Bruce's Windows toolchain.
- **DONE (0.10.0 initial candidate)** `flutter test` passed 41/41 on `9ee7fe0e2d18f185e53b0ad210c703bdd1510c29`.
- **VERIFY (0.10.0 corrected candidate)** `flutter analyze` clean after the emergency-region null-safety/import correction.
- **VERIFY (0.10.0 corrected candidate)** rerun all 41+ Flutter tests on the exact corrected head before backend deployment.
- **VERIFY** S25 Ultra launch/regression after 0.10.0.
- **OPEN** fresh-install and returning-user paths.
- **OPEN** background/resume/swipe-away/reopen/network-loss recovery.
- **OPEN** keyboard/safe-area/Android navigation insets.
- **OPEN** screen-off/several-hours/process recreation/reboot/Samsung power-saving tests.

The first 0.10 analyzer run found only four client static-analysis findings in the new emergency-region code: one unused import, two nullable accesses caused by mutable-local promotion loss inside a sheet closure, and one redundant import. The source correction changes no backend/rules behavior. The local gate showed no tracked source drift; only established untracked local Android/assets/store/PSD/logcat material was present.

## Gate 2 — People/location/safety

Implemented source contracts:

- **DONE** map-first People inside normal Homi shell;
- **DONE** per-person explicit location sharing;
- **DONE** latest-state cloud model; no route history by default;
- **DONE** one foreground location stream shared by independent Live updates / Arrival check-ins;
- **DONE** first-arrival sample primes state; outside->inside only; +100 m exit hysteresis; one-hour local cooldown;
- **DONE** arrival delivery contains no Home/Work address/coordinate;
- **DONE** exact Home/Work visibility separate opt-in + selected viewer + accepted connection + active current-location share;
- **DONE** emergency actions use external phone-app handoff rather than silent direct call;
- **DONE in 0.10.0 source** client cloud-write floor 90 seconds;
- **DONE in 0.10.0 source** Firestore server floor 90 seconds;
- **DONE in 0.10.0 source** five-active-live-viewer server cap;
- **DONE in 0.10.0 source** privacy deactivation path not trapped by activation cap/rate limit.

Device/backend verification still required:

- **VERIFY** People auth recovery / Homi code / connection / relationship / heart flows;
- **VERIFY** Google Places autocomplete and saved address;
- **VERIFY** five active viewers allowed and sixth rejected cleanly;
- **VERIFY** stopping/deactivating a viewer works while capped and after disconnect;
- **VERIFY** two-device live location remains healthy;
- **VERIFY** Home and Work real transitions send exactly once;
- **VERIFY** check-in-only monitoring does not refresh cloud latest location;
- **BLOCKER** Google Play background-location declaration/prominent disclosure/review evidence.

## Gate 3 — Emergency-region launch data

- **DONE in source** offline Emergency region catalog/model.
- **DONE in source** onboarding region confirmation and local persistence.
- **DONE in source** Safety page uses selected regional numbers.
- **DONE in source** full map uses selected regional numbers and omits invented SOS for service-specific countries.
- **DONE in source** leading-zero numbers are stored as strings.
- **DONE in source** unsupported regions have no South Africa fallback.
- **VERIFY** representative S25 Ultra dialer targets without placing test emergency calls.
- **VERIFY** region changes update Safety/full map immediately.
- **BLOCKER per public country** verify the bundled entry against ITU-T E.129 and/or that country's official emergency authority before enabling/marketing that country in store rollout.

## Gate 4 — Shared Household product contract

Current cloud collaboration covers trusted People, selected shared Tasks, live/latest location, arrival events and optional exact Home/Work.

**BLOCKER if Homi is marketed as a fully shared household system:** implement canonical Household identity/membership plus conflict-safe cloud sync for Routines, Supplies, Home records and supported shared household state.

A local-first launch is possible only if product/store copy states current boundaries accurately.

## Gate 5 — Homi+ / payments

Approved commercial model is recorded in `documentation/MONETIZATION.md`:

- Free R0;
- Personal R19.99/month: 1 sender seat;
- Duo R34.99/month: 2 sender seats under one payer;
- Household R49.99/month or R499.99/year: up to 4 members + shared Household product;
- each paid sender: max 5 active live viewers;
- receiving live location remains free;
- privacy/revoke/delete controls never paywalled.

- **DONE in 0.10.0 source** typed plan definitions and cost constants.
- **BLOCKER** create Google Play subscription catalog/base plans.
- **BLOCKER** add official Flutter Play Billing purchase flow.
- **BLOCKER** server-side Google Play Developer API verification.
- **BLOCKER** authoritative entitlement storage/capability checks.
- **BLOCKER** RTDN/Pub/Sub lifecycle handling.
- **BLOCKER** purchase acknowledgement/restore/reinstall/account mapping.
- **BLOCKER** Internal Testing proof for purchase, renewal, cancellation, grace, hold, expiry and refund/revoke.

Do not enforce paid live sending until the secure server entitlement path exists. Do not unlock based only on a client purchase callback.

## Gate 6 — Backend/security

- **DONE previously** sensitive collaboration mutation behind Auth/App-Check-protected Functions.
- **DONE previously** verified-email requirement for password-provider sensitive sharing.
- **DONE previously** server-side limits for connections, shared Tasks, hearts, arrivals and campaigns.
- **DONE previously** dedicated bounded runtime identity.
- **DONE previously** 0.9.2 Firestore security suite passed 13/13 and governed backend deployment completed.
- **VERIFY 0.10.0** updated Firestore emulator suite passes with 90-second location rule.
- **VERIFY 0.10.0** governed deployment updates Firestore rules and `setLocationShare` while keeping the same public export count/name.
- **VERIFY** active debug devices have registered private App Check debug tokens.
- **BLOCKER** Play Integrity App Check for release traffic.
- **BLOCKER** Firestore App Check enforcement only after known-good valid-client metrics.
- **BLOCKER** Cloud Billing budgets/alerts/spend controls.

## Gate 7 — Authentication/account lifecycle

- **DONE** email/password + Google sign-in.
- **DONE** verification/reset/provider-aware password/sign-out.
- **DONE** recent reauthentication for account deletion.
- **DONE** local erase/sign-out/account deletion are distinct.
- **VERIFY** Play-installed Google Sign-In after Play App Signing fingerprints are registered.
- **VERIFY** disposable email/Google account deletion and optional shared-place cleanup.

## Gate 8 — Privacy/legal

- **DONE in source** no emergency-dispatch/crash-detection/proof-of-safety claims.
- **DONE in source** arrival payload coordinate/address-free.
- **DONE in source** exact Home/Work separately opt-in/server-rule gated.
- **BLOCKER** public Privacy Policy URL.
- **BLOCKER** public Terms URL.
- **BLOCKER** external account-deletion page/process.
- **BLOCKER** Play Data Safety matches background location + optional precise saved-place sharing + paid subscription behavior.
- **OPEN** POPIA/privacy wording professional review.

## Gate 9 — Production Android identity/signing

- **BLOCKER** permanent upload key + secure backup.
- **BLOCKER** release signing without committed secrets.
- **BLOCKER** Play App Signing.
- **BLOCKER** upload + Play App Signing SHA registration where required.
- **BLOCKER** production Maps/Places key restrictions include release package/fingerprint.
- **BLOCKER** approved AAB + Internal Testing proof.

Permanent package: `za.co.theconceptlab.homi`.

## Immediate sequence

1. Pull the corrected 0.10.0 candidate on Windows.
2. Run `flutter analyze` and `flutter test` on the exact corrected head.
3. If clean, run the governed Cloud Shell backend helper; it must pass the updated Firestore emulator gate before deploying rules/Functions.
4. S25 Ultra device acceptance for emergency regions, Places, People and viewer cap.
5. Then begin Shared Household + Google Play Billing/entitlement implementation.
