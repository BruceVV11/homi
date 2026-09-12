# Homi Architecture

Date: 2026-09-12
Current development candidate: **0.13.0+17**
Stacked base: exact 0.12 candidate `233c6ab16caa3a9c5951251d7805f57a68ca440c`

## Permanent identifiers

- Firebase/GCP: `homi-ee80a`
- project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`
- local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Firestore/Functions region: `africa-south1`
- Functions runtime: Node 22
- runtime service account: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Deleted project `homi-508000` must never be reused.

## Stack

- Flutter/Dart Android app
- Android minimum SDK 24
- SharedPreferences local-first persistence
- Firebase Authentication
- Cloud Firestore
- Cloud Functions 2nd gen in `africa-south1`
- Firebase Cloud Messaging
- Firebase App Check: debug during development, Play Integrity for release
- Google Maps + Geolocator
- Google Places API (New) through native wrapper
- `country_flags`
- `geocoding`
- `url_launcher`
- Google Play Billing through `in_app_purchase`
- Android Publisher API for subscription verification/acknowledgement
- Pub/Sub RTDN for subscription lifecycle signals

## Product shell

Primary destinations remain:

**Overview · Tasks · Home · Supplies · People**

People remains map-first. Profile/account/billing/Household management live in nested pages rather than replacing approved primary navigation.

## Local-first data

The device remains immediate authority for normal edits. Cloud sync is additive.

Local-only by default unless a feature explicitly says otherwise:

- onboarding/home name/type;
- private **Me** one-off Tasks;
- quick items;
- cached current-device location;
- local notification preferences/schedules;
- local Home/Work arrival config/radius/recipients/state.

0.12 additionally mirrors eligible Shared Household domains through Firestore while current canonical membership exists:

- Routines;
- Supplies;
- Home Things;
- maintenance/repair events;
- utility readings.

The controller persists locally first. Firestore snapshot application persists cloud state locally without echoing the same mutation back.

Explicit local-only mode suppresses Shared Household sync even if Firebase retains a cached sign-in.

## Canonical Shared Household

Canonical server-owned identity:

- `households/{householdId}`
- `households/{householdId}/members/{uid}`
- `householdMemberships/{uid}`
- `householdInvites/{householdId}_{inviteeUid}`

One account can belong to one Household. Maximum occupied/reserved seats: four. Inviting requires an accepted trusted connection; invitee accepts separately.

Connection, private relationship label, Household membership and location sharing are separate product states.

Server callables own Household mutation: create, rename, invite, accept/decline, cancel, remove, leave, transfer ownership, delete.

### Household UI stream stability

0.13 folds in the last 0.12 device-feedback polish. `HouseholdService` keeps stable current-Household/member/incoming/outgoing streams for the authenticated UID rather than manufacturing new Firestore streams on each `_busy` rebuild. This prevents cancel/rename/invite/remove/transfer/delete mutations from visually flashing the page back into a loading state.

The Add-to-Household picker now includes a short privacy/context panel explaining that membership does not enable location sharing.

## Shared Household data plane

Path:

`households/{householdId}/data/{domain--itemId}`

Envelope:

- `domain`
- `itemId`
- `payload`
- `schemaVersion`
- `updatedByUid`
- `updatedAt`

Supported domains: `routine`, `supply`, `homeThing`, `homeEvent`, `utilityReading`.

Access requires both:

1. `householdMemberships/{uid}` points to the Household; and
2. parent `memberUids` still contains the UID.

Writes also require deterministic `domain--itemId`, reviewed domain, matching payload ID, schema version 1, authenticated actor and request-time timestamp.

### First synchronization

Automatic import of existing local records occurs only when:

- this device has never synchronized another Household;
- current user is the owner; and
- a non-cache authoritative Firestore snapshot proves the new Household has no shared records.

Otherwise unmatched old records remain private legacy data. New records created after classification can synchronize normally.

### Conflict/removal

Different record IDs merge. Same-record changes settle to the last server-acknowledged Firestore value.

Leaving/removal revokes cloud access but does not erase the local copy already delivered to that phone.

### Household deletion

`onHomiHouseholdDeletedDataCleanup` removes nested Shared Household data and newer canonical shared Tasks after legitimate parent Household deletion.

## People and connection codes

Relationship labels remain editable. Household/Friend type is read-only and derived from real canonical membership.

`setTrustedPersonPreference` keeps its deployed callable name but server-derives Household scope.

Each account has one reusable six-character Homi code. People exposes **My code** on demand plus **Connect**. Established code loads from the user's self-readable profile before protected provisioning fallback. The persistent orange code card was removed by device-feedback approval.

People connection subscriptions start independently of GPS initialization.

## Shared Tasks

Private **Me** Tasks remain local.

Shared Tasks keep the existing `sharedTasks` compatibility collection/callable names, but new records derive canonical `householdId` and member audience from real Household membership.

New audience-version-1 Tasks follow current canonical membership. Removed assignee/completion UIDs are stripped.

Pre-0.12 Tasks use a governed intersection-only migration and `audienceVersion: 0`, so later Household joins cannot widen historical audiences.

## Location/privacy

Latest shared location lives at `locations/{uid}`. No default route history.

Background stream can serve two separately enabled consumers:

1. Live updates;
2. arrival check-ins.

Existing cost/privacy controls remain:

- roughly two-minute / 100 m Android background request behavior;
- 90-second client cloud write floor;
- 90-second Firestore update floor;
- maximum five active viewers per sender;
- no push simply because a coordinate changed.

Stopping/revoking sharing is always available.

Exact Home/Work visibility remains a separate explicit grant requiring accepted connection + active owner-to-viewer location sharing.

Arrival detection runs locally. The arrival callable receives Home/Work label + selected recipient UIDs, not the saved precise address/coordinate.

## Homi+ commercial model

Approved contract:

- Free: R0;
- Personal: R19.99/month, 1 sender seat;
- Duo: R34.99/month, purchaser + 1 accepted trusted account as second sender seat;
- Household: R49.99/month or R499.99/year, up to 4 canonical Household members;
- each sender: max 5 active live viewers;
- receiving live location: free;
- Duo seat reassignment cooldown: 7 days;
- privacy/revoke/erase/delete controls: never paywalled.

Paid enforcement remains off until Internal Testing proves the full billing lifecycle.

## 0.13 Play Billing architecture

### Store catalog

Personal, Duo and Household are separate subscription benefits, so Homi uses three Google Play subscription products with only the approved billing base plans:

- product `homi_plus_personal`
  - base plan `monthly`
- product `homi_plus_duo`
  - base plan `monthly`
- product `homi_plus_household`
  - base plans `monthly`, `annual`

Homi has one governed client catalog and one governed Functions catalog. Both remain blank/unconfigured until the real permanent Play IDs exist. Blank catalog means purchase UI is disabled/fail-closed.

Tier changes use Google Play subscription replacement rather than intentionally starting another concurrent Homi+ subscription. The client passes the current Homi+ Play purchase in `ChangeSubscriptionParam`; Google Play returns a new purchase token and `linkedPurchaseToken` lineage for an upgrade/downgrade/resubscribe before expiry. Homi verifies that lineage server-side before replacing an active canonical token.

### Client purchase path

`HomiBillingService`:

1. queries Play product/base-plan details;
2. displays Play-localized pricing;
3. starts purchase/restore using `in_app_purchase`;
4. supplies SHA-256(`homi:<uid>`) as opaque Play account association rather than raw UID;
5. uses Play replacement/proration when another Homi+ product is already active;
6. sends the purchase token to protected `verifyGooglePlaySubscription`;
7. never grants paid capability from local `PurchaseStatus`;
8. consumes authoritative `entitlements/{uid}` through `HomiEntitlementService`.

Profile Settings exposes **Homi+ → Plans & billing**. The page also supports Google Play subscription management and Duo seat assignment.

### Backend verification path

`verifyGooglePlaySubscription`:

1. requires Firebase Auth + App Check;
2. applies server rate limit;
3. verifies token through Android Publisher `purchases.subscriptionsv2.get` for permanent Homi package;
4. verifies Play `obfuscatedExternalAccountId` matches expected Homi account hash;
5. maps verified product + base plan to Homi tier;
6. stores token/lifecycle only in backend-only state;
7. validates canonical-token replacement against Play `linkedPurchaseToken` while the existing token is still entitled;
8. refuses a previously superseded token becoming canonical again;
9. acknowledges through Android Publisher if acknowledgement is pending;
10. normalizes known paid-term expiry so canceled/stale state cannot remain entitled after its expiry time;
11. projects coverage/capability state.

### Billing state collections

Backend-only:

- `billingPurchases/{purchaseTokenHash}`
- `billingAccounts/{purchaserUid}`
- `billingAccountLinks/{obfuscatedAccountId}`
- `billingCoverage/{purchaseTokenHash_recipientHash}`

Client self-readable only:

- `entitlements/{uid}`

The client cannot list/write/delete entitlement state.

### Multi-source entitlement model

One user may have more than one coverage source. Example: own Personal plus another payer's Household.

Each purchase creates backend-only per-recipient coverage. `entitlements/{uid}` is recomputed across sources. One source ending must not erase another still-valid source.

Capability fields include:

- `continuousLocationSender`
- `sharedHousehold`
- `householdMemberLimit`
- `maxTrustedLiveViewers`

### Duo

Purchaser is first seat. Second seat must be an accepted trusted connection. Seven-day reassignment cooldown is server-owned and persists through temporary unassignment/disconnection so those actions cannot bypass it.

### Household

Household Homi+ coverage derives from purchaser's **current canonical Household**, not a client-provided ID. Coverage is limited to current members and capped at four.

Membership changes trigger reconciliation. Losing Household coverage does not remove another valid Personal/Duo source.

### RTDN

Pub/Sub topic contract:

`homi-google-play-rtdn`

`onGooglePlayBillingNotification` treats message contents only as a change signal and re-queries Android Publisher before changing entitlement.

Expected states:

- active/grace/unexpired canceled term: capability available;
- hold/paused/pending/expired or known paid term already past: no paid capability.

Superseded purchase tokens can refresh historical lifecycle state but cannot retake canonical authority. A linked replacement token may replace the current active canonical purchase; an unrelated unlinked token cannot silently displace it while the current purchase remains entitled.

### Account deletion

Homi account deletion removes Homi billing mappings/coverage but does not cancel a Google Play subscription. UI/legal/external deletion flow must explicitly separate these actions.

## Billing deployment provider prerequisites

Before 0.13 billing runtime can deploy:

- real Play catalog IDs populated in source;
- Android Publisher API enabled on `homi-ee80a`;
- Pub/Sub topic `homi-google-play-rtdn` exists;
- Google Play developer-notification service account can publish to the topic;
- canonical Homi runtime identity has minimum Play Console API access needed to verify/acknowledge purchases.

Play Console access is not proven merely because GCP IAM is correct; the real Internal Testing purchase must prove it.

## Notifications/emergency

Notification categories remain explicit and product announcements are not a marketing backdoor.

Emergency numbers remain bundled local data and only reviewed regions should be enabled publicly. Emergency actions use external dialer handoff only.

## Release integrity

GitHub is tracked source of truth. `android/` remains intentionally local/untracked.

Current production remains 0.11 until the final 0.12 governed deployment is proven.

0.13 is stacked source, not permission to skip 0.12 deployment/acceptance.

Expected final 0.13 source gates after provider setup:

- Flutter dependency resolution/analyzer/full tests on Bruce's real toolchain;
- Node22 lint + policy tests **16/16**;
- exact Functions exports **43**;
- Firestore emulator **25/25**;
- S25 Ultra regression;
- Play Internal Testing purchase/lifecycle proof including cross-tier replacement and superseded-token replay resistance;
- paid enforcement only after lifecycle proof.
