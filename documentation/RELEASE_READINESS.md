# Homi — Release readiness

This is the source-of-truth checklist for moving Homi from working development build to a public Google Play release. A visually complete app is not considered release-ready until the security, shared-data, policy and production-signing gates below are satisfied.

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

- **VERIFY** `flutter analyze` clean on 0.8.2+10.
- **VERIFY** all Flutter tests pass on 0.8.2+10.
- **OPEN** production-like release build launches on a physical Android device.
- **OPEN** fresh install and returning-user paths tested.
- **OPEN** local-only and signed-in paths tested.
- **OPEN** app background/resume, swipe-away/reopen and network-loss/recovery tested.
- **OPEN** every primary destination tested with empty and populated data.
- **OPEN** keyboard, safe-area and Android navigation insets checked.
- **OPEN** destructive actions tested on disposable data/accounts.
- **DONE** developer self-test notification delivery proven on Samsung S25 Ultra.
- **OPEN** notification taps tested from foreground, background and terminated app state.
- **OPEN** one controlled **All enabled Homi devices** broadcast before public users exist.

## Gate 2 — Shared Household product contract

Homi already shares trusted-person location and specifically shared one-off Tasks through Firebase. Routines, Supplies and most Home records remain local-first on the current phone.

**BLOCKER if Homi is marketed as a shared household system:** implement a real Household identity/membership model plus conflict-safe cloud sync for Routines, Supplies, Home records and shared household state. This remains the preferred product path because Homi is intended to let authorised household members know what is happening at home from their own devices.

A local-first public launch remains technically possible only if store/in-app copy explicitly states those areas remain on the current device. Do not imply another household member can see Routine/Supply/Home changes from their own phone.

If Shared Household is implemented, the sync model must use stable record IDs, timestamps/versioning, offline mutations, membership authorization, safe merge rules and tested account/device migration. Never resolve two devices by blindly overwriting one with the other.

## Gate 3 — Location reliability and Google Play policy

- **DONE** explicit per-person opt-in sharing and visible stop-sharing controls.
- **DONE** latest-state-only default cloud model; no hidden route history.
- **DONE** Android foreground-service notification is explicit and uses the Homi icon.
- **VERIFY** two-device location sharing after 0.8.2 protected-callable deployment.
- **OPEN** screen-off test.
- **OPEN** several-hours background test.
- **OPEN** normal process recreation test.
- **OPEN** device reboot test.
- **OPEN** Samsung battery optimisation/default power-saving test.
- **OPEN** revoked permission and location-services-off tests.
- **OPEN** verify foreground-service notification remains visible while live updates are active.
- **OPEN** verify stopping live updates actually stops the stream.
- **OPEN** verify per-person share revocation immediately removes viewer access.
- **OPEN** representative-day battery measurement.
- **BLOCKER** Google Play background-location declaration, prominent disclosure and review evidence.

Force-stopping an Android app can prevent background work until the user opens it again. Homi must describe actual Android behaviour rather than promise impossible persistence.

## Gate 4 — Security and abuse/cost controls

### Implemented in source

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
- **DONE** user-triggered notification paths and developer broadcasts have server-side rate limits.
- **DONE** notification direct fan-out capped at 12 enabled device records per user.
- **DONE** Firestore emulator security suite gates backend deployment.
- **DONE** generated Cloud Shell dependencies/caches are temporary or safely cleanable.
- **DONE** Maps key design remains package/SHA/API restricted; no service-account private key is bundled.

### Must be proven/configured before release

- **VERIFY** run `configure-auth-security.sh` successfully: improved email privacy + password policy.
- **VERIFY** 0.8.2 Functions/rules deploy using the dedicated runtime identity.
- **VERIFY** emulator security suite passes against 0.8.2 rules.
- **VERIFY** all active debug testers have individually registered App Check debug tokens before testing protected callables.
- **OPEN** inspect App Check metrics for legitimate debug traffic.
- **BLOCKER** release build uses Play Integrity App Check.
- **BLOCKER** enable App Check enforcement for Cloud Firestore after known-good clients are proven.
- **OPEN/RECOMMENDED** if Authentication is upgraded to Identity Platform and valid traffic is proven, enforce App Check for Authentication too.
- **OPEN** review old default Compute service account permissions after every Function is proven on `homi-backend-runtime`; never remove permissions blindly.
- **BLOCKER** configure Cloud Billing budget alerts.
- **BLOCKER where available** configure a Cloud Run functions spend-cap budget for `homi-ee80a`. Budget alerts alone do not stop spend.
- **OPEN** Cloud Monitoring/Logging alerts for abnormal Function errors/invocations and Firestore usage.

