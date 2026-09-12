# Homi account and data deletion

Date: 2026-09-12
Status: implementation/release specification
Current development candidate: `0.13.0+17`

## In-app deletion

The discoverable in-app path is:

**Profile avatar → Homi & account → Your data → Delete Homi account**

The flow must:

1. explain that deletion is permanent;
2. clearly warn that deleting Homi does **not** cancel a Google Play Homi+ subscription;
3. provide a clear Google Play subscription-management route before final deletion when billing is available;
4. require a final destructive confirmation;
5. reauthenticate the current Firebase user;
6. remove the current push registration and stop local continuous sharing;
7. delete/detach Homi-managed account-linked cloud data through the protected backend;
8. reconcile canonical Household membership/ownership without deleting another current member's Household merely because one account leaves;
9. remove Homi billing account links/coverage/entitlement state without attempting to cancel Play billing on the user's behalf;
10. delete the Firebase Authentication identity;
11. erase Homi household data, cached location and Home/Work arrival state from the current phone.

Email/password reauthentication uses the current password only for Firebase confirmation and never stores it. Google accounts use Google confirmation again.

If Homi cloud cleanup fails, Homi must not intentionally delete the Firebase Authentication identity and pretend the cleanup succeeded. Retrying is expected to be safe/idempotent.

## Subscription interaction

**Homi account deletion and Google Play subscription cancellation are separate operations.**

0.13 introduces Homi-side billing records:

- `billingPurchases/*`
- `billingAccounts/*`
- `billingAccountLinks/*`
- `billingCoverage/*`
- `entitlements/{uid}`

All except the narrow self-readable entitlement projection are backend-only.

`onHomiPlusUserDeleted` is the billing cleanup backstop. It:

- finds **all** historical Homi purchase records still associated with the deleted purchaser, including superseded plan-change tokens rather than only the currently active token;
- removes coverage associated with each of those purchase records;
- removes the raw Play purchase token and Homi purchaser UID from those historical Homi records, clears their recipient list and records `accountDeletedAt` so they cannot silently restore the deleted Homi identity later;
- removes the deleted user as a recipient of another payer's Duo/Household coverage;
- removes the Homi billing account link and self entitlement;
- releases Duo coverage pointing at the deleted Homi account while preserving the payer's reassignment cooldown.

It does **not** call Google Play to cancel the user's subscription. Users must manage/cancel the Play subscription separately in Google Play. Public UI/legal copy must not imply otherwise.

## Canonical Household behavior during deletion

Shared Household data belongs to the canonical Household rather than exclusively to one account.

- deleting a non-owner removes that member while shared Household data remains for current members;
- deleting an owner with another member transfers/reconciles ownership through the governed Household deletion path;
- deleting the sole remaining owner may delete the parent Household and activate bounded `onHomiHouseholdDeletedDataCleanup` for nested synchronized data and canonical newer shared Tasks.

Previously synchronized copies on another device cannot be guaranteed to be remotely erased. Homi must not claim retroactive erasure from endpoints that already received shared content.

Household Homi+ coverage derives from current canonical membership, so a removed/deleted member loses that coverage source. A separate valid Personal/Duo/other coverage source must not be deleted merely because Household coverage disappears.

## Cloud records included in deletion

The protected deletion pipeline/backstops cover account-linked schema including:

- `users/{uid}` and `users/{uid}/devices/*`;
- `homiCodes/{code}`;
- trusted `connections` involving the user;
- private `peoplePreferences` references;
- `locationShares` references;
- latest `locations/{uid}`;
- shared Task creator/assignee/completer state where appropriate;
- canonical Household membership/member/ownership/invite state;
- nested Household shared data only when the Household itself is legitimately deleted;
- optional owned `sharedPlaces/{uid}/places/home|work`;
- server rate/cooldown data where covered;
- Homi billing mapping/coverage/entitlement state described above.

Whenever a new account-linked collection is introduced, both the deletion implementation and this document must be updated in the same development pass.

## Local erase without account deletion

**Profile avatar → Homi & account → Your data → Erase data from this phone** clears local/device state without deleting the cloud account, canonical Household or Google Play subscription.

Because 0.12 can synchronize Household records, one-phone erase does not delete those records for other members. If the phone remains signed in and remains a Household member, cloud-authoritative records may synchronize back later.

The product must distinguish:

- device-private data actually erased from the phone; and
- shared Household records that remain in cloud state.

Android location permission itself is not silently changed by local erase.

## Shared Household deletion

Deleting the canonical Household is separate from deleting one account or one phone.

`onHomiHouseholdDeletedDataCleanup` removes nested Shared Household data and newer canonical shared Tasks after a legitimate parent Household deletion. Device-local copies already delivered may remain until separately erased.

0.13 Homi+ Household coverage follows canonical membership/Household existence. Household deletion removes that coverage source but does not cancel the payer's Google Play subscription automatically; the purchaser must manage the Play subscription separately.

## External web deletion requirement

Homi supports account creation, so a stable external account/data deletion resource remains a production blocker.

Recommended URL direction:

`https://theconceptlab.co.za/homi/delete-account`

Do not submit that URL to Play Console until a real functional page exists.

The page must:

- identify Homi/Concept Lab correctly;
- work without reinstalling the app;
- verify identity before destructive action;
- explain deleted/retained data;
- provide a working request mechanism;
- explain clearly that Google Play subscription cancellation is separate and provide the appropriate Play management guidance.

## Privacy controls are not subscription controls

Payment state must never prevent:

- stop/revoke live location;
- exact Home/Work revoke;
- check-in disable;
- disconnecting a person;
- Household leave where allowed;
- device-local erase;
- Homi account deletion;
- emergency-number shortcuts.

## Release tests

Before production, test at minimum:

- email/password correct/wrong reauthentication;
- Google successful/canceled reauthentication;
- network failure during cleanup;
- account with no connections and accepted/pending connections;
- sole Household owner deletion;
- owner-with-member deletion/transfer;
- non-owner Household deletion;
- shared Household with synchronized data and shared Tasks;
- live location/check-ins active during deletion;
- exact Home/Work shares removed as designed;
- device-local erase versus cloud-shared rehydration;
- notification/device registration cleanup;
- Homi+ purchaser deletion while Play subscription remains active, including multiple historical/superseded Homi+ purchase tokens;
- Homi+ Duo secondary deletion;
- Homi+ Household member deletion;
- user with multiple Homi+ coverage sources;
- Play management/cancellation messaging before account deletion;
- app restart after successful deletion;
- external web deletion request process.
