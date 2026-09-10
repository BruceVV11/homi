# Homi Location & Safety

Date: 2026-09-10
Source version: `0.9.0+11`

## Purpose

Homi lets people share their latest location with trusted people they explicitly choose, send lightweight arrival check-ins to selected trusted connections, and quickly open verified South African emergency numbers from the People safety surface.

A trusted person may be a partner, family member, roommate, friend, caregiver or another appropriate contact. The People feature remains intentionally broader than the physical household.

## Non-negotiable principle

**Location sharing and arrival check-ins must be explicit, visible, reversible and understandable.**

- A Homi connection never starts location sharing automatically.
- The person/device being located controls who can see their location.
- Arrival check-ins are separately configured and separately enabled.
- Live background updates require an explicit opt-in and Android background-location permission.
- Android live location/check-ins keep a visible foreground-service notification.
- Stopping live updates, disabling check-ins and revoking one person's location access remain understandable controls.
- Homi has no stealth-sharing mode.
- Location/battery values must not be placed in analytics or general logs.
- Arrival notification payloads must not contain saved Home/Work coordinates.

## Emergency call shortcuts

People → **Safety & check-ins** exposes South African emergency call shortcuts:

- `112` — mobile emergency;
- `10111` — police emergency;
- `10177` — ambulance emergency.

Homi opens the device phone application with the selected number through a `tel:` URI. It does not silently place the call, request direct-call permission, dispatch responders, transmit the user's location to emergency services or claim that an emergency request was received.

The emergency shortcuts do not require a Homi account. They are a convenience layer over the phone/network, not an emergency-response service.

## Connection, relationship, location share and check-in are separate

Homi deliberately models independent decisions:

1. **Connection** — both users accept a trusted-person connection.
2. **Relationship/scope** — each user may privately label the other person, for example Mother, Roommate or Friend, and decide whether they are `household` or `friend`.
3. **Location share** — the location owner explicitly chooses whether that connected person may see their current location.
4. **Arrival check-in recipient** — the location owner explicitly chooses whether that accepted trusted person receives Home and/or Work arrival notifications.

None of these decisions silently enables the others.

### Location-only friends

Friends are a first-class use case. Two close friends may connect and mutually share location or receive explicitly selected arrival check-ins without being treated as members of the same household.

A person marked Friend/location-only:

- may receive location only when the owner separately enables a location share;
- may receive a Home/Work check-in only when separately selected for that saved place;
- does not receive access to Home, Supplies, Routines or other household records;
- is not offered as a household Task assignee or household-Task viewer;
- can be relabelled later without changing location consent automatically.

### Household people

A connected person may be privately marked **Household** when they genuinely participate in the user's home context. Household status makes that person eligible for narrowly scoped collaboration such as one-off Tasks.

A household Task may be visible to the creator's chosen Household people so everybody can see who it is assigned to and whether it was completed. A Task explicitly assigned to **Me** remains private/local. Household Task visibility does not grant Home, Routine, Supply or location access.

Household status still does not automatically share location or enable arrival check-ins.

## People hub and identity

The primary People destination separates accepted connections into:

- **Household**;
- **Friends & trusted people**.

Both sections use the connection profile photo where available, with safe fallbacks when an image is unavailable. Pending requests remain surfaced. The existing detailed map/connection/location experience is preserved behind **Manage connections & live location**.

Task assignment continues to use the Household-only service boundary and now displays profile images for identifiable assignees.

## Arrival check-ins

Arrival check-ins currently support two user-defined places: **Home** and **Work**.

The user must:

1. sign in;
2. save Home or Work while physically at that location;
3. choose an arrival radius;
4. choose accepted trusted people who should receive that place's arrival notification;
5. turn Arrival check-ins on.

The current UI offers 150 m, 250 m and 500 m arrival radii. The underlying local model accepts a bounded 75 m–1 km radius.

### Local-data boundary

Home/Work coordinates are stored in user-scoped local preferences on the device. The `sendArrivalCheckIn` callable receives only:

- `place`: `home` or `work`;
- selected trusted-recipient UIDs.

It receives no saved place latitude/longitude. The push payload includes the place label but no coordinates or address.

No route or long-term movement history is created by arrival check-ins.

### Arrival detection

Homi avoids false arrival messages on startup:

- the first location sample establishes whether the device is already inside or outside a saved place and does not send;
- only an outside → inside transition is an arrival;
- the device must move beyond the configured radius plus a 100 m exit margin before being considered outside again;
- a one-hour per-place local cooldown reduces repeated edge notifications.

This is a convenience check-in, not a guaranteed geofencing or emergency-monitoring service.

### Background operation

Arrival check-ins reuse Homi's existing foreground live-location stream instead of creating a hidden second tracker.

The Android strategy remains:

- visible foreground location service;
- `Allow all the time` location permission for background use;
- medium location accuracy;
- roughly 100 m movement threshold;
- roughly two-minute update interval;
- no wake/Wi-Fi lock policy added by Homi.

When the user turns check-ins off, Homi checks for any still-active explicit per-person location shares. If none exist, it stops the continuous location stream. If Homi cannot safely prove that there are no active viewers, it leaves the existing live-location stream untouched rather than silently breaking another sharing choice.