Full architecture: `documentation/SECURITY.md` and `documentation/releases/0.8.2.md`.

## Gate 5 — Authentication/account lifecycle

- **DONE** email/password sign-in and Google sign-in implemented.
- **DONE** email verification send/refresh flow implemented.
- **DONE** password reset implemented.
- **DONE** Google-only accounts do not receive irrelevant password controls.
- **DONE** provider-appropriate recent reauthentication exists for destructive deletion.
- **DONE** local erasure, sign-out and account deletion are distinct actions.
- **DONE** 0.8.2 create-account UI mirrors stronger password baseline.
- **VERIFY** Authentication server security helper has been applied.
- **VERIFY** Google sign-in from the new 0.8.2 debug build.
- **VERIFY** verified email/password sharing works and unverified email/password sharing is blocked cleanly.
- **VERIFY** password reset remains non-enumerating after improved email privacy is enabled.
- **VERIFY** full account deletion on a disposable Google account and disposable email/password account.

## Gate 6 — Legal, privacy and user-data obligations

- **DONE in-app draft** Why Homi exists, Privacy & your data, Location & safety, Terms of use and account controls exist.
- **BLOCKER** final public Privacy Policy hosted on a stable HTTPS URL.
- **BLOCKER** final Terms of Use hosted on a stable HTTPS URL.
- **BLOCKER** external account-deletion page available without requiring the app.
- **BLOCKER** external deletion page actually performs or starts the supported deletion process rather than being a placeholder.
- **BLOCKER** Google Play Data Safety form matches the real implementation.
- **BLOCKER** background/precise location disclosures match actual processing.
- **OPEN** POPIA/privacy wording professionally reviewed for the intended South African launch.
- **OPEN** monitored support contact.
- **OPEN** retention/deletion wording reconciled against the final shared-Household schema.
- **DONE** Homi does not market itself as emergency dispatch/crash detection/proof somebody is safe.

## Gate 7 — Payments and Homi+

A paid launch is not required for the first public build. Current commercial direction remains:

- Homi Free — R0;
- Homi+ — R49.99/month or R499.99/year;
- location-only friends do not consume paid Household seats;
- privacy, stop-sharing and account-deletion controls are never paywalled.

Do not enable a Homi+ paywall until the premium value actually exists. If the first public release is paid/premium-enabled, complete Google Play Billing product/base-plan setup, purchase acknowledgement, entitlement restoration, grace/hold/cancel states and server-side purchase verification before release.

## Gate 8 — Production Android identity/signing

- **BLOCKER** create and safely back up the permanent Homi upload key.
- **BLOCKER** configure release signing without committing passwords/keystores.
- **BLOCKER** opt into Play App Signing.
- **BLOCKER** register upload certificate SHA values where required.
- **BLOCKER** register Play app-signing SHA-1/SHA-256 with Firebase/Google OAuth where required.
- **BLOCKER** prove Google Sign-In from the Play-installed build.
- **BLOCKER** production Maps key restrictions include the production package/signing fingerprint.
- **BLOCKER** Play Integrity App Check configured for the Play-signed build.
- **BLOCKER** approved Android App Bundle (`.aab`) produced.
- **BLOCKER** install/test through Google Play Internal Testing before production rollout.

Permanent package remains `za.co.theconceptlab.homi`.

## Gate 9 — Store listing and operational readiness

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

The approved Homi interface and core single-device flows are close to release-candidate quality. Notifications and developer self-test delivery have been proven on the Samsung S25 Ultra. 0.8.2 is the security-closure source pass and must now be compiled, emulator-tested, deployed and exercised across at least two Android devices.

The largest product blocker remains the shared-Household contract. If the public product promises a household-wide source of truth, Household cloud sync is the next major implementation milestone after 0.8.2 verification. Production signing, Play Integrity/App Check enforcement, public legal URLs and Play policy declarations then form the final deployment phase.
