# Homi privacy, legal and launch compliance draft

Date: 2026-09-11
Status: internal working product/legal draft for source `0.9.2+13`. Obtain professional South African legal review before public production release.

## Product position

Homi is a household operating system with optional trusted-person location sharing, user-configured arrival check-ins and separately optional exact Home/Work sharing. The app remains local-first where practical and does not require an account for local-only household use or emergency-number shortcuts.

Homi must not be presented as an emergency dispatch service, covert tracker, proof that somebody is safe, crash detection, medical/child-safety guarantee or guaranteed check-in delivery system.

Initial account eligibility should remain adults (18+) until any minor-specific use case has undergone separate privacy/consent/Google Play Families/legal review.

## South African privacy baseline

Homi is developed in South Africa and must be assessed against the Protection of Personal Information Act 4 of 2013 (POPIA), including appropriate reasonable technical and organisational safeguards.

Official source: https://www.justice.gov.za/legislation/acts/2013-004.pdf

Before launch, the final notice must identify the legally correct responsible party/operator details, required contact details, information-officer process and data-subject request channel. Do not guess those particulars in code.

## Local/device data

Local-first records can include:

- home name/type;
- Tasks, Routines and completion attribution;
- Supplies and expiry/status/quantity;
- Home Things, maintenance/repair and utility readings;
- cached current-device location/battery;
- live/background location preference state;
- Home/Work arrival coordinates, readable address, optional Google Place ID, radius, selected arrival recipients, exact-place sharing preference and local cooldown timestamp;
- notification preferences/schedules;
- installation identifier used for push registration.

Most household records are SharedPreferences/local-first rather than a full cloud backup unless the relevant product surface explicitly identifies sharing.

## Google Places processing

For Home/Work setup, 0.9.2 uses Google Places API (New) through the native Places SDK wrapper.

Homi sends the user's autocomplete query to Google Places and, after selection, requests only the Place ID, formatted address and coordinate required to save the place. Suggestions are limited to South Africa in the current UI. Google's attribution is displayed with results.

**Set from here** remains a separate route using current device location and reverse geocoding where available.

The Google Places credential is an Android package/SHA-restricted client credential and must not be committed to source or logged. The final privacy notice should accurately describe Google Maps/Places processing and link relevant provider policy where appropriate.

## Cloud/account data

When the user signs in and activates relevant features, Firebase/Google Cloud can process:

- Firebase UID/account/profile metadata;
- Homi connection code;
- trusted connection records;
- private relationship/scope preferences;
- narrowly shared Tasks;
- per-person current-location authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, update time/source;
- FCM device registration and notification preferences;
- developer campaign metadata for authorised developer accounts;
- server rate-limit records;
- optional exact Home/Work cloud copies only when the owner separately enables that per-place control.

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

This is separate from arrival delivery. It is off by default, including after migration from older builds.

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

## Location purpose and consent separation

Homi location exists for consensual trusted-person current-location sharing, explicit arrival check-ins and separately explicit saved-place visibility.

The product keeps these distinct:

1. connecting two Homi accounts;
2. private Household/Friend classification;
3. enabling current-location visibility for an individual;
4. enabling background current-location updates on the tracked device;
5. selecting a person as an arrival recipient for Home/Work;
6. enabling arrival monitoring;
7. separately allowing selected recipients to see the exact saved Home/Work.

A connection or Household label alone never enables any location capability.

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

Homi exposes 112, 10111 and 10177 under Safety & check-ins and places quick emergency access on the full People map.

Tapping a control hands the number to the external phone application. Homi does not silently place the call, request direct-call permission, dispatch responders, automatically transmit location or claim the call was connected/acted upon.

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
- no contact-book collection just to discover Homi users when Homi codes suffice;
- no stored raw passwords;
- no hidden route history;
- no automatic Household conversion merely to enable location/check-ins;
- no privacy, stop-sharing, saved-place revoke or deletion paywall;
- remove/disable dead push tokens;
- developer notifications remain category-controlled, not a marketing backdoor.

## User-facing controls

Homi & account provides Why Homi exists, Notifications, Help, Privacy & your data, Location & safety, Terms, About, Erase data from this phone and Delete Homi account.

People remains map-first and contains connection grouping beneath the map/location experience plus a lower Safety & check-ins entry. The full map keeps quick emergency access in reach.

User-facing wording must remain finished-product copy. Internal documents may identify unverified/release-blocked state.

## Account deletion

Google Play requires an app supporting account creation to provide a discoverable in-app account deletion path and an external web resource for account/data deletion requests.

Official reference: https://support.google.com/googleplay/android-developer/answer/13327111

Homi's account-deletion server flow removes Homi-managed cloud collaboration data and triggers cleanup of owned `sharedPlaces` Home/Work documents. The current device then clears local Homi/arrival data according to the deletion flow.

The external deletion page remains a production blocker and must be real/functional before entering it into Play Console.

## Play Data Safety preparation

Before public release, reconcile the form against the exact build, including:

- precise/background location;
- optional cloud-stored precise Home/Work when explicitly shared;
- Google Places search/selected place processing;
- account/user IDs, email/name/profile photo;
- trusted relationship/arrival-recipient/viewer selections;
- push device identifiers/FCM processing;
- cloud-synced household content actually enabled in release;
- encryption in transit and account deletion;
- optional vs required collection and service-provider sharing.

Do not copy another app's Data Safety answers.

## Production privacy/security checklist

Before production:

- App Check valid traffic confirmed and production enforcement deliberately staged;
- release signing/Play signing SHA credentials registered;
- Firestore allow/deny rules proven including sharedPlaces;
- protected Functions tested with valid/invalid users and App Check;
- exact Home/Work grant/revoke/location-share-off/disconnect/account-delete behaviour verified;
- Home/Work absent from arrival notification payload/logs;
- external deletion page published;
- stable Privacy Policy/Terms URLs published;
- background-location disclosure and Play declaration reviewed;
- Data Safety completed from actual release build;
- cloud billing/monitoring configured;
- final POPIA/privacy documents professionally reviewed.