Force-stopping the Android app can interrupt background behaviour until the user opens Homi again. Do not claim Life360-equivalent force-stop/reboot persistence until it is proven on production devices.

## Arrival notification authorization

`sendArrivalCheckIn` is a callable Cloud Function in `africa-south1`.

The backend requires:

- Firebase Authentication;
- verified email for password-provider accounts;
- Firebase App Check;
- place label limited to Home/Work;
- 1–10 unique non-self recipients;
- every recipient to be an accepted trusted connection.

It also applies sender rate limits and respects each recipient device's People-notification preference. No client may use the arrival callable to notify an arbitrary UID that is not an accepted Homi connection.

## People hearts

A heart remains a lightweight check-in action on the full People map.

- sender must be authenticated;
- recipient must be an accepted trusted connection;
- the action never enables or changes location sharing;
- the action never changes Household/Friend scope;
- it does not create a chat thread or persistent social feed;
- a server-side one-minute sender→recipient cooldown limits repetition;
- the recipient can receive **“{sender} is thinking about you!”** when People notifications are enabled;
- tapping the notification opens People;
- the heart is not an emergency, acknowledgement or proof that the recipient saw it.

## Current cloud authorization

### Trusted connections

`connections/{connectionId}` stores the trusted-person relationship between two authenticated accounts. Sensitive connection create/accept/remove mutations are server-controlled through App-Check-protected callable Functions; clients retain only the reads required by the product.

### Private relationship metadata

`peoplePreferences/{ownerUid}/people/{otherUid}` contains the owner's private relationship label and household/friend scope. The owner may read this metadata; mutation is server-controlled through protected Homi Functions.

### Location authorization

`locationShares/{ownerUid}/viewers/{viewerUid}` is readable by the owner or viewer. Mutation is server-controlled through Homi's protected location-share callable.

A viewer can read `locations/{ownerUid}` only when:

- the users still have an accepted connection; and
- the owner has an active share document for that viewer.

Removing a connection therefore prevents stale share metadata from continuing to authorize location access.

### Household Tasks do not broaden location or Home access

`sharedTasks/{taskId}` is a narrowly scoped one-off Task document. Its `memberUids` visibility list is derived server-side from people the creator explicitly marked Household. A specific non-self assignee must be an accepted Household connection. Tasks assigned to the creator remain private/local.

The Task contains only Task data and does not grant access to Home, Supplies, Routines or location.

## Current location data

Homi currently works with latest-state data:

- latitude / longitude;
- accuracy;
- battery percentage;
- charging state;
- last update time;
- optionally resolved human-readable address in the client UI.

Latest location/battery is convenience/safety context, not emergency-grade telemetry.

## Map markers, focus and details

Authorized people can appear on the map with their profile picture, falling back to initials when no image is available.

People has an embedded interactive map plus a full-screen map. The full map allows normal panning/zooming and includes person focus chips so the user can intentionally centre the map on a specific trusted person.

Selecting a person or marker may show:

- address;
- coordinates;
- battery and charging state;
- accuracy;
- last update;
- individual copy controls for address and coordinates;
- **Copy all**;
- open coordinates in Google Maps;
- a heart action for an accepted non-self trusted person on the full map.

The UI must always show freshness so stale location/battery data is not presented as live.

## Returning to People / cached state

People reuses the app-level location service, cached latest snapshot and kept-alive state. Returning to the destination should show the last known state immediately rather than briefly reverting to an uninitialised state while an async refresh completes.

A trusted-person sync failure must not erase the last successfully received locations. The UI should distinguish a secure-sync/unavailable failure from having no connections and avoid exposing raw Firestore errors.

## Location history

Default architecture favours current state, not indefinite route history.

- latest location remains until replaced or sharing is revoked according to product policy;
- long-term route history is not enabled by default;
- Home/Work check-in coordinates remain local to the device;
- check-ins store only the most recent local send time needed for cooldown/status;
- any future breadcrumb/history feature requires a specific purpose, short retention by default and explicit user-facing controls.

## Safety boundaries

Homi is not:

- emergency-service dispatch;
- crash detection;
- a medical or child-safety guarantee;
- a covert tracker;
- proof that a person is safe merely because a recent location/check-in exists;
- guaranteed delivery of an arrival notification.

User-facing copy must avoid implying any of those capabilities.

## Notifications and sensitive data

People notifications can include connection activity, sender name for a heart, and a selected Home/Work arrival label. They must not include precise coordinates, saved addresses or hidden household information in lock-screen text.

Notification delivery is not guaranteed emergency communication. Android power management, connectivity, notification permissions and FCM delivery can delay or suppress a message.

The normal People notification preference is separate from the persistent Android foreground-service notification required while live location/check-ins are active.

## Google Play / Android release requirements

Before production release of background location/check-ins:

- verify background location is essential to the user-facing People/check-in feature;
- provide contextual disclosure before permission requests;
- test foreground-only behaviour;
- verify persistent-notification behaviour;
- test screen off, multi-hour background operation, process recreation and device reboot where supported;
- test Home and Work arrival transitions on at least two Android devices;
- prepare the Google Play background-location declaration/review material;
- ensure Data Safety and public privacy wording disclose the real location/check-in processing;
- verify all permission wording against Android/Google Play requirements current at release time.
