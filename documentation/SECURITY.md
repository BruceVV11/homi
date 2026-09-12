# Homi security architecture

Date: 2026-09-12
Current source candidate: `0.12.0+16`
Development branch: `homi-0.12-shared-data-plane`

Homi handles trusted relationships, device push tokens, shared Household records and precise location. A modified client is treated as hostile. UI checks are convenience only; authorization belongs in Firebase Authentication, App Check, Cloud Functions, Firestore rules and IAM.

## Security goals

- no private Household/location read without the required server-owned authorization state;
- clients cannot forge identity, canonical Household membership, ownership, completion attribution or developer role;
- a People relationship label cannot grant Household data access;
- connection, Household membership, location sharing and exact Home/Work visibility remain separate permissions;
- removal/reclassification/revocation removes the corresponding derived access;
- arrival delivery cannot become an arbitrary-recipient notification primitive;
- arrival notifications contain no saved Home/Work address/coordinate;
- check-in-only samples do not silently update cloud latest location;
- high-frequency writes and fan-out remain bounded where applicable;
- local-only mode does not activate Household data synchronization merely because Firebase still has a cached authenticated user;
- privacy exits remain available regardless of plan/payment state;
- destructive account operations require recent authentication and remove/account for Homi-managed cloud data according to Household ownership rules.

## Protected callable mutation boundary

Sensitive collaboration writes continue to use App-Check-protected callable Functions for:

- identity/code issuance or repair;
- connection lifecycle;
- relationship-label updates;
- canonical Household membership/ownership/invitations;
- per-viewer location authorization;
- shared one-off Tasks;
- People hearts;
- arrival delivery;
- exact saved-place sharing;
- developer campaigns;
- device registration; and
- account deletion.

Reading an already-issued Homi code is not a sensitive mutation. `users/{uid}` is self-readable under Firestore rules, and the server writes the user's valid `homiCode` plus its lookup index atomically when provisioning identity. 0.12 therefore reads that established self profile first for display and only falls back to the protected `ensureHomiIdentity` callable when the profile is new/incomplete or needs repair. This prevents a transient Auth/App Check callable-proof problem from unnecessarily hiding a code the account already owns without weakening code issuance or connection lookup security.

0.12 keeps the historic callable name `setTrustedPersonPreference`, but the server no longer trusts caller-supplied Household/Friend scope. The callable derives `household` only when both accounts currently share the same canonical Household; otherwise it stores `friend`.

The historic shared-task callable names also remain stable. `createSharedTask`, `toggleSharedTask` and `removeSharedTask` are overridden by a canonical implementation that derives authorization from current Household membership rather than a user-editable People preference.

## Canonical Household authorization

The server-owned identity relationship is:

- `households/{householdId}` with `memberUids` and `ownerUid`;
- `households/{householdId}/members/{uid}`;
- `householdMemberships/{uid}`;
- `householdInvites/{householdId}_{inviteeUid}`.

A shared-data caller must satisfy **both** halves of membership:

1. `householdMemberships/{auth.uid}.householdId == householdId`; and
2. the parent Household's server-owned `memberUids` still contains `auth.uid`.

A forged/stale membership pointer alone is insufficient, and a stale parent member list alone is insufficient after the membership pointer is removed.

Household identity/membership/invite mutations remain server-only callables. Clients cannot directly promote themselves to owner/member or manufacture an invitation.

## 0.12 Household data plane

Shared Household domain records are nested under the exact canonical Household:

`households/{householdId}/data/{domain--itemId}`

Allowed domains are deliberately fixed to:

- `routine`;
- `supply`;
- `homeThing`;
- `homeEvent`;
- `utilityReading`.

Create/update requires a fixed outer envelope with only the reviewed fields:

- `domain`;
- `itemId`;
- `payload`;
- `schemaVersion`;
- `updatedByUid`;
- `updatedAt`.

Rules require:

