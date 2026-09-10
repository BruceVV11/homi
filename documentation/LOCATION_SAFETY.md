# Homi Location & Safety

Date: 2026-09-11
Source version: `0.9.2+13`

## Purpose

Homi lets people share their latest location with trusted people they explicitly choose, send lightweight Home/Work arrival check-ins, optionally show an exact saved Home/Work place under a separate privacy control, and quickly open South African emergency numbers.

A trusted person may be a partner, family member, roommate, friend, caregiver or another appropriate contact. People remains intentionally broader than the physical household.

## Non-negotiable principle

**Connection, current-location sharing, arrival delivery and exact saved-place visibility are separate choices.**

- A Homi connection never starts location sharing automatically.
- Household/Friend classification never starts location sharing.
- Arrival recipients are chosen per Home/Work place.
- Exact Home/Work visibility is separately off by default.
- Exact Home/Work visibility additionally requires an active owner→viewer location share.
- Arrival check-ins are separately enabled/disabled for the device.
- Background use requires explicit Android background-location permission and a visible foreground-service notification.
- Homi has no stealth-sharing mode.
- Location, Home/Work coordinates and readable addresses must not enter analytics/general logs.
- Arrival notification payloads must never contain Home/Work coordinates or addresses.

## Emergency call shortcuts

People → **Safety & check-ins** exposes:

- `112` — emergency from a mobile phone;
- `10111` — police emergency;
- `10177` — ambulance emergency.

The full-screen People map also keeps emergency controls at the bottom within normal thumb reach:

- **SOS · 112** opens the phone application with 112 ready in one tap;
- **Emergency numbers** opens all three service choices without leaving the map first.

Homi uses `tel:` external phone-app handoff. It does not silently place the call, request direct-call permission, dispatch responders, transmit location to emergency services or claim an emergency request was received.

These controls are convenience shortcuts, not an emergency-response service.

## People page and map

The approved People destination remains map-first inside the normal Homi shell. The embedded map, person chips, current-device location card and live-sharing controls appear before connection management.

Connections appear beneath that experience, grouped into:

- **Household**;
- **Friends & trusted people**.

The full map keeps the existing people markers/focus controls and adds the emergency controls above. Its Person Details sheet includes:

- latest location;
- Home;
- Work.

For the signed-in user, Home/Work is read from the user's local arrival configuration. For another person, the exact place is displayed only if the server read authorization below succeeds.

## Connection and sharing decisions

Homi models these independent decisions:

1. **Connection** — both users accept the trusted-person relationship.
2. **Relationship/scope** — each user privately labels the other and chooses Household/Friend context.
3. **Location share** — the owner chooses whether that viewer may read the owner's latest/current location.
4. **Arrival recipient** — the owner chooses whether that connection receives a Home and/or Work arrival event.
5. **Exact place visibility** — the owner separately chooses whether selected arrival people may see the precise saved Home/Work place.
6. **Arrival monitoring** — the tracked device separately turns background arrival detection on/off.

None silently enables the others.

## Home and Work setup

Arrival check-ins support **Home** and **Work**.

A user can set each place through:

- **Google Places autocomplete** — type an address/place, choose the correct South African Google result, then Homi fetches only the Place ID, formatted address and coordinate it needs;
- **Set from here** — capture the phone's current coordinate and reverse-resolve a readable address where possible.

The Google picker displays Google's attribution asset with results. The Android credential remains package/SHA restricted and is not committed to source.

Local saved data includes:

- latitude/longitude;
- readable address;
- optional Google Place ID;
- radius;
- selected arrival recipients;
- exact-place sharing switch;
- most recent successful arrival-send timestamp.

Older 0.9/0.9.1 records without Place IDs remain valid. Older records default exact-place sharing to **off**.

## Arrival monitoring UX

The Arrival check-ins section uses one Notifications-style setting card at all times.

- Switch ON: Homi watches configured Home/Work areas in the background while platform permission/conditions allow it.
- Switch OFF: monitoring stops, but saved Home/Work configuration remains.
- Missing setup/permission errors are shown only when actionable.
- Successful state changes do not add a redundant success box.
- **How it works** uses the standard information icon and a bottom sheet rather than an oversized passive help box.

## Arrival detection

Homi avoids startup false positives:

- the first fresh sample establishes inside/outside state and sends nothing;
- only outside → inside is an arrival;
- leaving requires distance beyond radius + 100 m exit hysteresis;
- one-hour local place cooldown reduces repeated edge sends;
- changing a saved place resets the old place cooldown;
- no route/breadcrumb history is created.

This is convenience communication, not guaranteed geofencing or emergency monitoring.

## Arrival notification privacy

`sendArrivalCheckIn` receives only:

- `place`: `home` or `work`;
- selected trusted-recipient UIDs.

It receives no saved Home/Work coordinate or readable address. The push notification likewise contains no precise saved-place data.

The backend requires:

- Firebase Authentication;
- Firebase App Check;
- verified email for password-provider accounts;
- Home/Work event label only;
- maximum 10 unique non-self recipients;
- accepted trusted relationship for every delivered recipient.

