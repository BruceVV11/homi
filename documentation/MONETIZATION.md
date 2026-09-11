# Homi+ commercial and entitlement contract

Date: 2026-09-11
Applies from source line: `0.10.0+14`

This document is the product and engineering source of truth for Homi's first paid model. Pricing may change before public sale, but code must not silently invent different seat or privacy rules.

## Core rule

**Receiving a live location is free. Continuously sending your own location requires one Homi+ sender seat. Every paid sender seat may share continuous live location with up to five trusted Homi viewers.**

The five viewers do not have to be members of the same Household and do not need a paid plan merely to receive the sender's location.

Connections, relationship labels and Household membership are not substitutes for the explicit per-person location-sharing grant.

## Plans

### Homi Free — R0

- local Homi functionality;
- Homi account and trusted connections;
- receive a trusted person's live location when that person shares it;
- receive arrival check-ins;
- emergency-number shortcuts;
- People hearts and basic social connection functions;
- manual/current-location refresh where the product supports it;
- all privacy, stop-sharing, check-in disable, exact-place revoke, erase and account-deletion controls.

Free does **not** include a continuous-location sender seat once billing enforcement is activated.

### Homi+ Personal — R19.99/month

- one continuous-location sender seat;
- that sender may have up to five active trusted live-location viewers.

Personal is for one person who wants several trusted people to be able to follow that person's ongoing location. The viewers may remain on Free.

### Homi+ Duo — R34.99/month

- two continuous-location sender seats under one subscription;
- each covered sender independently receives the same five-viewer limit;
- the second seat can cover another trusted Homi account and does not require the two people to live together;
- intended use includes couples, parent/child, siblings and friends;
- target seat-reassignment cooldown: seven days, subject to final billing implementation.

Duo is two sender entitlements paid by one purchaser. It does not create a shared Household by itself.

### Homi+ Household — R49.99/month or R499.99/year

- up to four members in one shared Homi Household;
- each covered member receives continuous-location sender entitlement with up to five viewers;
- full Household cloud synchronization is the differentiating paid value: shared Home, Tasks, Routines, Supplies, assignments and supported Household history/state.

Trusted friends outside the Household do not consume Household member seats merely because a Household member shares location with them.

## Privacy and safety are never paywalled

Payment state must never prevent a user from:

- stopping continuous sharing;
- removing a viewer;
- disabling arrival monitoring/check-ins;
- revoking exact Home/Work visibility;
- disconnecting another person;
- erasing local data;
- deleting an account;
- opening emergency-number shortcuts.

If a subscription expires, existing data is not immediately destroyed. Paid creation/sync/broadcast capabilities may be disabled, while privacy exits remain available.

## Cost guardrails

The first paid model assumes continuous location remains a latest-state feature, not route history.

Source/runtime boundaries from 0.10.0:

- Android asks for background positions at roughly two-minute intervals with a 100 m movement filter;
- Homi's client cloud-write guard is 90 seconds;
- Firestore independently rejects repeat latest-location updates inside 90 seconds;
- one sender can authorize no more than five active live-location viewers;
- location remains one latest document rather than an append-only trail;
- a location update does not invoke a Cloud Function or send an FCM push by itself.

These controls are business-protection and privacy controls as well as technical limits. Do not raise them casually.

## Billing architecture — required before paid enforcement

The plan definitions in source are commercial contracts only. They do not yet grant a paid entitlement.

Paid enforcement must be activated only after all of the following exist:

1. Google Play subscription products/base plans for the intended plans;
2. Flutter purchase flow using the official Play Billing integration;
3. server-side purchase-token verification through the Google Play Developer API;
4. authoritative server-stored entitlement state;
5. real-time subscription lifecycle handling (RTDN / Pub/Sub plus authoritative Play lookup);
6. restore/reinstall/account-change handling;
7. cancellation, grace period, hold, expiry and refund/revocation handling;
8. Play Internal Testing proof from a store-installed build.

The client must never unlock Homi+ only because a local purchase callback says a payment succeeded.

## Entitlement model target

The backend should ultimately answer capability questions, not scatter `isPaid` checks through Flutter.

Examples:

- `continuousLocationSender`
- `sharedHousehold`
- `householdMemberLimit`
- `maxTrustedLiveViewers`

A Duo subscription should identify the purchaser plus one assigned Homi account. Household should identify one shared Household and its covered members. Store purchase ownership and Homi entitlement membership are separate concepts.

## Annual pricing

Only Household annual pricing is currently approved: **R499.99/year**.

Do not hard-code annual Personal or Duo products until those prices are separately approved.
