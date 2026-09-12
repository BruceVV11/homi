# Homi — Release readiness

Date: 2026-09-12
Current source candidate: **0.12.0+16**
Development branch: `homi-0.12-shared-data-plane`
Production/backend baseline before this branch: `3b26f3120864146f4ad3d2949e5a1a1416694b5c`

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## Gate 1 — Source and device stability

Established accepted baselines:

- **DONE (0.10.0)** Windows `flutter analyze` clean and **41/41** Flutter tests passed on the accepted 0.10 app/runtime source.
- **DONE (0.10.0)** governed Firebase deployment passed Node 22, project-number guard, Firestore emulator **13/13**, and deployed 24 Functions/rules.
- **DONE (0.11 operator/device review)** Bruce reported the governed backend deployed and confirmed on the S25 Ultra that the emergency-sheet overflow was resolved, country flags displayed, Shared Household creation worked and a connected person could be invited. True second-device invitation acceptance/realtime propagation remains unproven because no second physical device is currently available.
- **DONE as historical 0.12 evidence only** Bruce's Windows Flutter gate passed the exact earlier 0.12 head `6ac25b464fe5ee25d940416783148b88bb6cdc78`. The subsequent S25 Ultra review found the Add-person empty-state UX and established Homi-code loading issue. Source has changed to address those findings, so the old pass cannot validate the final head.

Required for the final exact 0.12 candidate:

- **VERIFY** Windows `flutter pub get` on the final PR head.
- **VERIFY** Windows `flutter analyze` clean on the final PR head.
- **VERIFY** full Flutter test suite including `household_data_sync_controller_test.dart` on the final PR head.
- **VERIFY** S25 Ultra focused People/Household regression after the device-feedback fixes.
- **OPEN** broader fresh-install/returning-user/background/reboot/Samsung-power tests before store release.

No 0.12 source is production state until the final branch passes the exact-SHA gates, is merged deliberately and the affected Firebase surfaces are deployed from the accepted merge SHA.

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

- **DONE in source / partially observed on device / VERIFY final head** People connection/preference streams bind immediately instead of waiting for location startup and identity provisioning.
- **DONE in source / VERIFY final head** **My code** remains available in the populated Connections state. An already-provisioned account now reads its valid code from the signed-in user's self-readable `users/{uid}` profile before falling back to the protected `ensureHomiIdentity` callable. A fresh Auth/App Check callable is therefore not required merely to display an established code.
- **DONE in source / observed UI / VERIFY final head** Household/Friend connection type is no longer user-selectable; it is displayed from canonical Household membership and the edit sheet explains how to create/invite/join a Household.
- **DONE in source** shared-task assignee discovery uses canonical Household membership rather than the old editable preference scope.

Still required before production:

- **VERIFY** established Homi code renders on Bruce's S25 Ultra without the previous protected-session error.
- **VERIFY** **My code** sheet/copy and **Connect** remain healthy.
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

The S25 Ultra review also exposed an interaction-quality issue when the owner tapped **Add person** but no additional accepted trusted connection was eligible. The old implementation injected a low-visibility inline notice after the tap. The final source now uses the branded informational bottom-sheet pattern and distinguishes a full Household, existing member/pending invite, and the need to connect another person first.

- **DONE in source** canonical scope derivation.
- **DONE in source / VERIFY final head** graceful Add-person informational sheet when no candidate exists or connections cannot be loaded.
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

Personal **Me** Tasks remain local/private. Shared one-off Tasks keep their existing collection/UI but their server authorization and assignee source derive from canonical Household membership.

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
- **DONE in source** canonical shared Tasks remain usable by their safe current Household audience if the original creator leaves; the current Household owner has explicit recovery actions.
- **DONE in source** `onHouseholdTaskMembershipChanged` updates only audience-version-1 Tasks, strips removed assignee/completion UIDs, and never widens migrated audience-version-0 Tasks.
- **DONE in source** pre-0.12 Tasks are migrated only when safely mappable and are not silently widened to a newer Household audience.

