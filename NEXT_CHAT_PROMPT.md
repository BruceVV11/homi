# CURRENT OVERRIDE — 2026-09-26

This section supersedes conflicting older state later in this handoff.

- GitHub `main` contains the Windows/S25-accepted 0.12 app source via merge `82f8f5ba2e4fdb443142d3272c9f47cbb187f616`, but Firebase production is **still the 0.11 backend**. No 0.12 migration, Firestore deployment, or Function deployment has completed.
- Current backend-qualification PR: **#2 — Fix Homi 0.12 Firestore security qualification**, branch `homi-0.12-security-test-deps`. Always re-fetch its exact live head.
- Qualification evidence before the current correction:
  1. Node 22, project number, runtime identity, Functions lint, task policy **5/5**, exact **37** exports and all **23** declared Firestore tests were proven.
  2. First Firestore attempt stopped before mutation on an incompatible security-test dependency pair.
  3. After restoring `@firebase/rules-unit-testing 5.0.2` + Firebase `12.19.0`, the emulator ran all 23 tests and produced **21/23**; both failures were the canonical shared-Task list query.
  4. A rule-only attempt that moved the external lookup to the authenticated membership document still produced the same **21/23** signature. This demonstrated that the root-collection list design itself was not query-provable under the required canonical membership boundary.
- The current durable correction stores canonical Tasks at `households/{householdId}/sharedTasks/{taskId}`. The Household ID is now part of the request path; the client listens to that exact subcollection with `memberUids array-contains uid`. Rules still require both the caller's membership pointer and the parent Household member list.
- Root `sharedTasks/{taskId}` is migration-only and client access fails closed. The migration moves only safely mappable records into the exact Household subcollection and deletes each old root record in the same batch. Unsafe records remain stored but unreadable.
- Migrated `audienceVersion: 0` Tasks may shrink when a member leaves but never widen when somebody joins later. New `audienceVersion: 1` Tasks follow current canonical membership.
- The old root Task notification trigger exports are replaced one-for-one by `onHouseholdSharedTaskCreated` and `onHouseholdSharedTaskUpdated`. The governed export count remains **37**. The release helper deploys/proves the replacements before removing only the two retired root trigger names.
- The security suite remains exactly **23** tests and now covers the nested Household path, recipient query, top-level fail-closed behavior, and both stale membership halves.
- Because the same list-query failure occurred twice, do **not** perform another release/deployment attempt until the exact current PR head passes the complete pre-mutation contract: Functions syntax/lint, task policy **5/5**, exact **37** loaded exports, and Firestore **23/23**.
- Once PR #2 is validated and merged, carry the same nested-task/security-test correction into `homi-0.13-billing-entitlements` before any 0.13 backend qualification.
- 0.13 billing branch currently starts from `d5bf2286d9dbb7a3e55b5f9fb0eb77452acd5566`; it remains **implemented but not released** and must not skip 0.12 backend closure.
- Current commercial contract: Personal R79.99/month or R799.99/year; Duo R129.99/month or R1,299.99/year; Household R199.99/month or R1,999.99/year for four, plus R50/month or R500/year per additional member up to ten; maximum three active live viewers per covered sender; receiving remains free.
- Current workflow names: **mobile-app-development**, **concept-lab-delivery-integrity**, and later **app-store-deployment**. Any older `concept-lab-release-integrity` wording below is obsolete.

# Homi — next chat handoff

Continue development of **Homi** from the focused GitHub branch `homi-0.12-shared-data-plane`. GitHub is the source of truth for tracked source/docs. The focused PR title is **Homi 0.12: shared Household data plane**.

Before changing anything, re-fetch the current branch/PR head and inspect:

