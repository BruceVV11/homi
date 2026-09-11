# Homi Architecture

Date: 2026-09-11
Current source candidate: **0.10.0+14**

## Permanent identifiers

- Google Cloud / Firebase project: `homi-ee80a`
- Project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Firestore / Functions region: `africa-south1`
- Functions runtime: Node 22
- Runtime service account: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

The deleted project `homi-508000` is not part of Homi and must never be reused.

## Stack

- Flutter / Dart Android application
- Android minimum SDK 24
- SharedPreferences for version-tolerant local-first household records and local feature preferences
- Firebase Authentication for optional identity and protected collaboration
- Cloud Firestore for narrowly scoped shared state
- Firebase Cloud Functions 2nd gen in `africa-south1`
- Firebase Cloud Messaging for remote push delivery
- Firebase App Check: debug provider during development, Play Integrity for release
- Google Maps Flutter + Geolocator for consensual trusted-person location and local arrival detection
- `google_places_sdk_plus` + Places API (New) for Home/Work address selection
- `geocoding` for readable reverse-geocoding when using **Set from here**
- `url_launcher` for external Google Maps and emergency phone-app handoff

## Product shell

Primary destinations remain:

**Overview · Tasks · Home · Supplies · People**

The exact Homi mark remains the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move while swiping between destinations.

People remains the approved **map-first** experience. Relationship editing, live-location controls, connections and Safety & check-ins remain inside that product flow rather than replacing it with a management-first hub.

## Local-first household data

These areas remain local-first unless a specific feature explicitly states otherwise:

- onboarding/home name/type;
- private one-off Tasks;
- recurring Routines;
- Supplies and quantities/status/expiry;
- Home Things, maintenance/repair history and utility readings;
- cached current-device location;
- local notification preferences/schedules;
- local Home/Work arrival configuration, radius, recipients and arrival state.

Model changes must preserve existing data through safe defaults/migrations rather than destructive resets.

## Current cloud collaboration

Homi currently shares only narrowly defined collaboration state:

- `users/{uid}` and device registrations;
- Homi connection codes and accepted connections;
- private relationship/scope preferences;
- specifically shared one-off Tasks;
- owner-to-viewer location-share grants;
- one latest location document per sender;
- optional explicitly shared Home/Work places;
- notification/developer-admin state and server rate limits.

A full shared Household identity and synchronization model is a later paid-product layer. 0.10.0 records the commercial contract but does not falsely claim Routines, Supplies or all Home records are already shared across devices.

## People, location and privacy

Connection, relationship label, current-location sharing, arrival-recipient selection and exact Home/Work visibility remain independent choices.

Live location uses one latest-state document at `locations/{uid}`. Homi does not create route history by default.

The Android background stream is shared by two explicit consumers:

1. **Live updates** — cloud latest-location updates for individually authorized viewers;
2. **Arrival check-ins** — local Home/Work arrival detection.

The stream uses medium accuracy, roughly a 100 m movement threshold and roughly a two-minute Android interval. Check-in-only samples do not update the cloud location document unless Live updates are independently enabled.

0.10.0 adds business/cost boundaries:

- client latest-location cloud writes are held to at least 90 seconds apart;
- Firestore independently rejects repeat latest-location writes inside 90 seconds;
- one sender may authorize at most five simultaneously active live-location viewers;
- removing/stopping a viewer remains available regardless of paid state and cannot be trapped behind the activation limit.

## Arrival check-ins and exact saved places

Home/Work arrival configuration remains local-first. A fresh first location sample establishes inside/outside state and sends nothing. Only outside -> inside triggers an arrival, leaving requires radius + 100 m hysteresis, and a one-hour local cooldown reduces edge repeats.

`sendArrivalCheckIn` receives only Home/Work label and selected recipient UIDs. Saved coordinates/addresses are not included in arrival delivery.

Exact Home/Work visibility is a separate explicit permission. The owner toggles **Show this place to selected people** for each saved place. A different user may read it only when all of these are true:

1. they are explicitly listed for that saved place;
2. the Homi connection remains accepted;
3. the owner currently shares location with that viewer.

Clients cannot directly mutate `sharedPlaces`. Server Functions own the mutation path.

## Homi+ commercial model

The source contract lives in `lib/src/domain/homi_plus_plan.dart` and `documentation/MONETIZATION.md`.

Core rule for the paid system once billing enforcement is enabled:

**Receiving a live location is free. Continuously sending your own live location requires one Homi+ sender seat. One paid sender may share with up to five trusted viewers.**

Approved first plan structure:

- Free: R0, no continuous sender seat after billing enforcement activates;
- Personal: R19.99/month, 1 sender seat;
- Duo: R34.99/month, 2 sender seats under one payer;
- Household: R49.99/month or R499.99/year, up to 4 Household members plus the future fully shared Household product.

Duo members do not need to live together. Household value is the shared household platform, not an arbitrary restriction on who can receive a location.

Plan definitions do **not** grant entitlement yet. Google Play product IDs, purchase-token verification, RTDN/Pub/Sub and authoritative server entitlement state are required before paid enforcement.

Privacy, stop-sharing, check-in disable, exact-place revoke, local erase and account deletion are never paywalled.

## Emergency-region architecture

Emergency numbers are bundled in the application binary. Firebase, mobile data and location permission are not required to display them.

`EmergencyRegionService` stores a user-selected region locally. Device locale can suggest a supported region, but Homi does not silently change emergency numbers from GPS/geocoding.

The same region powers:

- People -> Safety & check-ins emergency cards;
- full-screen People map emergency controls;
- the Home/Work Google Places country bias in 0.10.0.

Regions with one verified universal number can show an SOS shortcut. Regions such as Japan/Brazil that are represented with service-specific numbers do not get an invented universal SOS target.

Emergency actions use external `tel:` handoff only. Homi does not silently place calls, dispatch responders or send the user's location to emergency services.

The catalog is source-controlled and must be release-reviewed against ITU-T E.129 and/or the relevant national public-safety authority for every country enabled in public distribution.

## Authentication and protected mutations

Homi supports email/password and Google sign-in. Sensitive sharing requires Auth + App Check; password-provider sensitive sharing additionally requires verified email.

`HomiCloudActions` is the typed client boundary for protected callable mutations. A stale `unauthenticated` response gets one forced Firebase ID token + App Check refresh and one retry. Raw backend codes must not reach the UI.

Sensitive server mutations include connection lifecycle, relationship/scope, location-share grants, shared Tasks, hearts, arrival delivery, exact saved-place sharing, device registration, developer notifications and account deletion.

## Notifications

Operational notification preferences remain category-based. Arrival/People notifications respect the recipient's People-notification choice. A normal location position update does not generate a push notification.

## Release integrity

GitHub `main` is the tracked source of truth. `android/` remains intentionally local/untracked because Android/Firebase/signing configuration contains machine-specific or private values.

A source change is not considered compiled/device-accepted until Bruce's Windows Flutter toolchain and S25 Ultra prove it. Backend/rules changes require the governed Node 22 / Firestore emulator / batched Functions deployment helper after the Flutter gate passes.
