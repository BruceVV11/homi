# Homi — Release readiness

Date: 2026-09-12
Current development candidate: **0.13.0+17**
Development branch: `homi-0.13-billing-entitlements`
Stacked base: exact 0.12 candidate `233c6ab16caa3a9c5951251d7805f57a68ca440c`
Current production/backend baseline: 0.11 on `3b26f3120864146f4ad3d2949e5a1a1416694b5c`

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Release order

0.13 is intentionally stacked on the final 0.12 source so billing work can continue without creating a cosmetic micro-release. That does **not** make the 0.12 Firebase backend deployed.

The governed order remains:

1. validate/merge/deploy the final 0.12 shared-Household data plane;
2. accept the affected 0.12 runtime behavior;
3. finish 0.13 Google Play provider setup and exact-head validation;
4. deploy/validate the 0.13 billing backend;
5. prove the complete billing lifecycle from a Play Internal Testing install;
6. activate paid enforcement only in a final accepted launch candidate;
7. close store/signing/legal/background-location/App Check gates before production.

## Gate 1 — Source and device stability

Established evidence:

- **DONE (0.10)** Windows analyzer/tests and governed backend deployment.
- **DONE (0.11)** governed backend deployed; S25 Ultra confirmed emergency-sheet/flag fixes and canonical Household creation/invite flow. True second-physical-device acceptance remains unproven because a second device is unavailable.
- **DONE as historical 0.12 evidence** an earlier 0.12 exact head passed the Windows Flutter gate; later device feedback drove further source changes.
- **DONE on S25 Ultra for the latest reviewed 0.12 UX before 0.13 stacking** reusable **My code** loads, the persistent orange code card was removed by request, and the Household candidate picker was reviewed.
- **DONE in 0.13 source / VERIFY** the Household Firestore streams are now stable across `_busy` rebuilds so cancel/rename/invite/remove/transfer/delete do not recreate the stream and flash back to loading.
- **DONE in 0.13 source / VERIFY** Add-to-Household now ends with a compact privacy/context panel so a one-person candidate sheet does not feel visually sunken.

Still required:

- **VERIFY** exact final 0.12 Windows gate before merging/deploying 0.12 if that pass has not already been captured against its final exact head.
- **VERIFY** exact final 0.13 Windows `flutter pub get`, analyzer and full Flutter tests after Play Billing dependencies are locked.
- **VERIFY** S25 Ultra 0.13 regression: invitation cancel has no page refresh/loading flash, short Add-to-Household sheet is balanced, Homi+ page opens safely, existing People/Home/Tasks/Supplies data remains intact.
- **OPEN** fresh-install/returning-user/background/reboot/Samsung power-management pass before production.

## Gate 2 — People, location and safety

Implemented and preserved:

- **DONE** map-first People, opt-in per-person location sharing and latest-state location model;
- **DONE** accepted connections load independently of GPS startup;
- **DONE** reusable **My code** is available on demand without a permanent code card;
- **DONE** Household/Friend scope is canonical/read-only rather than a user-created authorization toggle;
- **DONE** Household membership does not enable location sharing;
- **DONE** arrival check-ins are locally detected and contain no saved precise Home/Work address/coordinate in the arrival delivery payload;
- **DONE** exact saved Home/Work sharing is separately controlled;
- **DONE** emergency actions hand off to the system dialer;
- **DONE** existing 90-second cloud-write floor and five-active-viewer limit.

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

Personal **Me** Tasks remain local/private. Shared one-off Tasks retain their compatibility collection but now use canonical Household authorization.

0.12 safety contracts:

- **DONE in source** local writes remain first and cloud sync is additive;
- **DONE in source** authoritative non-cache empty state required before the narrow first-owner migration;
- **DONE in source** old unmatched records stay private when joining an existing/different Household;
- **DONE in source** local-only mode suppresses Household synchronization;
- **DONE in source** account/Household deletion cleanup and canonical shared-task membership handling;
- **DONE in source** safe legacy shared-task migration that never widens old audiences.

Required before calling 0.12 deployed/accepted:

- **VERIFY** exact governed Node 22 backend gate;
- **VERIFY** exact **37** Function exports;
- **VERIFY** existing Functions task policy **5/5**;
- **VERIFY** Firestore **23/23**;
- **VERIFY** legacy shared-task migration dry-run/apply/assert-stable;
- **VERIFY** Firestore rules/indexes and all 37 Functions deployed from the accepted merge SHA;
- **VERIFY** existing local Routines/Supplies/Home records survive and shared add/update/delete survives restart;
- **VERIFY when a second client is available** true remote propagation/conflict behavior.

## Gate 4 — Homi+ commercial contract

Approved contract:

- Free — R0;
- Personal — R19.99/month, one sender seat;
- Duo — R34.99/month, purchaser + one assigned accepted trusted Homi connection;
- Household — R49.99/month or R499.99/year, up to four canonical Household members;
- every paid sender: maximum five active trusted live viewers;
- receiving live location remains free;
- privacy/revoke/leave/erase/delete controls never paywalled;
- Duo seat reassignment cooldown: seven days;
- no annual Personal/Duo price is approved.

