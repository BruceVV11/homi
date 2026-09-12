# Homi Architecture

Date: 2026-09-12
Current source candidate: **0.12.0+16**

## Permanent identifiers

- Google Cloud / Firebase project: `homi-ee80a`
- Project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Firestore / Functions region: `africa-south1`
- Functions runtime: Node 22
- Runtime service account: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

The deleted project `homi-508000` is not part of Homi and must never be reused.

## Stack

- Flutter / Dart Android application
- Android minimum SDK 24
- SharedPreferences for version-tolerant local-first household records and local feature preferences
- Firebase Authentication for optional identity and protected collaboration
- Cloud Firestore for narrowly scoped shared state and canonical Household synchronization
- Firebase Cloud Functions 2nd gen in `africa-south1`
- Firebase Cloud Messaging for remote push delivery
- Firebase App Check: debug provider during development, Play Integrity for release
- Google Maps Flutter + Geolocator for consensual trusted-person location and local arrival detection
- `google_places_sdk_plus` + Places API (New) for Home/Work address selection
- `country_flags` for bundled ISO country-flag artwork in emergency-region selection and display
- `geocoding` for readable reverse-geocoding when using **Set from here**
- `url_launcher` for external Google Maps and emergency phone-app handoff

## Product shell

Primary destinations remain:

**Overview · Tasks · Home · Supplies · People**

The exact Homi mark remains the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move while swiping between destinations.

People remains the approved **map-first** experience. Relationship editing, live-location controls, connections and Safety & check-ins remain inside that product flow rather than replacing it with a management-first hub.

## Local-first household data

Homi keeps local persistence as the immediate device layer. Cloud synchronization is additive rather than a replacement for the local app.

These remain device-local by definition unless a specific feature says otherwise:

- onboarding/home name/type;
- private **Me** one-off Tasks;
- quick items;
- cached current-device location;
- local notification preferences/schedules;
- local Home/Work arrival configuration, radius, recipients and arrival state.

When a signed-in user belongs to a canonical Shared Household, 0.12 can additionally mirror these Household domains through the shared data plane:

- recurring Routines;
- Supplies and quantities/status/expiry;
- Home Things;
- maintenance/repair events;
- utility readings.

The controller still saves these records to SharedPreferences first. Cloud snapshot application persists the synchronized result locally without echoing it back as another cloud write.

Explicit local-only mode suppresses the Household synchronizer even if Firebase still has a cached authenticated identity. Returning through the account/cloud flow recreates the shell after local-only mode is disabled so synchronization starts deliberately rather than from stale authentication state.

Model changes must preserve existing data through safe defaults/migrations rather than destructive resets.

## Canonical shared Household identity

0.11.0 introduced the first real shared-Household identity layer. It deliberately separates **being a trusted person** from **being a member of one shared Household**.

Canonical server-owned collections are:

- `households/{householdId}` — Household name, owner UID, current member UIDs, pending invite UIDs and the four-seat limit;
- `households/{householdId}/members/{uid}` — member profile snapshot and owner/member role;
- `householdMemberships/{uid}` — one-per-account pointer to the Household and role;
- `householdInvites/{householdId}_{inviteeUid}` — pending invitation state.

A Homi account can belong to at most one canonical Household at a time. The implementation supports up to four occupied or reserved seats, matching the approved Homi+ Household contract. Inviting a person requires an existing accepted trusted-person connection; the invitee must accept separately. Connection acceptance does not silently join a Household.

Household identity mutations are App-Check-protected server callables. Clients can read only their own membership, a Household they currently belong to, that Household's member directory, and invitations they are entitled to see. Clients cannot manufacture membership, ownership or invitations directly in Firestore.

The Household owner can rename the Household, invite connected people, cancel pending invitations, remove members, transfer ownership and delete an empty/sole-member Household. A non-owner can leave. Ownership transfer also rebinds pending invitation ownership to the new owner so management access does not become stale.

The management UI is available from **Homi & account -> profile -> Shared Household**. It uses the existing local home name only as the default name when creating a new shared Household. If **Add person** has no eligible accepted connection, the UI uses Homi's branded informational bottom sheet instead of injecting a transient inline page error; full, already-member/pending, and connect-someone-first states are explained separately.

## 0.12 shared Household data plane

The first synchronized Household records live at:

`households/{householdId}/data/{domain--itemId}`

The outer record envelope is:

- `domain`
- `itemId`
- `payload`
- `schemaVersion`
- `updatedByUid`
- `updatedAt`

Supported 0.12 domains are `routine`, `supply`, `homeThing`, `homeEvent` and `utilityReading`.

The document ID is deterministic and must equal `domain--itemId`. Firestore allows access only when the caller's `householdMemberships/{uid}` pointer references that Household **and** the server-owned Household `memberUids` still contains that UID. A forged/stale half of the membership relationship is insufficient.

