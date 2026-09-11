# Homi — Release readiness

Date: 2026-09-11
Current source candidate: **0.12.0+16**
Development branch: `homi-0.12-shared-data-plane`
Production/backend baseline before this branch: `3b26f3120864146f4ad3d2949e5a1a1416694b5c`

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

Established accepted baselines:

- **DONE (0.10.0)** Windows `flutter analyze` clean and **41/41** Flutter tests passed on the accepted 0.10 app/runtime source.
- **DONE (0.10.0)** governed Firebase deployment passed Node 22, project-number guard, Firestore emulator **13/13**, and deployed 24 Functions/rules.
- **DONE (0.11 operator/device review)** Bruce reported the governed backend deployed and confirmed on the S25 Ultra that the emergency-sheet overflow was resolved, country flags displayed, Shared Household creation worked and a connected person could be invited. True second-device invitation acceptance/realtime propagation remains unproven because no second physical device is currently available.

0.12 changes Flutter app source, Firestore rules and Functions runtime source, so the older Flutter gate cannot be inherited for this candidate.

Required for exact 0.12 candidate:

- **VERIFY** Windows `flutter pub get`.
- **VERIFY** Windows `flutter analyze` clean.
- **VERIFY** full Flutter test suite including `household_data_sync_controller_test.dart`.
- **VERIFY** S25 Ultra launch and focused People/Household regression.
- **OPEN** broader fresh-install/returning-user/background/reboot/Samsung-power tests before store release.

No 0.12 source is production state until this branch passes the exact-SHA gates, is merged deliberately and the affected Firebase surfaces are deployed from the accepted SHA.

## Gate 2 — People/location/safety

Previously implemented and preserved:

- **DONE** map-first People inside the normal Homi shell;
- **DONE** per-person opt-in location sharing;
- **DONE** latest-state cloud location with no default route history;
- **DONE** local arrival detection with initial-state priming, outside->inside transition, exit hysteresis and cooldown;
- **DONE** arrival payload excludes saved Home/Work coordinates/address;
- **DONE** exact Home/Work visibility is a separate grant requiring accepted connection + active location share;
- **DONE** emergency actions hand off to the external phone app;
- **DONE** 90-second client/server location-write floor and five-active-viewer cap.

0.12 source changes:

- **DONE in source / VERIFY on device** People connection/preference streams now bind immediately instead of waiting for location startup and identity provisioning.
- **DONE in source / VERIFY on device** **My code** remains available in the populated Connections state, with explicit loading/retry and a reusable-code sheet.
- **DONE in source / VERIFY on device** Household/Friend connection type is no longer user-selectable; it is displayed from canonical Household membership and the edit sheet explains how to create/invite/join a Household.
- **DONE in source** shared-task assignee discovery now uses canonical Household membership rather than the old editable preference scope.

Still required before production:

- **VERIFY** People/Homi-code/Connect/relationship flows on the S25 Ultra.
- **VERIFY** People list appears without the previous structural 1–2 second dependency on location startup.
- **VERIFY** existing live location, Places, check-ins, hearts and share/revoke behavior remains healthy.
- **VERIFY** true two-account/two-device current-location and Household propagation when hardware/test setup permits.
- **BLOCKER** Google Play background-location declaration/prominent disclosure/review evidence.

## Gate 3 — Emergency-region launch data

- **DONE in source/device review** emergency-region flags and scroll-safe S25 Ultra emergency sheet.
- **DONE in source** leading-zero numbers stored as strings and unsupported regions do not silently fall back to South Africa.
- **VERIFY** representative dialer targets without placing test emergency calls.
- **BLOCKER per public country** verify every enabled emergency-number entry against ITU-T E.129 and/or the relevant national authority before broad country rollout.

## Gate 4 — Canonical Shared Household identity

0.11 established:

- `households/{householdId}`;
- `households/{householdId}/members/{uid}`;
- `householdMemberships/{uid}`;
- `householdInvites/{householdId}_{inviteeUid}`;
- one Household per account;
- four occupied/reserved seats;
- owner/member roles;
- accepted trusted connection required before invite;
- explicit invite acceptance;
- server-owned create/rename/invite/respond/cancel/remove/leave/transfer/delete mutations;
- ownership-change pending-invite rebinding;
- account-deletion Household cleanup/transfer;
- connection, Household membership and location sharing remain independent.

