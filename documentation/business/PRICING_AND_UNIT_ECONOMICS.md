# Homi pricing and unit economics

Date: 2026-09-26
Status: approved launch commercial model; Google Play products/provider proof and paid enforcement are still pending.

`documentation/MONETIZATION.md` is the engineering entitlement source of truth. This document records the matching commercial model and cost guardrails.

## Approved South African launch pricing

| Plan | Monthly | Annual | Included covered people |
| --- | ---: | ---: | ---: |
| Homi Free | R0 | R0 | 0 paid sender seats |
| Homi+ Personal | R79.99 | R799.99 | 1 |
| Homi+ Duo | R129.99 | R1,299.99 | 2 |
| Homi+ Household | R199.99 | R1,999.99 | 4 |

Every annual plan is priced at roughly ten monthly payments for twelve months of access.

Household supports additional members above four at **R50/month or R500/year per person**, up to the launch technical cap of ten members.

Examples:
- 5 people: R249.99/month or R2,499.99/year;
- 6 people: R299.99/month or R2,999.99/year;
- 10 people: R499.99/month or R4,999.99/year.

## Product ladder

### Free

Useful local-first Homi plus receiving collaboration. Free users can receive another person's live location and may receive/participate in paid-originated shared collaboration without needing to subscribe simply to respond.

### Personal

One covered Homi+ person. The paid value is continuous location sending to up to three viewers plus originating trusted-person Shared Tasks/Routines.

### Duo

Two covered Homi+ people under one payer, each with up to three viewers and creator capability for Shared Tasks/Routines. The two people do not need to share a physical home.

### Household

The flagship home product. Four people are included, scalable to ten. It combines sender entitlement with the canonical Shared Household data plane: shared Tasks, Routines, Supplies, Home records, assignments and supported household state/history.

## Non-negotiable commercial rules

- receiving live location is free;
- maximum three active live viewers per paid sender;
- Shared Task/Routine recipients are not forced to subscribe merely to receive/complete an item;
- Household membership never enables location sharing automatically;
- privacy/revoke/stop-sharing/leave/local erase/account deletion are never paywalled;
- subscription expiry does not destroy local data;
- Homi account deletion does not cancel Google Play billing;
- no client purchase callback is authoritative entitlement.

## Google Play product structure

Permanent products:

- `homi_plus_personal` — monthly + annual;
- `homi_plus_duo` — monthly + annual;
- `homi_plus_household_4` through `homi_plus_household_10` — monthly + annual.

Separate Household capacity products are deliberate because adding a paid Household person changes entitlement, not merely billing cadence.

## Cost guardrails

Continuous location remains latest-state rather than route history. Preserve:

- roughly two-minute / 100 m Android background request behavior;
- 90-second client cloud-write floor;
- 90-second Firestore update floor;
- maximum three live viewers per sender;
- no push generated merely because a coordinate changed;
- no default route history.

The higher commercial pricing creates healthier room for Play fees, Firebase/Functions/Firestore/Maps/Places use, support and future operational overhead than the previous R19.99/R34.99/R49.99 model.

Before public production:
- configure Google Cloud budget/alerts for `homi-ee80a`;
- keep Functions runtime/instance limits bounded;
- measure actual location fan-out and Household sync cost from Internal Testing;
- track conversion/retention before introducing additional plan complexity.