- `recordId == domain + '--' + itemId`;
- non-empty bounded `itemId`;
- map payload whose `id` matches the outer item ID;
- `schemaVersion == 1`;
- `updatedByUid == request.auth.uid`; and
- `updatedAt == request.time`.

The domain payload remains versioned app data. A malformed record is ignored by the client rather than blocking the rest of the Household snapshot. Firestore's document-size limit still provides the outer storage bound.

Unlike high-risk identity/permission mutations, this data plane uses authenticated Firestore writes so the existing local-first app can retain Firestore's offline queue. The authorization boundary is therefore the canonical Household rules, not a client boolean. Production Firestore App Check enforcement remains a staged release requirement after valid-client traffic is proven.

## Local-first migration/privacy boundary

The local controller writes SharedPreferences first. Household synchronization is additive.

0.12 never treats an empty Firestore cache as proof that a server Household has no data. Initial migration waits for an authoritative non-cache snapshot.

Automatic legacy import is limited to the narrow safe case where:

- this device has never synchronized another canonical Household;
- the signed-in user is the owner; and
- the authoritative Household data collection is empty.

Otherwise pre-existing local records that are not already known shared records remain device-private legacy records and are not silently uploaded. New records created after Household classification may synchronize normally.

If Homi is in explicit local-only mode, the Household synchronizer does not start even when a Firebase account happens to remain cached on the device.

## Shared one-off Tasks

Personal **Me** Tasks remain local/private.

For a new 0.12 shared Task, the server derives `householdId` and `memberUids` from the creator's current canonical Household. A caller cannot manufacture task visibility by setting a People scope. An assignee must be a current member of the same Household.

The new callable implementation also verifies canonical Household access before toggle/remove operations. Existing completion/reopen/removal restrictions remain.

`onHouseholdTaskMembershipChanged` keeps new Tasks carrying the canonical `householdId` aligned when the Household member list changes. Removed assignee UIDs are cleared, and removed completion UIDs are stripped. This prevents the authorization list on a new shared Task from becoming stale merely because membership changed after task creation.

Pre-0.12 Tasks are governed by the deployment migration. A safely mappable legacy Task receives the creator's current canonical Household and only the intersection of its historical recipients and current members. It is marked `audienceVersion: 0`, so the canonical audience synchronizer does not widen it to newer members. Unmappable Tasks remain stored but fail closed under the 0.12 read rule.

`sharedTasks` remains a separate compatibility collection in 0.12 rather than being destructively migrated into the generic data plane during the same release.

## Household deletion/orphan cleanup

Firestore parent deletion does not recursively delete subcollections. 0.12 adds `onHomiHouseholdDeletedDataCleanup` on `households/{householdId}` deletion.

The trigger deletes nested `data` documents in bounded batches and removes new shared Tasks that carry the deleted `householdId`. This prevents an intentionally deleted Household from leaving unreachable synchronized data indefinitely.

The Functions export surface is exactly **37** in the 0.12 deployment contract: one new Household-data cleanup trigger plus one new Task-membership synchronizer. The preference/task implementation modules override existing callable names rather than adding further public names.

## Continuous-location abuse/cost controls

The established controls remain:

1. Firestore rejects an update to `locations/{uid}` if the previous server timestamp is less than 90 seconds old.
2. The protected `setLocationShare` callable allows at most five active outbound viewers for one sender.

The client independently uses the same 90-second cloud gap and Android requests roughly two-minute / 100 m movement updates.

The five-viewer limit applies to active outgoing live authorization, not total trusted connections or Household seats.

`setLocationShare(active:false)` is deliberately not blocked by activation limits. A user must always be able to stop sharing.

## Location reads

A user writes only their own `locations/{uid}`. Rules validate exact schema, coordinate/accuracy/battery bounds, allowed source and server timestamp.

A viewer reads another user's latest location only with both an accepted connection and active owner-to-viewer share.

Optional precise `sharedPlaces` reads require explicit viewer selection, accepted connection and active owner-to-viewer current-location share. Clients cannot mutate `sharedPlaces` directly.

