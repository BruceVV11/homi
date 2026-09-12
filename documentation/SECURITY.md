# Homi security architecture

Date: 2026-09-12
Current development candidate: `0.13.0+17`
Branch: `homi-0.13-billing-entitlements`
Stacked base: exact 0.12 candidate `233c6ab16caa3a9c5951251d7805f57a68ca440c`

Homi handles trusted relationships, precise location, Shared Household records and Google Play subscription state. A modified client is treated as hostile. UI visibility and local purchase callbacks are convenience state only; authorization belongs in Firebase Authentication, App Check, Cloud Functions, Firestore rules, Google Play verification and least-privilege IAM.

## Core security goals

- no private Household/location read without server-owned authorization;
- clients cannot forge identity, Household membership/ownership, shared-task audience or Homi+ entitlement;
- connection, Household membership, current-location sharing and exact Home/Work visibility remain separate permissions;
- Google Play purchase success on-device never grants paid capability by itself;
- purchase tokens never become client-readable cloud records;
- billing lifecycle changes are re-verified against Google Play rather than trusted from RTDN payload contents;
- an unrelated or previously superseded purchase token cannot silently replace the current active Homi+ purchase;
- out-of-app resubscribe can reconnect only through Google Play's verified prior account identifiers, never by trusting arbitrary client input;
- multiple subscription/coverage sources cannot overwrite each other accidentally;
- account deletion removes Homi-side billing mappings and raw stored tokens without falsely representing Play subscription cancellation;
- privacy exits remain available regardless of paid state;
- high-frequency/location/billing mutation surfaces retain server-side abuse bounds;
- release scripts fail closed on wrong project/runtime/export/test/provider identity.

## Permanent backend identity

