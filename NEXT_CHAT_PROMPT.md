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

Use **mobile-app-development** first for app/source work, **concept-lab-delivery-integrity** for validation/merge/deployment, and **app-store-deployment** for Play Console/store work. Preserve approved behavior/design, brand assets and existing user data. Never claim a pass compiled/worked on-device until Bruce's real Flutter/Android toolchain proves it. A user rerun is not a diagnostic tool.

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

Firebase production/backend is now **0.12**, released from accepted merge:

`6a97eb23956da97cfe8266008c0827a303eec72c`

The governed release proved exactly 37 expected Functions ACTIVE on `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`, accepted Firestore rules/indexes deployed, the root-to-Household Shared Task migration stable with zero root records to move, and retired root Task/connection triggers absent. The exact pre-merge source had already passed Flutter 47/47, Functions policy 5/5 and Firestore 23/23.

Bruce then reported the requested S25 Ultra live Household/data-plane checks otherwise working as intended. True two-physical-device propagation is still unproven because only one real device is available.

0.12 version remains `0.12.0+16`. Do not repeat the 0.12 deployment gate unless new live evidence requires reconciliation.

0.13 version: `0.13.0+17`.
Branch: `homi-0.13-billing-entitlements`.
Always re-fetch the live branch head; do not trust a SHA copied into this handoff because this file's own commit advances the branch.

## Final 0.12 Household feedback folded into 0.13

Bruce explicitly asked not to make a cosmetic micro-release for these:

1. Canceling a pending Household invitation caused a refresh/loading flash.
2. The one-person **Add to Household** sheet felt too sunken/short.

0.13 source addresses both:

- `HouseholdService` reuses stable current-Household/member/incoming/outgoing Firestore streams for the authenticated UID, so `_busy` rebuilds do not manufacture a new stream/loading state. This fixes the root pattern across cancel, rename, invite, remove, transfer and delete actions.
- `_InviteMemberSheet` ends with a compact sage privacy/context panel explaining that Household membership never turns on location sharing. This adds useful visual weight instead of empty filler.

Source only until Bruce's real S25 Ultra proves it.

## 2026-09-27 live-device notification/sign-out feedback folded into 0.13

During the post-0.12 live S25 Ultra pass Bruce reported the Household/data-plane test otherwise working correctly, but identified three general account/settings issues:

1. Notification category switches felt swipe-dependent rather than tap-responsive.
2. Each notification change took several seconds before the visual state moved, and the master-enable flow left a redundant orange **Notifications are on for this device** success box below information already shown above.
3. **Sign out** showed an unrelated spinner below the button and then appeared to do nothing.

0.13 source now addresses these as one coherent settings/auth polish pass:

- each notification preference card is itself tappable and toggles the switch with one tap;
- notification preferences update the in-memory UI state immediately, persist locally, then serialize topic/device registration as best-effort background work so remote latency no longer holds the visible switch;
- category handlers read the latest preference state at tap time so rapid changes cannot revert a different category;
- successful notification enabling no longer creates the duplicate orange status box; a genuine Android permission denial still shows an explanation;
- sign-out stops local continuous sharing first, gives push deregistration only a short authenticated best-effort window, closes Firebase Auth as the actual Homi session boundary, and bounds Google provider cleanup so provider/network latency cannot trap the user;
- sign-out progress is rendered inline in the button as **Signing out…** rather than as a separate spinner below it;
- `test/settings_interaction_regression_test.dart` guards the notification tap/immediate-state contract, duplicate-banner removal, inline sign-out progress, bounded cleanup, and Firebase-before-Google sign-out ordering.
- a genuine sign-out failure uses Homi's branded information sheet and explicitly confirms local Homi data was not erased.

A follow-up S25 Ultra 0.13 pass then exposed one remaining signed-out navigation issue: tapping the Account hero's sign-in action set the app root to auth but left the pushed Account route above it, so Auth only became visible after Android Back. 0.13 now uses a single `_beginSignIn()` helper that switches the root into auth mode and pops the Account route in the same interaction. The same helper is used by signed-out Profile, Household and bottom sign-in entry points.

Authentication itself now has an explicit blocking product state: email/password create/sign-in and Google sign-in show a branded Homi overlay with animated progress until the auth result is known. `test/auth_navigation_regression_test.dart` guards both behaviours.

