# Homi — Release readiness

This is the source-of-truth checklist for moving Homi from a working development build to a public Google Play release. A visually complete app is not release-ready until the security, shared-data, policy, device and production-signing gates below are satisfied.

Current source version: **`0.9.0+11`**

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

- **DONE (Bruce-confirmed, 2026-09-10)** `flutter analyze` is clean on the validated 0.9.0+11 candidate.
- **DONE (Bruce-confirmed, 2026-09-10)** all Flutter tests pass on the validated 0.9.0+11 candidate.
- **OPEN** 0.9.0+11 launches and behaves correctly on the Samsung S25 Ultra.
- **OPEN** fresh-install and returning-user paths tested.
- **OPEN** local-only and signed-in paths tested.
- **OPEN** app background/resume, swipe-away/reopen and network-loss/recovery tested.
- **OPEN** every primary destination tested with empty and populated data.
- **OPEN** keyboard, safe-area and Android navigation insets checked.
- **OPEN** destructive actions tested on disposable data/accounts.
- **DONE previously** developer self-test notification delivery proven on Samsung S25 Ultra.
- **OPEN** notification taps tested from foreground, background and terminated app state.
- **OPEN** one controlled **All enabled Homi devices** broadcast before public users exist.

Validated application/backend candidate:

`c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`

Documentation-only commits may advance `main` after this SHA without changing the validated 0.9 application/backend source.

## Gate 2 — Shared Household product contract

Homi currently shares trusted-person location, Home/Work arrival events and specifically shared one-off Tasks through Firebase. Routines, Supplies and most Home records remain local-first on the current phone.

**BLOCKER if Homi is marketed as a shared household system:** implement a real Household identity/membership model plus conflict-safe cloud sync for Routines, Supplies, Home records and shared household state.

A local-first public launch is technically possible only if store/in-app copy explicitly states those boundaries. Do not imply another household member can see Routine/Supply/Home changes from their own phone when they cannot.

If Shared Household is implemented, use stable record IDs, timestamps/versioning, offline mutations, membership authorization, safe merge rules and tested account/device migration. Never resolve two devices by blindly overwriting one with the other.

## Gate 3 — Location, arrival check-ins and Google Play policy

### Implemented

- **DONE** explicit per-person opt-in live location sharing and visible stop-sharing controls.
- **DONE** latest-state-only cloud model; no default hidden route history.
- **DONE** Android foreground-service notification uses the Homi icon and remains visible while the shared background location stream is active.
- **DONE in source** Home and Work check-in places are stored locally, not as cloud location-history records.
- **DONE in source** arrival events send only Home/Work label + selected trusted recipients; no saved coordinates/address are included in the callable/push payload.
- **DONE in source** initial inside-zone state does not send; only outside → inside transition sends.
- **DONE in source** 100 m exit hysteresis plus one-hour local place cooldown reduces GPS-edge duplicates.
- **DONE in source** Live updates and Arrival check-ins have independent local ownership flags while sharing one foreground location stream.
- **DONE in source** emergency call shortcuts use phone-app handoff rather than silent direct-call permission.

### Must be verified on devices

- **VERIFY** two-device live location after 0.9.0 client install.
- **VERIFY** Home check-in real outside → inside transition sends exactly once.
- **VERIFY** Work check-in independently sends to selected people.
- **VERIFY** opening/restarting while already inside Home/Work does not send a false arrival.
- **VERIFY** recipient People-notification OFF suppresses arrival delivery.
- **VERIFY** disconnected/stale selected recipients are not notified and do not block valid selected recipients.
- **VERIFY** turning Arrival check-ins off leaves explicit Live updates working when live sharing remains on.
- **VERIFY** turning Live updates off leaves Arrival check-ins monitoring working when check-ins remain on.
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

### Proven backend foundation

