# Homi privacy, legal and launch compliance draft

Date: 2026-09-11
Status: internal working product/legal draft for source `0.12.0+16`. Obtain professional South African legal review before public production release.

## Product position

Homi is a household operating system with optional shared-Household collaboration, trusted-person location sharing, user-configured arrival check-ins and separately optional exact Home/Work sharing. The app remains local-first where practical and does not require an account for local-only household use or emergency-number shortcuts.

Homi must not be presented as an emergency dispatch service, covert tracker, proof that somebody is safe, crash detection, medical/child-safety guarantee or guaranteed check-in delivery system.

Initial account eligibility should remain adults (18+) until any minor-specific use case has undergone separate privacy/consent/Google Play Families/legal review.

## South African privacy baseline

Homi is developed in South Africa and must be assessed against the Protection of Personal Information Act 4 of 2013 (POPIA), including appropriate reasonable technical and organisational safeguards.

Official source: https://www.justice.gov.za/legislation/acts/2013-004.pdf

Before launch, the final notice must identify the legally correct responsible party/operator details, required contact details, information-officer process and data-subject request channel. Do not guess those particulars in code.

## Local/device data

Local records can include:

- home name/type;
- private and shared-view Tasks plus completion attribution;
- Routines and bounded completion attribution;
- Supplies and expiry/status/quantity;
- Home Things, maintenance/repair and utility readings;
- cached current-device location/battery;
- live/background location preference state;
- Home/Work arrival coordinates, readable address, optional Google Place ID, radius, selected arrival recipients, exact-place sharing preference and local cooldown timestamp;
- notification preferences/schedules;
- installation identifier used for push registration;
- local synchronization lineage identifying which Household record IDs have previously been synchronized on that phone.

SharedPreferences remains Homi's immediate local-first persistence layer. From 0.12, a signed-in member of a canonical Shared Household can additionally synchronize selected Household domains to Firestore. Local-only mode does not start this Household synchronizer even if Firebase still has a cached signed-in identity.

Pre-existing local records are not silently uploaded merely because an account joins a Household. The narrow automatic first-import case is restricted to the owner on a device that has never synchronized another Household when an authoritative server read confirms the Household data collection is empty. Otherwise older unmatched records stay device-private until a future explicit import/merge choice.

## Google Places processing

For Home/Work setup, Homi uses Google Places API (New) through the native Places SDK wrapper.

Homi sends the user's autocomplete query to Google Places and, after selection, requests only the Place ID, formatted address and coordinate required to save the place. Google's attribution is displayed with results.

**Set from here** remains a separate route using current device location and reverse geocoding where available.

The Google Places credential is an Android package/SHA-restricted client credential and must not be committed to source or logged. The final privacy notice should accurately describe Google Maps/Places processing and link relevant provider policy where appropriate.

## Cloud/account data

When the user signs in and activates relevant features, Firebase/Google Cloud can process:

- Firebase UID/account/profile metadata;
- reusable Homi connection code;
- trusted connection records;
- private relationship-label preferences;
- canonical Household identity, membership, ownership and invitations;
- canonical Household Routines, Supplies, Home Things, maintenance/repair events and utility readings when Household sync is active;
- narrowly shared one-off Tasks and their assignment/completion attribution;
- per-person current-location authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, update time/source;
- FCM device registration and notification preferences;
- developer campaign metadata for authorised developer accounts;
- server rate-limit records;
- optional exact Home/Work cloud copies only when the owner separately enables that per-place control.

The canonical Household shared-data path is:

`households/{householdId}/data/{domain--itemId}`

Each record contains a versioned outer envelope plus the domain payload and server update metadata. Access requires the caller to remain a current member of that exact Household through both the membership pointer and parent Household member list.

For an arrival notification, `sendArrivalCheckIn` receives only `home`/`work` plus selected trusted recipient UIDs. It does **not** receive the saved address/coordinate.

### Optional exact Home/Work cloud copy

If the owner enables **Show this place to selected people**, Homi stores a minimal document at:

`sharedPlaces/{ownerUid}/places/{home|work}`

containing:

- owner UID;
- Home/Work kind;
- precise latitude/longitude;
- readable address;
- explicitly selected viewer UIDs;
- server update timestamp.

This is separate from arrival delivery and separate from Shared Household data sync. It is off by default, including after migration from older builds.