Do not confuse **local-only** with **Free**. Local-only is a no-account/device-only mode for personal on-device home tools. A signed-in Free user still has an account and can use account-dependent free capabilities such as trusted connections, receiving supported shared/location state, check-ins/emergency and other server-backed free features; paid sender/creator/Household capabilities remain governed separately by Homi+ entitlements.

These fixes are source-only until the next exact-head Windows/S25 validation.

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

Personal **Me** Tasks remain local/private. Canonical shared Tasks use `households/{householdId}/sharedTasks/{taskId}`; the root `sharedTasks` collection is migration-only and client access fails closed. Pre-0.12 safe audiences move into the exact Household subcollection, may shrink when members leave, and never widen on later joins.

Accepted 0.12 source contract before billing additions:

- exactly **37** Functions;
- pure shared-task policy **5/5**;
- Firestore emulator **23/23**;
- nested Task notification trigger replacements;
- governed root-to-Household legacy task migration and old Function drift reconciliation.

## Approved Homi+ commercial contract

- Free — R0
- Personal — R79.99/month or R799.99/year: one sender seat + trusted-person Shared Task/Routine creator capability
- Duo — R129.99/month or R1,299.99/year: purchaser + one accepted trusted Homi connection, both covered
- Household — R199.99/month or R1,999.99/year: four canonical Household members included
- extra Household members — R50/month or R500/year each, launch maximum ten
- every paid sender: maximum three active live viewers
- receiving live location is free
- Duo reassignment cooldown: seven days
- Household membership never turns on location sharing
- deleting Homi is separate from canceling Google Play billing

## 0.13 Flutter/client source

Added:

- `lib/src/domain/homi_entitlement.dart`
- `lib/src/domain/homi_billing_catalog.dart`
- `lib/src/services/homi_entitlement_service.dart`
- `lib/src/services/homi_billing_service.dart`
- `lib/src/services/homi_plus_management_service.dart`
- `lib/src/features/profile/homi_plus_page.dart`
- Profile Settings → **Homi+ → Plans & billing**
- `test/homi_entitlement_test.dart`

`pubspec.yaml` is `0.13.0+17` and adds:

- `crypto: ^3.0.6`
- `in_app_purchase: ^3.3.0`
- exact `in_app_purchase_android: 0.5.0`

The Android billing plugin is pinned to 0.5.0 because it moves Homi onto the Play Billing Library 8 integration line while remaining compatible with Dart 3.11.3. Later 0.5.x versions raise the Dart floor beyond the current Homi toolchain.

**Important:** Bruce's Windows validation on 2026-09-26 regenerated `pubspec.lock` successfully with the new billing dependencies, and that exact lockfile was subsequently committed/pushed on the 0.13 branch. Later source reconciliation/fixes moved the branch head, so the final exact 0.13 candidate still requires a fresh analyzer/test gate rather than reusing the older runtime claim.

The client:

- queries Play products/base plans and displays Play-localized prices;
- seeds the untouched Household member-count selector from the current server-written entitlement capacity rather than always showing four;
- starts purchase/restore only once the governed catalog is real/configured;
- uses SHA-256(`homi:<uid>`) rather than raw UID as Play's obfuscated account identifier;
- uses Google Play `ChangeSubscriptionParam` for cross-tier replacement rather than intentionally creating a second concurrent Homi+ subscription;
- uses Play Console's same-subscription base-plan replacement rule for monthly/annual changes; cross-product upgrades use `chargeProratedPrice` and downgrades use `withTimeProration`; license-test every transition before public sale;
- sends purchase token to the protected backend;
- never grants itself entitlement from local purchase state;
- reads only server-written `entitlements/{uid}`;
- fails closed when active/grace/canceled state has no future verified paid-through timestamp;
- provides Google Play subscription management and Duo seat UI.

## 2026-09-26 Windows validation/fix checkpoint

Bruce ran the exact local validation against predecessor head `4349791983bd8ed1f15a71cf79a1a285edecd54b`.

Observed directly:

- branch/head reconciliation succeeded;
- Flutter 3.41.5 / Dart 3.11.3 confirmed;
- `flutter pub get` regenerated only `pubspec.lock` and resolved `in_app_purchase`, `in_app_purchase_android` and related packages;
- analyzer found the invalid `HomiPlusManagementService({required this.firebaseReady})` initializing formal;
- full Flutter tests ran to completion with three failures, all tied to the retired five-viewer/old-price contract;
- Functions source lint completed;
- pure Functions policy tests passed **17/17**;
- the pasted validator's Functions dependency-install branch was malformed for interactive PowerShell, so that dependency-loaded stage is not proven;
- the pasted export regex returned zero because Homi's `entrypoint.js` uses `module.exports = { ...moduleSpreads }`, not direct `exports.foo =` declarations.

