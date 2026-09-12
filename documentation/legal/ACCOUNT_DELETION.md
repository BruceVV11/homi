# Homi account and data deletion

Date: 2026-09-11
Status: implementation/release specification
Current source candidate: `0.12.0+16`

## In-app deletion

The discoverable in-app path is:

**Profile avatar → Homi & account → Your data → Delete Homi account**

The flow:

1. explains that deletion is permanent;
2. requires an additional final confirmation;
3. reauthenticates the current user because Firebase requires recent authentication for destructive identity actions;
4. removes the current device push registration;
5. deletes/detaches Homi-managed account-linked cloud data through the protected backend;
6. reconciles canonical Household membership/ownership without deleting another current member's Household merely because one account leaves;
7. deletes the Firebase Authentication account;
8. erases Homi household data and cached Homi location from the current phone;
9. clears that account's local Home/Work arrival settings, including coordinates, readable addresses, optional Google Place IDs, radii, recipients, exact-place sharing preferences and cooldown timestamps.

For email/password accounts, the current password is used only for Firebase reauthentication and is never stored. Google accounts use the Google confirmation flow again before deletion.

If cloud cleanup fails, Homi does not intentionally delete the Firebase Authentication identity and pretend cleanup succeeded. The user remains able to retry.

## Canonical Household behavior during deletion

Shared Household data belongs to the canonical Household rather than exclusively to the account that happened to create an individual record.

Account deletion must therefore preserve other current members' access:

- deleting a non-owner removes that user's membership and leaves the Household/shared Household data intact for remaining members;
- deleting an owner with another current member transfers/reconciles ownership according to the governed Household deletion path rather than deleting everybody else's shared home;
- deleting the sole remaining Household owner can delete the parent Household, which then activates the bounded `onHomiHouseholdDeletedDataCleanup` trigger for nested synchronized Household data and newer shared Tasks carrying that Household ID.

Previously synchronized local copies on another member's device cannot be guaranteed to be remotely erased. Homi must not claim retroactive erasure from third-party endpoints that already received shared content.

## Cloud records included in deletion

The protected deletion pipeline/backstops cover active account-linked schema including:

- `users/{uid}`;
- `users/{uid}/devices/*`;
- the user's `homiCodes/{code}`;
- trusted `connections` involving the user;
- private `peoplePreferences` references;
- outgoing/incoming `locationShares` references;
- `locations/{uid}` latest state;
- shared Tasks created by the user where deletion is appropriate;
- the deleting user detached/anonymised from another person's shared Task where appropriate;
- canonical `householdMemberships/{uid}` and `households/{householdId}/members/{uid}` state through the Household cleanup path;
- Household ownership/invite state where the deleting user is owner/inviter;
- nested `households/{householdId}/data/*` only when the canonical Household itself is legitimately deleted, not merely because one member deletes their account;
- server-only cooldown/rate-limit metadata where covered;
- developer-admin/campaign metadata where applicable;
- owned optional `sharedPlaces/{uid}/places/home|work` precise saved-place documents.

`onHomiUserSharedPlacesDeleted` remains the saved-place cleanup backstop that deletes owned Home/Work shared-place documents when the user's Homi user document is deleted.

When the deleting account appears only as a viewer of another person's shared Home/Work, connection deletion triggers `onTrustedConnectionDeleted`, which strips the UID from the other owner's saved-place viewer list. Firestore rules also require the connection and active owner→viewer location share, so stale viewer data alone cannot authorize access.

Whenever a new cloud collection containing account-linked data is added, the deletion pipeline and this document must be updated in the same development pass.

## Local data deletion without account deletion

A separate action exists:

**Profile avatar → Homi & account → Your data → Erase data from this phone**

This clears local household records and cached Homi location from that phone without deleting the cloud account or the canonical Shared Household.

The location-data reset also removes the signed-in user's local Home/Work arrival configuration and stops local background arrival requirements. If exact Home/Work cloud copies are owned by that user, local erase attempts to clear those copies while a signed-in cloud session is available; a temporary failure retains only a non-sensitive pending-clear marker for retry.

### Important 0.12 shared-data behavior

Routines, Supplies and supported Home records may now also exist as canonical Shared Household cloud data. Erasing one phone does **not** delete those Household records for other members.

If the phone remains signed in and continues participating in that Shared Household, cloud-authoritative shared records may synchronize back to it. The user-facing copy must distinguish:

- private/device-only data that is actually being erased from that phone; and
- shared Household records that remain in the Household cloud state.

A future dedicated **leave Household / remove shared data from this device** flow may combine membership changes with local cleanup, but Homi must not silently leave a Household merely because the user taps local erase.

Android location permission itself is not silently changed by local erase.

Signing out does not silently delete local household records. It removes the signed-in user's push token from that device record. Arrival settings remain user-scoped locally, but background arrival monitoring does not continue for a signed-out account.

General Homi product/service topic subscriptions are installation preferences managed separately in Notifications.

## Shared Household deletion

Deleting the canonical Household is a separate owner-controlled action from deleting an account or erasing one phone.

Because Firestore does not recursively delete subcollections with the parent document, 0.12 adds `onHomiHouseholdDeletedDataCleanup`. When the parent Household is legitimately deleted, the trigger removes nested `data` documents in bounded batches and removes newer shared Tasks carrying that Household ID.

The local copy already stored on a device is not remotely guaranteed to disappear merely because cloud membership/data is deleted. Device-local erase remains a separate control.

## External web deletion requirement

Google Play requires an external web resource as well as the in-app route when an app supports account creation.

Official reference:
https://support.google.com/googleplay/android-developer/answer/13327111

Before production release, publish a stable public Homi account-deletion page. Recommended URL direction:

`https://theconceptlab.co.za/homi/delete-account`

Do not enter that URL into Play Console until the real page exists and works.

The page must clearly identify Homi/Concept Lab, expose the deletion-request path, work without reinstalling the app, protect against malicious deletion requests through appropriate identity verification, explain deleted/retained data, provide a working request mechanism and explain subscription cancellation separately once Homi+ billing exists.

## Subscription interaction

Deleting a Homi account and cancelling a Google Play subscription are separate actions. Once Homi+ is monetised, deletion UI must surface actual subscription state and a clear Play subscription-management route.

Privacy, current-location revoke, exact Home/Work revoke, arrival-check-in disable, Household leave/removal and deletion controls must never be paywalled.

## Release tests

Test at minimum:

- email/password correct/wrong reauthentication;
- Google successful/cancelled reauthentication;
- transient network failure during cleanup;
- account with no connections and account with accepted/pending connections;
- sole canonical Household owner deletion;
- owner-with-member deletion/ownership transfer;
- non-owner Household member deletion;
- canonical Household containing Routines/Supplies/Home data;
- creator/viewer/assignee of shared Tasks;
- live location active during deletion;
- arrival check-ins active during deletion;
- Home and Work stored locally and optionally cloud-shared;
- successful deletion removes owned `sharedPlaces` Home/Work;
- deleting/disconnecting a viewer removes their stale viewer grant from another owner's shared place;
- deleting the sole Household causes bounded nested shared-data cleanup;
- deleting one member does not incorrectly delete remaining members' shared Household data;
- **Erase data from this phone** removes local/private records and cached location without deleting the Shared Household;
- shared Household records can rehydrate appropriately while the account remains signed in/member after a device-local erase;
- background arrival monitoring stops after local erase/account deletion;
- notifications with active FCM device record;
- account that has sent/received People hearts and arrival check-ins;
- developer-admin/campaign cleanup where applicable;
- app restart after deletion;
- external web deletion request process.