Create/update rules additionally require the reviewed domain, matching payload/item identity, schema version 1, authenticated `updatedByUid` and a server request-time timestamp.

### First synchronization

Homi does not infer that every record already on a device belongs to whatever Household the account joins next.

If the current user is the owner, this device has never synchronized another Household, and an **authoritative non-cache** Firestore snapshot proves the new Household has no shared data, 0.12 imports the existing local Routines, Supplies and Home records once. This is the migration path from the pre-0.12 single-device model.

Otherwise, local record IDs not already known in the current Household are classified as private legacy records. They stay on the device and are not silently uploaded. New records created after Household classification synchronize normally. A later explicit merge/import UX can promote private legacy records when the user deliberately chooses to do so.

### Conflict behavior

The data plane is record-based. Different IDs merge. If two devices edit the same record, the last Firestore write acknowledged by the server becomes the shared version and is then persisted by listening devices.

Leaving/removal from a Household revokes cloud access but does not erase the local copy already stored on that phone.

### Household deletion

Deleting a Firestore document does not recursively delete its subcollections. `onHomiHouseholdDeletedDataCleanup` therefore removes nested Household data in bounded batches after the canonical Household parent is deleted. It also removes new shared Task documents carrying that Household ID.

## People, Household scope and connection codes

Connection, relationship label, canonical Household membership, current-location sharing, arrival-recipient selection and exact Home/Work visibility remain independent choices.

A relationship label such as Partner, Friend or Roommate remains editable. The old People **Household / Friend** scope is no longer a user-controlled authorization switch. People displays Household only when the other UID is in the same canonical Household. The edit sheet keeps the type visible but disabled and directs membership changes to Shared Household settings.

The protected `setTrustedPersonPreference` callable retains its deployed name for client compatibility but derives scope server-side. Caller-provided scope can no longer manufacture Household status.

Each signed-in account has one reusable six-character Homi code. The populated People page keeps **My code** available alongside **Connect**. For an established account, the client first reads the signed-in user's self-readable `users/{uid}` profile and reuses a valid stored `homiCode`; the App-Check-protected `ensureHomiIdentity` callable remains the provisioning/repair fallback. Connection creation with a code remains server-protected. Code loading/error state is independent of the connections refresh.

People Firestore subscriptions start immediately; cached GPS loading, passive location refresh and continuous-sharing resume happen in parallel rather than blocking the connection list.

## Tasks

Private **Me** Tasks remain local-only.

Shared Tasks continue using `sharedTasks`, but the existing callable names `createSharedTask`, `toggleSharedTask` and `removeSharedTask` are overridden by canonical implementations. New shared Tasks derive `householdId` and `memberUids` from the creator's canonical Household. A People preference cannot manufacture task access or make a non-member assignable.

The canonical Household is the durable collaboration owner of a shared Task. Callable access requires the acting UID to be in the Task's stored safe audience **and** still be a current canonical member of that Task's `householdId`; it does not require the original creator to remain in the Household. For new audience-version-1 Tasks, the Household owner can perform the owner-level reopen/remove recovery actions when the creator/completer is no longer available.

The UI source for Household assignees is canonical Household membership rather than `peoplePreferences.scope`.

`onHouseholdTaskMembershipChanged` watches canonical Household member-list changes. **Only** new `audienceVersion: 1` Tasks are rebound to the current member list; removed assignees become Unassigned and removed completion UIDs are stripped.

Pre-0.12 Tasks are migrated separately. A safely mappable legacy Task receives its creator's current canonical `householdId`, but its audience becomes only the intersection of historical recipients and current Household members and it is marked `audienceVersion: 0`. The membership synchronizer deliberately ignores version 0 so a later Household join cannot widen that historical audience. Unmappable legacy Tasks remain stored but fail closed under the canonical read rule.

## Current cloud collaboration

Homi currently shares narrowly defined collaboration state:

- `users/{uid}` and device registrations;
- Homi connection codes and accepted connections;
- private relationship-label preferences;
- canonical Household identity, member directory and invitations;
- canonical shared Household Routines, Supplies and Home records;
- specifically shared one-off Tasks;
- owner-to-viewer location-share grants;
- one latest location document per sender;
- optional explicitly shared Home/Work places;
- notification/developer-admin state and server rate limits.

No canonical Household membership silently enables location sharing or exact Home/Work visibility.

## People, location and privacy

Live location uses one latest-state document at `locations/{uid}`. Homi does not create route history by default.

The Android background stream is shared by two explicit consumers:

1. **Live updates** — cloud latest-location updates for individually authorized viewers;
2. **Arrival check-ins** — local Home/Work arrival detection.

The stream uses medium accuracy, roughly a 100 m movement threshold and roughly a two-minute Android interval. Check-in-only samples do not update the cloud location document unless Live updates are independently enabled.

Business/cost boundaries remain:

- client latest-location cloud writes are held to at least 90 seconds apart;
- Firestore independently rejects repeat latest-location writes inside 90 seconds;
- one sender may authorize at most five simultaneously active live-location viewers;
- removing/stopping a viewer remains available regardless of paid state and cannot be trapped behind the activation limit.

## Arrival check-ins and exact saved places

Home/Work arrival configuration remains local-first. A fresh first location sample establishes inside/outside state and sends nothing. Only outside -> inside triggers an arrival, leaving requires radius + 100 m hysteresis, and a one-hour local cooldown reduces edge repeats.

`sendArrivalCheckIn` receives only Home/Work label and selected recipient UIDs. Saved coordinates/addresses are not included in arrival delivery.

Exact Home/Work visibility is a separate explicit permission. The owner toggles **Show this place to selected people** for each saved place. A different user may read it only when all of these are true:

1. they are explicitly listed for that saved place;
2. the Homi connection remains accepted;
3. the owner currently shares location with that viewer.

Clients cannot directly mutate `sharedPlaces`. Server Functions own the mutation path.

## Homi+ commercial model

The source contract lives in `lib/src/domain/homi_plus_plan.dart` and `documentation/MONETIZATION.md`.

Core rule for the paid system once billing enforcement is enabled:

**Receiving a live location is free. Continuously sending your own live location requires one Homi+ sender seat. One paid sender may share with up to five trusted viewers.**

Approved first plan structure:

- Free: R0, no continuous sender seat after billing enforcement activates;
- Personal: R19.99/month, 1 sender seat;
- Duo: R34.99/month, 2 sender seats under one payer;
- Household: R49.99/month or R499.99/year, up to 4 canonical Household members plus the synchronized Household product.

Duo members do not need to live together. Household value is the shared household platform, not an arbitrary restriction on who can receive a location.

Plan definitions and canonical Household membership do **not** grant entitlement yet. Google Play product IDs, purchase-token verification, RTDN/Pub/Sub and authoritative server entitlement state are required before paid enforcement.

Privacy, stop-sharing, check-in disable, exact-place revoke, local erase and account deletion are never paywalled.

## Emergency-region architecture

Emergency numbers are bundled in the application binary. Firebase, mobile data and location permission are not required to display them.

`EmergencyRegionService` stores a user-selected region locally. Device locale can suggest a supported region, but Homi does not silently change emergency numbers from GPS/geocoding.

The same region powers:

- People -> Safety & check-ins emergency cards;
- full-screen People map emergency controls;
- the Home/Work Google Places country bias.

The emergency picker and emergency-call sheet use bundled ISO flag assets supplied by `country_flags`; flag rendering does not require a network request. Flag availability is broader than Homi's emergency-number catalog. Homi continues to list only regions whose emergency data has been explicitly source-reviewed rather than inventing numbers for every ISO country merely because a flag exists.

Regions with one verified universal number can show an SOS shortcut. Regions such as Japan/Brazil that are represented with service-specific numbers do not get an invented universal SOS target.

Emergency actions use external `tel:` handoff only. Homi does not silently place calls, dispatch responders or send the user's location to emergency services.

The emergency-call bottom sheet is scroll-controlled and height-bounded so service-specific country lists remain usable above Android system navigation without RenderFlex overflow.

The catalog is source-controlled and must be release-reviewed against ITU-T E.129 and/or the relevant national public-safety authority for every country enabled in public distribution.

## Authentication and protected mutations

Homi supports email/password and Google sign-in. Sensitive sharing requires Auth + App Check where the operation uses a callable; password-provider sensitive callable sharing additionally requires verified email.

`HomiCloudActions` is the typed client boundary for protected callable mutations. A stale `unauthenticated` response gets one forced Firebase ID token + App Check refresh and one retry. Raw backend codes must not reach the UI.

Sensitive server mutations include connection lifecycle, relationship labels/canonical derived scope, canonical Household membership/ownership/invitations, location-share grants, shared Tasks, hearts, arrival delivery, exact saved-place sharing, device registration, developer notifications and account deletion.

The 0.12 Household data plane uses authenticated Firestore offline-capable writes under the canonical Household rule boundary rather than a callable for each local-first record edit.

## Notifications

Operational notification preferences remain category-based. Arrival/People notifications respect the recipient's People-notification choice. A normal location position update does not generate a push notification.

## Release integrity

GitHub `main` is the tracked source of truth. `android/` remains intentionally local/untracked because Android/Firebase/signing configuration contains machine-specific or private values.

0.12 currently exists only on `homi-0.12-shared-data-plane` and is not production state until governed validation/merge/deployment completes.

A source change is not considered compiled/device-accepted until Bruce's Windows Flutter toolchain and S25 Ultra prove it. Backend/rules changes require the governed Node 22 / Firestore emulator / migration / batched Functions deployment helper after the Flutter gate passes. The 0.12 backend source surface is governed at exactly **37** Function exports and the Firestore emulator surface at **23** tests.