Source fixes applied after that run:

- constructor now accepts `required bool firebaseReady` and passes it to `HomiCloudActions`;
- backend live-location cap changed from five to the approved three viewers;
- `functions/package.json` lint now explicitly syntax-checks `location_share.js`;
- commercial guardrail and Homi+ plan tests now assert the approved three-viewer and R79.99 / R129.99 / R199.99 launch contract;
- location-safety documentation now distinguishes the current three-viewer candidate from older historical behavior.

Do **not** ask Bruce for more diagnosis. The next local action is one corrected exact-head validation block. It must preserve his locally regenerated `pubspec.lock`, fast-forward the branch, run Flutter analyze/tests, install Functions dependencies without an interactive `else` parser trap, run lint + 17/17 policy tests, and verify 43 exports by loading `entrypoint.js` and counting `Object.keys()`.

## Permanent Play catalog direction

Permanent Play catalog direction:

- `homi_plus_personal` — base plans `monthly`, `annual`;
- `homi_plus_duo` — base plans `monthly`, `annual`;
- `homi_plus_household_4` through `homi_plus_household_10` — base plans `monthly`, `annual`.

Household capacity variants are separate products because capacity changes the entitlement.

Do not populate source catalogs until these exact IDs exist in Play Console. Do not create temporary duplicate products.

## 0.13 billing backend source

Added:

- `functions/billing_catalog.js`
- `functions/billing_policy.js`
- `functions/billing_policy.test.js`
- `functions/check_policy_test_count.js`
- `functions/billing.js`
- billing exports in `functions/entrypoint.js`
- `google-auth-library`

Billing Functions:

- `verifyGooglePlaySubscription`
- `setHomiPlusDuoSeat`
- `onGooglePlayBillingNotification`
- `onHomiPlusHouseholdChanged`
- `onHomiPlusConnectionDeleted`
- `onHomiPlusUserDeleted`

Expected 0.13 export surface: **43 Functions**.

Current backend behavior:

- Auth + App Check + rate limit on purchase verification;
- authoritative Android Publisher `purchases.subscriptionsv2.get` for `za.co.theconceptlab.homi`;
- verified Play account/Homi account binding through obfuscated account ID;
- raw purchase tokens kept backend-only;
- entitlement/coverage reconciliation occurs from verified Play state; server acknowledges when Play says acknowledgement is pending;
- active/grace/canceled state grants capability only with a future verified paid-through timestamp;
- multi-source `billingCoverage` is reduced into `entitlements/{uid}`, so one source ending cannot erase a separate valid source;
- Duo second seat requires accepted connection and seven-day reassignment cooldown cannot be bypassed by unassign/disconnect;
- Household coverage derives from the current canonical Household; four are included and verified paid capacity can scale to ten;
- the purchaser always counts inside that verified paid member limit, so member ordering cannot accidentally cover one extra person;
- a new token replacing another still-entitled canonical purchase must be linked by Play's `linkedPurchaseToken`;
- a token already marked superseded cannot become canonical again;
- a fresh verified purchase may become canonical after the previous one is no longer entitled;
- Google Play out-of-app resubscribe is supported using the authoritative `outOfAppPurchaseContext.expiredExternalAccountIdentifiers` and `expiredPurchaseToken` fields when the prior Homi billing account link still exists;
- deleting a Homi account removes coverage and scans **all** historical purchaser-linked Homi billing records, strips raw stored Play purchase tokens/Homi purchaser identity, removes the billing account link, and does not pretend to cancel the Google Play subscription.

The official current `SubscriptionPurchaseV2` schema confirms the out-of-app context field names above and states they are present for Play subscription-center resubscriptions after the previous same-product subscription expired. Do not replace these with guessed field names.

## Billing Firestore/security gates

Client may `get` only its own `entitlements/{uid}` and cannot list/write/delete it.

Backend-only:

- `billingPurchases/*`
- `billingAccounts/*`
- `billingAccountLinks/*`
- `billingCoverage/*`

0.13 Firestore expected count: **25/25** = existing 23 + 2 billing boundary tests.

