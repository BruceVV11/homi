# Homi+ commercial and entitlement contract

Date: 2026-09-12
Applies from source line: `0.13.0+17`
Status: **approved product contract; billing implementation in source, Play provider setup and paid enforcement still pending**

This document is the product and engineering source of truth for Homi's first paid model. Pricing may change only by an explicit product decision; code must not silently invent different seat, entitlement or privacy rules.

## Core rule

**Receiving a live location is free. Continuously sending your own location requires one Homi+ sender seat once paid enforcement is activated. Every paid sender seat may share continuous live location with up to five trusted Homi viewers.**

The five viewers do not have to be members of the same Household and do not need a paid plan merely to receive the sender's location.

Connections, relationship labels and canonical Household membership are not substitutes for the explicit per-person location-sharing grant.

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

Free does **not** include a continuous-location sender seat after paid enforcement is activated.

### Homi+ Personal — R19.99/month

- one continuous-location sender seat;
- that sender may have up to five active trusted live-location viewers.

Personal is for one person who wants several trusted people to be able to follow that person's ongoing location. The viewers may remain on Free.

### Homi+ Duo — R34.99/month

- two continuous-location sender seats under one subscription;
- each covered sender independently receives the same five-viewer limit;
- the first seat is the purchaser;
- the second seat can cover one accepted trusted Homi connection and does not require the two people to live together;
- intended use includes couples, parent/child, siblings and friends;
- seven-day seat-reassignment cooldown.

Duo is two sender entitlements paid by one purchaser. It does not create a shared Household by itself.

Unassigning the second seat, disconnecting that person or reconnecting them must not reset/bypass the seven-day reassignment cooldown.

### Homi+ Household — R49.99/month or R499.99/year

- up to four members in one canonical shared Homi Household;
- each covered member receives continuous-location sender entitlement with up to five viewers;
- full Household cloud synchronization is the differentiating paid value: shared Home, Tasks, Routines, Supplies, assignments and supported Household history/state.

Trusted friends outside the Household do not consume Household member seats merely because a Household member shares location with them.

## Canonical Household and data-plane status

0.11 established the server-owned canonical Household identity. 0.12 adds the shared Household data plane for Routines, Supplies, Home Things, maintenance/repair events and utility readings, plus canonical Household authorization for shared one-off Tasks. Existing local data uses the explicit safe first-sync/private-legacy strategy recorded in the 0.12 release documents.

0.13 attaches billing capability to these stable Household identifiers; it does not infer a paid Household from a People relationship label.

## Privacy and safety are never paywalled

Payment state must never prevent stopping continuous sharing, removing a viewer, disabling arrival monitoring/check-ins, revoking exact Home/Work visibility, disconnecting another person, leaving a Household where allowed, erasing local data, deleting an account, or opening emergency-number shortcuts.

If a subscription expires, existing local data is not immediately destroyed. Paid creation/sync/broadcast capabilities may be disabled while privacy exits remain available.

Deleting a Homi account and canceling a Google Play subscription are separate operations. Homi must warn about this clearly. Account deletion removes Homi-side entitlement/account mappings but does not cancel a Play subscription on the user's behalf.

## Cost guardrails

The first paid model assumes continuous location remains a latest-state feature, not route history. Preserve the roughly two-minute/100 m Android request behavior, 90-second client/Firestore cloud-write floor, five-viewer cap and absence of automatic push on each coordinate update.

## Google Play catalog direction

Personal, Duo and Household are **different subscription benefits**, so they must be separate Google Play subscription products. Base plans define pricing/billing options for one subscription's benefit; they are not a substitute for different tiers of service.

Proposed permanent identifiers:

- product `homi_plus_personal`
  - base plan `monthly`
- product `homi_plus_duo`
  - base plan `monthly`
- product `homi_plus_household`
  - base plan `monthly`
  - base plan `annual`

Only Household has an approved annual price. Do not add annual Personal or Duo base plans until separately approved.

