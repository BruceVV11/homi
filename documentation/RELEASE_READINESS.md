# Homi — Release readiness

This is the source-of-truth checklist for moving Homi from working development build to a public Google Play release. A visually complete app is not considered release-ready until the security, shared-data, policy and production-signing gates below are satisfied.

Current source version: **`0.9.0+11`**

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

- **VERIFY** `flutter analyze` clean on 0.9.0+11.
- **VERIFY** all Flutter tests pass on 0.9.0+11.
- **OPEN** production-like release build launches on a physical Android device.
- **OPEN** fresh install and returning-user paths tested.
- **OPEN** local-only and signed-in paths tested.
- **OPEN** app background/resume, swipe-away/reopen and network-loss/recovery tested.
- **OPEN** every primary destination tested with empty and populated data.
- **OPEN** keyboard, safe-area and Android navigation insets checked.
- **OPEN** destructive actions tested on disposable data/accounts.
- **DONE** developer self-test notification delivery was previously proven on Samsung S25 Ultra.
- **OPEN** notification taps tested from foreground, background and terminated app state.
- **OPEN** one controlled **All enabled Homi devices** broadcast before public users exist.

## Gate 2 — Shared Household product contract

Homi already shares trusted-person location, Home/Work arrival events and specifically shared one-off Tasks through Firebase. Routines, Supplies and most Home records remain local-first on the current phone.

**BLOCKER if Homi is marketed as a shared household system:** implement a real Household identity/membership model plus conflict-safe cloud sync for Routines, Supplies, Home records and shared household state. This remains the preferred product path because Homi is intended to let authorised household members know what is happening at home from their own devices.

A local-first public launch remains technically possible only if store/in-app copy explicitly states those areas remain on the current device. Do not imply another household member can see Routine/Supply/Home changes from their own phone.

If Shared Household is implemented, the sync model must use stable record IDs, timestamps/versioning, offline mutations, membership authorization, safe merge rules and tested account/device migration. Never resolve two devices by blindly overwriting one with the other.

## Gate 3 — Location, arrival check-ins and Google Play policy

### Implemented

- **DONE** explicit per-person opt-in live location sharing and visible stop-sharing controls.
- **DONE** latest-state-only default cloud model; no hidden route history.
- **DONE** Android foreground-service notification uses the Homi icon and remains visible while the shared background location stream is active.
- **DONE in source** Home and Work check-in places are saved locally, not as a cloud location-history collection.
- **DONE in source** arrival notifications send only Home/Work event label + selected trusted recipients; no saved coordinates/address are included in the callable/push payload.
- **DONE in source** initial inside-zone state does not send; only outside → inside transition sends.
- **DONE in source** 100 m exit hysteresis plus one-hour local place cooldown reduces GPS-edge duplicate alerts.
- **DONE in source** Live updates and Arrival check-ins have independent local ownership flags while sharing one foreground location stream, so turning either feature off does not silently disable the other.
- **DONE in source** emergency call shortcuts use phone-app handoff rather than silent direct-call permission.

### Must be verified

- **VERIFY** two-device live location after 0.9.0 client install.
- **VERIFY** Home check-in real outside → inside transition sends exactly once.
- **VERIFY** Work check-in independently sends to the selected people.
- **VERIFY** opening/restarting while already inside Home/Work does not send a false arrival.
- **VERIFY** recipient People-notification OFF suppresses arrival delivery.
- **VERIFY** disconnected/stale selected recipients are not notified and do not block still-valid selected recipients.
- **VERIFY** turning Arrival check-ins off leaves explicit Live updates working when live sharing is still on.
- **VERIFY** turning Live updates off leaves Arrival check-ins monitoring working when check-ins are still on.
- **VERIFY** turning both off stops the foreground location stream.
- **VERIFY** Emergency 112, Police 10111 and Ambulance 10177 each open the phone application with the intended number.
- **OPEN** screen-off test.
- **OPEN** several-hours background test.
- **OPEN** normal process recreation test.
- **OPEN** device reboot test.
- **OPEN** Samsung battery optimisation/default power-saving test.
- **OPEN** revoked permission and location-services-off tests.
- **OPEN** representative-day battery measurement.
- **BLOCKER** Google Play background-location declaration, prominent disclosure and review evidence.

Force-stopping an Android app can prevent background work until the user opens it again. Homi must describe actual Android behaviour rather than promise impossible persistence.

## Gate 4 — Security and abuse/cost controls

### Proven 0.8.2 backend foundation