Canonical Household membership does **not** satisfy or replace these location permissions.

## Arrival check-ins

`sendArrivalCheckIn` remains Auth/App-Check protected and validates recipients/server limits. It receives no saved Home/Work coordinate/address. Recipients are revalidated as accepted trusted connections and notification preferences are respected.

## Authentication recovery

`PeopleHubPage` recreates auth-scoped People state when Firebase identity changes/restores. `HomiCloudActions` retries one `unauthenticated` protected call after forced Firebase Auth + App Check refresh, then surfaces product language rather than raw codes.

0.12 separates Homi-code display from mandatory callable provisioning. The client first attempts the signed-in user's permitted `users/{uid}` profile read and reuses a valid established code. Only a missing/invalid profile code needs the protected provisioning fallback. Connection streams remain independent, so identity-code errors cannot hide trusted People.

This is a usability/recovery path, not a trust-boundary change: another account still cannot read `users/{uid}`, clients still cannot write profile/code records directly, and connecting with a code still uses the protected server lookup/mutation path.

## Emergency-region safety

Emergency numbers are source-controlled local data, not writable server authorization state. Homi fails closed for unsupported regions rather than inventing a fallback number.

Release governance requires every country offered publicly to be verified against ITU-T E.129 and/or an official national emergency source. Leading-zero numbers are strings.

Emergency taps only hand off to the system phone app with `tel:`. They do not silently place calls or transmit location.

## IAM and backend runtime

Functions run as `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`. The runtime identity must not receive Owner/Editor. Global bounded defaults remain max 5 instances, min 0, 256 MiB unless a smaller Function-specific cap is defined.

Permanent backend identity remains:

- project `homi-ee80a`;
- project number `883068189841`;
- region `africa-south1`;
- Node 22.

## Automated gates

`scripts/test-firestore-security.sh` runs the Firestore emulator security suite serially.

For the final 0.12 candidate the expected suite is **23 tests**:

- 13 established server-boundary tests;
- 8 canonical Household identity/data-plane tests;
- 2 canonical shared-Task query/fail-closed tests.

The governed Functions helper requires Node 22, the immutable project number, exact source files, dependency lint and exactly **37** exports before it reaches deployment. The legacy shared-Task migration is dry-run/apply/stability governed, and Firestore security tests must pass before the stricter rules/indexes and remaining Functions deployment continue.

Standalone new JavaScript modules have received source-level Node 22 syntax checks where recorded. This is not a substitute for the governed dependency/export/emulator gate.

Do not weaken collection-wide rules to make a client test pass. Fix the intended contract, inspect dependent query behavior, rerun the exact security gate, then deploy.

## Homi+ entitlement security target

`lib/src/domain/homi_plus_plan.dart` records commercial plan definitions only. It is not trusted authorization state.

Paid enforcement must not activate until Google Play purchases are performed through Play Billing, verified server-side using the Google Play Developer API, represented by authoritative server entitlement state, maintained through RTDN/Pub/Sub, and tested through Play Internal Testing lifecycle states.

A local purchase callback, cached boolean or editable client record must never grant Homi+ by itself.

Privacy, current-location revoke, exact-place revoke, local erase and account deletion must never be trapped behind entitlement state.

## Production gates still required

- final exact 0.12 Windows analyzer/full Flutter test pass after the 2026-09-12 device-feedback source changes;
- S25 Ultra acceptance of the affected People/Household/data flows, including established Homi-code display and graceful Add-person empty state;
- governed Node 22 / **37-export** / **23-test** backend pass before 0.12 deployment;
- permanent release signing / Play App Signing fingerprints;
- Play-installed Google Sign-In;
- production Maps/Places key restrictions;
- Play Integrity App Check and later Firestore App Check enforcement after valid traffic metrics;
- billing alerts/spend/monitoring;
- public Privacy Policy/Terms/account-deletion URL;
- Google Play Data Safety and background-location declarations;
- authoritative Play Billing verification before Homi+ gating.