- `documentation/releases/0.12.0.md`
- `documentation/releases/0.12.0-shared-task-migration.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/SECURITY.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first and **concept-lab-release-integrity** for every validation/merge/deployment step. Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a new pass compiled/worked on-device until Bruce's real Flutter/Android toolchain proves it.

## Permanent project context

- local root: `C:\ConceptLab\Projects\homi`
- repo: `BruceVV11/homi`
- Android package: `za.co.theconceptlab.homi`
- Firebase/GCP project: `homi-ee80a`
- numeric project number: `883068189841`
- Firestore/Functions region: `africa-south1`
- Functions runtime: Node 22
- runtime identity: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`
- Flutter 3.41.5 / Dart 3.11.3 / JDK 21 / Gradle 8.14
- real device: Samsung S25 Ultra / `SM-S938B`
- `android/` is intentionally local/untracked
- deleted project `homi-508000` must never be used
- safety stash `stash@{0}: On main: Homi pre-0.5.0 local tracked changes` must never be popped/deleted automatically
- brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito and exact assets under `assets/brand/`
- primary nav: **Overview · Tasks · Home · Supplies · People**; People remains map-first
- connection, canonical Household membership, current-location sharing, arrival recipients and exact Home/Work visibility are separate choices
- local-first use remains available; privacy/revoke/stop-sharing/delete controls are never paywalled

## Production baseline before 0.12

Production/backend baseline for this branch is:

`3b26f3120864146f4ad3d2949e5a1a1416694b5c`

Bruce reported that the governed 0.11 backend deployment completed and then reviewed 0.11 on the S25 Ultra. Device review confirmed the emergency-sheet overflow was resolved, country flags displayed, Shared Household creation worked, and an accepted trusted connection could be invited to the Household. There is no second physical device, so true second-device invitation acceptance/realtime propagation remains unproven.

Do not infer a stronger 0.11 deployment/test result than the evidence available in the current chat/repository.

## Current candidate

Version: **`0.12.0+16`**
Branch: **`homi-0.12-shared-data-plane`**
Production state: **NOT deployed**
Validation state: **an earlier exact 0.12 head passed Bruce's Windows Flutter gate, then S25 Ultra feedback caused new source commits; the final live PR head therefore requires a fresh exact-head Windows gate and focused device recheck before merge**

Always re-fetch the live branch/PR head before validation. Do not rely on a SHA copied into this handoff because this file's own commit advances the branch.

## 2026-09-12 S25 Ultra feedback

Bruce reviewed the earlier 0.12 candidate in Android Studio and confirmed the new **My code** and **Connect** controls were present. Two issues were found:

1. Household **Add person**, when no additional accepted trusted connection was eligible, caused a page refresh/layout jump and inserted an easy-to-miss inline peach error card.
2. **My code** remained visible, but the code card showed: `Homi could not verify your signed-in session. Check your connection and try again.`

The second message is the `unauthenticated` friendly message from `HomiCloudActions`; it is **not** evidence that `ensureHomiIdentity` is missing. The 0.11 production backend already contains that callable. It is Auth + App Check protected.

The source now fixes both cases:

- a reusable `showHomiInfoSheet` branded one-action bottom sheet exists in `lib/src/widgets/homi_controls.dart`;
- Household **Add person** uses that sheet for full/no-candidate/connection-load cases instead of injecting an inline notice;
- `TrustedPeopleService.ensureIdentity()` first reads the signed-in user's self-readable `users/{uid}` document and reuses a valid established `homiCode`;
- `ensureHomiIdentity` remains the protected provisioning/repair fallback for a genuinely new or incomplete profile;
- connecting **with** a code still uses the protected server mutation path; the fallback does not weaken code lookup/connection authorization.

Bruce already used a Homi code to establish the existing Casey connection, and the backend provisions `users/{uid}.homiCode` and the lookup index atomically. The final device recheck should therefore show the existing six-character code without needing a fresh protected callable merely for display.

## 0.12 People fixes implemented in source

