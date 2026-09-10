# Homi account and data deletion

Date: 2026-09-10
Status: implementation/release specification
Current source: `0.9.0+11`

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
8. clears that account's user-scoped Home/Work arrival-check-in settings from the current phone, including coordinates, radii, selected recipients and local last-send timestamps.

For email/password accounts, the current password is used only for Firebase reauthentication and is never stored.

For Google accounts, the Google account confirmation flow is used again before deletion.

If cloud cleanup fails, Homi does not intentionally delete the Firebase Authentication identity and pretend cleanup succeeded. The user remains able to retry.

## Cloud records included in the deletion pipeline

The protected Homi account-deletion backend covers active cloud/account-linked schema including:

- `users/{uid}`;
- `users/{uid}/devices/*`, including FCM push registration and notification preferences;
- the user's `homiCodes/{code}` record;
- trusted `connections` where the user is either participant;
- private `peoplePreferences` records/references;
- outgoing and incoming location-share authorization involving the account;
- `locations/{uid}` latest location/battery state;
- shared Tasks created by the deleting account;
- references to the deleting account inside another person's shared Task, which are detached/anonymised rather than deleting the other person's Task;
- server-only anti-spam/rate-limit records belonging to the UID where covered by the deletion backend/trigger;
- developer-admin/campaign metadata associated with the deleting UID where applicable.

The `onHomiUserDocumentDeleted` server backstop removes server-only metadata deliberately inaccessible to mobile clients.

Home/Work arrival-place coordinates are **not** stored in Firestore in the current architecture. They are local user-scoped preferences and are cleared on successful in-app account deletion.

Whenever a new cloud collection containing account-linked data is added, the deletion pipeline and this document must be updated in the same development pass.

## Local data deletion without account deletion

A separate action exists:

**Profile avatar → Homi & account → Your data → Erase data from this phone**

This clears local household records and Homi cached location from that phone without deleting the cloud account. The local-data inventory must include Home/Work arrival-check-in data before public release so an erase action does not leave locally saved sensitive place coordinates behind.

Signing out does not silently delete local household records. It removes the signed-in user's push token from that device record. Arrival check-in settings are user-scoped locally; background arrival monitoring must not continue for a signed-out account.

General Homi product/service topic subscriptions are installation preferences and are managed separately by Notifications settings.

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
- provide a working request mechanism;
- explain subscription cancellation separately once Homi+ billing exists.

## Subscription interaction

Deleting a Homi account and cancelling a Google Play subscription are separate actions. Once Homi+ is monetised, the deletion UI must surface active subscription state, explain the real cancellation relationship and provide a clear Play subscription-management route.

Privacy, stop-sharing, arrival-check-in disable and deletion controls must never be paywalled.

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
- arrival check-ins enabled during deletion;
- locally saved Home and Work check-in data removed after successful deletion;
- background arrival monitoring stopped after deletion;
- notifications enabled with an active FCM device record;
- account that has sent/received People hearts and arrival check-ins;
- developer-admin test account and notification campaign cleanup;
- app restarted after deletion;
- external web deletion request process.
