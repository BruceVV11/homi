# Homi Architecture

Date: 2026-09-11
Current source: **`0.9.2+13`**

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
- `flutter_google_places_sdk` with Places API (New) for South African Home/Work autocomplete and place details
- `geocoding` for readable reverse-geocoding when the user chooses **Set from here**
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
- Home/Work arrival latitude/longitude, readable address, Place ID, recipient/radius preferences, exact-place sharing choice and local arrival state.

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

The approved primary People experience is **map-first**. Selecting the People tab opens the existing `PeoplePage` inside the persistent Homi shell, preserving the approved header/navigation and embedded map.

The page order remains intentionally:

1. People title/subtitle;
2. embedded interactive map, person focus chips and Open map action;
3. current-device location/live-update controls and location help;
4. Homi code, connection requests and accepted connections;
5. accepted connections grouped into **Household** and **Friends & trusted people**;
6. **Safety & check-ins** entry after the connection groups.

There is no separate primary **Manage connections & live location** detour. Relationship editing uses a labelled Edit action rather than relying on a small pencil icon alone.

`PeopleHubPage` is now only a compatibility/lifecycle wrapper around `PeoplePage`. It watches Firebase ID-token identity changes and re-keys the map-first People destination when the signed-in UID changes/restores so realtime subscriptions cannot remain bound to a stale signed-out user.

Relationship scope, location share, arrival-recipient selection and exact Home/Work visibility remain independent choices.

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

## Arrival check-ins

`ArrivalCheckInService` and `ArrivalCheckInConfig` implement explicit Home/Work check-ins.

Per signed-in user, local preferences hold:

- saved Home latitude/longitude, readable address and optional Google Place ID;
- saved Work latitude/longitude, readable address and optional Google Place ID;
- radius per place;
- selected accepted arrival-recipient UIDs;
- exact-place sharing switch per place;
- last successful local send timestamp;
- check-in enabled state.

A saved place can be created through Google Places autocomplete or **Set from here**. Google place selection stores only the Place ID/address/coordinate required by Homi; Set from here captures the current location and attempts to reverse-resolve a readable address. Older 0.9/0.9.1 records remain readable and default exact-place sharing to off.

Arrival logic:

- first fresh current position primes inside/outside state without sending;
- only outside → inside triggers an arrival;
- leaving requires distance greater than radius + 100 m hysteresis;
- local one-hour place cooldown reduces repeated edge sends;
- no route/breadcrumb history is created.

When an arrival occurs, the client calls `sendArrivalCheckIn` with only:

- `place`: `home` or `work`;
- selected trusted-recipient UIDs.

The arrival callable still receives **no saved coordinate or address**.

The enable/disable UX follows the Notifications settings pattern with one always-visible settings card and one switch. Contextual education uses **How it works** with an information icon and bottom sheet rather than persistent oversized help containers.

## Optional exact Home/Work sharing

Exact Home/Work visibility is a separate permission from arrival delivery.

The per-place **Show this place to selected people** switch is off by default. When enabled, `ArrivalCheckInService` uses the protected `setSharedArrivalPlace` callable to maintain a minimal cloud copy at:

`sharedPlaces/{ownerUid}/places/{home|work}`

The document contains the owner UID, place kind, latitude/longitude, readable address, selected viewer UIDs and server update timestamp.

A different user may read an exact place only when all of these are true:

1. their UID appears in that place's explicit `viewerUids`;
2. the users still have an accepted Homi connection;
3. the owner currently has location sharing active to that viewer.

Clients cannot create/update/delete shared-place documents directly. Turning the per-place switch off removes the cloud copy while preserving the owner's local arrival settings. Removing a connection strips stale saved-place viewer access. Account deletion removes the owner's Home/Work cloud copies.

The owner sees their own Home/Work from local preferences in Person Details without needing to cloud-share them.

## Emergency call shortcuts

People → Safety & check-ins provides South African emergency shortcuts for `112`, `10111` and `10177`.

The full-screen People map also keeps emergency actions in the lower thumb-reach control area: **SOS · 112** opens the dialer immediately and **Emergency numbers** exposes all three services.

Homi uses `tel:` external phone-app handoff. It deliberately does not request silent direct-call permission, dispatch responders or automatically transmit the user's location to emergency services.

## Maps, focus, details and hearts

The People map remains the immediate live-location surface. Available people use profile-photo markers with initials fallback.

Full-map Person Details now includes:

- latest location;
- Home;
- Work.