0.12 removes the old authorization ambiguity: a People preference can no longer manufacture Household status. The protected relationship callable derives scope from canonical membership and the client displays the same canonical state.

- **DONE in source** canonical scope derivation.
- **VERIFY** no-Household connection edit shows Household muted/disabled with explanation.
- **VERIFY** connected non-member remains in Friends & trusted people.
- **VERIFY** invited/joined canonical member appears in Household after membership is real.

## Gate 5 — Shared Household data plane

0.12 introduces the first synchronized data plane at:

`households/{householdId}/data/{domain--itemId}`

Current 0.12 domains:

- Routines;
- Supplies;
- Home Things;
- maintenance/repair events;
- utility readings.

Personal **Me** Tasks remain local/private. Shared one-off Tasks keep their existing collection/UI but their server authorization and assignee source now derive from canonical Household membership.

Implemented source contracts:

- **DONE in source** local device persistence remains first; cloud sync is additive.
- **DONE in source** Firestore snapshot application persists locally without echo loops.
- **DONE in source** first owner + first-ever Household + authoritative empty server collection can import existing local Household-domain records once.
- **DONE in source** cached-empty Firestore state is not accepted as proof that the server Household is empty.
- **DONE in source** a member joining an existing/different Household does not silently upload unrelated pre-existing local records.
- **DONE in source** local-only mode suppresses the Household synchronizer even if Firebase still has a cached authenticated user.
- **DONE in source** deterministic record IDs and versioned envelope.
- **DONE in source** parent Household deletion has a bounded cleanup trigger for nested shared data and canonical new shared Tasks.
- **DONE in source** shared Task creation/toggle/removal are bound to canonical Household membership while retaining their deployed callable names.
- **DONE in source** `onHouseholdTaskMembershipChanged` keeps new 0.12 shared Task `memberUids` aligned with current Household membership and strips removed assignee/completion UIDs.
- **DONE in source** pre-0.12 Tasks without `householdId` are not silently widened to a newer Household audience.

Validation required:

- **VERIFY** existing local Routines/Supplies/Home records survive update to 0.12.
- **VERIFY** first-owner migration does not visually clear records while the initial upload is acknowledged.
- **VERIFY** add/update/delete after migration remains visible after app restart.
- **VERIFY** local-only mode does not start Household synchronization.
- **VERIFY** switching/removing Household membership does not erase the device's local copy.
- **VERIFY when second client available** remote changes appear on another Household member's device and same-record conflicts settle to the server-acknowledged version.

The release must not claim a two-device proof until that test is actually possible.

## Gate 6 — Backend/security

Established backend identity:

- Firebase/GCP `homi-ee80a` / project `883068189841`;
- Functions region `africa-south1`;
- Node 22;
- runtime identity `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`.

0.12 backend source:

- **DONE in source** `setTrustedPersonPreference` keeps the public name but derives Household/Friend scope server-side.
- **DONE in source** `createSharedTask`, `toggleSharedTask`, `removeSharedTask` keep public names but use canonical Household membership.
- **DONE in source** `onHomiHouseholdDeletedDataCleanup` adds bounded orphan-data cleanup.
- **DONE in source** `onHouseholdTaskMembershipChanged` reconciles new canonical shared Task membership after Household changes.
- **DONE in source** deployment helper source-completeness list updated.
- **DONE in source** exact Functions export guard changed from 35 to **37**: the two new trigger names are cleanup + Task-membership sync; the preference/task modules override existing callable names.
- **DONE static only** new standalone JavaScript modules pass Node 22 syntax checks. This is not a Functions runtime or emulator pass.

Firestore 0.12 boundary:

- member must have both canonical membership pointer and current parent `memberUids` membership;
- allowed data domains are fixed;
- deterministic `domain--itemId` identity is enforced;
- payload ID, schema version, authenticated actor and server request timestamp are enforced;
- outsiders and stale/forged half-memberships are denied in the new tests.

