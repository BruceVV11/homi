# Homi — Release readiness

This is the source-of-truth checklist for moving Homi from working development build to a public Google Play release. A visually complete app is not considered release-ready until the security, shared-data, policy and production-signing gates below are satisfied.

## Gate 1 — Source and device stability

Required before release candidate:

- `flutter analyze` clean;
- all Flutter tests pass;
- production-like release build launches on a physical Android device;
- fresh install and returning-user paths tested;
- local-only and signed-in paths tested;
- app background/resume, swipe-away/reopen and network-loss/recovery tested;
- every primary destination tested with empty and populated data;
- keyboard, safe-area and Android navigation insets checked;
- destructive actions tested on disposable data/accounts;
- notification taps tested from foreground, background and terminated app state;
- one controlled **All enabled Homi devices** broadcast tested before public users exist.

## Gate 2 — Shared Household product contract

Homi already shares trusted-person location and specifically shared one-off Tasks through Firebase. Routines, Supplies and most Home records remain local-first on the current phone.

Before release, choose one truthful launch contract:

**A. Shared Household launch:** implement a real Household identity/membership model plus conflict-safe cloud sync for Routines, Supplies, Home records and shared household state. This is the preferred path because the product is designed around multiple people knowing what is happening at home.

**B. Local-first launch:** keep those areas device-local and make that boundary unmistakable in store copy and in-app explanations. Do not imply another household member can see Routine/Supply/Home changes from their own phone.

If Shared Household is implemented, the sync model must use stable record IDs, timestamps/versioning, offline mutations, membership authorization, safe merge rules and tested account/device migration. Never resolve two devices by blindly overwriting one with the other.

## Gate 3 — Location reliability and Google Play policy

Before public background-location release:

- test while screen is off;
- test app background for several hours;
- test normal process recreation;
- test device reboot;
- test Samsung battery optimisation/default power-saving behaviour;
- test revoked permission and location-services-off states;
- verify foreground-service notification remains visible while live updates are active;
- verify stopping live updates actually stops the stream;
- verify per-person share revocation immediately removes viewer access;
- measure battery behaviour over a representative day;
- prepare the Google Play background-location declaration, disclosure and review evidence;
- ensure store description explains the user-facing reason for background location without presenting Homi as emergency-grade tracking.

Force-stopping an Android app can prevent background work until the user opens it again. Homi must describe actual Android behaviour rather than promise impossible persistence.

## Gate 4 — Security and abuse/cost controls

Required before public release:

- App Check debug traffic shows valid requests;
- release build uses Play Integrity App Check;
- App Check enforcement enabled for Cloud Firestore only after legitimate traffic is proven;
- callable Functions that accept mobile input enforce App Check;
- restrictive Firestore rules deploy cleanly and are tested against unauthorised reads/writes;
- Cloud Functions keep bounded `maxInstances` in source;
- user-triggered notification paths keep server-side rate limits;
- developer broadcasts remain server-authorised and rate-limited;
- production Functions migrate from the broad default Compute runtime identity to a dedicated least-privilege service account;
- Maps/API keys remain Android-app + SHA restricted and API restricted;
- no service-account private key is bundled or downloaded for the app;
- Google Cloud billing budget alerts are configured;
- use a project/service spend cap where the billing account supports an appropriate cap, understanding that ordinary budget alerts alone do not stop spend;
- Cloud Monitoring/Logging reviewed for abnormal Firestore writes, Function invocations and error spikes during testing.

The current security-hardening details are in `documentation/releases/0.8.1.md`.

## Gate 5 — Legal, privacy and user-data obligations

Required before Play submission:

- final public Privacy Policy hosted on a stable HTTPS URL;
- final Terms of Use hosted on a stable HTTPS URL;
- external account-deletion page available without requiring the app;
- account-deletion page actually performs or starts the supported deletion process rather than being a placeholder;
- Google Play Data Safety form matches the real implementation;
- background location, precise location, account identity, notification token and shared household data disclosures match actual processing;
- POPIA/privacy wording professionally reviewed for the intended South African launch;
- support contact is monitored;
- retention/deletion wording matches backend behaviour;
- no marketing claim describes Homi as emergency dispatch, crash detection or proof that somebody is safe.

## Gate 6 — Payments and Homi+

A paid launch is not required for the first public build. Current commercial direction remains:

- Homi Free — R0;
- Homi+ — R49.99/month or R499.99/year;
- location-only friends do not consume paid Household seats;
- privacy, stop-sharing and account-deletion controls are never paywalled.

Do not enable a Homi+ paywall until the premium value actually exists. If the first public release is paid/premium-enabled, complete Google Play Billing product/base-plan setup, purchase acknowledgement, entitlement restoration, grace/hold/cancel states and server-side purchase verification before release.

## Gate 7 — Production Android identity/signing

Before the first Play release candidate:

- create and safely back up the permanent Homi upload key;
- configure release signing without committing passwords/keystores;
- opt into Play App Signing;
- register the upload certificate SHA values where required;
- after Play App Signing is available, register the Play app-signing SHA-1/SHA-256 with Firebase/Google OAuth as required;
- ensure Google Sign-In works from the Play-installed build, not only debug;
- ensure Maps key restrictions include the production package/signing fingerprint;
- ensure Play Integrity App Check is configured for the Play-signed build;
- build an Android App Bundle (`.aab`) from the approved release candidate;
- install/test through Google Play internal testing before production rollout.

Permanent package remains `za.co.theconceptlab.homi`.

## Gate 8 — Store listing and operational readiness

Required for submission/launch:

- final app name, short description and full description;
- launcher icon, feature graphic, phone screenshots and any required promotional assets;
- content rating questionnaire;
- target audience/age declarations;
- ads declaration;
- app access instructions if review needs a signed-in test account;
- background-location declaration/review;
- Data Safety form;
- Privacy Policy URL;
- external account-deletion URL;
- support contact;
- release notes;
- staged production rollout plan rather than immediate 100% rollout.

Recommended before broad rollout:

- crash/error monitoring such as Firebase Crashlytics with privacy-conscious logging;
- basic operational dashboard for Functions errors, Firestore usage and cloud spend;
- a tested rollback/disable plan for developer broadcasts and problematic cloud features.

## Current release position

Homi's visual/product baseline is close to approval and 0.8 notifications have been proven on the Samsung S25 Ultra, including developer self-test delivery. The remaining work is now primarily release hardening and product-contract work rather than a redesign.

The largest functional decision before store deployment is whether the first public release promises **shared Household state across devices**. If yes, Household cloud sync is the next major development milestone. If no, the release can remain local-first for Routines/Supplies/Home, but every public claim must reflect that boundary.