1. People connections/preferences subscribe immediately instead of waiting behind cached GPS, passive location refresh, continuous-sharing resume and identity provisioning.
2. Homi code display has independent loading/error state so a successful connection refresh cannot silently hide a failed code load.
3. The populated Connections header exposes **My code** and **Connect**.
4. The reusable six-character account code can be copied/shown even when existing connections are present.
5. An established code is read from the self-readable account profile first; protected provisioning is fallback only.
6. Relationship labels remain editable.
7. Household/Friend connection type is read-only and displayed from canonical Household membership.
8. If no Household exists, the edit sheet explains that Shared Household must be created first and the person invited/accepted through **Homi & account -> Shared Household**.
9. `setTrustedPersonPreference` keeps its public callable name but derives scope server-side; a client can no longer manufacture Household status by sending `scope: household`.
10. `HouseholdPeopleService` uses canonical Household membership for shared Task assignee eligibility.

Key source:

- `lib/src/features/people/people_page.dart`
- `lib/src/services/trusted_people_service.dart`
- `lib/src/widgets/homi_controls.dart`
- `lib/src/features/profile/household_settings_page.dart`
- `lib/src/services/household_people_service.dart`
- `functions/trusted_people_preferences.js`

## 0.12 shared Household data plane

Canonical path:

`households/{householdId}/data/{domain--itemId}`

Supported domains:

- `routine`
- `supply`
- `homeThing`
- `homeEvent`
- `utilityReading`

Envelope:

- `domain`
- `itemId`
- `payload`
- `schemaVersion: 1`
- `updatedByUid`
- `updatedAt`

Firestore requires both the caller's `householdMemberships/{uid}` pointer and the parent Household `memberUids` to agree. Writes also require an allowed domain, deterministic document ID, matching payload ID, schema version, authenticated actor and server request timestamp.

The device controller remains local-first. User actions persist to SharedPreferences first, then an eligible Household mutation is mirrored to Firestore. Applying a Firestore snapshot persists the synchronized state locally without echoing the same record back to cloud.

Key source:

- `lib/src/domain/household_data_mutation.dart`
- `lib/src/state/homi_app_controller.dart`
- `lib/src/services/household_data_sync_service.dart`
- `lib/src/shell/homi_shell.dart`
- `firebase/firestore.rules`

### First-sync rule

Do not silently upload arbitrary pre-existing records when an account joins a Household.

Automatic import is restricted to the safe migration case where:

- this device has never synchronized another Household;
- the current user is the owner; and
- an **authoritative non-cache** Firestore snapshot proves the Household data collection is empty.

Otherwise unmatched local records remain device-private legacy data. New records created after Household classification may synchronize normally. A future explicit import/merge UI can promote private legacy records.

Explicit local-only mode suppresses the Household synchronizer even if Firebase still has a cached signed-in user.

## Shared one-off Tasks

Personal **Me** Tasks remain local/private.

New 0.12 shared Tasks use the existing public callable names but derive authorization from canonical Household identity:

- `createSharedTask`
- `toggleSharedTask`
- `removeSharedTask`

New tasks carry canonical `householdId`, `audienceVersion: 1` and current canonical `memberUids`.

The client shared-task query requires both:

- `householdId == current Household`; and
- `memberUids array-contains current UID`.

`firebase/firestore.indexes.json` contains the composite index for this query. Firestore rules additionally require current canonical Household membership.

Pre-0.12 Tasks are handled by `functions/migrate_legacy_shared_tasks.js` during governed deployment. The helper defaults to dry-run. A safe legacy Task is attached only to the creator's current canonical Household and keeps only the intersection of its historical recipients and current Household members. It receives `audienceVersion: 0`, so it is never silently widened to newer Household members. Unsafe/unmappable legacy Tasks fail closed rather than being deleted.

`onHouseholdTaskMembershipChanged` keeps audience-version-1 Tasks aligned with current canonical membership. The deployment helper first dry-runs legacy migration, deploys canonical Task writers so no new preference-era Task can appear, applies the safe migration, asserts stability, and only then deploys the stricter Firestore rules/indexes.

Key source:

- `lib/src/services/shared_task_service.dart`
- `functions/shared_tasks_canonical.js`
- `functions/household_task_membership_sync.js`
- `functions/migrate_legacy_shared_tasks.js`
- `security-tests/shared_task_household.boundary.test.js`

