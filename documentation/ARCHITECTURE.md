# Homi Architecture

Date: 2026-09-10
Current source: **`0.9.1+12`**

## Permanent project identifiers

- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android application ID: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub repository: `BruceVV11/homi`
- Firestore / Functions region: `africa-south1`

These identifiers are locked for the Android/Firebase/Play lifecycle. The deleted `homi-508000` project is not part of Homi and must never be reused.

## Stack

- Flutter / Dart Android application
- Android minimum SDK 24
- SharedPreferences for version-tolerant local-first household records and local feature preferences
- Firebase Authentication for optional identity and protected collaboration
- Cloud Firestore for narrowly scoped shared state
- Firebase Cloud Functions 2nd gen in `africa-south1`
- Firebase Cloud Messaging for remote push delivery
- Firebase App Check: debug provider during development, Play Integrity for release
- `flutter_local_notifications` for local due/attention reminders and foreground push presentation
- Google Maps Flutter + Geolocator for consensual trusted-person location and local arrival detection
- `geocoding` for device-side typed-address resolution and readable reverse-geocoded addresses
- `url_launcher` for external Google Maps and emergency phone-app handoff

## Primary shell

Primary destinations remain:

**Overview · Tasks · Home · Supplies · People**

The exact Homi mark remains the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move when swiping between destinations.

The profile/avatar entry opens **Homi & account**. Local-only users retain access to product information, Notifications, Help, privacy/location/terms/about and local-data controls without being forced to sign in.

Notification taps route to Overview, Tasks, Routines, Home, Supplies, People or Homi & account.

## Overview / local household state

Overview aggregates open Tasks, due Routines, Supply attention and Home service dates. Quick Reset remains based on real due Routines plus bounded suggestions.

These areas remain local-first unless a specific record is explicitly shared:

- onboarding/home name/type;
- private one-off Tasks;
- recurring Routines;
- Supplies and quantities/status/expiry;
- Home Things, maintenance/repair history and utility readings;
- cached current-device location;
- local notification preferences/schedules;
- Home/Work arrival place latitude/longitude, readable address, recipient/radius preferences and local arrival state.

Local records use version-tolerant JSON in SharedPreferences. Model changes must retain safe defaults for older persisted data rather than requiring destructive resets.

## Tasks vs routines

### Tasks

Tasks are one-off jobs with optional due time and assignee. A Task assigned to **Me** remains private/local. A Task assigned to another Household person or **Anyone at home** is created through the protected backend as a shared Task.

Shared Task membership is derived server-side from accepted connections the creator marked Household. Non-Household trusted people are excluded from Task assignment and visibility.

The Task editor displays the current user and Household assignees with profile photos where available, falling back to initials/person/group icons.

Completed Tasks remain visible for 48 hours before normal cleanup.

### Routines

Routines remain local repeating responsibilities. Current recurrence supports Daily, Weekdays, Weekly, Bi-weekly and Monthly. Completion keeps actor/timestamp and restores the same occurrence if an accidental completion is undone.

## People architecture

The approved primary People experience is **map-first**. Selecting the People tab opens the existing `PeoplePage` directly inside the persistent Homi shell rather than a separate lightweight hub or manager page.

The page order is intentionally:

1. People title/subtitle;
2. embedded interactive map, person focus chips and Open map action;
3. current-device location/live-update controls and location help;
4. Homi code, connection requests and accepted connections;
5. accepted connections grouped into **Household** and **Friends & trusted people**;
6. **Safety & check-ins** entry after the connection groups.

There is no separate primary **Manage connections & live location** detour. The existing map, relationship, per-person share and location-detail functionality remains directly available where it was originally approved.

Profile images come from the existing trusted-connection identity fields. Pending connection requests remain surfaced. Relationship editing uses an explicit labelled Edit action rather than relying on a small pencil icon alone.

Relationship scope and location/check-in consent remain independent decisions. Marking somebody Household does not automatically enable location sharing or arrival notifications.

## Trusted connections and private labels

`connections/{connectionId}` represents the accepted/pending relationship between two authenticated Homi accounts. Connection creation/accept/remove is server-controlled through App-Check-protected callable Functions.

