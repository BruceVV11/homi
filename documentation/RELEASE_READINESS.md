# Homi — Release readiness

Date: 2026-09-27
Current development candidate: **0.13.0+17**
Development branch: `homi-0.13-billing-entitlements`
Stacked base: accepted 0.12 merge `6a97eb23956da97cfe8266008c0827a303eec72c`
Current production/backend baseline: **0.12 released from `6a97eb23956da97cfe8266008c0827a303eec72c`**

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Release order

0.13 is intentionally stacked on the accepted 0.12 source so billing work and the final live-device polish can continue without creating another cosmetic micro-release. The governed 0.12 backend is now deployed and its requested S25 Ultra live Household/data-plane checks were reported working as intended; true two-physical-device propagation remains unproven.

The governed order is now:

1. exact-head validate the reconciled 0.13 client/backend source and S25 Ultra UX;
2. finish 0.13 Google Play provider setup;
3. deploy/validate the 0.13 billing backend only after provider prerequisites are present;
4. prove the complete billing lifecycle from a Play Internal Testing install;
5. activate paid enforcement only in a final accepted launch candidate;
6. close store/signing/legal/background-location/App Check gates before production.

## Gate 1 — Source and device stability

Established evidence:

- **DONE (0.10)** Windows analyzer/tests and governed backend deployment.
- **DONE (0.11)** governed backend deployed; S25 Ultra confirmed emergency-sheet/flag fixes and canonical Household creation/invite flow. True second-physical-device acceptance remains unproven because a second device is unavailable.
- **DONE as historical 0.12 evidence** an earlier 0.12 exact head passed the Windows Flutter gate; later device feedback drove further source changes.
- **DONE on S25 Ultra for the latest reviewed 0.12 UX before 0.13 stacking** reusable **My code** loads, the persistent orange code card was removed by request, and the Household candidate picker was reviewed.
- **DONE in 0.13 source / VERIFY** the Household Firestore streams are now stable across `_busy` rebuilds so cancel/rename/invite/remove/transfer/delete do not recreate the stream and flash back to loading.
- **DONE in 0.13 source / VERIFY** Add-to-Household now ends with a compact privacy/context panel so a one-person candidate sheet does not feel visually sunken.
- **DONE in 0.13 source / VERIFY** notification preference cards are full tap targets, local preference state updates immediately while provider sync runs in serialized background work, and the redundant enabled-success banner is gone.
- **DONE in 0.13 source / VERIFY** sign-out uses inline button progress, bounds push/Google cleanup so it cannot stall the account session, and surfaces real failures in a branded sheet.
- **DONE in 0.13 source** `test/settings_interaction_regression_test.dart` guards the notification tap/immediate-state and sign-out sequencing contracts.
- **DONE in 0.13 source / VERIFY** signed-out Account/Household sign-in actions now reveal the auth page immediately rather than leaving the pushed Account route above it.
- **DONE in 0.13 source / VERIFY** email/password and Google sign-in use a branded blocking progress state while authentication is in flight.
- **DONE in 0.13 source** `test/auth_navigation_regression_test.dart` guards the signed-out auth-route and progress-overlay contracts.
- **DONE in 0.13 source / VERIFY** People/location is fully gated behind signed-in + verified-email state, with branded sign-in/verification actions and no underlying map/sharing controls constructed while locked.
- **DONE in 0.13 source** runtime/check-in, `setLocationShare` and Firestore sensitive location surfaces carry the same verified-account boundary.
- **DONE in 0.13 source** `test/people_verified_access_regression_test.dart` guards that cross-layer contract.

Still required:

- **VERIFY** exact final 0.13 Windows `flutter pub get`, analyzer and full Flutter tests after Play Billing dependencies are locked.
- **VERIFY** exact current S25 Ultra 0.13 regression: signed-out People shows only the account gate, unverified email shows only the verification gate, verified account restores People/location; invitation cancel has no page refresh/loading flash; notification categories toggle immediately; sign-out/auth progress remains correct; Homi+ opens safely; existing Home/Tasks/Supplies data remains intact.
- **OPEN** fresh-install/returning-user/background/reboot/Samsung power-management pass before production.

## Gate 2 — People, location and safety

Implemented and preserved:

- **DONE** map-first People, opt-in per-person location sharing and latest-state location model for signed-in verified accounts;
- **DONE** accepted connections load independently of GPS startup;
- **DONE** reusable **My code** is available on demand without a permanent code card;
- **DONE** Household/Friend scope is canonical/read-only rather than a user-created authorization toggle;
- **DONE** Household membership does not enable location sharing;
- **DONE** arrival check-ins are locally detected and contain no saved precise Home/Work address/coordinate in the arrival delivery payload;
- **DONE** exact saved Home/Work sharing is separately controlled;
- **DONE** emergency actions hand off to the system dialer;
- **DONE** existing 90-second cloud-write floor; 0.13 revises the paid sender limit to three active viewers.

Before production:

- **VERIFY** store-installed background sharing/check-ins under real Samsung power behavior;
- **VERIFY** Play-installed Google Sign-In and App Check after Play App Signing fingerprints are registered;
- **BLOCKER** Google Play background-location prominent disclosure/declaration/review evidence.

## Gate 3 — Canonical Shared Household + 0.12 data plane

0.11 canonical identity is implemented:

- one Household per account;
- owner/member roles;
- four occupied/reserved seats;
- accepted trusted connection required before invitation;
- explicit invite acceptance;
- owner transfer/remove/leave/delete semantics;
- membership separate from connection/location sharing.

0.12 shared data is implemented in source at:

`households/{householdId}/data/{domain--itemId}`

Domains:

- Routines;
- Supplies;
- Home Things;
- maintenance/repair events;
- utility readings.

Personal **Me** Tasks remain local/private. Canonical shared Tasks use `households/{householdId}/sharedTasks/{taskId}`; the root `sharedTasks` collection is migration-only and fails closed to clients.

0.12 safety contracts:

- **DONE in source** local writes remain first and cloud sync is additive;
- **DONE in source** authoritative non-cache empty state required before the narrow first-owner migration;
- **DONE in source** old unmatched records stay private when joining an existing/different Household;
- **DONE in source** local-only mode suppresses Household synchronization;
- **DONE in source** parent Household deletion cleans nested `data` and canonical nested `sharedTasks` in bounded batches;
- **DONE in source** shared Task create/toggle/remove retain their callable names while storage is Household-path-authoritative;
- **DONE in source** migrated historical Task audiences may shrink when members leave but never widen when later members join;
- **DONE in source** safe root-to-Household legacy Task migration with fail-closed unmappable records.

Required before calling 0.12 deployed/accepted:

- **VERIFY** exact governed Node 22 backend gate;
- **VERIFY** exact **37** Function exports;
- **VERIFY** existing Functions task policy **5/5**;
- **DONE source gate** Firestore **23/23** passed on accepted 0.12 PR head `709a8c92458b7b3b056e8e55e52eec05e8d8757b` before merge;
- **VERIFY** legacy shared-task migration dry-run/apply/assert-stable;
- **VERIFY** Firestore rules/indexes and all 37 Functions deployed from the accepted merge SHA;
- **VERIFY** existing local Routines/Supplies/Home records survive and shared add/update/delete survives restart;
- **VERIFY when a second client is available** true remote propagation/conflict behavior.

## Gate 4 — Homi+ commercial contract

Approved contract:

- Free — R0;
- Personal — R79.99/month or R799.99/year, one sender seat plus trusted-person Shared Task/Routine creator capability;
- Duo — R129.99/month or R1,299.99/year, purchaser + one assigned accepted trusted Homi connection, both covered;
- Household — R199.99/month or R1,999.99/year, four members included;
- Household extras — R50/month or R500/year per member above four, launch maximum ten;
- every paid sender: maximum three active trusted live viewers;
- receiving live location remains free;
- privacy/revoke/leave/erase/delete controls never paywalled;
- Duo seat reassignment cooldown: seven days.

## Gate 5 — 0.13 billing client and entitlement architecture

**DONE in source / VERIFY compile/runtime:**

- official Flutter `in_app_purchase` purchase stream/query/restore integration;
- Android billing plugin pinned to the current Homi Dart-compatible Billing Library 8 line;
- one source-controlled Play catalog boundary, deliberately unconfigured until real Play IDs exist;
- opaque SHA-256-derived Homi account association instead of raw UID as Play obfuscated account ID;
- dedicated **Homi+ → Plans & billing** surface in Profile Settings;
- Play-localized price display once products exist;
- Household member-count selection starts from the current server-written Household capacity until the user intentionally changes the requested 4–10 member tier;
- explicit purchase confirmation and Play subscription-management handoff;
- Google Play cross-product subscription replacement for Homi+ tier changes;
- server-written entitlement reader that fails closed to Free and treats active/grace/canceled state as expired when its verified paid-through timestamp is missing or no longer in the future;
- Duo seat management UI/service;
- client never grants itself entitlement from local purchase state.