It applies sender rate limits and respects recipient People-notification preferences.

## Optional exact saved-place sharing

The per-place **Show this place to selected people** switch is distinct from arrival delivery and defaults off.

When the owner enables it, Homi creates/updates a minimal server-controlled document:

`sharedPlaces/{ownerUid}/places/{home|work}`

It contains:

- `ownerUid`;
- `kind`;
- latitude/longitude;
- readable address;
- `viewerUids` selected by the owner;
- server timestamp.

The client never writes this collection directly. `setSharedArrivalPlace` is App-Check-protected, validates Home/Work, bounds coordinate/address/viewer values, revalidates accepted connections and rate-limits changes.

A different user can read one exact place only when:

1. the owner's server document explicitly lists their UID;
2. the connection remains accepted;
3. `locationShares/{ownerUid}/viewers/{viewerUid}` remains active.

Turning off normal location sharing therefore immediately blocks saved-place reads through Firestore rules even if a stale document still exists. Turning off the saved-place switch deletes the cloud copy. Removing a connection strips the UID from the saved-place viewer list so reconnecting later cannot silently revive old access.

The owner sees their own saved Home/Work from local preferences; they do not need to upload a place merely to see it themselves.

## Local erase and deletion

**Erase data from this phone** clears local Home/Work configuration and background-arrival requirement state. In 0.9.2 it also attempts to revoke owned optional `sharedPlaces` Home/Work copies before/while clearing local state.

If cloud revocation is temporarily unreachable, Homi stores only a local pending-revocation marker and retries the cloud clear on the next signed-in load. Server read authorization still independently requires the accepted connection and active location share.

Account deletion removes the user's cloud identity/collaboration data and owned shared-place copies through server cleanup, then clears current-device local Homi data according to the account-deletion flow.

## Background operation

Live updates and Arrival check-ins share one visible Android foreground location stream but retain separate local ownership flags.

The background strategy remains:

- `Allow all the time` location permission when the user activates a background feature;
- visible Homi foreground-service notification;
- medium location accuracy;
- roughly 100 m movement threshold;
- roughly two-minute update interval;
- no hidden wake/Wi-Fi-lock strategy added by Homi.

Turning one background feature off does not stop the stream if the other still explicitly requires it. When both are off, the stream stops.

Force-stopping Android can interrupt background behaviour until Homi is opened again. Do not claim Life360-equivalent persistence until real release-device tests prove it.

## People authentication/reachability

The People destination is kept alive for fast map return, but its auth-scoped realtime subscriptions must never remain bound to a stale user.

`PeopleHubPage` observes Firebase ID-token identity changes and recreates the map-first `PeoplePage` when the UID changes/restores.

`HomiCloudActions` handles protected callable mutations. If a callable returns `unauthenticated`, Homi forces one Firebase ID-token refresh and App Check-token refresh, retries once, then shows finished-product recovery text if verification still fails. Raw codes such as `UNAUTHENTICATED` must not be shown to the user.

The Android log supplied during the first 0.9.1 device review also showed Firestore `UNAVAILABLE`/DNS name-resolution failures. Realtime Firestore connectivity is separate from callable authentication; listeners should recover when connectivity/DNS recovers and Homi should preserve/represent last valid state rather than expose transport codes.

## Current-location authorization

`locationShares/{ownerUid}/viewers/{viewerUid}` is server-controlled. A viewer can read `locations/{ownerUid}` only while the connection remains accepted and the owner→viewer share is active.

Latest cloud location contains current-state latitude/longitude, accuracy, battery, charging state, update time and bounded source value. It is not route history.

Check-in-only background sampling does not refresh `locations/{uid}` unless Live updates is independently active.

## Friends and Household

A Friend/location-only connection may receive location or arrival events only through the separate explicit choices above. Friend status never grants Home, Supplies, Routines or household Task data.

A Household connection can be eligible for narrowly shared one-off Tasks. Household status alone still grants no location, arrival or precise saved-place visibility.

## People hearts

A heart remains a lightweight authenticated action to an accepted trusted connection. It does not change any location/scope/place permission. It is server-rate-limited and respects People notifications.

The full-map heart action now uses the common protected-callable wrapper so stale auth/App Check is retried once and raw backend codes do not leak into UI.

## Google Play / release requirements

Before public production use of background location/check-ins:

- verify foreground/background permission progression on real Android devices;
- provide prominent contextual disclosure before the sensitive permission request;
- verify persistent foreground notification behaviour;
- test screen-off, multi-hour background operation, normal process recreation and reboot;
- test Samsung power-saving/battery optimisation;
- measure representative battery impact;
- test Home and Work transitions using at least two accounts/devices;
- verify exact-place grant/revoke/disconnect behaviour;
- prepare Play background-location declaration/review evidence;
- ensure Data Safety/public privacy wording reflects optional precise saved-place cloud sharing;
- use Play Integrity App Check for release traffic.

Homi must never present location/check-in data as emergency-grade telemetry or proof that a person is safe.