Pure Functions policy expected count: **17/17** = 5 shared-task + 12 billing tests.

`functions/check_policy_test_count.js` is wired into Functions `pretest`, so a stale/omitted pure policy suite fails closed unless it declares exactly 17 tests.

**Historical evidence:** the source-level pure policy suite passed **16/16** under Node 22 before the exact Household paid-capacity regression test was added. The current candidate now requires **17/17** and still needs that exact post-fix validation.

## Account deletion UX/source

0.13 source now explicitly says on the Delete Homi account card and both destructive confirmation sheets that deleting Homi does **not** cancel a Google Play Homi+ subscription. It directs users who also want billing canceled to:

**Profile settings → Homi+ → Plans & billing → Manage subscription**

The Privacy/Terms/About source copy is also aligned to 0.12 Shared Household synchronization and 0.13 Google Play billing.

## Provider prerequisites before billing deployment

The governed backend helper expects exactly 43 Functions and refuses billing deployment until:

- source-controlled Play catalog is populated;
- Android Publisher API is enabled on `homi-ee80a`;
- Pub/Sub topic `homi-google-play-rtdn` exists;
- `google-play-developer-notifications@system.gserviceaccount.com` has publisher on that topic;
- canonical Homi runtime identity has the minimum Play Console API access for purchase verification/acknowledgement.

Actual Play app/API authorization must be proven by a Play Internal Testing purchase. GCP IAM alone is not proof.

## Paid enforcement status

**Paid enforcement is deliberately OFF.**

Do not gate continuous location or Shared Household capabilities merely because 0.13 billing source exists. First prove:

- real Play purchase;
- backend verification;
- server acknowledgement;
- cross-tier replacement and linked-token lineage;
- restore/reinstall;
- out-of-app resubscribe;
- voluntary cancellation through paid term;
- grace;
- hold/paused/expiry;
- RTDN refresh;
- superseded-token replay resistance;
- Duo/Household coverage;
- multi-source entitlement safety;
- privacy exits without entitlement.

Then activate final server-authoritative capability enforcement in the launch candidate.

## Exact next sequence

1. Re-fetch the branch head; current source/document preflight has been narrowed to real-toolchain/provider validation rather than another speculative source pass.
2. On Bruce's real Flutter 3.41.5 toolchain, resolve/update the tracked `pubspec.lock`, then run exact-head analyzer/full Flutter tests. Treat `pubspec.lock` as an expected change but stop if unrelated tracked files become dirty.
3. Run exact-head 0.13 governed Node 22 dependency lint/policy **17/17**, exact **43** exports and Firestore **25/25**, then S25 Ultra regression covering Household Cancel no-refresh, balanced Add-to-Household sheet, tap-responsive notification preferences with immediate visual state, no duplicate enabled banner, responsive inline sign-out, Homi+ page safety, and preservation of existing People/Home/Tasks/Supplies data.
4. Create the nine permanent Homi+ subscription products in Play Console — Personal, Duo, and Household 4–10 — with monthly and annual base plans, and record the exact IDs.
5. Populate both client/backend governed catalogs with those IDs.
6. Configure Android Publisher API, Play Console API access and RTDN Pub/Sub.
7. Merge/deploy the exact accepted 0.13 billing source only after provider prerequisites are present.
8. Upload/store-install an Internal Testing AAB and prove the complete billing lifecycle, including client/server acknowledgement behavior, replacement modes, out-of-app resubscribe and token-lineage behavior.
9. Activate paid enforcement only after lifecycle proof.
10. Complete release signing/Play App Signing fingerprints, store-installed Google Sign-In, Play Integrity App Check, budgets, Privacy Policy, Terms, external deletion page, Data Safety, background-location approval evidence, listing/assets and any account-specific closed-testing requirement before production.

## Do not overclaim

- 0.12 backend is production-released and Bruce reported the requested one-device live Household/data-plane acceptance otherwise working as intended; true two-device propagation remains unproven.
- 0.13 has not yet been compiled/analyzed/tested on Bruce's final exact branch head after the notification/sign-out fixes and 0.12 reconciliation.
- 0.13 current exact `billing.js` still requires the governed dependency-loaded Functions lint before any deploy claim.
- Homi+ cannot be purchased until real Play IDs/provider setup exist.
- No billing lifecycle has been proven from a Play-installed build yet.
- A second physical device is still unavailable; do not claim two-device Shared Household acceptance.