- **DONE** sensitive collaboration mutations moved behind Firebase callable Functions.
- **DONE** protected callables require Firebase Authentication and enforce App Check.
- **DONE** password-provider accounts must verify email before using sharing callables.
- **DONE** Homi code issuance/lookup is server-side, App-Check protected and rate-limited.
- **DONE** connection count and code-attempt limits.
- **DONE** shared Task membership is server-derived from accepted Household relationships rather than client-supplied.
- **DONE** disconnect and Household→Friend cleanup removes stale Task-derived access.
- **DONE** server derives Task creator/completer identity.
- **DONE** account cloud deletion moved server-side and requires recent authentication.
- **DONE** developer campaign creation moved server-side; developer admin cannot be self-granted.
- **DONE** Firestore sensitive collections are client-read-only/server-write-only as applicable.
- **DONE** direct latest-location writes are owner-only, schema bounded and limited to one update per 30 seconds.
- **DONE** Functions use bounded instances, zero warm minimum and dedicated least-privilege runtime identity.
- **DONE** notification fan-out and user-triggered operations use server-side abuse/cost controls.
- **DONE** Firestore Emulator security suite gates backend deployment.
- **DONE (2026-09-10)** Firestore Emulator security suite passed **12/12** against the 0.8.2 rules.
- **DONE (2026-09-10)** 0.8.2 Firestore rules compiled and were released to `homi-ee80a`.
- **DONE (2026-09-10)** stale `onConnectionDeleted` trigger-type migration completed safely; replacement `onTrustedConnectionDeleted` is active and the obsolete HTTPS resource was deleted.
- **DONE (Bruce-confirmed, 2026-09-10)** corrected batched 0.8.2 backend deployment completed successfully using the dedicated runtime path.

### 0.9 additions

- **DONE in source** `sendArrivalCheckIn` enforces App Check and authentication.
- **DONE in source** password-provider sender must be verified.
- **DONE in source** only Home/Work event labels are accepted.
- **DONE in source** maximum 10 selected recipients.
- **DONE in source** each delivered recipient is revalidated as an accepted Homi trusted connection at send time.
- **DONE in source** stale/disconnected selected recipients are skipped rather than notified.
- **DONE in source** sender rate limits: 20/hour and 60/day.
- **DONE in source** no more than 12 enabled device records are read per valid recipient.
- **DONE in source** recipient People-notification preference is respected.
- **DONE in source** saved Home/Work coordinates are never passed to the arrival callable.
- **VERIFY** deploy `sendArrivalCheckIn` through the proven batched helper after Flutter source validation.
- **VERIFY** callable succeeds from a registered App Check debug client and rejects invalid/unattested calls.

### Remaining production security/configuration

- **VERIFY** `configure-auth-security.sh` successfully applied: improved email privacy + password policy.
- **VERIFY** all active debug testers have individually registered App Check debug tokens before testing protected callables.
- **OPEN** inspect App Check metrics for legitimate debug traffic.
- **BLOCKER** release build uses Play Integrity App Check.
- **BLOCKER** enable App Check enforcement for Cloud Firestore after known-good clients are proven.
- **OPEN/RECOMMENDED** if Authentication is upgraded to Identity Platform and valid traffic is proven, enforce App Check for Authentication too.
- **OPEN** review old default Compute service-account permissions only after all active Functions are proven on `homi-backend-runtime`; never remove permissions blindly.
- **BLOCKER** configure Cloud Billing budget alerts.
- **BLOCKER where available** configure an appropriate Cloud Run Functions spend-control strategy. Budget alerts alone do not stop spend.
- **OPEN** Cloud Monitoring/Logging alerts for abnormal Function errors/invocations and Firestore usage.

Full architecture: `documentation/SECURITY.md`, `documentation/ARCHITECTURE.md`, `documentation/releases/0.8.2.md`, `documentation/releases/0.9.0.md`.

## Gate 5 — Authentication/account lifecycle

- **DONE** email/password sign-in and Google sign-in implemented.
- **DONE** email verification send/refresh flow implemented.
- **DONE** password reset implemented.
- **DONE** Google-only accounts do not receive irrelevant password controls.
- **DONE** provider-appropriate recent reauthentication exists for destructive deletion.
- **DONE** local erasure, sign-out and account deletion are distinct actions.
- **DONE** stronger create-account password baseline implemented.
- **DONE in source** successful account deletion clears user-scoped local arrival-check-in settings from the current device.
- **VERIFY** Authentication server security helper has been applied.
- **VERIFY** Google sign-in from the new 0.9.0 debug build.
- **VERIFY** verified email/password check-in/sharing works and unverified password accounts are blocked cleanly.
- **VERIFY** password reset remains non-enumerating after improved email privacy is enabled.
- **VERIFY** full account deletion on a disposable Google account and disposable email/password account, including arrival settings.

## Gate 6 — Notifications