A viewer can read the document only if they are explicitly listed, the Homi connection remains accepted and the owner currently has location sharing active to that viewer. Direct client mutation is denied; a protected callable validates/grants/revokes the server copy.

Turning the per-place sharing switch off removes the cloud copy. Disconnect cleanup strips stale viewers. Account deletion removes owned shared-place copies. Local erase attempts to revoke owned copies and retains only a non-sensitive pending-clear marker if temporary connectivity prevents immediate cloud cleanup.

## Third-party processors/platforms

Current technical providers include:

- Google Firebase / Google Cloud for Auth, Firestore, Cloud Functions and FCM;
- Google Maps Platform including Maps SDK for Android and Places API (New);
- Android/device location/geocoding services;
- the user's telephone/network provider for emergency phone calls opened by Homi;
- Google Play for Android distribution and later paid Android digital products if Homi+ launches.

Final privacy/Data Safety disclosures must match the exact release SDKs and actual feature configuration.

## Household membership and consent separation

The product keeps these distinct:

1. connecting two Homi accounts;
2. editing a private relationship label such as Partner/Friend/Roommate;
3. creating/joining the canonical Shared Household through a separate invitation/acceptance flow;
4. synchronizing supported Household records while current canonical membership exists;
5. enabling current-location visibility for an individual;
6. enabling background current-location updates on the tracked device;
7. selecting a person as an arrival recipient for Home/Work;
8. enabling arrival monitoring;
9. separately allowing selected recipients to see the exact saved Home/Work.

A connection or relationship label never grants Household data access. Household membership never enables any location capability by itself. From 0.12, the old Household/Friend People scope is displayed from canonical membership rather than being a user-editable authorization control.

## Household synchronization and retention

Routines, Supplies and supported Home records remain locally persisted even while cloud-synchronized. This supports Homi's local-first/offline behavior.

Different record IDs merge. If two synchronized clients update the same record, the last server-acknowledged Firestore write becomes the shared value and listening devices persist that value locally.

Removing a person from a Household or leaving it revokes future cloud access but does not remotely erase the copy of records already stored on that person's device. This limitation must be accurately disclosed because a system cannot reliably revoke data already delivered to another endpoint. Sensitive information should therefore not be placed in shared household records under an assumption of retroactive device erasure.

Deleting a canonical Household deletes the shared Household identity and triggers bounded cleanup of its nested synchronized data plus newer shared Tasks carrying that Household ID. Individual devices may still retain previously synchronized local copies until the user erases/reinstalls/overwrites them through normal device controls.

## Arrival check-in data minimisation

The arrival detector runs locally against the device location and locally saved Home/Work boundary.

- initial inside/outside state primes without sending;
- only outside→inside produces an arrival;
- hysteresis/cooldown reduces edge duplicates;
- the arrival callable/push contains no saved precise coordinate/address;
- no route history is created;
- selected arrival recipients are revalidated as accepted connections server-side.

Arrival recipients need not receive exact Home/Work visibility; that requires the separate switch described above.

## Background location disclosure

Before production background permission, clearly explain:

- why background access is needed for user-selected Live updates/check-ins;
- who may see location or receive arrivals;
- that Android shows a persistent foreground-service notification;
- how to stop Live updates/check-ins and revoke a person;
- how exact Home/Work sharing is separately controlled;
- that device/network/power conditions can delay/invalidate location;
- that force-stop can interrupt background operation until Homi reopens.

Disclosure must appear contextually before the sensitive permission request, not only in the privacy policy.

## Emergency shortcuts

Emergency-region data is bundled locally and only reviewed/supported regions are offered. Tapping a control hands the selected number to the external phone application. Homi does not silently place the call, request direct-call permission, dispatch responders, automatically transmit location or claim the call was connected/acted upon.

## Location retention

Default location architecture is latest state, not long-term route history.

The owner's full Home/Work check-in configuration remains local. Only the explicitly shared minimal precise-place copy described above can be stored in Firestore, and only while that owner sharing choice remains enabled. The arrival backend still does not receive the precise place merely to deliver a check-in.

Any future breadcrumb/history feature requires a defined purpose, bounded retention, explicit user control, deletion coverage and refreshed Play/privacy disclosures before release.

## Notifications