Validation required:

- **VERIFY** existing local Routines/Supplies/Home records survive update to the final 0.12 candidate.
- **VERIFY after backend deploy** first-owner migration does not visually clear records while initial upload is acknowledged.
- **VERIFY after backend deploy** add/update/delete survives app restart with the 0.12 rules/data plane active.
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
- **DONE in source** `createSharedTask`, `toggleSharedTask`, `removeSharedTask` keep public names but use canonical Household membership and durable Household ownership semantics.
- **DONE in source** `onHomiHouseholdDeletedDataCleanup` adds bounded orphan-data cleanup.
- **DONE in source** `onHouseholdTaskMembershipChanged` reconciles only new canonical shared Task audiences after Household changes; migrated historical audiences remain privacy-stable.
- **DONE in source** deployment helper source-completeness list updated.
- **DONE in source** exact Functions export guard is **37**: two new trigger names (cleanup + Task-membership sync); preference/task modules override existing callable names.
- **DONE source preflight only** `household_task_policy.test.js` defines five pure policy tests for historical-audience non-widening, canonical membership reconciliation, attribution cleanup and Household-owner recovery. The policy suite passed 5/5 under Node 22 during source preflight, but this does not replace the governed Cloud Shell run.

Firestore 0.12 boundary:

- member must have both canonical membership pointer and current parent `memberUids` membership;
- allowed data domains are fixed;
- deterministic `domain--itemId` identity is enforced;
- payload ID, schema version, authenticated actor and server request timestamp are enforced;
- canonical shared-Task reads require both `householdId == current Household` and exact `memberUids array-contains current UID` query constraints;
- legacy shared Tasks without a safely migrated canonical Household fail closed;
- outsiders and stale/forged half-memberships are denied in the source-controlled tests.

Governed backend gate still required before deployment:

- **VERIFY** Node 22 dependency install/lint.
- **VERIFY** Functions policy suite **5/5** under the dependency-loaded governed worker.
- **VERIFY** exactly **37** entrypoint exports.
- **VERIFY** Firestore emulator suite **23/23**: 13 established + 8 Household + 2 canonical shared-Task tests. The helper refuses to run a stale/omitted suite if those three files do not declare exactly 23 tests.
- **VERIFY** legacy shared-Task migration dry-run/apply/stability sequence.
- **VERIFY** known legacy `onConnectionDeleted` drift is reconciled before any new 0.12 Function deployment if that old resource still exists.
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
- **DONE in source draft** privacy/account-deletion documentation distinguishes synchronized Household records from private/device-only data and records the non-retroactive local-copy limitation.
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

1. Re-fetch the final focused PR head after all 2026-09-12 device-feedback/backend-contract patches and finish repository-wide source/document preflight.
2. Bruce fast-forwards the local `homi-0.12-shared-data-plane` branch to that exact head and runs one final Windows gate: dependency resolution, analyzer, full Flutter tests, final SHA/worktree check.
3. If green, run that same exact source on the S25 Ultra and verify:
   - **Add person** with no eligible extra connection opens the custom informational bottom sheet without page-jump/inline-error behaviour;
   - the already-established reusable Homi code loads from the account profile and **My code** opens/copies it;
   - People immediate load, canonical disabled connection type, preserved local data and normal Home/Routines/Supplies behavior remain healthy.
4. Re-fetch the PR and merge only the exact Windows/device-accepted head using expected-head protection.
5. Run the governed refresh-safe Cloud Shell backend worker against the exact merge SHA. Required evidence includes Node 22, Functions policy **5/5**, project-number guard, exactly 37 exports, Firestore **23/23**, legacy Function drift reconciliation and safe legacy Task migration before the stricter rules/remaining Functions deployment proceeds.
6. After backend deployment passes, re-test the affected Household data-plane flows and record the exact deployed SHA in release docs.
7. After 0.12 acceptance, build the centralized capability/entitlement layer, then Google Play Billing + server verification + RTDN/Pub/Sub before any paid enforcement.
