# Homi+ commercial and entitlement contract

Date: 2026-09-26
Applies from source line: `0.13.0+17`
Status: **approved launch contract; billing implementation is in source, Play provider setup and paid enforcement remain pending**

This is the product and engineering source of truth for Homi's first paid model. Google Play localized pricing is authoritative at checkout, but the South African launch prices below are the approved commercial targets.

## Core rules

- Receiving another trusted person's live location remains free.
- A paid sender may continuously share live location with up to **three** trusted viewers.
- Location sharing remains explicit per person. Household membership never enables it automatically.
- Privacy, revoke, stop-sharing, local erase, leaving where allowed and account deletion are never paywalled.
- Free remains useful rather than acting as a trial-only shell.
- Personal and Duo include trusted-person **Shared Tasks and Shared Routines**.
- Household adds the full canonical shared-home workspace and scalable paid Household membership.

## Launch plans

### Homi Free — R0

For somebody using Homi mainly for themselves, or receiving things another person shares.

Includes:
- local Tasks, Routines, Supplies and Home records;
- Homi account and trusted connections;
- receiving shared live location and arrival/check-in information;
- emergency shortcuts and supported safety controls;
- all privacy/data controls.

After paid enforcement is activated, Free does not originate continuous live-location sending or paid Shared Task/Routine creation.

### Homi+ Personal — R79.99/month or R799.99/year

For one person who wants Homi+ for themselves while still collaborating with trusted people.

Includes:
- one continuous-location sender seat;
- up to three active trusted live viewers;
- ability to create/share Tasks and Routines with trusted Homi connections;
- a Free recipient may receive/participate without buying Homi+ merely to respond.

### Homi+ Duo — R129.99/month or R1,299.99/year

For two people who both actively use Homi+ together: partners, siblings, parent/child or close friends.

Includes:
- purchaser plus one accepted trusted Homi connection as the second covered sender;
- up to three live viewers per covered sender;
- both covered people can originate Shared Tasks and Shared Routines;
- seven-day second-seat reassignment cooldown;
- Duo does not create a Shared Household by itself.

### Homi+ Household — R199.99/month or R1,999.99/year

For people actually running one home together.

Four members are included. Each covered member receives:
- continuous-location sender entitlement with up to three viewers;
- Shared Tasks and Routines;
- full canonical Shared Household cloud workspace: Home, Tasks, Routines, Supplies, assignments, supported maintenance/history and synchronized household state.

Additional Household members are **R50/month or R500/year each** above the included four.

Examples:
- 4 members: R199.99/month or R1,999.99/year;
- 5 members: R249.99/month or R2,499.99/year;
- 6 members: R299.99/month or R2,999.99/year.

Launch technical maximum: **10 Household members**. This prevents the consumer product from accidentally becoming an unmanaged team/business plan while leaving room for large families and households.

Existing members are never automatically removed merely because billing later drops below the occupied member count. The server blocks further additions until paid capacity is sufficient again.

## Shared Tasks and Shared Routines

### Trusted-person collaboration — Personal and Duo

A Shared Task is a one-off item such as "Collect the parcel". A Shared Routine is recurring, such as "Take the bins out every Thursday".

Personal allows the covered subscriber to originate those shared items with trusted connections. Duo gives that creator capability to both covered people.

Receiving/participating is not itself a paid action. This follows the same product philosophy as location: the paid entitlement funds the capability being originated, while a trusted recipient should not be forced to subscribe simply to receive or complete something that was shared with them.

### Household collaboration — Household

Household collaboration belongs to the canonical Household rather than a single relationship. Tasks/Routines can be visible and assignable across the home, and the rest of the shared-home data plane joins them: Supplies, Home records, maintenance/history and other supported synchronized household state.

That is the main difference between "we collaborate in Homi" and "we run our home in Homi".

## Capability model

Paid access is projected as capabilities rather than scattered plan-name checks:

- `continuousLocationSender`
- `sharedTasks`
- `sharedRoutines`
- `sharedHousehold`
- `householdMemberLimit`
- `maxTrustedLiveViewers`

The backend remains authoritative. Flutter purchase callbacks never grant capability directly.

## Household capacity contract

- four members included;
- each additional member raises the recurring target price by R50/month or R500/year;
- source supports Household tiers from 4 through 10 members;
- the canonical Household backend reads server-written entitlement state before allowing places above four;
- billing reconciliation projects the verified paid member limit back onto the Household;
- if entitlement falls back to four, existing over-cap members are not silently deleted, but no further member can be added until capacity is restored.

## Google Play catalog direction

Personal and Duo each use one permanent subscription product with monthly and annual base plans because the entitlement is the same and only billing cadence changes.

Household member counts change the entitlement itself, so each supported Household capacity is a separate subscription product, each with monthly and annual base plans. This allows normal Google Play subscription replacement when moving between 4, 5, 6, ... 10 members.

Permanent IDs to create:

- `homi_plus_personal`
  - `monthly`
  - `annual`
- `homi_plus_duo`
  - `monthly`
  - `annual`
- `homi_plus_household_4` through `homi_plus_household_10`
  - `monthly`
  - `annual`

The source catalogs remain deliberately blank until those exact Play products exist. Purchases fail closed before that provider setup.

Same-subscription monthly/annual changes use the Play Console base-plan replacement rule. Cross-product plan/Household-capacity upgrades request an immediate prorated charge; cross-product downgrades use time-proration so the new entitlement is immediate while remaining value is carried into the next billing date. Every transition must still be proven with license testers before public sale.

## Lifecycle and security

The existing 0.13 billing architecture still applies:

- Firebase Auth + App Check verification boundary;
- Android Publisher authoritative verification;
- opaque Homi account association rather than raw UID;
- server acknowledgement of verified pending-ack purchases;
- RTDN as a change signal followed by authoritative re-fetch;
- canonical purchase-token lineage and superseded-token replay protection;
- active/grace/canceled access only through a future verified paid-through time;
- multi-source coverage reduction so one ending source does not erase another valid source;
- Google Play subscription management remains separate from Homi account deletion.

## Current implementation boundary

Pricing, annual catalog shape, three-viewer capability, server-authoritative member-capacity projection and the Homi+ plan UI are now represented in the 0.13 source.

**Paid enforcement is still deliberately OFF.**

Before activation, Homi must still prove the real Play purchase lifecycle and finish/verify the lower-plan trusted-person Shared Task/Routine path. The 0.12 canonical Household Tasks/Routines remain preserved and must not be weakened to fake lower-tier support.

## Release proof still required

1. close the 0.12 governed backend deployment;
2. resolve/lock the 0.13 Flutter billing dependencies on Bruce's real toolchain;
3. compile/analyze/test the final exact 0.13 source;
4. create all permanent Play products/base plans above;
5. populate identical client/backend catalogs;
6. configure Android Publisher API + RTDN;
7. deploy the accepted billing backend;
8. prove monthly/annual purchase, acknowledgement, restore/reinstall, cancellation, grace, hold, expiry and RTDN;
9. prove cross-tier and Household-capacity replacements;
10. prove Duo/Household coverage and lower-plan Shared Task/Routine behavior;
11. activate paid enforcement only after that evidence is green.