Fresh-install operational categories remain enabled by default in Homi preferences:

- Household attention;
- Tasks & routines;
- People;
- Service & security.

Homi Updates/product announcements remain off by default. Android retains actual notification-permission control and existing persisted user choices remain authoritative.

Arrival notifications may show sender name and Home/Work label because those are the chosen event details, but must not include precise addresses/coordinates on the lock screen.

The foreground-service notification used for active background location is operational platform disclosure and separate from optional notification categories.

## Data minimisation principles

- no precise coordinates/addresses/household notes/Task text in analytics/general logs;
- no saved Home/Work coordinate/address in `sendArrivalCheckIn` merely to generate a message;
- no contact-book collection just to discover Homi users when reusable Homi codes suffice;
- no stored raw passwords;
- no hidden route history;
- no automatic Household conversion merely to enable location/check-ins;
- no upload of unmatched pre-existing local Household records solely because a user joined a different Household;
- no privacy, stop-sharing, saved-place revoke or deletion paywall;
- remove/disable dead push tokens;
- developer notifications remain category-controlled, not a marketing backdoor.

## User-facing controls

Homi & account provides Why Homi exists, Household, Notifications, Help, Privacy & your data, Location & safety, Terms, About, Erase data from this phone and Delete Homi account.

People remains map-first. Connections expose **My code** and **Connect** separately. Relationship labels remain editable, while Household membership is managed only through Shared Household. The full map keeps quick emergency access in reach.

User-facing wording must remain finished-product copy. Internal documents may identify unverified/release-blocked state.

## Account deletion

Google Play requires an app supporting account creation to provide a discoverable in-app account deletion path and an external web resource for account/data deletion requests.

Official reference: https://support.google.com/googleplay/android-developer/answer/13327111

Homi's protected deletion server flow removes account-linked collaboration state and then the Firebase Authentication account after successful cleanup. Canonical Household handling depends on the deleting user's role:

- a non-owner is removed from the Household while the Household and shared Household data remain for current members;
- an owner with another current member transfers ownership according to the governed deletion flow rather than deleting everybody else's Household;
- an owner with no remaining member may cause the empty Household parent to be deleted, which triggers cleanup of its shared data.

The current phone then clears local Homi/arrival data according to the deletion flow. Previously synchronized copies on other members' devices cannot be guaranteed to be remotely erased.

The external deletion page remains a production blocker and must be real/functional before entering it into Play Console.

## Local erase semantics with shared data

**Erase data from this phone** is not the same as deleting the Shared Household from the cloud. It clears device-local/private records and cached location. If the user remains signed in to an active Shared Household, cloud-authoritative shared records may synchronize to the phone again. The final user-facing copy must make this distinction explicit rather than promising permanent deletion of cloud-shared records from one device.

## Play Data Safety preparation

Before public release, reconcile the form against the exact build, including:

- precise/background location;
- optional cloud-stored precise Home/Work when explicitly shared;
- Google Places search/selected place processing;
- account/user IDs, email/name/profile photo;
- trusted relationships and canonical Household membership/invites;
- arrival-recipient/viewer selections;
- push device identifiers/FCM processing;
- cloud-synchronized Household Routines, Supplies, Home Things, maintenance/repair and utility data;
- shared Task text/assignment/completion attribution;
- encryption in transit and account deletion;
- optional vs required collection and service-provider sharing.

Do not copy another app's Data Safety answers.

## Production privacy/security checklist

Before production:

- App Check valid traffic confirmed and production enforcement deliberately staged;
- Firestore App Check enforcement staged only after valid release-client traffic is visible;
- release signing/Play signing SHA credentials registered;
- Firestore allow/deny rules proven including canonical Household data and sharedPlaces;
- protected Functions tested with valid/invalid users and App Check;
- exact Home/Work grant/revoke/location-share-off/disconnect/account-delete behaviour verified;
- Shared Household join/remove/leave/delete/account-delete retention behavior verified;
- first-owner Household migration and non-owner/private-legacy non-upload behavior verified;
- Home/Work absent from arrival notification payload/logs;
- external deletion page published;
- stable Privacy Policy/Terms URLs published;
- background-location disclosure and Play declaration reviewed;
- Data Safety completed from actual release build;
- cloud billing/monitoring configured;
- final POPIA/privacy documents professionally reviewed.