- **DONE** sensitive collaboration mutations use Firebase callable Functions rather than broad client Firestore writes.
- **DONE** protected callables require Firebase Authentication and enforce App Check.
- **DONE** password-provider accounts must verify email before protected sharing actions.
- **DONE** Homi code issuance/lookup is server-side, App-Check protected and rate-limited.
- **DONE** connection count/code-attempt limits.
- **DONE** shared Task membership is server-derived from accepted Household relationships.
- **DONE** disconnect and Household→Friend cleanup removes stale Task-derived access.
- **DONE** server derives Task creator/completer identity.
- **DONE** cloud account deletion is server-side and requires recent authentication.
- **DONE** developer campaign creation is server-side; users cannot self-grant developer admin.
- **DONE** direct latest-location writes are owner-only, schema bounded and rate limited by Firestore rules.
- **DONE** Functions use bounded instances, zero warm minimum and the dedicated runtime identity.
- **DONE** notification fan-out and user-triggered operations use server-side abuse/cost controls.
- **DONE** Firestore Emulator security suite gates backend deployment.
- **DONE (2026-09-10)** Firestore Emulator security suite passed **12/12**.
- **DONE (2026-09-10)** Firestore rules compiled and were released to `homi-ee80a`.
- **DONE (2026-09-10)** stale `onConnectionDeleted` trigger migration completed; `onTrustedConnectionDeleted` is the active replacement.
- **DONE (Bruce-confirmed, 2026-09-10)** corrected batched 0.8.2 backend deployment completed successfully.

### 0.9 additions

- **DONE in source** `sendArrivalCheckIn` enforces App Check/authentication.
- **DONE in source** verified-email requirement for password-provider sender.
- **DONE in source** only Home/Work event labels accepted.
- **DONE in source** maximum 10 selected recipients.
- **DONE in source** each recipient is revalidated as an accepted Homi connection at send time.
- **DONE in source** stale/disconnected selections are skipped rather than notified.
- **DONE in source** sender rate limits: 20/hour and 60/day.
- **DONE in source** no more than 12 enabled device registrations read per valid recipient.
- **DONE in source** recipient People-notification preference respected.
- **DONE in source** saved Home/Work coordinates are never passed to the arrival callable.
- **DONE (Bruce-reported, 2026-09-10)** governed 0.9 backend helper completed without an observed failure, publishing the validated backend candidate including `sendArrivalCheckIn`.
- **VERIFY** `sendArrivalCheckIn` succeeds from a registered App Check debug client on-device and rejects invalid/unattested calls.

Full deployment record: `documentation/releases/0.9.0-backend-deployment-complete.md`.

### Remaining production security/configuration

- **VERIFY** `configure-auth-security.sh` has been applied successfully: improved email privacy + password policy.
- **VERIFY** all active debug testers have their own registered App Check debug token before protected-callable testing.
- **OPEN** inspect App Check metrics for legitimate debug traffic.
- **BLOCKER** release build uses Play Integrity App Check.
- **BLOCKER** enable App Check enforcement for Cloud Firestore only after known-good client traffic is proven.
- **OPEN/RECOMMENDED** consider Authentication App Check enforcement once Identity Platform/valid traffic requirements are satisfied.
- **OPEN** review old default Compute service-account permissions only after all active Functions are proven on `homi-backend-runtime`; never remove blindly.
- **BLOCKER** configure Cloud Billing budget alerts.
- **BLOCKER where available** configure appropriate Cloud Run Functions spend-control strategy.
- **OPEN** Cloud Monitoring/Logging alerts for abnormal Function errors/invocations and Firestore usage.

## Gate 5 — Authentication/account lifecycle

- **DONE** email/password and Google sign-in implemented.
- **DONE** email verification send/refresh flow implemented.
- **DONE** password reset implemented.
- **DONE** Google-only accounts do not receive irrelevant password controls.
- **DONE** provider-appropriate recent reauthentication exists for destructive deletion.
- **DONE** local erasure, sign-out and account deletion are distinct actions.
- **DONE** stronger create-account password baseline implemented.
- **DONE in source** successful account deletion clears user-scoped local arrival-check-in settings from the current device.
- **VERIFY** Authentication server security helper has been applied.
- **VERIFY** Google sign-in from the 0.9.0 debug build.
- **VERIFY** verified email/password check-in/sharing works and unverified password accounts are blocked cleanly.
- **VERIFY** password reset remains non-enumerating after improved email privacy is enabled.
- **VERIFY** full account deletion on disposable Google and email/password accounts, including arrival settings.

## Gate 6 — Notifications

- **DONE in source** fresh-install master operational notifications default ON.
- **DONE in source** Household attention, Tasks & routines, People, Service & security default ON.
- **DONE in source** Homi Updates/product announcements remain OFF until explicitly enabled.
- **DONE in source** existing persisted notification preferences remain authoritative.
- **DONE in source** Android notification permission is requested once when operational notifications are enabled but OS permission is absent.
- **DONE in source** a denied/dismissed permission request is not repeatedly shown every launch.
- **VERIFY** fresh-install Android permission prompt and resulting settings state on physical Android.
- **VERIFY** existing explicit notification-off install remains off after update.
- **VERIFY** arrival check-ins respect People notification opt-out.
- **DONE previously** developer self-test notification delivery proven on Samsung S25 Ultra.
- **OPEN** controlled broad developer broadcast before public users exist.

