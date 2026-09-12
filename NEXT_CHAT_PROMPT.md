# Homi — next chat handoff

Continue development of **Homi** from GitHub branch `homi-0.13-billing-entitlements`. GitHub is the source of truth for tracked source/docs. This branch is deliberately stacked on the final 0.12 candidate so the last minor Household UX polish could be included with the billing phase instead of creating a cosmetic micro-release.

Before changing anything, re-fetch the live branch head and inspect:

- `documentation/releases/0.12.0.md`
- `documentation/releases/0.12.0-shared-task-migration.md`
- `documentation/releases/0.13.0.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/MONETIZATION.md`
- `documentation/SECURITY.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- latest affected source

Use **mobile-app-development** first for app/source work, **concept-lab-release-integrity** for validation/merge/deployment, and **app-store-deployment** for Play Console/store work. Preserve approved behavior/design, brand assets and existing user data. Never claim a pass compiled/worked on-device until Bruce's real Flutter/Android toolchain proves it. A user rerun is not a diagnostic tool.

## Permanent project context

- local root: `C:\ConceptLab\Projects\homi`
- repo: `BruceVV11/homi`
- Android package: `za.co.theconceptlab.homi`
- Firebase/GCP: `homi-ee80a`
- project number: `883068189841`
- Firestore/Functions region: `africa-south1`
- Functions runtime: Node 22
- runtime identity: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`
- Flutter 3.41.5 / Dart 3.11.3 / JDK 21 / Gradle 8.14
- real device: Samsung S25 Ultra / `SM-S938B`
- `android/` intentionally local/untracked
- deleted `homi-508000` must never be used
- safety stash `stash@{0}: On main: Homi pre-0.5.0 local tracked changes` must never be popped/deleted automatically
- brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito, exact assets in `assets/brand`
- primary nav: **Overview · Tasks · Home · Supplies · People**
- privacy/revoke/stop-sharing/local erase/account deletion never paywalled

## Production and stacked source state

Production/backend remains the deployed 0.11 baseline at:

`3b26f3120864146f4ad3d2949e5a1a1416694b5c`

0.12 final candidate/head used as the 0.13 branch base:

`233c6ab16caa3a9c5951251d7805f57a68ca440c`

0.12 version: `0.12.0+16`.

0.12 is **not yet recorded as a governed Firebase production deployment**. Do not let 0.13 billing deployment skip that data-plane deployment/acceptance gate.

0.13 version: `0.13.0+17`.
Branch: `homi-0.13-billing-entitlements`.
Always re-fetch the live branch head; do not trust a SHA copied into this handoff because this file's own commit advances the branch.

## Final 0.12 device feedback carried into 0.13

Bruce approved the reusable **My code** behavior and requested the persistent orange code card be removed. Only the **My code** header action remains, opening the dedicated code sheet.

Bruce then reported two final minor Household UX issues and explicitly asked that they be folded into the next pass rather than creating a separate pass:

1. Canceling a pending Household invitation caused the same refresh/loading flash seen earlier.
2. The one-person **Add to Household** sheet felt visually sunken/too short.

0.13 source addresses both:

- `HouseholdService` now reuses stable current-Household/member/incoming/outgoing Firestore streams per authenticated UID, so `_busy` rebuilds no longer manufacture a new stream/loading state. This fixes the root pattern across cancel, rename, invite, remove, transfer and delete actions.
- `_InviteMemberSheet` now ends with a compact sage privacy/context panel explaining that Household membership never turns on location sharing. This adds useful visual balance rather than empty filler.

These changes are source-only until Bruce's real Flutter/device gate proves them.

## 0.12 shared Household data plane to preserve

Canonical path:

`households/{householdId}/data/{domain--itemId}`

Domains:

- `routine`
- `supply`
- `homeThing`
- `homeEvent`
- `utilityReading`

