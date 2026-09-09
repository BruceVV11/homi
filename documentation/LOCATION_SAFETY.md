# Homi Location & Safety

## Purpose

Homi can share a person's latest location with trusted people they explicitly choose. A trusted person may be a partner, family member, friend, housemate, caregiver or another appropriate contact; the feature is not limited to members of the same physical household.

## Non-negotiable product principle

**Location sharing must be explicit, visible, reversible and understandable.**

- A Homi connection never starts tracking automatically.
- The person/device being located controls who can see them.
- Live background updates require a separate opt-in.
- Stopping live updates and revoking one person's access are independent controls.
- Homi has no stealth-sharing mode.
- Sensitive location/battery data must not be placed in analytics or general logs.

## Current connection model

Signed-in users receive a six-character Homi code.

1. Person A enters Person B's code.
2. Homi creates a pending connection request.
3. Person B explicitly accepts or declines.
4. Once connected, each person separately chooses whether to share location with the other.
5. Either person can remove the trusted connection later.

The Homi-code directory cannot be browsed: Firestore rules allow authenticated exact-document lookup and deny collection listing.

## Current shared signals

When a person has explicitly granted access, Homi may display their latest:

- latitude and longitude
- reverse-geocoded address when available
- accuracy estimate
- update timestamp
- battery percentage
- charging state
- profile photo/name from the accepted connection

Battery information is convenience telemetry, not emergency-grade data. The UI must always expose freshness/last-updated time so stale values are not presented as current.

## Map behavior

People contains a persistent Google Map.

- A person is represented by their profile picture when available, not a generic drop pin.
- If no photo is available, Homi uses an initials-based marker.
- Selecting a marker opens a Homi-styled detail sheet.
- The detail sheet exposes address, coordinates, accuracy, battery and update time.
- Address/coordinates can be copied.
- The coordinates can be opened externally in Google Maps.

A connected person appears on the map only when their own share to the current viewer is active and a readable latest location exists.

## Foreground location

Foreground/current location is useful even without background sharing.

If Homi already has foreground location permission, the People page refreshes the phone's status automatically when opened rather than requiring a repeated `Check my location` action. If permission has never been granted, Homi asks only when the user chooses to enable location.

The latest self snapshot is cached locally so the People page can show the most recent known status immediately after restart.

## Live background sharing

Live sharing is an explicit signed-in capability.

On Android, the current implementation uses Geolocator's location foreground-service configuration. While live sharing is active:

- Android location permission must be `Allow all the time`.
- Homi keeps a foreground-service notification visible as required by Android.
- the requested accuracy is **medium**, not maximum GPS accuracy;
- location updates use a **100 metre movement filter**;
- the requested interval is approximately **two minutes**;
- Homi does **not** enable a wake lock by default;
- each accepted update refreshes the latest location/battery document rather than creating an indefinite route history.

These choices are intended to reduce battery impact while still giving useful household/loved-one awareness. Android may batch or delay delivery, so the actual update cadence and battery cost must be validated on representative real devices rather than treated as a guaranteed two-minute heartbeat.

## Resume and stop behavior

If the user has explicitly enabled live sharing, Homi stores that preference locally and attempts to resume the location foreground service the next time the signed-in app starts, provided Android still grants the necessary permission.

If the user explicitly chooses **Stop live updates**, Homi cancels the stream and clears that preference. Homi must not silently re-enable it afterwards.

Signing out also stops live updates before the Firebase session ends.

## Important Android/release limitations

A functioning location foreground service is not the same as complete Life360-grade process resilience.

The current implementation still requires release hardening and real-device validation for cases such as:

- device reboot
- OEM battery optimizers
- force-stop behavior
- long stationary periods
- lost/recovered network connectivity
- Play Store background-location declaration/review
- notification permission behavior across Android versions

Homi must not claim guaranteed continuous tracking until those scenarios are implemented/tested for the production release.

## Firestore authorization

Connection and location authorization are deliberately separate.

```text
users/{uid}
homiCodes/{code}
connections/{sortedUidPair}
locationShares/{ownerUid}/viewers/{viewerUid}
locations/{ownerUid}
```

- `connections` answers: “Are these two Homi users connected?”
- `locationShares` answers: “Has the location owner explicitly allowed this viewer?”
- `locations` stores the latest shareable status.

A viewer cannot read another person's `/locations/{uid}` document unless an active owner-controlled `locationShares` document grants them access.

## Data retention

The default architecture remains current-state location, not movement history.

Current default:

- latest location/battery snapshot: replaced by newer status
- no long-term route history collection
- no hidden breadcrumb collection

Places, arrival/departure alerts and short history may be added later only as clearly explained features with appropriate retention and privacy controls.

## User-facing FAQ requirements

The in-app FAQ should explain, in plain language:

- why background permission is needed
- why Android shows a persistent notification
- that connecting to someone does not start location sharing
- that location sharing can be revoked per person
- that live updates can be stopped globally
- that battery use is reduced through moderate accuracy, movement filtering and spaced updates
- that Homi stores the latest state by default rather than a travel history

## Play Store requirement

Because background location is a sensitive Android permission, production release work must include the relevant Google Play background-location declaration, prominent user-facing disclosure, privacy-policy alignment and evidence that the feature is core to Homi's People experience. Permission must not be requested out of context merely because it exists in the manifest.

## Out of scope by default

- covert tracking
- monitoring a non-Homi device without the device owner's consent
- indefinite route history
- crash detection
- emergency-service dispatch
- insurance scoring
- location sharing that cannot be stopped without payment