Each user privately classifies a trusted person at:

`peoplePreferences/{ownerUid}/people/{otherUid}`

with relationship label and `household` / `friend` scope. Mutation is server-controlled; required reads remain available to the owner.

## Shared Tasks

`sharedTasks/{taskId}` contains a narrowly scoped one-off Task. Authoritative membership and actor identity come from the backend, not arbitrary client fields.

Sharing one Task does not expose Home, Supplies, Routines or location.

## Live location architecture

The tracked device controls sharing.

- Location visibility is granted per accepted trusted person through `locationShares/{ownerUid}/viewers/{viewerUid}`.
- Live background updates require sign-in, Android background-location permission and explicit user action.
- Latest location/battery is written to `locations/{uid}`.
- Authorized viewers can read only while the accepted connection and active share remain valid.
- Long-term movement history is not stored by default.

Android background location uses one visible foreground Geolocator stream with medium accuracy, roughly 100 m movement threshold and roughly two-minute interval.

### Shared stream ownership

The foreground location stream is shared by two explicit product features:

1. **Live updates** — current-location sharing to individually authorized viewers;
2. **Arrival check-ins** — local Home/Work arrival detection.

`LocationStatusService` stores separate local requirement flags for these two features. Turning Live updates off does not stop the stream when Arrival check-ins still require it. Turning Arrival check-ins off does not stop the stream when Live updates still require it. The underlying foreground service stops when neither feature needs it.

`resumeContinuousSharingIfEnabled()` resumes the shared stream only when an explicit saved requirement exists and Android background permission is already available; it does not silently open a new permission prompt during app startup.

The foreground notification uses neutral wording because the stream may be serving either or both features.

## Arrival check-ins

`ArrivalCheckInService` and `ArrivalCheckInConfig` implement explicit Home/Work check-ins.

Per signed-in user, local preferences hold:

- saved Home latitude/longitude and optional readable address;
- saved Work latitude/longitude and optional readable address;
- radius per place;
- selected accepted trusted-recipient UIDs;
- last successful local send timestamp;
- check-in enabled state.

A saved place can be created either by entering an address, which is resolved through the device geocoding layer, or by **Set from here**, which captures the current location and attempts to reverse-resolve a readable address. Older 0.9 saved place records without an address remain valid.

Coordinates and readable addresses stay local in the current architecture.

Arrival logic:

- first fresh current position primes inside/outside state without sending;
- only outside → inside triggers an arrival;
- leaving requires distance greater than radius + 100 m hysteresis;
- local one-hour place cooldown reduces repeated edge sends;
- no route/breadcrumb history is created.

When an arrival occurs, the client calls `sendArrivalCheckIn` with only:

- `place`: `home` or `work`;
- selected trusted-recipient UIDs.

The callable revalidates accepted connections, skips stale/disconnected selections, rate-limits the sender, respects recipient People-notification settings and sends no coordinate/address data.

The enable/disable UX follows Homi's Notifications settings pattern: status hero, explicit enable button while off, and a settings-style switch while on. Educational explanation uses a **How it works** bottom sheet rather than persistent oversized help containers.

## Emergency call shortcuts

People → Safety & check-ins provides South African emergency shortcuts for `112`, `10111` and `10177`.

Homi uses a `tel:` URI through the external phone application. The app deliberately does not request direct-call permission or silently place the call. Homi does not dispatch responders or automatically transmit the user's location to emergency services.

## Maps, focus and hearts

The People map remains the immediate live-location surface. Available people use profile-photo markers with initials fallback. Location details include freshness, address/coordinates, accuracy, battery/charging, copy controls and Google Maps handoff.

A selected accepted trusted person can receive a lightweight People heart through the protected `sendHeart` callable. Hearts do not change any sharing/scope permission and remain rate-limited.

## Notification architecture

See `documentation/NOTIFICATIONS.md` for the complete matrix.

### Fresh-install defaults

`HomiNotificationPreferences` defaults useful operational notifications on:

- master operational notifications: ON;
- Household attention: ON;
- Tasks & routines: ON;
- People: ON;
- Service & security: ON;
- Homi Updates/product announcements: OFF.