## Household deletion cleanup

Firestore parent deletion does not recursively remove subcollections. `onHomiHouseholdDeletedDataCleanup` removes nested Household data in bounded batches after a canonical Household is deleted and removes new canonical shared Tasks carrying that Household ID.

Key source:

- `functions/household_data_cleanup.js`

## Backend release contract

The 0.12 Functions entrypoint is governed at exactly **37 unique exports**:

- the preference/task modules override existing callable names;
- `onHomiHouseholdDeletedDataCleanup` is a new export;
- `onHouseholdTaskMembershipChanged` is a new export.

`scripts/deploy-notification-backend.sh` requires:

- Node 22;
- project `homi-ee80a`;
- project number `883068189841`;
- complete 0.12 Functions source;
- dependency install + lint;
- exactly 37 exports;
- Firestore emulator security gate;
- legacy shared-Task migration preflight/apply/stability check;
- safe legacy `onConnectionDeleted` migration if still present;
- Firestore rules/indexes;
- Functions in batches of five.

Do not deploy if any preflight/gate fails.

## Tests in source

Flutter/controller coverage added:

- `test/household_data_sync_controller_test.dart`

Firestore suites:

- `security-tests/server.boundary.test.js` — established 13 tests;
- `security-tests/household.boundary.test.js` — 8 canonical Household identity/data-plane tests;
- `security-tests/shared_task_household.boundary.test.js` — 2 canonical shared-Task query/fail-closed tests.

Final 0.12 Firestore gate is expected to prove **23 tests**.

Standalone new JavaScript modules have received source-level Node 22 syntax checks during development where recorded, but that is not the dependency-loaded Functions/export/emulator gate.

## Exact next sequence

1. Re-fetch focused PR metadata and the exact live head after all 2026-09-12 device-feedback/documentation commits.
2. Inspect the final branch diff and all changed source/contracts; do not ask Bruce to validate while a known stale dependency remains.
3. Bruce fast-forwards local `homi-0.12-shared-data-plane` to the exact live head and runs one final Windows gate with Flutter 3.41.5:
   - `flutter pub get`
   - `flutter analyze`
   - full `flutter test`
   - final exact SHA/worktree check
4. If green, Bruce runs the same exact source on the S25 Ultra and verifies:
   - People list still appears without the previous structural delay;
   - **My code** displays the established reusable code instead of the previous protected-session error;
   - code sheet/copy and **Connect** work;
   - Household **Add person** with no eligible person opens the custom informational bottom sheet without an inline page jump;
   - connection edit keeps Household/Friend type muted/read-only with correct explanation;
   - actual canonical member appears in Household grouping;
   - existing Routines/Supplies/Home records remain intact;
   - normal add/update/delete/restart, location/safety and navigation behavior remain healthy.
5. Do not claim second-device sync acceptance because Bruce does not currently have another device.
6. Re-fetch the PR. Merge only the exact Windows/device-accepted head with expected-head protection.
7. Run the governed refresh-safe Cloud Shell backend worker against the exact merge SHA. Required proof includes Node 22, project-number guard, exactly 37 exports, safe legacy shared-Task migration and Firestore **23/23** before deployment can continue.
8. If backend deployment passes, record the exact deployed SHA and update release docs from pending to deployed/accepted based only on real evidence.
9. After 0.12 is accepted, proceed to centralized capability/entitlement state, then Google Play Billing + server verification + RTDN/Pub/Sub before any paid enforcement.

## Commercial contract to preserve

- Free: R0
- Personal: R19.99/month — 1 sender seat
- Duo: R34.99/month — 2 sender seats under one payer
- Household: R49.99/month or R499.99/year — up to 4 canonical Household members + shared Household product
- each paid sender: max 5 active live viewers
- receiving live location remains free
- privacy/revoke/delete controls never paywalled

No Homi+ entitlement is active yet. Client purchase state must never become authoritative by itself.