## Gate 5 — 0.13 billing client and entitlement architecture

**DONE in source / VERIFY compile/runtime:**

- official Flutter `in_app_purchase` purchase stream/query/restore integration;
- Android billing plugin pinned to the current Homi Dart-compatible Billing Library 8 line;
- one source-controlled Play catalog boundary, deliberately unconfigured until real Play IDs exist;
- opaque SHA-256-derived Homi account association instead of raw UID as Play obfuscated account ID;
- dedicated **Homi+ → Plans & billing** surface in Profile Settings;
- Play-localized price display once products exist;
- explicit purchase confirmation and Play subscription-management handoff;
- Google Play cross-product subscription replacement for Homi+ tier changes;
- server-written entitlement reader that fails closed to Free and treats a stale canceled entitlement as expired after its known paid term;
- Duo seat management UI/service;
- client never grants itself entitlement from local purchase state.

The permanent Play catalog to create/verify is three subscription products:

- `homi_plus_personal` → base plan `monthly`;
- `homi_plus_duo` → base plan `monthly`;
- `homi_plus_household` → base plans `monthly` and `annual`.

Personal, Duo and Household are different subscription benefits; their base plans are billing options rather than unrelated entitlement tiers. Cross-tier changes use Play subscription replacement, not an intentional second concurrent Homi+ purchase.

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
- accepted trusted connection derives the Duo second seat;
- Duo cooldown cannot be reset by unassign/disconnect;
- paid-term expiry normalization prevents known canceled/stale paid state from remaining entitled after its verified term;
- Play `linkedPurchaseToken` lineage is required before a new token can replace another still-entitled canonical purchase;
- an already-superseded token cannot retake canonical authority;
- Homi account deletion removes Homi billing mappings/coverage without pretending to cancel Google Play billing.

0.13 backend expected gates:

- **VERIFY** Node 22 dependency install/lint;
- **VERIFY** pure Functions policy suite **16/16**: 5 shared-task + 11 billing;
- **VERIFY** exact **43** Function exports;
- **VERIFY** Firestore emulator **25/25**: existing 23 + 2 billing boundary tests;
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
- grace period keeps access while hold/paused/expired states do not;
- RTDN causes authoritative state refresh;
- Personal/Duo/Household upgrades and downgrades use Play replacement and produce the expected linked-token lineage;
- an old superseded token cannot regain canonical authority;
- an unlinked second token cannot silently displace a still-entitled canonical purchase;
- a fresh verified purchase after full expiry can become canonical without requiring stale linkage;
- Duo assign/unassign/reassign cooldown behavior;
- Household join/remove/leave causes coverage reconciliation;
- an account with multiple coverage sources retains the surviving source when one expires;
- Homi account deletion does not misrepresent Google Play subscription cancellation.

**BLOCKER** until all above have real Internal Testing evidence.

## Gate 8 — Paid enforcement

Paid enforcement is intentionally **OFF** in the current source candidate. This is a release-safety rule, not unfinished UI.

Do not gate continuous location or Shared Household mutation merely because the billing source exists. Activate enforcement only after the complete lifecycle gate above is green. The final enforcement must remain server-authoritative and must never block privacy exits.

## Gate 9 — Authentication/account deletion/legal

Implemented:

- email/password + Google sign-in;
- verification/reset/provider-aware controls;
- recent reauthentication for account deletion;
- local erase/sign-out/account deletion are separate;
- canonical Household deletion/transfer rules;
- 0.13 billing cleanup backstops are present in source.

Production blockers:

- **BLOCKER** live Privacy Policy URL;
- **BLOCKER** live Terms URL;
- **BLOCKER** external account-deletion page/process;
- **BLOCKER** account-deletion UI must clearly state that deleting Homi does not cancel a Google Play subscription and give a Play management path;
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

1. Finish 0.13 repository/document/security preflight without asking Bruce to use a rerun as diagnosis.
2. Resolve/update the tracked `pubspec.lock` from Bruce's real Flutter 3.41.5 toolchain because the Play Billing dependencies are new.
3. Close the final exact 0.12 validation/merge/governed Firebase deployment before any billing deployment mutates production.
4. Create the three real Homi+ subscription products/base plans in Play Console and record the exact permanent IDs.
5. Populate the governed client/server catalogs with those IDs; configure Android Publisher API access and RTDN Pub/Sub.
6. Run exact-head 0.13 Windows/Node/security gates, then S25 Ultra regression.
7. Merge/deploy 0.13 billing backend only after provider prerequisites are present.
8. Upload/store-install the Internal Testing AAB and prove purchase, cross-tier replacement and the complete billing lifecycle.
9. Activate paid enforcement only after that proof.
10. Close the remaining signing/App Check/legal/background-location/Data Safety/store-listing gates, then move to production rollout.