- project: `homi-ee80a`
- project number: `883068189841`
- region: `africa-south1`
- Functions runtime: Node 22
- canonical runtime identity: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`
- Android package: `za.co.theconceptlab.homi`

Do not replace the canonical runtime/deployment identity merely to work around a missing Play or GCP permission. Provider access is repaired on the existing identity with the minimum required role/Play Console permission.

## Protected callable mutation boundary

Sensitive writes use App-Check-protected callables where appropriate, including:

- identity/code issuance/repair;
- trusted connection lifecycle;
- relationship-label update;
- Household identity/membership/invitations;
- per-viewer location authorization;
- shared one-off Tasks;
- People hearts and arrival delivery;
- exact saved-place grant/revoke;
- device registration/developer campaigns;
- account deletion;
- Google Play purchase verification; and
- Homi+ Duo seat assignment.

Reading an already-issued Homi code is a self-profile read, not a new identity mutation. Another user still cannot read/write that profile/code.

## Canonical Household authorization

The canonical relationship remains:

- `households/{householdId}`;
- `households/{householdId}/members/{uid}`;
- `householdMemberships/{uid}`;
- `householdInvites/{householdId}_{inviteeUid}`.

Shared Household data requires both:

1. the caller's membership pointer references that Household; and
2. the parent Household's server-owned `memberUids` contains the caller.

A People label cannot manufacture Household access. Household membership also does not imply any location authorization.

0.12 synchronized Household records live at:

`households/{householdId}/data/{domain--itemId}`

Allowed domains are `routine`, `supply`, `homeThing`, `homeEvent`, and `utilityReading`. Rules enforce deterministic document identity, a fixed/versioned envelope, authenticated actor and server request timestamp.

The safe first-sync strategy remains unchanged: an authoritative non-cache empty server collection is required for the narrow first-owner import; unmatched data on a member joining another/existing Household remains private legacy data rather than being silently uploaded. Explicit local-only mode suppresses this synchronizer.

## Shared one-off Tasks

Personal **Me** Tasks remain local/private. Shared Tasks retain the compatibility collection, but access now requires both the safe stored audience and current canonical Household membership.

New canonical tasks follow current membership. Removed assignee/completion UIDs are stripped. Pre-0.12 tasks are migrated only to the intersection of their historical audience and current canonical Household, marked with the historical audience version, and are never widened when a new member joins later.

## Continuous-location abuse/cost controls

Existing controls remain:

- Firestore enforces at least 90 seconds between direct latest-location updates;
- the client independently uses the same cloud-write gap;
- Android requests background positions roughly every two minutes with a 100 m movement filter;
- one sender can authorize at most five active trusted viewers;
- stopping/revoking sharing is never blocked by a paid state or viewer limit;
- default location storage is latest state, not route history.

Exact Home/Work sharing remains an independent explicit grant requiring an accepted connection and active owner-to-viewer current-location share.

## Homi+ trust model

### Client catalog and purchase flow

The client has one source-controlled `HomiPlayBillingCatalog.current`. It is deliberately blank/unconfigured until the real Play product/base-plan IDs exist. An unconfigured catalog cannot start a purchase.

Personal, Duo and Household are different subscription benefits and therefore use three permanent Play subscription products. The client uses Google Play subscription replacement when moving between those products instead of intentionally creating a concurrent Homi+ purchase.

The client uses the maintained Flutter `in_app_purchase` integration. Homi sends Google Play a SHA-256-derived opaque account identifier rather than the raw Firebase UID.

The purchase stream can initiate verification but cannot grant capability. The app consumes paid state only from its own server-written `entitlements/{uid}` projection.

### Google Play verification

`verifyGooglePlaySubscription` requires Firebase Auth + App Check, applies a server rate limit, then verifies the purchase token against the Android Publisher API for the permanent Homi package.

For a normal in-app purchase, the backend requires Google Play's `externalAccountIdentifiers.obfuscatedExternalAccountId` to equal the expected opaque identifier for the signed-in Homi account.

Google Play can also create an **out-of-app resubscription** after a previous subscription expired. In that case the verified subscriptions-v2 resource can carry the previous account association under `outOfAppPurchaseContext.expiredExternalAccountIdentifiers` and the prior token under `outOfAppPurchaseContext.expiredPurchaseToken`. Homi accepts those fields only from the authoritative Google Play response and uses them to resolve the already-linked Homi account. If the Homi billing account link has been removed, for example after account deletion, the RTDN cannot recreate that deleted Homi identity by itself.

A purchase already claimed by another Homi account cannot be reassigned by changing client input.

The backend maps the **verified Play product + base-plan ID** to a Homi+ tier. Product/base-plan IDs are public but durable release infrastructure and are source-controlled after Play Console creation; they are not guessed at runtime.

### Canonical purchase-token lineage

Google Play issues a new token for an in-app upgrade/downgrade/resubscribe before expiry and returns the previous purchase in `linkedPurchaseToken`. Homi uses that lineage as part of its server-side replacement decision. The verified `expiredPurchaseToken` from an out-of-app resubscribe is also retained as Play-provided historical lineage.

While a canonical purchase is still entitled:

- the same token may refresh itself;
- a new token may replace it only when Play links the new token to the current canonical token;
- an unrelated unlinked token cannot silently displace it;
- a token Homi has already marked with `supersededByTokenHash` cannot become canonical again.

If the current canonical purchase is no longer entitled, a new verified token tied to the same Homi account may become canonical even when Play correctly issues it as a fresh purchase after full expiry.

A dangling canonical-token pointer with no purchase record fails closed rather than being used as permission to accept an unrelated replacement.

### Purchase token storage and acknowledgement

Raw purchase tokens exist only in backend-only `billingPurchases`; clients cannot read them through Firestore rules.

After authoritative Play verification and entitlement reconciliation, when Google reports acknowledgement pending, the backend acknowledges the subscription through Android Publisher. Server-side acknowledgement is intentional so a valid purchase is not dependent on the app staying online/open long enough to satisfy Play's acknowledgement window. The client does not issue a second acknowledgement from stale local purchase state.

The governed Internal Testing gate must prove acknowledgement/lifecycle behavior; source alone is not acceptance evidence.

### Server-only billing collections

- `billingPurchases/{purchaseTokenHash}` — verified Play lifecycle/token metadata;
- `billingAccounts/{purchaserUid}` — canonical active token and Duo seat bookkeeping;
- `billingAccountLinks/{obfuscatedAccountId}` — server-side account resolution for RTDN/out-of-app resubscribe;
- `billingCoverage/{purchaseTokenHash_recipientHash}` — backend-only per-source coverage;
- `entitlements/{uid}` — narrow self-readable projection only.

Clients may `get` only their own `entitlements/{uid}` and cannot list/write/delete it. All other billing collections are backend-only.

### Multi-source entitlement projection

A person may be covered by more than one source, for example their own Personal subscription plus another payer's Household plan. Therefore a single purchase document is never allowed to directly overwrite/delete all entitlement state.

Each verified purchase projects backend-only coverage records. `entitlements/{uid}` is recomputed across current sources. If one source expires while another stays valid, the remaining source continues to grant its capabilities.

A state of `active`, `grace_period` or `canceled` grants capability only when the authoritative Play purchase has a verified paid-through timestamp in the future. A missing or already-past paid-through time fails closed to expired during backend projection. The Flutter entitlement parser mirrors the same fail-closed rule so delayed RTDN cannot leave stale paid capability enabled on-device.

### Duo seat safety

- purchaser is the first seat;
- second seat must be an accepted trusted Homi connection;
- server chooses the entitlement recipient;
- reassignment cooldown is seven days;
- unassigning or disconnecting the person does not reset the existing cooldown and cannot be used to bypass it.

### Household coverage safety

Household coverage is derived from the purchaser's **current canonical Household**, never a client-supplied arbitrary Household ID. Only current canonical members are covered, with the product cap of four members.

Membership changes trigger entitlement reconciliation. Losing Household coverage does not remove another valid subscription source that the user owns/receives separately.

### Subscription lifecycle and RTDN

`onGooglePlayBillingNotification` listens on governed Pub/Sub topic `homi-google-play-rtdn`. RTDN payload contents are treated only as a change signal; the backend re-fetches authoritative state from Android Publisher before changing entitlement.

Expected capability behavior:

- `active` — paid capabilities enabled only with a future verified paid-through time;
- `grace_period` — enabled only with a future verified paid-through time while Play attempts payment recovery;
- `canceled` — enabled through the already-paid term only;
- `on_hold`, `paused`, `pending`, `expired`, or a missing/elapsed paid-through time — paid capabilities disabled.

Superseded purchase tokens may refresh their own historical lifecycle state but cannot regain canonical authority after a newer token replaces them.

## Account deletion + billing

Deleting a Homi account and canceling Google Play billing are separate actions.

The in-app account-deletion card and both destructive confirmations now say this explicitly and direct a Homi+ purchaser to **Profile settings → Homi+ → Plans & billing → Manage subscription** before deletion when they also want billing canceled.

`onHomiPlusUserDeleted` removes Homi-side billing account links, self entitlement and coverage. It scans every historical `billingPurchases` record still associated with the purchaser, not only the current active token; removes coverage; strips raw stored purchase tokens and the Homi purchaser UID; and records account deletion. It also releases Duo secondary coverage from other payers while preserving the payer's reassignment cooldown.

It does **not** silently call Google Play to cancel the subscription.

Privacy/location revoke/local erase/Household leave where permitted remain independent and free.

## Firestore security gates

0.13 adds two billing boundary tests to the existing 23. The governed emulator suite is expected to contain exactly **25/25** tests:

- 13 established server-boundary tests;
- 8 canonical Household/data-plane tests;
- 2 canonical shared-task query tests;
- 2 Homi+ billing tests.

The billing tests prove:

- a user can read only their own server-written entitlement and cannot mutate it;
- purchase-token/account-link/coverage state cannot be read from a client.

## Functions policy/export gates

The dependency-loaded pure Node policy suite is expected to contain **16/16** tests:

- 5 Household/shared-task policy tests;
- 11 billing policy tests covering state/capability semantics, verified paid-term expiry, multi-source reduction, fail-closed catalog mapping and canonical purchase-token replacement/replay rules.

The source includes `check_policy_test_count.js`; the Functions `pretest` refuses to run a stale suite unless those two policy files declare exactly 16 tests.

The current source-level pure-policy preflight was run under Node 22 and passed **16/16**. That is source evidence only and does not replace the governed dependency-loaded lint/export/emulator/deployment gate.

0.13 adds six billing exports to the 0.12 expected 37, giving an exact expected Functions surface of **43**.

The deploy helper refuses billing deployment until it proves:

- Node 22;
- immutable project number;
- complete billing source;
- Functions lint + 16 policy tests;
- exactly 43 exports;
- Firestore 25/25;
- source-controlled Play catalog is configured;
- Android Publisher API is enabled;
- RTDN Pub/Sub topic exists;
- Google Play's notification service account can publish to the topic;
- known legacy Function/task migration gates are handled before stricter runtime deployment.

Actual Play Console API authorization for the canonical runtime identity still requires an Internal Testing purchase verification; GCP state alone does not prove Play app access.

## Paid enforcement remains disabled

The 0.13 source builds authoritative purchase/entitlement state, but existing continuous-location and Shared-Household capabilities are not yet paywalled. This is deliberate.

Enforcement must not activate until real Play Internal Testing proves purchase, server acknowledgement, in-app replacement, out-of-app resubscribe, restore/reinstall, cancellation, grace, hold, expiry, RTDN, Duo/Household coverage, superseded-token replay resistance and privacy exits. Final enforcement must be server-authoritative rather than a scattered Flutter `isPaid` check.

## Production security/compliance gates still required

- 0.12 exact-head merge/governed Firebase deployment and runtime acceptance;
- final 0.13 Windows analyzer/tests plus Node 22 / 16 policy / 43-export / Firestore 25 gates;
- real Play product/base-plan catalog and Play API access;
- RTDN Pub/Sub setup;
- store-installed billing lifecycle proof including out-of-app resubscribe/account resolution;
- permanent release signing / Play App Signing fingerprints;
- Play-installed Google Sign-In;
- production Maps/Places restrictions;
- Play Integrity App Check and staged Firestore App Check enforcement after valid release-client metrics;
- Cloud Billing budgets/alerts/monitoring;
- public Privacy Policy, Terms and external account-deletion resources;
- Google Play Data Safety and background-location disclosure/declaration/review evidence.
