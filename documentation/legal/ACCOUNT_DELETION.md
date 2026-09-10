# Homi account and data deletion

Date: 2026-09-11
Status: implementation/release specification
Current source: `0.9.2+13`

## In-app deletion

The discoverable in-app path is:

**Profile avatar → Homi & account → Your data → Delete Homi account**

The flow:

1. explains that deletion is permanent;
2. requires an additional final confirmation;
3. reauthenticates the current user because Firebase requires recent authentication for destructive identity actions;
4. removes the current device push registration;
5. deletes Homi-managed cloud data associated with the account through the protected backend;
6. deletes the Firebase Authentication account;
7. erases Homi household data and cached Homi location from the current phone;
8. clears that account's local Home/Work arrival settings, including coordinates, readable addresses, optional Google Place IDs, radii, recipients, exact-place sharing preferences and cooldown timestamps.

For email/password accounts, the current password is used only for Firebase reauthentication and is never stored. Google accounts use the Google confirmation flow again before deletion.

If cloud cleanup fails, Homi does not intentionally delete the Firebase Authentication identity and pretend cleanup succeeded. The user remains able to retry.

## Cloud records included in deletion

The protected deletion pipeline/backstops cover active account-linked schema including:

- `users/{uid}`;
- `users/{uid}/devices/*`;
- the user's `homiCodes/{code}`;
- trusted `connections` involving the user;
- private `peoplePreferences` references;
- outgoing/incoming `locationShares` references;
- `locations/{uid}` latest state;
- shared Tasks created by the user;
- the deleting user detached/anonymised from another person's shared Task where appropriate;
- server-only cooldown/rate-limit metadata where covered;
- developer-admin/campaign metadata where applicable;
- owned optional `sharedPlaces/{uid}/places/home|work` precise saved-place documents.

`onHomiUserSharedPlacesDeleted` is the 0.9.2 cleanup backstop that deletes owned Home/Work shared-place documents when the user's Homi user document is deleted.

When the deleting account appears only as a viewer of another person's shared Home/Work, connection deletion triggers `onTrustedConnectionDeleted`, which strips the UID from the other owner's saved-place viewer list. Firestore rules also require the connection and active owner→viewer location share, so stale viewer data alone cannot authorize access.

Whenever a new cloud collection containing account-linked data is added, the deletion pipeline and this document must be updated in the same development pass.

## Local data deletion without account deletion

A separate action exists:

**Profile avatar → Homi & account → Your data → Erase data from this phone**

This clears local household records and cached Homi location from that phone without deleting the cloud account. In 0.9.2, the location-data reset also removes the signed-in user's local Home/Work arrival configuration and stops local background arrival requirements.

Because 0.9.2 can optionally cloud-share an exact Home/Work place, local erase also attempts to clear the user's owned `sharedPlaces` Home/Work documents while the signed-in cloud session is available. If temporary connectivity prevents immediate cloud revocation, Homi keeps only a local non-sensitive pending-clear marker and retries on the next signed-in arrival-service load. Independent Firestore rules continue to require an accepted connection and active location share for any remote read.

Android location permission itself is not silently changed by local erase.

Signing out does not silently delete local household records. It removes the signed-in user's push token from that device record. Arrival settings remain user-scoped locally, but background arrival monitoring does not continue for a signed-out account.

General Homi product/service topic subscriptions are installation preferences managed separately in Notifications.

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

Privacy, current-location revoke, exact Home/Work revoke, arrival-check-in disable and deletion controls must never be paywalled.

## Release tests

Test at minimum:

- email/password correct/wrong reauthentication;
- Google successful/cancelled reauthentication;
- transient network failure during cleanup;
- account with no connections and account with accepted/pending connections;
- creator/viewer/assignee of shared Tasks;
- live location active during deletion;
- arrival check-ins active during deletion;
- Home and Work stored locally and optionally cloud-shared;
- successful deletion removes owned `sharedPlaces` Home/Work;
- deleting/disconnecting a viewer removes their stale viewer grant from another owner's shared place;
- **Erase data from this phone** removes local Home/Work and clears/retries owned cloud exact-place copies without deleting the account;
- background arrival monitoring stops after local erase/account deletion;
- notifications with active FCM device record;
- account that has sent/received People hearts and arrival check-ins;
- developer-admin/campaign cleanup where applicable;
- app restart after deletion;
- external web deletion request process.
