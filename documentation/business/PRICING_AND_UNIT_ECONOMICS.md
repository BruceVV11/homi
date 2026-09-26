# Homi pricing and unit economics

Date: 2026-09-12
Status: current launch-planning contract; Google Play Billing and paid entitlement enforcement are not enabled yet.

`documentation/MONETIZATION.md` is the engineering source of truth for entitlement behaviour. This document records the matching commercial model and operating assumptions. If these documents ever disagree, stop billing implementation and reconcile them before creating Play products or writing entitlement code.

## Approved launch structure

### Homi Free — R0

Free remains a useful local-first Homi product and keeps all privacy/safety exits available.

Included:

- local Tasks and Routines;
- local Supplies and expiry/quantity tracking;
- local Home Things, maintenance/repair history and utility readings;
- Overview / Quick Reset;
- optional account creation for cloud/collaboration features;
- trusted-person connections;
- receiving a trusted person's live location when that person shares it;
- arrival check-ins, People hearts and emergency-number shortcuts;
- manual/current-location refresh where supported;
- account deletion, local erase, stop-sharing, check-in disable and exact-place revoke controls.

Once billing enforcement is activated, Free does **not** include a continuous-location sender seat. Receiving live location remains free.

### Homi+ Personal — R19.99/month

- one continuous-location sender seat;
- that sender may share continuous live location with up to five active trusted Homi viewers;
- viewers do not need a paid plan merely to receive the location.

### Homi+ Duo — R34.99/month

- two continuous-location sender seats under one payer;
- each covered sender has the same five-viewer limit;
- the second seat can cover another trusted Homi account and does not require a shared Household;
- intended use includes couples, parent/child, siblings and friends;
- target seat-reassignment cooldown is seven days, subject to final billing implementation.

### Homi+ Household — R49.99/month or R499.99/year

- up to four members in one canonical shared Homi Household;
- each covered Household member receives continuous-location sender entitlement with up to five active trusted viewers;
- full shared-Household cloud functionality is the differentiating paid value: supported Home data, Routines, Supplies, shared Tasks/assignments and synchronized Household state.

Trusted friends outside the canonical Household do not consume Household member seats merely because a Household member shares location with them.

Only Household annual pricing is currently approved. Do not invent annual Personal or Duo products.

## Non-negotiable product rules

- Receiving live location is free.
- Every paid continuous-location sender can have at most five active live viewers.
- Household membership does not automatically enable location sharing.
- Location sharing remains an explicit per-person choice.
- Stop-sharing, viewer removal, check-in disable, exact-place revoke, local erase and account deletion are never paywalled.
- Subscription expiry must not destroy the user's local data.
- A client-side purchase callback is never authoritative entitlement state.

## Why Google Play Billing

Homi+ sells digital app/cloud functionality in the Android app, so the first Play release should use Google Play Billing rather than introducing an external card flow. The billing client launches the Google Play purchase UI, while Homi's backend verifies purchase tokens and owns entitlement state.

Do not grant Homi+ directly from Flutter purchase state. Google recommends sending purchase tokens to a secure backend, verifying them with the Google Play Developer API, granting entitlement only for a verified PURCHASED state, and acknowledging initial subscription purchases. Real-time developer notifications (RTDN) plus authoritative Play lookups should keep lifecycle state synchronized after the initial purchase.

## Billing architecture

The paid implementation is split deliberately into client, backend and lifecycle layers.

### Client

The Flutter app will:

- query the real Play subscription products/base plans;
- show current Play pricing rather than hard-coded transactional prices;
- launch the Play purchase flow;
- attach a stable obfuscated account identifier where appropriate;
- send the resulting purchase token to Homi's protected backend;
- display authoritative entitlement/capability state returned from the backend;
- provide restore/refresh and **Manage subscription** routes;
- handle pending purchases without granting benefits.

### Backend

The backend will:

- verify tokens through the Google Play Developer API;
- use the current subscriptions v2 purchase-state API for new integration work;
- store purchase-token records server-side;
- map the verified subscription to the signed-in Homi account;
- acknowledge new subscription purchases through the server path where possible;
- derive authoritative Homi capabilities rather than exposing a generic `isPaid` boolean;
- enforce premium mutations independently of Flutter UI visibility.

Target capability examples remain:

- `continuousLocationSender`;
- `sharedHousehold`;
- `householdMemberLimit`;
- `maxTrustedLiveViewers`.

Duo additionally needs payer/seat-assignment state. Household entitlement binds to one canonical `householdId` and its covered members while valid.

### Lifecycle

RTDN through Pub/Sub must trigger authoritative Play lookups for events such as:

- purchase/renewal;
- cancellation while entitlement remains active until expiry;
- grace period/account hold where applicable;
- pause/resume where supported;
- expiry;
- refund/revocation;
- replacement/plan change;
- re-purchase.

The event notification itself is not sufficient proof of entitlement; Homi should fetch current state from Google Play and update its own authoritative entitlement record idempotently.

## Play product contract

Product/base-plan IDs are irreversible operating identifiers once activated, so create them only after the source implementation is ready for Internal Testing.

The intended first catalogue is:

- Homi+ Personal monthly;
- Homi+ Duo monthly;
- Homi+ Household monthly;
- Homi+ Household annual.

Exact Play product IDs/base-plan IDs must be recorded in source documentation before activation and reused permanently. Do not create temporary duplicate products to work around a setup mistake.

## Current product readiness

0.11 established canonical Household identity/membership. 0.12 implements the first real synchronized Household data plane and canonical shared-Task boundary in source. The final 0.12 exact-head app/backend gate is still being closed before any payment implementation is merged into production.

That sequencing is intentional: billing should attach to proven Household and shared-data primitives rather than forcing product architecture to conform to placeholder purchase state.

## Current cloud economics

Development usage has been extremely low and is not a production cost benchmark. Homi remains local-first, location uses one latest-state document rather than route history, and 0.12 is only now introducing synchronized Household records.

Location fan-out remains the primary high-frequency cost sensitivity: one sender write can cause several listener reads. Existing protections therefore remain business and privacy guardrails:

- roughly two-minute / 100 m Android continuous-location request behaviour;
- 90-second client cloud-write floor;
- 90-second Firestore write floor;
- maximum five active live viewers per sender;
- no push notification generated merely because a location coordinate updates.

Do not weaken those limits merely to make a paid tier appear more generous.

## Launch cost controls

Before public production:

- configure a Google Cloud billing budget and alerts for `homi-ee80a`;
- keep Functions instance/runtime limits bounded;
- monitor Firestore/Functions/Places/Maps usage without logging coordinates, addresses or Household content into analytics;
- measure Homi+ conversion and retention before adding more plans or higher-cost features;
- keep no default location history unless a separately reviewed retention product is introduced.

## Next commercial milestone

After the final 0.12 candidate is validated, merged and its governed Firebase surfaces are deployed, the next development release should implement:

1. centralized server-authoritative capability/entitlement state;
2. Google Play Billing client integration;
3. Google Play Developer API server verification and acknowledgement;
4. RTDN/Pub/Sub lifecycle processing;
5. Duo and Household seat/coverage rules;
6. Plans & billing UI, restore/refresh and manage-subscription flow;
7. Internal Testing proof using real Play test subscriptions;
8. paid enforcement only after the complete lifecycle is proven.

Payment integration is therefore the next major product phase, but it is not by itself the final store-release gate. Release signing, Play App Signing/Firebase fingerprints, App Check, current target API compliance, privacy/account-deletion URLs and forms, Data safety, background-location approval evidence, store listing/content rating and store-installed regression testing must also be completed before production rollout.