Governed backend gate still required before deployment:

- **VERIFY** Node 22 dependency install/lint.
- **VERIFY** exactly **37** entrypoint exports.
- **VERIFY** Firestore emulator suite expected **21/21**: original 13 + eight Household tests.
- **VERIFY** Firestore rules/index deploy.
- **VERIFY** all 37 Functions deploy in controlled batches.
- **VERIFY** final exact-SHA/worktree status ends PASS.
- **BLOCKER before public release** Play Integrity App Check and deliberately staged Firestore App Check enforcement after valid-client metrics.
- **BLOCKER before public release** Cloud Billing budgets/alerts/spend controls.

## Gate 7 — Authentication/account lifecycle

- **DONE** email/password + Google sign-in.
- **DONE** verification/reset/provider-aware password/sign-out.
- **DONE** recent reauthentication for account deletion.
- **DONE** local erase/sign-out/account deletion remain distinct product actions.
- **VERIFY** Play-installed Google Sign-In after Play App Signing fingerprints are registered.
- **VERIFY** account deletion for sole Household owner, non-owner member and owner-with-member transfer cases after 0.12 shared data exists.

## Gate 8 — Privacy/legal

- **DONE in source** no emergency-dispatch/crash-detection/proof-of-safety claims.
- **DONE in source** Household membership does not silently enable location or exact-place sharing.
- **DONE in 0.12 source** local-only mode prevents the new Household data sync from activating from a cached Firebase identity.
- **DONE in source draft** privacy/account-deletion documentation now distinguishes synchronized Household records from private/device-only data and records the non-retroactive local-copy limitation.
- **BLOCKER** public Privacy Policy URL.
- **BLOCKER** public Terms URL.
- **BLOCKER** external account-deletion page/process.
- **OPEN** POPIA/privacy wording professional review.

## Gate 9 — Homi+ / payments

Approved commercial contract remains:

- Free R0;
- Personal R19.99/month: 1 sender seat;
- Duo R34.99/month: 2 sender seats under one payer;
- Household R49.99/month or R499.99/year: up to 4 members + shared Household product;
- each paid sender: max 5 active live viewers;
- receiving live location remains free;
- privacy/revoke/delete controls never paywalled.

The definitions are planning/source contracts only. No paid entitlement is active.

- **BLOCKER** Google Play subscription catalog/base plans.
- **BLOCKER** official Flutter Play Billing flow.
- **BLOCKER** server Play Developer API verification.
- **BLOCKER** authoritative entitlement/capability state.
- **BLOCKER** RTDN/Pub/Sub lifecycle handling.
- **BLOCKER** acknowledgement/restore/reinstall/account mapping.
- **BLOCKER** Internal Testing lifecycle proof.

Do not enforce paid live sending or shared-Household entitlement from client purchase state.

## Gate 10 — Production Android identity/signing

- **BLOCKER** permanent upload key + secure backup.
- **BLOCKER** release signing without committed secrets.
- **BLOCKER** Play App Signing.
- **BLOCKER** upload + Play App Signing SHA registration where required.
- **BLOCKER** production Maps/Places key restrictions include release package/fingerprint.
- **BLOCKER** approved AAB + Internal Testing proof.

Permanent package: `za.co.theconceptlab.homi`.

## Immediate sequence

1. Finish repository-wide 0.12 source/document preflight on `homi-0.12-shared-data-plane`.
2. Record the exact final branch SHA and open/refresh the focused PR against `main`.
3. Bruce pulls that exact candidate on Windows and runs one Flutter validation gate: dependency resolution, analyzer and full tests.
4. If green, run the candidate on the S25 Ultra and check People immediate load, permanent My code access, canonical disabled connection type, preserved local data and normal Home/Routines/Supplies behavior.
5. Only after the exact app candidate passes, run the governed Node 22 / 37-export / expected-21-test Firebase gate and deploy the affected backend/rules surfaces from the accepted exact SHA.
6. After 0.12 acceptance, build the centralized capability/entitlement layer, then Google Play Billing + server verification + RTDN/Pub/Sub before any paid enforcement.