Android still controls actual notification permission. Homi requests that system permission once when a fresh install has operational notifications enabled but OS permission is absent. A denial/dismissal is not repeatedly forced. Existing persisted Homi preferences remain authoritative, including an explicit master OFF.

### Local notifications

`HomiNotificationService` schedules/produces local reminders for due Tasks/Routines, Supply attention/expiry and Home service dates. Schedules use inexact Android timing and do not require exact-alarm permission.

### Remote notifications

FCM handles:

- connection request/acceptance;
- People hearts;
- shared Task creation/assignment/completion;
- Home/Work arrival check-ins;
- developer product/service/security notices.

Signed-in device registration is stored under `users/{uid}/devices/{deviceId}` through protected callable Functions. Direct fan-out remains bounded.

## Cloud Functions layout

`functions/entrypoint.js` is the deploy manifest entrypoint. It loads the core module first so Firebase Admin/global second-gen options are initialized before supplementary modules.

Current supplementary modules include:

- `functions/check_in.js` — `sendArrivalCheckIn`;
- `functions/connection_cleanup.js` — `onTrustedConnectionDeleted` privacy backstop;
- `functions/device_registration.js` — protected push registration/removal.

All Functions use the dedicated runtime identity:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Global bounded defaults remain `maxInstances: 5`, `minInstances: 0`, `256MiB`, with smaller per-Function caps where appropriate.

The backend deployment helper validates Node 22, prepares a disposable synchronized npm lock, runs local `npm ci`, syntax checks all Function modules, runs the Firestore Emulator security gate, deploys Firestore separately, then deploys discovered Function exports in batches of five.

Bruce confirmed the corrected `0.8.2+10` backend completed successfully through this batched path on 10 September 2026. Bruce subsequently confirmed the governed `0.9.0+11` backend deployment completed without an observed failure, including the `sendArrivalCheckIn` candidate. The 0.9.1 refinement changes client/local UI-data behavior only and therefore does not require another backend deployment.

## Firestore collections in active use

```text
users/{uid}
users/{uid}/devices/{deviceId}
homiCodes/{code}
connections/{connectionId}
peoplePreferences/{ownerUid}/people/{otherUid}
sharedTasks/{taskId}
locationShares/{ownerUid}/viewers/{viewerUid}
locations/{ownerUid}
developerAdmins/{uid}
notificationCampaigns/{campaignId}
heartCooldowns/{senderUid_recipientUid}   # server-only
serverRateLimits/{scope_actorUid}         # server-only
```

Home/Work arrival coordinates/readable addresses are intentionally **not** a Firestore collection in 0.9.1.

Anything not explicitly allowed by Firestore rules fails closed. Admin SDK operations bypass client rules and therefore must perform their own authorization/validation in server code.

## Account, privacy and data controls

The Account centre keeps Sign in, Sign out, Erase data from this phone and Delete Homi account distinct.

Successful account deletion removes Homi-managed cloud data/Auth identity and current-device Homi data. The shell additionally clears that UID's user-scoped Home/Work arrival-check-in settings, including local readable addresses. Local data erasure/location cleanup must also clear background location requirement state without changing Android permission itself.

Privacy, stop-sharing, check-in disable and account deletion must never depend on payment.

## Security / secrets

- No service-account private key is bundled in the app.
- Android Maps/Firebase/signing configuration remains local/ignored where designed.
- Maps keys and App Check debug tokens must never be pasted into chat/source.
- Sensitive coordinates/addresses must not enter analytics/general logs or arrival push payloads.
- Developer-admin access cannot be granted by the client.
- Protected callables enforce App Check in source.
- Release App Check/Play Integrity remains a separate production gate.

## Verification state

The validated/deployed 0.9.0 backend foundation remains active. `0.9.1+12` restores the approved map-first People UX and refines client-side check-in setup after the first S25 Ultra UI review.

Because 0.9.1 changes Flutter source after the last green local gate, it is **pending a fresh `flutter analyze` + `flutter test`** and then another S25 Ultra acceptance pass. Do not redeploy Firebase for this client-only refinement unless later source changes touch a backend runtime surface.