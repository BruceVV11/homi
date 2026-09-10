# Homi — Release readiness

This is the source-of-truth checklist for moving Homi from a working development build to a public Google Play release. A visually complete app is not release-ready until the security, shared-data, policy, device and production-signing gates below are satisfied.

Current source version: **`0.9.2+13`**

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

- **DONE (Bruce-confirmed, 2026-09-10)** 0.9.0+11 analyzer clean and Flutter tests passed.
- **DONE (Bruce-confirmed, 2026-09-11)** 0.9.1+12 analyzer/tests passed before the first 0.9.1 S25 Ultra review.
- **VERIFY** `flutter pub get` resolves the new Places dependency for 0.9.2+13.
- **VERIFY** `flutter analyze` clean for 0.9.2+13.
- **VERIFY** all Flutter tests pass for 0.9.2+13.
- **OPEN** 0.9.2+13 launches and behaves correctly on Samsung S25 Ultra.
- **OPEN** fresh-install and returning-user paths tested.
- **OPEN** local-only and signed-in paths tested.
- **OPEN** background/resume, swipe-away/reopen and network-loss/recovery tested.
- **OPEN** every primary destination tested with empty/populated data.
- **OPEN** keyboard, safe-area and Android navigation insets checked.
- **OPEN** destructive actions tested on disposable data/accounts.
- **DONE previously** developer self-test notification delivery proven on S25 Ultra.
- **OPEN** notification taps tested foreground/background/terminated.
- **OPEN** one controlled **All enabled Homi devices** broadcast before public users exist.

The deployed 0.9.0 backend candidate remains the current production-development backend until the 0.9.2 governed deployment succeeds:

`c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`

0.9.2 changes both Flutter and backend/rules and therefore requires a fresh deployment gate after Flutter validation.

## Gate 2 — Shared Household product contract

Homi currently shares trusted-person location, explicitly shared Home/Work details, Home/Work arrival events and specifically shared one-off Tasks through Firebase. Routines, Supplies and most Home records remain local-first on the current phone.

**BLOCKER if Homi is marketed as a shared household system:** implement a real Household identity/membership model plus conflict-safe cloud sync for Routines, Supplies, Home records and shared household state.

A local-first public launch is possible only if store/in-app copy states those boundaries accurately. Never imply another household member automatically sees Routine/Supply/Home changes from their own device.

## Gate 3 — People, location, check-ins and Google Play policy

### Implemented in source

- **DONE** People primary destination remains the approved map-first screen inside the persistent Homi shell.
- **DONE** Household and Friends & trusted people are grouped under existing map/location controls.
- **DONE** explicit labelled relationship Edit action.
- **DONE** per-person opt-in latest/live location sharing and visible stop-sharing controls.
- **DONE** latest-state cloud model; no default route history.
- **DONE** one visible Android foreground location stream shared by independently enabled Live updates / Arrival check-ins.
- **DONE** first arrival sample primes state; only outside→inside sends; +100 m exit hysteresis; one-hour local cooldown.
- **DONE** `sendArrivalCheckIn` contains no Home/Work coordinate/address.
- **DONE** Safety page uses one always-visible Notifications-style arrival switch card; no oversized green hero/redundant success box.
- **DONE** How it works uses information icon + bottom sheet.
- **DONE** Home/Work address setup uses Google Places autocomplete plus Set from here.
- **DONE** arrival recipients display profile images + names.
- **DONE** full People map contains bottom-reach **SOS · 112** and **Emergency numbers** controls.
- **DONE** full-map Person Details includes latest location + Home + Work.
- **DONE** exact Home/Work visibility is separately opt-in and additionally requires active owner→viewer location sharing.
- **DONE** emergency actions use phone-app handoff rather than silent direct call.

### Must be verified on devices

