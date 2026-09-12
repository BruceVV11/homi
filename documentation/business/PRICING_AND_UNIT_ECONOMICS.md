# Homi pricing and unit economics

Date: 2026-09-12
Status: current launch-planning contract; 0.13 Google Play Billing/entitlement architecture is implemented in source, but real Play catalog/provider setup and paid enforcement are not active yet.

`documentation/MONETIZATION.md` is the engineering source of truth for entitlement behaviour. This document records the matching commercial model and operating assumptions. If these documents disagree, stop billing work and reconcile them before creating/activating Play products.

## Approved launch structure

### Homi Free — R0

Free remains useful and local-first. It includes local Tasks/Routines/Supplies/Home records, Overview/Quick Reset, optional account creation, trusted connections, receiving a trusted person's shared live location, arrival check-ins, emergency shortcuts, manual/current-location refresh where supported and all privacy/data controls.

Once paid enforcement is deliberately activated after billing proof, Free does **not** include a continuous-location sender seat. Receiving live location remains free.

### Homi+ Personal — R19.99/month

- one continuous-location sender seat;
- up to five active trusted live viewers;
- viewers remain eligible on Free.

### Homi+ Duo — R34.99/month

- two continuous-location sender seats under one payer;
- purchaser is the first seat;
- second seat is one accepted trusted Homi connection;
- each sender has up to five viewers;
- seven-day seat reassignment cooldown;
- does not create a Shared Household by itself.

### Homi+ Household — R49.99/month or R499.99/year

- up to four canonical Shared Household members;
- each covered member receives sender entitlement with up to five viewers;
- shared Home/Routines/Supplies/Tasks/assignments/supported Household sync is the differentiating paid value.

Trusted friends outside the Household do not consume Household seats merely because a covered member shares location with them.

Only Household annual pricing is approved. Do not create annual Personal/Duo plans without a separate decision.

## Non-negotiable product rules

- Receiving live location is free.
- Maximum five active live viewers per paid sender.
- Household membership never turns on location sharing.
- Location sharing remains explicit per-person consent.
- Stop-sharing, revoke, check-in disable, exact-place revoke, local erase and account deletion are never paywalled.
- Subscription expiry must not destroy local data.
- A client purchase callback is never authoritative entitlement.
- Homi account deletion is separate from Google Play subscription cancellation.

## Google Play product structure

Use one Google Play subscription family for Homi+, with base plans for the tier/cadence. This reduces accidental simultaneous unrelated Homi+ purchases and gives Google Play the correct same-subscription plan-switch context.

Proposed durable IDs to create/verify once in Play Console:

- subscription product: `homi_plus`
- base plan: `personal-monthly`
- base plan: `duo-monthly`
- base plan: `household-monthly`
- base plan: `household-annual`

Do not create throwaway duplicate IDs to work around setup mistakes. After the real store IDs exist, populate the same exact identifiers into Homi's source-controlled client/backend catalog.

## 0.13 billing architecture

### Client

Implemented in source:

- maintained Flutter `in_app_purchase` integration;
- query real Play products/base plans;
- display Play-localized pricing;
- launch purchase/restore;
- opaque SHA-256-derived account association rather than raw Homi UID;
- send purchase token to protected Homi backend;
- consume server-written capability state;
- Plans & billing UI;
- Google Play subscription-management handoff;
- Duo second-seat management UI.

The source catalog remains deliberately unconfigured until exact Play IDs exist, so this development build cannot accidentally start a real purchase using guessed identifiers.

### Backend

Implemented in source:

- Auth + App Check purchase-verification callable;
- Android Publisher subscriptions-v2 verification;
- verified Play account/Homi account binding;
- server acknowledgement when Play reports acknowledgement pending;
- backend-only purchase/account/coverage storage;
- self-readable server-written entitlement projection;
- multi-source coverage reduction so one ending source does not remove a separate valid source;
- Duo seat/cooldown rules;
- Household coverage derived from canonical Household membership;
- superseded-token protection for plan changes;
- billing verification/seat mutation rate limits.

Capability examples remain:

- `continuousLocationSender`
- `sharedHousehold`
- `householdMemberLimit`
- `maxTrustedLiveViewers`

### Lifecycle

Implemented in source:

- RTDN Pub/Sub receiver;
- notification used only as a change signal;
- authoritative Android Publisher refresh before entitlement changes;
- active/grace/canceled-paid-term versus hold/paused/pending/expired capability semantics;
- restore/reinstall path;
- account/Household/connection cleanup reconciliation.

The real provider lifecycle still requires Play Internal Testing proof.

## Current readiness

0.11 production provides canonical Household identity. 0.12 source provides the shared Household data plane and canonical shared-Task boundary, but its final governed Firebase deployment still has to be closed before billing is allowed to mutate production.

0.13 is stacked on that final 0.12 source and now contains the payment/entitlement architecture. It is **not** yet a launch-ready paid build because:

- tracked Flutter dependencies still need exact lock resolution/compile/analyzer/test on Bruce's Flutter 3.41.5 toolchain;
- real Play subscription/base-plan IDs do not exist in the source catalog yet;
- Android Publisher API/Play Console access and RTDN Pub/Sub are not yet configured/proven;
- purchase/acknowledgement/restore/lifecycle has not yet been proven from a Play-installed Internal Testing build;
- paid enforcement remains deliberately off until that proof is green.

## Cloud/unit economics guardrails

Development usage remains too small to use as a production cost benchmark. Homi is local-first and location remains a latest-state document rather than route history.

High-frequency sensitivity remains location fan-out: one sender write can create multiple listener reads. Preserve:

- roughly two-minute / 100 m Android background request behaviour;
- 90-second client cloud-write floor;
- 90-second Firestore update floor;
- maximum five live viewers per sender;
- no push generated merely because a location coordinate changes;
- no default route history.

Before public production:

- configure Google Cloud budget/alerts for `homi-ee80a`;
- keep Functions instance/runtime limits bounded;
- monitor Firestore/Functions/Maps/Places/RTDN usage without logging coordinates, addresses or Household content into analytics;
- measure Homi+ conversion/retention before adding plans or expensive features.

## Next commercial milestone

The source implementation milestone is now **provider integration and proof**, not more speculative pricing design:

1. close 0.12 merge/governed Firebase deployment;
2. create the permanent `homi_plus` Play subscription and approved base plans;
3. populate the exact source catalogs;
4. configure Android Publisher API access and RTDN Pub/Sub;
5. run final 0.13 Windows/Node/Firestore/device gates;
6. deploy the billing backend from an accepted exact merge SHA;
7. prove real purchase, server verification/acknowledgement, restore/reinstall and lifecycle through Play Internal Testing;
8. prove Duo/Household coverage changes and multi-source safety;
9. only then activate paid enforcement;
10. close signing/App Check/legal/background-location/Data Safety/store-listing gates before production rollout.

Payment integration is the last major product-development phase, but public release still requires store/release compliance and production infrastructure proof.
