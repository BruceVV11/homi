# Homi Location & Safety

## Purpose

Homi lets people share their latest location with trusted people they explicitly choose. A trusted person may be a partner, family member, roommate, friend, caregiver or another appropriate contact. The People feature is intentionally broader than the physical household.

## Non-negotiable principle

**Location sharing must be explicit, visible, reversible and understandable.**

- A Homi connection never starts location sharing automatically.
- The person/device being located controls who can see their location.
- Live background updates require a separate opt-in.
- Android live sharing keeps a visible foreground-service notification.
- Stopping live updates and revoking one person's access remain separate controls.
- Homi has no stealth-sharing mode.
- Location/battery values must not be placed in analytics or general logs.

## Connection, relationship and sharing are separate

Homi deliberately models three independent decisions:

1. **Connection** — both users accept a trusted-person connection.
2. **Relationship/scope** — each user may privately label the other person, for example Mother, Roommate or Friend, and decide whether they are `household` or `friend`.
3. **Location share** — the location owner explicitly chooses whether that connected person may see their current location.

None of these decisions silently enables the others.

### Location-only friends

Friends are a first-class use case. Two close friends may connect and mutually share location simply to check in on one another.

A person marked **Friend · location only**:

- may receive location only when the owner separately enables a location share;
- does not receive access to Home, Supplies, Routines or other household records;
- is not offered as a household task assignee;
- can be relabelled later without changing location consent automatically.

This supports the social/check-in value of Life360-style location sharing without treating every trusted person as a member of the same home.

### Household people

A connected person may be privately marked **Household** when they genuinely participate in the user's home context. Household status can make that person eligible for narrowly scoped collaboration such as an assigned one-off task.

Household status still does not automatically share location, and it is not yet full Home/Routine/Supply membership.

## Current cloud authorization

### Trusted connections

`connections/{connectionId}` stores an accepted relationship between two authenticated accounts.

### Private relationship metadata

`peoplePreferences/{ownerUid}/people/{otherUid}` is readable/writable only by `ownerUid` and contains the owner's private relationship label and household/friend scope.

### Location authorization

`locationShares/{ownerUid}/viewers/{viewerUid}` is controlled by the location owner. Firestore rules require an accepted connection before the share may be enabled.

A viewer can read `locations/{ownerUid}` only when:

- the users still have an accepted connection; and
- the owner has an active share document for that viewer.

Removing a connection therefore prevents the old share document from continuing to authorize location access.

### Assigned tasks do not broaden location or Home access

`sharedTasks/{taskId}` is a narrowly scoped collaboration document between creator and assignee. Creating one requires an accepted connection and the creator's private Household preference for that assignee.

It does not grant access to Home, Supplies, Routines or location.

## Current location data

Homi currently works with latest-state data:

- latitude / longitude
- accuracy
- battery percentage
- charging state
- last update time
- optionally resolved human-readable address in the client UI

Latest location/battery is treated as convenience/safety context, not emergency-grade telemetry.

## Map markers and details

Authorized people can appear on the map with their profile picture, falling back to initials when no image is available.

Tapping a marker may show:

- address
- coordinates
- battery and charging state
- accuracy
- last update
- individual copy controls for address and coordinates
- Copy all
- open coordinates in Google Maps

The UI should always show freshness so stale location/battery data is not presented as live.

## Background location and battery discipline

Modern Android treats background location as a sensitive capability. Homi therefore requests background behavior only from the explicit Live updates flow.

The current Android strategy uses:

- a foreground location service while live sharing is active;
- visible persistent notification;
- medium location accuracy rather than maximum accuracy;
- a movement threshold;
- spaced update requests rather than continuous maximum-frequency GPS.

This is intended to reduce battery cost, but exact battery behavior must be measured on real devices.

**Do not claim Life360-equivalent force-stop/reboot persistence until it has been proven.** Android may stop or restrict app processes depending on OS and manufacturer behavior. Full production-grade resilience may require additional native Android work, boot/restart handling, foreground-service policy validation and Google Play background-location review.

## Location history

Default architecture favours current state, not indefinite route history.

- latest location remains until replaced or sharing is revoked according to product policy;
- long-term route history is not enabled by default;
- any future recent breadcrumb/history feature must have a specific retention purpose, short retention by default and clear user-facing controls.

## Places and arrival/departure alerts

Places remain a planned capability rather than a completed one. Potential examples include Home, Work, School, Gym or a partner's home.

Any arrival/departure alert must be transparent, tied to an authorized location share and easy to disable. Homi must not add a hidden surveillance mode through Places.

## Safety boundaries

Homi is not currently:

- emergency-service dispatch;
- crash detection;
- a medical or child-safety guarantee;
- a covert tracker;
- proof that a person is safe merely because a recent location exists.

User-facing copy should avoid implying any of those capabilities.

## Google Play / Android release requirements

Before production release of background location:

- verify background location is essential to the user-facing People feature;
- provide contextual disclosure before permission requests;
- test foreground-only fallback;
- verify persistent-notification behavior;
- test screen off, app background, process recreation and device reboot where supported;
- prepare the Google Play background-location declaration/review material;
- verify all final permission wording against the Android/Play requirements current at release time.