The current user's Home/Work comes from local saved arrival settings. Another person's Home/Work appears only through the exact-place permission boundary above. Visible saved places can be opened in Google Maps.

A selected accepted trusted person can receive a lightweight People heart through the protected `sendHeart` callable. The full map now routes that action through `HomiCloudActions`, including the same token refresh/friendly failure handling used by other protected People actions.

## Protected callable client boundary

`HomiCloudActions` is the client boundary for protected mutations. It requires a current Firebase user and maps callable errors to finished-product language.

If a protected callable returns `unauthenticated`, Homi performs one forced Firebase ID-token refresh plus one App Check-token refresh and retries once. If authentication still cannot be verified, Homi shows a recoverable product-level message rather than raw backend codes such as `UNAUTHENTICATED`.

Firestore transport/listener failures remain separate. Realtime listeners retain/recover state where possible and the UI must not expose raw Firestore transport codes.

## Notification architecture

See `documentation/NOTIFICATIONS.md` for the complete matrix.

Fresh-install operational defaults remain ON for Household attention, Tasks & routines, People and Service & security. Homi Updates/product announcements remain OFF. Android retains final control of runtime notification permission and existing persisted preferences remain authoritative.

## Cloud Functions layout

`functions/entrypoint.js` is the deploy manifest entrypoint. It loads the core module first so Firebase Admin/global second-gen options are initialized before supplementary modules.

Current supplementary modules include:

- `functions/check_in.js` — `sendArrivalCheckIn`;
- `functions/connection_cleanup.js` — `onTrustedConnectionDeleted` privacy backstop;
- `functions/device_registration.js` — protected push registration/removal;
- `functions/saved_places.js` — protected `setSharedArrivalPlace` plus account-deletion saved-place cleanup.

All Functions use the dedicated runtime identity:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Global bounded defaults remain `maxInstances: 5`, `minInstances: 0`, `256MiB`, with smaller per-Function caps where appropriate.

The backend deployment helper validates Node 22, prepares a disposable synchronized npm lock, runs local `npm ci`, syntax checks all Function modules, runs the Firestore Emulator security gate, deploys Firestore separately, then deploys discovered Function exports in batches of five.

The validated/deployed 0.9.0 backend remains the active backend until 0.9.2 passes Flutter validation and the governed helper publishes the new saved-place callable/trigger/rules.

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
sharedPlaces/{ownerUid}/places/{home|work}  # optional exact-place sharing only
developerAdmins/{uid}
notificationCampaigns/{campaignId}
heartCooldowns/{senderUid_recipientUid}     # server-only
serverRateLimits/{scope_actorUid}           # server-only
```

Anything not explicitly allowed by Firestore rules fails closed. Admin SDK operations bypass client rules and therefore must perform their own authorization/validation in server code.

## Account, privacy and data controls

The Account centre keeps Sign in, Sign out, Erase data from this phone and Delete Homi account distinct.

Successful account deletion removes Homi-managed cloud data/Auth identity and current-device Homi data. 0.9.2 also removes owned optional `sharedPlaces` Home/Work copies through server cleanup.

**Erase data from this phone** clears local arrival places and attempts to revoke any optional cloud shared-place copies while the signed-in session is still available. If that cloud revoke is temporarily unreachable, Homi stores only a local pending-revocation marker and retries on the next signed-in load. Independent Firestore read rules still require an accepted connection and active location share, so stale storage cannot bypass access checks.

Privacy, stop-sharing, check-in disable, exact-place revoke and account deletion must never depend on payment.

## Security / secrets

- No service-account private key is bundled in the app.
- Android Maps/Firebase/signing configuration remains local/ignored where designed.
- Maps/Places keys and App Check debug tokens must never be pasted into chat/source.
- Development Places credentials are passed through `HOMI_PLACES_API_KEY` and must remain Android package/SHA restricted.
- Sensitive coordinates/addresses must not enter analytics/general logs or arrival push payloads.
- Developer-admin access cannot be granted by the client.
- Protected callables enforce App Check in source.
- Release App Check/Play Integrity remains a separate production gate.

## Verification state

`0.9.2+13` is implemented in source in response to the first 0.9.1 device review. The existing 0.9 backend is still deployed, but 0.9.2 adds a new callable, cleanup trigger and Firestore rule boundary.

Do not call 0.9.2 compiled, backend-deployed or device-accepted until Bruce's real Flutter analyzer/tests, the governed backend security/deployment helper and the S25 Ultra regression all pass.