- **DONE in source** fresh-install master operational notifications default ON.
- **DONE in source** Household attention, Tasks & routines, People, Service & security default ON.
- **DONE in source** Homi Updates/product announcements remain separately opt-in/OFF.
- **DONE in source** existing persisted notification preferences remain authoritative; an existing explicit OFF is not silently overwritten.
- **DONE in source** Android notification permission is requested once when operational notifications are enabled but OS permission is absent.
- **DONE in source** a denied/dismissed permission request is not repeatedly shown on every launch; user can retry from Homi & account → Notifications.
- **VERIFY** fresh-install Android permission prompt and resulting settings state on physical Android.
- **VERIFY** existing explicit notification-off install remains off after update.
- **VERIFY** arrival check-ins respect People notification opt-out.
- **DONE previously** developer self-test notification delivery proven on Samsung S25 Ultra.
- **OPEN** controlled broad developer broadcast before public users exist.

## Gate 7 — Legal, privacy and user-data obligations

- **DONE in-app draft** Why Homi exists, Privacy & your data, Location & safety, Terms of use and account controls exist.
- **DONE in source** Safety & check-ins states that Homi does not dispatch emergency responders or automatically send location to them.
- **DONE in source** Home/Work coordinates are local in the current check-in architecture and not inserted in arrival push payloads.
- **BLOCKER** final public Privacy Policy hosted on a stable HTTPS URL.
- **BLOCKER** final Terms of Use hosted on a stable HTTPS URL.
- **BLOCKER** external account-deletion page available without requiring the app.
- **BLOCKER** external deletion page actually performs or starts the supported deletion process rather than being a placeholder.
- **BLOCKER** Google Play Data Safety form matches the real implementation including background location/check-ins.
- **BLOCKER** background/precise location disclosures match actual processing.
- **OPEN** POPIA/privacy wording professionally reviewed for the intended South African launch.
- **OPEN** monitored support contact.
- **OPEN** retention/deletion wording reconciled against final Shared Household schema.
- **DONE** Homi does not market itself as emergency dispatch/crash detection/proof somebody is safe.

## Gate 8 — Payments and Homi+

A paid launch is not required for the first public build. Current commercial direction remains:

- Homi Free — R0;
- Homi+ — R49.99/month or R499.99/year;
- location-only friends do not consume paid Household seats;
- privacy, stop-sharing and account-deletion controls are never paywalled.

Do not enable a Homi+ paywall until the premium value actually exists. If the first public release is premium-enabled, complete Google Play Billing product/base-plan setup, purchase acknowledgement, entitlement restoration, grace/hold/cancel states and server-side purchase verification before release.

## Gate 9 — Production Android identity/signing

- **BLOCKER** create and safely back up permanent Homi upload key.
- **BLOCKER** configure release signing without committing passwords/keystores.
- **BLOCKER** opt into Play App Signing.
- **BLOCKER** register upload certificate SHA values where required.
- **BLOCKER** register Play app-signing SHA-1/SHA-256 with Firebase/Google OAuth where required.
- **BLOCKER** prove Google Sign-In from Play-installed build.
- **BLOCKER** production Maps key restrictions include production package/signing fingerprint.
- **BLOCKER** Play Integrity App Check configured for Play-signed build.
- **BLOCKER** approved Android App Bundle (`.aab`) produced.
- **BLOCKER** install/test through Google Play Internal Testing before production rollout.

Permanent package remains `za.co.theconceptlab.homi`.

## Gate 10 — Store listing and operational readiness

Required for submission/launch:

- final app name, short description and full description;
- launcher icon, feature graphic, phone screenshots and promotional assets;
- content rating questionnaire;
- target audience/age declarations;
- ads declaration;
- app access/reviewer instructions and test account if required;
- background-location declaration/review;
- Data Safety form;
- Privacy Policy URL;
- external account-deletion URL;
- support contact;
- release notes;
- staged production rollout plan rather than immediate 100% rollout.

Recommended before broad rollout:

- Firebase Crashlytics or equivalent privacy-conscious crash monitoring;
- operational dashboard/alerts for Functions errors, Firestore usage and cloud spend;
- tested rollback/disable plan for developer broadcasts and problematic cloud features.

## Current release position

The corrected `0.8.2+10` backend deployment has been confirmed successful. The source has now advanced to `0.9.0+11` with emergency-number shortcuts, explicit Home/Work arrival check-ins, People household/trusted grouping, assignee profile photos and fresh-install operational notification defaults.

The 0.9 source has **not yet been proven by Bruce's Flutter/Android toolchain** and the new `sendArrivalCheckIn` callable has not yet been claimed deployed. Immediate next gate is Windows `flutter analyze` + `flutter test`; only after those pass should the proven batched Cloud Shell helper publish the new callable, followed by physical-device regression.

The largest product blocker after this pass remains the Shared Household contract. If the public product promises a household-wide source of truth, Household cloud sync is the next major implementation milestone. Production signing, Play Integrity/App Check enforcement, public legal URLs and Play policy declarations then form the final deployment phase.