The permanent Play catalog to create/verify is:

- `homi_plus_personal` → `monthly`, `annual`;
- `homi_plus_duo` → `monthly`, `annual`;
- `homi_plus_household_4` through `homi_plus_household_10` → `monthly`, `annual`.

Personal/Duo cadence changes stay within one subscription product. Household capacity is an entitlement change, so each capacity uses its own product and cross-product changes use Play subscription replacement rather than a concurrent purchase.

**BLOCKER before 0.13 billing can be exercised:** create/verify these permanent store IDs in Play Console and then populate the source-controlled Flutter + Functions catalogs with the exact same identifiers.

## Gate 6 — 0.13 billing backend/security

**DONE in source / VERIFY governed runtime:**

- App-Check/Auth-protected `verifyGooglePlaySubscription`;
- Android Publisher `purchases.subscriptionsv2.get` verification;
- purchase/account binding through expected Play obfuscated external account ID;
- raw token stored only in backend-only state;
- backend acknowledgement for verified unacknowledged subscriptions;
- RTDN Pub/Sub handler that treats notifications only as a signal and re-fetches Play state;
- server rate limits for billing verification and Duo seat changes;
- multi-source `billingCoverage` reduction into self-readable `entitlements/{uid}` so one expired source cannot erase another valid source;
- current canonical Household derives Household coverage;
- Household coverage always counts the purchaser inside the verified paid member limit and cannot over-cover by one when the purchaser is later in canonical member ordering;
- accepted trusted connection derives the Duo second seat;
- Duo cooldown cannot be reset by unassign/disconnect;
- paid-term expiry normalization requires a future verified paid-through timestamp before active/grace/canceled state can grant capability;
- Play `linkedPurchaseToken` lineage is required before a new token can replace another still-entitled canonical purchase;
- an already-superseded token cannot retake canonical authority;
- account deletion cleans every historical purchaser-linked Homi billing record, strips raw stored purchase tokens/Homi purchaser identity, removes coverage/account links, and does not pretend to cancel Google Play billing;
- pure policy source preflight has a fail-closed declared-test-count guard for the exact expected suite.

Source-level evidence already obtained in this development pass:

- **DONE historical source-only** an earlier Node 22 pure Functions policy run passed **16/16** before the exact Household capacity regression guard was added. The current candidate now requires **17/17** (5 shared-task + 12 billing); that exact suite is **VERIFY**, not yet claimed.

0.13 backend expected governed gates:

- **VERIFY exact current head** Node 22 dependency install/lint, including the exact current `billing.js` and three-viewer `location_share.js` source. A predecessor-head source-level lint completed on 2026-09-26, but the dependency-install step in the pasted PowerShell validator did not complete;
- **VERIFY exact current head** pure Functions policy suite **17/17**. The suite passed 17/17 on predecessor head `4349791983bd8ed1f15a71cf79a1a285edecd54b`, but the candidate moved afterward;
- **VERIFY** exact **43** Function exports by loading `functions/entrypoint.js` after dependencies are installed; do not use a regex that only counts `exports.foo =` because the entrypoint composes module spreads;
- **VERIFY** Firestore emulator **26/26**: existing 23 + 2 billing boundary tests + 1 verified-location boundary tests + 1 verified-location boundary test;
- **DONE in source / PROVIDER ACTION REQUIRED** exact nine-product/18-base-plan contract is frozen in `scripts/google-play-subscription-catalog.json` and checked by `scripts/check-google-play-subscription-contract.js`;
- **DONE in source / PROVIDER ACTION REQUIRED** `scripts/bootstrap-google-play-provider.sh` safely enables Android Publisher + creates/verifies `homi-google-play-rtdn` and its Google Play publisher binding;
- **BLOCKER** source-controlled Play catalog IDs are currently blank;
- **BLOCKER** Android Publisher API must be enabled on `homi-ee80a`;
- **BLOCKER** Pub/Sub topic `homi-google-play-rtdn` plus Google Play notification publisher IAM;
- **BLOCKER** canonical runtime identity must have the minimum Play Console API access needed to verify/acknowledge purchases;
- **VERIFY** purchase verification from a real Play Internal Testing install proves Play Console API access rather than assuming GCP IAM is enough.