- **VERIFY** People no longer surfaces raw `UNAUTHENTICATED` and recovers correctly after auth restoration/network recovery.
- **VERIFY** Homi code, connection requests, relationship edits, location shares and People hearts work after 0.9.2 auth recovery changes.
- **VERIFY** Google autocomplete returns appropriate South African suggestions and selected result stores the expected address/coordinate.
- **VERIFY** Set from here independently stores the intended current location/address.
- **VERIFY** recipient avatars/names display correctly for each saved place.
- **VERIFY** check-in switch off/on matches saved state and no redundant success card appears.
- **VERIFY** 112/10111/10177 open correct dialer target; do not complete test emergency calls.
- **VERIFY** full-map SOS control is immediately reachable and opens 112 dialer.
- **VERIFY** current user's own Home/Work appears in Person Details.
- **VERIFY** another user cannot see Home/Work until exact-place sharing is explicitly enabled and current-location sharing is active.
- **VERIFY** turning current-location share off immediately hides previously shared Home/Work.
- **VERIFY** removing/disconnecting a person removes stale exact-place viewer access.
- **VERIFY** two-device live location remains healthy.
- **VERIFY** real Home outside→inside transition sends exactly once.
- **VERIFY** Work sends independently.
- **VERIFY** restart while already inside does not send false arrival.
- **VERIFY** People notification OFF suppresses arrival delivery.
- **VERIFY** stale/disconnected arrival recipient does not block valid recipients.
- **VERIFY** turning one background location feature off leaves the other working.
- **VERIFY** turning both off stops the foreground stream.
- **OPEN** screen-off/several-hours/process recreation/reboot/Samsung power-saving tests.
- **OPEN** revoked permission/location-services-off tests.
- **OPEN** representative-day battery measurement.
- **BLOCKER** Google Play background-location declaration, prominent disclosure and review evidence.

Force-stopping Android can prevent background work until the app is opened again. Homi must describe actual platform behaviour.

## Gate 4 — Security and abuse/cost controls

### Proven foundation

- **DONE** sensitive collaboration mutation uses callable Functions instead of broad client writes.
- **DONE** protected callables require Auth + App Check.
- **DONE** password-provider sensitive sharing requires verified email.
- **DONE** server-side Homi codes/connection limits/rate limits.
- **DONE** server-derived shared Task membership and actor identity.
- **DONE** cloud account deletion requires recent authentication.
- **DONE** developer admin/campaign boundary is server-authorized.
- **DONE** latest-location owner write is schema/time bounded.
- **DONE** bounded Function instances + dedicated runtime identity.
- **DONE** Firestore Emulator security suite gates deployment.
- **DONE (2026-09-10)** previous suite passed 12/12 and deployed rules.
- **DONE** stale historical `onConnectionDeleted` migration completed; active replacement is `onTrustedConnectionDeleted`.
- **DONE (Bruce-confirmed, 2026-09-10)** batched 0.8.2 backend deployment successful.
- **DONE (Bruce-confirmed, 2026-09-10)** 0.9 backend helper completed without observed failure, including `sendArrivalCheckIn`.

### 0.9.2 additions pending deployment proof

- **DONE in source** `setSharedArrivalPlace` Auth/App Check/verified-password-email protected.
- **DONE in source** only Home/Work accepted; bounded coordinates/address; max 10 viewers.
- **DONE in source** viewer UIDs revalidated against accepted connections.
- **DONE in source** precise-place change limits 120/hour and 400/day.
- **DONE in source** direct client sharedPlaces writes denied.
- **DONE in source** sharedPlaces reads require explicit viewer list + accepted connection + active owner→viewer location share.
- **DONE in source** disconnect cleanup strips stale shared-place viewers.
- **DONE in source** account deletion saved-place cleanup trigger.
- **DONE in source** protected callable client retries one stale Auth/App Check session and maps technical failures to product copy.
- **VERIFY** expanded Firestore security suite passes under emulator.
- **VERIFY** new Functions/rules deploy successfully through governed helper.
- **VERIFY** valid App Check debug client can call `setSharedArrivalPlace`; invalid/unattested call rejected.

### Remaining production configuration

- **VERIFY** `configure-auth-security.sh` applied: improved email privacy + password policy.
- **VERIFY** active debug test devices have registered private App Check debug tokens.
- **OPEN** inspect valid App Check metrics.
- **BLOCKER** release build uses Play Integrity App Check.
- **BLOCKER** enable Firestore App Check enforcement only after known-good traffic.
- **BLOCKER** Cloud Billing budget alerts/spend controls.
- **OPEN** Cloud Monitoring alerts for abnormal Functions/Firestore activity.

## Gate 5 — Authentication/account lifecycle

- **DONE** email/password + Google sign-in.
- **DONE** verification/reset/provider-aware password controls/sign-out.
- **DONE** recent reauthentication for account deletion.
- **DONE** local erase/sign-out/account deletion are distinct.
- **DONE in source 0.9.2** People lifecycle rebinds when authenticated UID changes/restores.
- **DONE in source 0.9.2** protected callable `unauthenticated` gets one token refresh/retry and no raw-code UI leak.
- **VERIFY** Google sign-in from current debug build.
- **VERIFY** verified email/password People/check-in/share operations.
- **VERIFY** unverified password account blocked cleanly.
- **VERIFY** password reset remains non-enumerating.
- **VERIFY** disposable Google/email account deletion, including local/optional shared Home/Work.