When moving between Personal, Duo and Household, the Android client must use Google Play's subscription replacement flow rather than purchase an unrelated concurrent Homi+ subscription. 0.13 supplies the current active Homi+ Play purchase as `ChangeSubscriptionParam` and requests time-prorated immediate replacement. That exact upgrade/downgrade behavior must be proven with license testers before public sale.

## Billing architecture — 0.13 source status

0.13 implements in source:

1. Flutter purchase flow using `in_app_purchase`;
2. Play-localized plan price display;
3. opaque account association rather than exposing raw Homi UID to Play;
4. App-Check-protected server purchase verification;
5. Android Publisher `purchases.subscriptionsv2.get` verification;
6. server-side purchase acknowledgement when Google says acknowledgement is pending;
7. server-only purchase/account/coverage storage;
8. self-readable authoritative `entitlements/{uid}` projection;
9. Pub/Sub RTDN receiver that re-fetches authoritative Play state before changing entitlement;
10. restore/reinstall flow;
11. governed subscription upgrade/downgrade replacement;
12. Duo second-seat assignment with accepted-connection and cooldown checks;
13. Household coverage derived from canonical Household membership;
14. multi-source entitlement projection so one coverage source cannot erase another valid source;
15. Google Play subscription-management handoff.

The client never unlocks Homi+ merely because a local purchase callback says `purchased`.

### Capability model

The backend projects capability questions rather than scattered local `isPaid` checks:

- `continuousLocationSender`
- `sharedHousehold`
- `householdMemberLimit`
- `maxTrustedLiveViewers`

A Homi account can have multiple entitlement sources. Backend-only `billingCoverage` records are reduced into one `entitlements/{uid}` projection; an expiring source does not delete a separate valid source.

## Play lifecycle semantics

- `active` grants paid capability;
- `grace_period` keeps paid capability while Play attempts payment recovery;
- a voluntarily `canceled` subscription keeps entitlement through the already-paid term until Play reports expiration;
- `on_hold`, `paused`, `pending` and `expired` do not grant paid capability;
- superseded purchase tokens cannot regain authority after a newer plan-change token becomes canonical;
- new purchase tokens are acknowledged on the server after verification;
- RTDN is a signal, not trusted entitlement data: backend always re-queries Google Play.

## Provider infrastructure required before billing deployment

The 0.13 governed deploy fails closed until:

- exact Play product/base-plan IDs are source-controlled in both Flutter and Functions catalogs;
- Android Publisher API is enabled on `homi-ee80a`;
- Pub/Sub topic `homi-google-play-rtdn` exists;
- `google-play-developer-notifications@system.gserviceaccount.com` can publish to that topic;
- canonical Homi runtime identity is linked/authorized for the Play Console app with minimum purchase/subscription access needed for verification/acknowledgement.

The last item must be proven through an actual Play-installed Internal Testing purchase; GCP IAM alone is not evidence that Play API access is correct.

## Paid enforcement sequencing

Paid enforcement is deliberately **not active merely because the billing source exists**.

Required sequence:

1. deploy and accept the 0.12 shared Household data plane;
2. compile/analyze/test final 0.13 app source;
3. create and verify the three Play subscription products/base plans;
4. configure Android Publisher API access and RTDN Pub/Sub;
5. deploy/validate the 0.13 billing backend;
6. prove purchase + server verification + acknowledgement from a Play Internal Testing install;
7. prove upgrades/downgrades, restore/reinstall/account mapping;
8. prove active/canceled/grace/hold/expiry lifecycle reconciliation and RTDN;
9. prove Duo and Household coverage changes;
10. prove privacy exits with no entitlement;
11. only then activate paid enforcement for continuous sending and shared-Household premium capability in the final launch candidate.

## Store/install verification

Android Studio sideloads are not accepted as payment proof. Google Play Billing must be exercised from the Google Play Internal Testing build attached to the real store catalog/test-account setup.

Store-signed authentication, Play Integrity/App Check and Google Sign-In also require their own Internal Testing proof before production.