## Gate 7 — Subscription lifecycle proof

Internal Testing must prove:

- purchase starts from a Play-installed build;
- product/base-plan price and selected tier match Google Play;
- server verification succeeds;
- server acknowledgement succeeds within the Play requirement;
- entitlement appears after verification and survives reinstall/restore;
- voluntary cancellation retains access through the paid term then expires;
- active/grace/canceled state with missing or elapsed verified paid-through time fails closed;
- grace period keeps access while hold/paused/expired states do not;
- RTDN causes authoritative state refresh;
- Personal/Duo/Household upgrades and downgrades use Play replacement and produce the expected linked-token lineage;
- an old superseded token cannot regain canonical authority;
- an unlinked second token cannot silently displace a still-entitled canonical purchase;
- a fresh verified purchase after full expiry can become canonical without requiring stale linkage;
- Duo assign/unassign/reassign cooldown behavior;
- Household join/remove/leave causes coverage reconciliation;
- an account with multiple coverage sources retains the surviving source when one expires;
- Homi account deletion severs all Homi-side historical billing mappings/tokens while leaving Google Play cancellation as a separate user action.

**BLOCKER** until all above have real Internal Testing evidence.

## Gate 8 — Paid enforcement

Paid enforcement is intentionally **OFF** in the current source candidate. This is a release-safety rule, not unfinished UI.

Do not gate continuous location or Shared Household mutation merely because the billing source exists. Activate enforcement only after the complete lifecycle gate above is green. The final enforcement must remain server-authoritative and must never block privacy exits.

## Gate 9 — Authentication/account deletion/legal

Implemented:

- **DONE** email/password + Google sign-in;
- **DONE** verification/reset/provider-aware controls;
- **DONE** recent reauthentication for account deletion;
- **DONE** local erase/sign-out/account deletion are separate;
- **DONE** canonical Household deletion/transfer rules;
- **DONE in 0.13 source / VERIFY UX** the account-deletion card and both destructive confirmations explicitly say deleting Homi does **not** cancel a Google Play Homi+ subscription and direct the user to **Profile settings → Homi+ → Plans & billing → Manage subscription** first when they also want billing canceled;
- **DONE in 0.13 source / VERIFY governed runtime** billing cleanup backstops cover all historical purchaser-linked records rather than only the current active token.

Production blockers:

- **BLOCKER** live Privacy Policy URL;
- **BLOCKER** live Terms URL;
- **BLOCKER** external account-deletion page/process;
- **OPEN** POPIA/privacy wording professional review.

## Gate 10 — Android/store production readiness

Still required before public rollout:

- permanent upload key + secure backup;
- release signing without committed secrets;
- Play App Signing;
- upload + Play App Signing SHA registration where required;
- production Maps/Places restrictions for package/fingerprint;
- target SDK/current Google Play platform requirement audit;
- approved release AAB;
- Play-signed Google Sign-In;
- Play Integrity App Check and staged Firestore App Check enforcement after valid-client metrics;
- Cloud Billing budgets/alerts/spend monitoring;
- Data Safety;
- content rating, app access, target audience and ads declarations as applicable;
- store listing screenshots/icon/feature graphic;
- background-location declaration/disclosure/review video/evidence;
- any mandatory closed-testing requirement shown by this Play developer account;
- final Internal Testing acceptance followed by controlled production rollout.

Permanent package: `za.co.theconceptlab.homi`.

## Immediate sequence

1. Resolve/update the tracked `pubspec.lock` from Bruce's real Flutter 3.41.5 toolchain because the Play Billing dependencies are new; this is the next unresolved source-validation dependency, not a diagnostic rerun.
2. Run exact-head 0.13 Windows/Node/security gates, including **17/17** Functions policy tests, **43** exports and Firestore **26/26**, then perform the S25 Ultra UX regression including notification/sign-out fixes.
3. Create the nine real Homi+ subscription products in Play Console — Personal, Duo, and Household 4–10 — with monthly and annual base plans, then record the exact permanent IDs.
4. Populate the governed client/server catalogs with those IDs; configure Android Publisher API access and RTDN Pub/Sub.
5. Merge/deploy 0.13 billing backend only after provider prerequisites are present.
6. Upload/store-install the Internal Testing AAB and prove purchase, cross-tier replacement and the complete billing lifecycle.
7. Activate paid enforcement only after that proof.
8. Close the remaining signing/App Check/legal/background-location/Data Safety/store-listing gates, then move to production rollout.