Local-first controller remains immediate device authority. Safe first-owner migration requires an authoritative non-cache empty server collection. Older unmatched data stays private when joining another/existing Household. Explicit local-only mode suppresses sync.

Personal **Me** Tasks remain local/private. Shared one-off Tasks use canonical Household membership; pre-0.12 task migration is intersection-only and never widens old audiences.

0.12 backend contract before billing additions:

- exactly **37** Functions;
- pure shared-task policy **5/5**;
- Firestore emulator **23/23**;
- governed safe legacy task migration and old Function drift reconciliation.

## Approved Homi+ commercial contract

- Free — R0
- Personal — R19.99/month: one sender seat
- Duo — R34.99/month: purchaser + one accepted trusted Homi connection as second sender seat
- Household — R49.99/month or R499.99/year: up to four canonical Household members
- every paid sender: maximum five active live viewers
- receiving live location is free
- Duo reassignment cooldown: seven days
- no annual Personal/Duo pricing is approved
- Household membership never turns on location sharing
- deleting Homi is separate from canceling Google Play billing

## 0.13 Homi+ source implementation

### Flutter/client

Added:

- `lib/src/domain/homi_entitlement.dart`
- `lib/src/domain/homi_billing_catalog.dart`
- `lib/src/services/homi_entitlement_service.dart`
- `lib/src/services/homi_billing_service.dart`
- `lib/src/services/homi_plus_management_service.dart`
- `lib/src/features/profile/homi_plus_page.dart`
- Profile Settings → **Homi+ → Plans & billing**
- `test/homi_entitlement_test.dart`

`pubspec.yaml` is now `0.13.0+17` and adds:

- `crypto: ^3.0.6`
- `in_app_purchase: ^3.3.0`
- exact `in_app_purchase_android: 0.5.0`

The direct Android plugin is intentionally pinned to 0.5.0 because it moves Homi to Play Billing Library 8 while remaining compatible with Homi's current Dart 3.11.3 toolchain. Later 0.5.x versions raise the Dart floor beyond the current toolchain.

**Important:** tracked `pubspec.lock` has not yet been regenerated for these new dependencies. The next real Flutter dependency-resolution step must update/commit that exact lock before treating the final 0.13 candidate as clean/validated.

The client Play catalog is intentionally blank/unconfigured. It cannot start a purchase until exact real Play IDs exist.

The client:

- queries Play product/base-plan details;
- displays Play-localized prices;
- can launch purchase/restore once catalog exists;
- uses SHA-256(`homi:<uid>`) as opaque Play account identifier rather than raw UID;
- sends purchase token to the protected backend;
- never grants itself paid capability from local purchase state;
- reads server-written `entitlements/{uid}`;
- provides Play subscription-management handoff;
- provides Duo second-seat UI.

### Recommended Play catalog

Use **one Google Play subscription product** for the Homi+ family:

- product: `homi_plus`
- base plan: `personal-monthly`
- base plan: `duo-monthly`
- base plan: `household-monthly`
- base plan: `household-annual`

Do not populate source catalogs until these exact IDs have actually been created and verified in Play Console. Do not invent duplicate/temporary store products to recover from setup mistakes.

### Backend

Added:

- `functions/billing_catalog.js`
- `functions/billing_policy.js`
- `functions/billing_policy.test.js`
- `functions/billing.js`
- billing exports in `functions/entrypoint.js`
- `google-auth-library` dependency

Billing Functions:

- `verifyGooglePlaySubscription`
- `setHomiPlusDuoSeat`
- `onGooglePlayBillingNotification`
- `onHomiPlusHouseholdChanged`
- `onHomiPlusConnectionDeleted`
- `onHomiPlusUserDeleted`

Expected 0.13 Functions surface: **43**.

Backend behavior:

