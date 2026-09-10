# Homi account and data deletion

Date: 2026-09-10
Status: implementation/release specification

## In-app deletion

The discoverable in-app path is:

**Profile avatar → Homi & account → Your data → Delete Homi account**

The flow:

1. explains that deletion is permanent;
2. requires an additional final confirmation;
3. reauthenticates the current user because Firebase requires recent authentication for destructive identity actions;
4. removes the current device push registration;
5. deletes Homi-managed cloud data associated with the account;
6. deletes the Firebase Authentication account;
7. erases Homi household data and cached Homi location from the current phone.

For email/password accounts, the current password is used only for Firebase reauthentication and is never stored.

For Google accounts, the Google account confirmation flow is used again before deletion.

If cloud cleanup fails, Homi does not intentionally delete the Firebase Authentication identity and pretend cleanup succeeded. The user remains able to retry.

## Cloud records included in the deletion pipeline

Current `AccountDataService` covers client-visible active cloud schema:

- `users/{uid}`;
- `users/{uid}/devices/*`, including FCM push registration and notification preferences;
- the user's `homiCodes/{code}` record;
- trusted `connections` where the user is either participant;
- the user's private `peoplePreferences` records;
- another participant's private preference whose subject is the deleting account (delete-only permission; no read/edit permission);
- outgoing location-share authorizations;
- incoming location-share authorization records where the deleting account is the viewer (delete-only permission);
- `locations/{uid}` latest location/battery state;
- shared Tasks created by the deleting account;
- references to the deleting account inside another person's shared Task are detached/anonymised rather than deleting the other person's task.

When `users/{uid}` is deleted, the server-side `onHomiUserDocumentDeleted` Cloud Function additionally removes notification metadata that is deliberately inaccessible to clients:

- heart anti-spam/cooldown documents where the deleted UID is sender or recipient;
- `developerAdmins/{uid}` if the deleted account had developer access;
- developer notification campaign records created by that UID.

FCM topic membership belongs to an app installation/token rather than a Firestore account record. The Homi client synchronises update/service/security topic membership from the installation's notification preferences. Removing/reinstalling the app invalidates or replaces the FCM registration token; invalid direct-delivery tokens are also disabled when detected by the Homi notification backend.

Whenever a new cloud collection containing account-linked data is added, the deletion pipeline and this document must be updated in the same development pass.

## Local data deletion without account deletion

A separate action exists:

**Profile avatar → Homi & account → Your data → Erase data from this phone**

This clears local household records and Homi's cached location from that phone without deleting the cloud account. It is intentionally separate from Sign out.

Signing out does not silently delete local household records. It does remove the signed-in user's push token from that device record so the signed-out installation no longer receives direct account-specific Homi pushes for that user. User-enabled general Homi product/service topic subscriptions are installation preferences and are managed separately by the Notifications settings.

## External web deletion requirement

Google Play requires an external web resource as well as the in-app route when an app supports account creation.

Official reference:
https://support.google.com/googleplay/android-developer/answer/13327111

Before production release, publish a stable public Homi account-deletion page. Recommended URL direction:

`https://theconceptlab.co.za/homi/delete-account`

Do not enter that URL into Play Console until the real page exists and works.

The page must:

- clearly mention Homi and Concept Lab as shown in the store listing;
- make the deletion-request path prominent;
- work for somebody who no longer has the app installed;
- not force the person to reinstall the app;
- explain identity verification needed to prevent malicious deletion requests;
- explain what data is deleted;
- explain any legitimately retained data and retention period, if applicable;
- provide a working request mechanism (authenticated web flow, deletion form or support process);
- explain subscription cancellation separately once Homi+ billing exists.

## Subscription interaction

Deleting a Homi account and cancelling a Google Play subscription are separate actions. Once Homi+ is monetised, the deletion UI must:

- surface active subscription state;
- explain whether deleting the account cancels the subscription (do not assume it does);
- provide a clear Play subscription-management route;
- prevent an active paid entitlement from becoming an invisible recurring charge after account deletion.

This must be completed before monetised production release.

## Release tests

Test at minimum:

- email/password account with correct password;
- email/password account with wrong password;
- Google account successful reauthentication;
- Google reauthentication cancellation;
- transient network failure during cleanup;
- user with no trusted connections;
- user with accepted/pending connections;
- user who created shared Tasks;
- user who is only assignee/viewer of another person's shared Task;
- current live location active during deletion;
- notifications enabled with an active FCM device record;
- account that has sent/received People hearts;
- developer-admin test account and notification campaign cleanup;
- app restarted after deletion;
- external web deletion request process.