## Gate 6 — Notifications

- **DONE in source** fresh-install operational master ON.
- **DONE in source** Household attention / Tasks & routines / People / Service & security ON.
- **DONE in source** Homi Updates OFF until explicitly enabled.
- **DONE in source** existing saved preference preserved.
- **DONE in source** Android notification permission requested once where needed.
- **VERIFY** fresh-install permission/settings state.
- **VERIFY** existing explicit notification-off remains off after update.
- **VERIFY** arrival delivery respects People notification opt-out.
- **OPEN** controlled broad developer broadcast before public users.

## Gate 7 — Privacy/legal/user data

- **DONE in-app draft** Why Homi exists, Privacy & your data, Location & safety, Terms and account controls.
- **DONE** Homi does not claim emergency dispatch/crash detection/proof of safety.
- **DONE in source** arrival push remains coordinate/address-free.
- **DONE in source** optional exact Home/Work cloud copy is separately opt-in and server/rule gated.
- **VERIFY** local erase clears local place data and revokes/retries optional cloud shared-place clear correctly.
- **BLOCKER** stable public Privacy Policy URL.
- **BLOCKER** stable public Terms URL.
- **BLOCKER** external account-deletion page with functional request process.
- **BLOCKER** Play Data Safety matches background location + optional precise saved-place cloud sharing.
- **BLOCKER** precise/background-location disclosures match actual processing.
- **OPEN** South African POPIA/privacy wording professionally reviewed.
- **OPEN** monitored support contact.

## Gate 8 — Payments / Homi+

Paid launch is not required for first public build. Planning remains:

- Free R0
- Homi+ R49.99/month or R499.99/year
- location-only friends do not consume paid Household seats
- privacy, stop-sharing, check-in disable, exact-place revoke and deletion never paywalled

Do not enable a paywall until premium shared-cloud value actually exists and Play Billing lifecycle/server verification is implemented.

## Gate 9 — Production Android identity/signing

- **BLOCKER** permanent upload key + safe backup.
- **BLOCKER** release signing without committed secrets.
- **BLOCKER** Play App Signing.
- **BLOCKER** upload + Play signing SHA registration where required.
- **BLOCKER** Google Sign-In from Play-installed build.
- **BLOCKER** production Maps/Places key restrictions include release package/fingerprint.
- **BLOCKER** Play Integrity App Check.
- **BLOCKER** approved AAB + Internal Testing proof.

Permanent package: `za.co.theconceptlab.homi`.

## Gate 10 — Store/operational readiness

Required before submission:

- final listing copy/assets/screenshots;
- content rating and target audience;
- ads declaration;
- reviewer access/test account where required;
- background-location declaration/review;
- Data Safety;
- Privacy Policy URL;
- external deletion URL;
- support contact;
- release notes;
- staged rollout plan.

Recommended before broad rollout: privacy-conscious crash monitoring, Functions/Firestore/spend monitoring, and tested rollback/disable plans.

## Current release position

The 0.9.0 backend foundation remains deployed and proven to the level previously recorded. 0.9.1 Flutter tests/analyzer passed, but its first S25 Ultra review exposed UI issues and a People authentication/connectivity failure.

`0.9.2+13` is the corrective source pass. It removes the rejected check-in UI states, adds bottom-reach map emergency controls, adds Google Places autocomplete, adds profile-based recipient presentation, adds self/authorized-other Home/Work Person Details, and hardens People auth recovery/raw error handling.

Because exact Home/Work sharing introduces `sharedPlaces`, a new protected callable/cleanup trigger and Firestore read boundary, **0.9.2 does require a backend deployment after its Flutter gate passes**.

Immediate sequence:

1. Windows `flutter pub get` + analyzer + tests.
2. If clean, governed Cloud Shell backend helper and expanded Firestore emulator gate.
3. Configure existing private restricted Places key for the debug run without sharing/committing it.
4. S25 Ultra acceptance.
5. Two-account/device privacy and arrival verification.

The largest later product blocker remains the Shared Household sync contract if Homi is marketed as a household-wide source of truth. Production signing, Play Integrity/App Check enforcement, public legal URLs and Google Play policy declarations remain subsequent deployment gates.