## Gate 7 — Legal, privacy and user-data obligations

- **DONE in-app draft** Why Homi exists, Privacy & your data, Location & safety, Terms of use and account controls exist.
- **DONE in source** Safety & check-ins states Homi does not dispatch emergency responders or automatically send location to them.
- **DONE in source** Home/Work coordinates are local in the current check-in architecture and not inserted into arrival push payloads.
- **BLOCKER** final public Privacy Policy hosted on stable HTTPS URL.
- **BLOCKER** final Terms of Use hosted on stable HTTPS URL.
- **BLOCKER** external account-deletion page available without requiring the app.
- **BLOCKER** external deletion page performs or starts the supported deletion process rather than being a placeholder.
- **BLOCKER** Google Play Data Safety form matches actual background location/check-in processing.
- **BLOCKER** background/precise-location disclosures match actual processing.
- **OPEN** POPIA/privacy wording professionally reviewed for intended South African launch.
- **OPEN** monitored support contact.
- **OPEN** retention/deletion wording reconciled against final Shared Household schema.
- **DONE** Homi does not market itself as emergency dispatch/crash detection/proof somebody is safe.

## Gate 8 — Payments and Homi+

A paid launch is not required for the first public build. Current planning direction remains:

- Homi Free — R0;
- Homi+ — R49.99/month or R499.99/year;
- location-only friends do not consume paid Household seats;
- privacy, stop-sharing, arrival-check-in disable and account deletion are never paywalled.

Do not enable a Homi+ paywall until premium value actually exists. If the first public release becomes premium-enabled, complete Play Billing product/base-plan setup, purchase acknowledgement, entitlement restoration, grace/hold/cancel states and server-side purchase verification first.

## Gate 9 — Production Android identity/signing

- **BLOCKER** create and safely back up permanent Homi upload key.
- **BLOCKER** configure release signing without committing passwords/keystores.
- **BLOCKER** opt into Play App Signing.
- **BLOCKER** register upload certificate SHA values where required.
- **BLOCKER** register Play app-signing SHA-1/SHA-256 with Firebase/Google OAuth where required.
- **BLOCKER** prove Google Sign-In from Play-installed build.
- **BLOCKER** production Maps key restrictions include production package/signing fingerprint.
- **BLOCKER** Play Integrity App Check configured for Play-signed build.
- **BLOCKER** approved Android App Bundle produced.
- **BLOCKER** install/test through Google Play Internal Testing before production rollout.

Permanent package: `za.co.theconceptlab.homi`.

## Gate 10 — Store listing and operational readiness

Required before submission/launch:

- final app name, short description and full description;
- launcher icon, feature graphic, phone screenshots and promotional assets;
- content rating questionnaire;
- target audience/age declarations;
- ads declaration;
- app access/reviewer instructions and test account where required;
- background-location declaration/review;
- Data Safety form;
- Privacy Policy URL;
- external account-deletion URL;
- support contact;
- release notes;
- staged production rollout plan.

Recommended before broad rollout:

- Firebase Crashlytics or equivalent privacy-conscious crash monitoring;
- operational dashboard/alerts for Functions errors, Firestore usage and cloud spend;
- tested rollback/disable plan for developer broadcasts and problematic cloud features.

## Current release position

The **0.9.0+11 source gate is complete**: Bruce confirmed the final post-cleanup analyzer was clean and all tests passed on the validated candidate `c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`.

Bruce subsequently reported that the governed Cloud Shell backend deployment completed without an observed failure. The backend publication gate is therefore recorded as user-confirmed complete; exact callable behaviour still requires physical-device acceptance.

**Immediate next gate: install/run the 0.9 client on the Samsung S25 Ultra and execute the structured device regression.** Do not return to backend deployment unless device evidence points to a backend defect.

The largest product blocker after device acceptance remains the Shared Household contract if Homi is to be marketed as a true household-wide source of truth. Production signing, Play Integrity/App Check enforcement, public legal URLs and Play policy declarations form the later deployment phase.