- purchase verification requires Firebase Auth + App Check + server rate limit;
- calls Android Publisher subscriptions-v2 for permanent package `za.co.theconceptlab.homi`;
- Play `obfuscatedExternalAccountId` must match expected opaque Homi account hash;
- raw purchase token is server-only;
- verified unacknowledged subscription is acknowledged by the server;
- RTDN is a change signal and triggers authoritative Play lookup;
- backend-only `billingCoverage` records are reduced into self-readable `entitlements/{uid}`;
- multiple coverage sources are safe: ending one source does not delete another active source;
- Duo second seat must be an accepted trusted connection and cannot bypass seven-day cooldown through unassign/disconnect;
- Household coverage derives from purchaser's current canonical Household and caps at four;
- superseded purchase tokens cannot retake authority after plan change;
- account deletion removes Homi mappings/coverage but does not cancel Play billing.

### Billing Firestore boundary

Client may get only its own `entitlements/{uid}` and cannot write/list it.

Backend-only:

- `billingPurchases/*`
- `billingAccounts/*`
- `billingAccountLinks/*`
- `billingCoverage/*`

Two new emulator tests raise final 0.13 Firestore expected count to **25/25**.

Pure Functions policy suite expected count: **14/14** = existing 5 shared-task + 9 billing policy tests.

## 0.13 provider prerequisites

The governed backend helper now expects exactly 43 Functions and refuses billing deployment until:

- source-controlled Play catalog is populated;
- Android Publisher API is enabled on `homi-ee80a`;
- Pub/Sub topic `homi-google-play-rtdn` exists;
- `google-play-developer-notifications@system.gserviceaccount.com` has publisher on that topic;
- canonical runtime identity receives the minimum Play Console API access required for purchase verification/acknowledgement.

Actual Play Console API access must be proven by a Play Internal Testing purchase. GCP IAM alone is not accepted as proof.

## Paid enforcement status

**Paid enforcement is deliberately OFF.**

Do not gate continuous location or Shared Household capabilities merely because 0.13 billing source exists. First prove:

- real Play purchase;
- backend verification;
- server acknowledgement;
- restore/reinstall;
- voluntary cancel through paid term;
- grace;
- hold/paused/expiry;
- RTDN refresh;
- plan changes/superseded token behavior;
- Duo/Household coverage;
- multi-source entitlement safety;
- privacy exits without entitlement.

Then activate final server-authoritative capability enforcement in the launch candidate.

## Exact next sequence

1. Re-fetch `homi-0.13-billing-entitlements` and finish source/document preflight before asking Bruce to validate.
2. Resolve the tracked `pubspec.lock` using Bruce's real Flutter 3.41.5 toolchain; do not treat the expected lock change as an unexplained dirty worktree.
3. Close final 0.12 exact-head validation/merge/governed Firebase deployment before any 0.13 billing deployment reaches production.
4. Create the real Homi+ subscription/base plans in Play Console and record exact IDs.
5. Populate both client/backend governed catalogs with those IDs.
6. Configure Android Publisher API, Play Console API access and RTDN Pub/Sub.
7. Run exact-head 0.13 Windows Flutter gate, Node 22 lint/policy **14/14**, exact **43** exports and Firestore **25/25**; then S25 Ultra regression.
8. Merge/deploy exact accepted 0.13 billing source.
9. Upload/store-install an Internal Testing AAB and prove complete billing lifecycle.
10. Activate paid enforcement only after lifecycle proof.
11. Complete release signing/Play App Signing fingerprints, store-installed Google Sign-In, Play Integrity App Check, budgets, Privacy Policy, Terms, external deletion page, Data Safety, background-location approval evidence, listing/assets and any account-specific closed-testing requirement before production.

## Do not overclaim

- 0.12 is not production until its governed backend deployment is proven.
- 0.13 has not yet been compiled on Bruce's current exact branch head.
- Homi+ cannot be purchased until real Play IDs/provider setup exist.
- No billing lifecycle has been proven from a Play-installed build yet.
- A second physical device is still unavailable; do not claim two-device Shared Household acceptance.
