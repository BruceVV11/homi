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
- is not offered as a household task assignee or household-task viewer;
- can be relabelled later without changing location consent automatically.

This supports the social/check-in value of Life360-style location sharing without treating every trusted person as a member of the same home.

### Household people

A connected person may be privately marked **Household** when they genuinely participate in the user's home context. Household status can make that person eligible for narrowly scoped collaboration such as one-off Tasks.

A household Task may be visible to the creator's chosen Household people so everybody can see who it is assigned to and whether it was completed. A Task explicitly assigned to **Me** remains private/local. Household Task visibility does not grant Home, Routine, Supply or location access.

Household status still does not automatically share location, and it is not full Home/Routine/Supply membership by itself.

## People hearts

A heart is a lightweight check-in action on the full People map.

- sender must be authenticated;
- recipient must be an accepted trusted connection;
- the action never enables or changes location sharing;
- the action never changes Household/Friend scope;
- it does not create a chat thread or persistent social feed;
- a server-side one-minute sender→recipient cooldown limits repetition;
- the recipient can receive **“{sender} is thinking about you!”** when their People notifications are enabled;
- tapping the notification opens People;
- the heart is not an emergency, acknowledgement or proof that the recipient saw it.

This feature is intentionally small: it adds a human check-in without turning location sharing into messaging or gamifying surveillance.

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

### Household Tasks do not broaden location or Home access

`sharedTasks/{taskId}` is a narrowly scoped one-off Task document. Its `memberUids` visibility list is built from people the creator explicitly marked Household. A specific non-self assignee must be an accepted Household connection. Tasks assigned to the creator are not stored as shared household Tasks.

The Task contains only Task data and does not grant access to Home, Supplies, Routines or location.

## Current location data

Homi currently works with latest-state data:

- latitude / longitude
- accuracy
- battery percentage
- charging state
- last update time
- optionally resolved human-readable address in the client UI

Latest location/battery is treated as convenience/safety context, not emergency-grade telemetry.

## Map markers, focus and details

Authorized people can appear on the map with their profile picture, falling back to initials when no image is available.

People has an embedded interactive map plus a full-screen map. The full map allows normal panning/zooming and includes person focus chips so the user can intentionally centre the map on a specific trusted person rather than treating every location as one undifferentiated map view.

Selecting a person or marker may show:

- address
- coordinates
- battery and charging state
- accuracy
- last update
- individual copy controls for address and coordinates
- **Copy all**
- open coordinates in Google Maps
- a heart action for an accepted non-self trusted person on the full map

The UI must always show freshness so stale location/battery data is not presented as live.

## Returning to People / cached state

People reuses the app-level location service, cached latest snapshot and kept-alive page state. Returning to the tab should therefore show the last known live/current state immediately rather than briefly reverting to an uninitialised state while an async refresh completes.

A trusted-person sync failure must not erase the last successfully received locations. The UI should distinguish a secure-sync/unavailable failure from having no connections and offer a retry action without exposing raw Firestore error strings.

## Background location and battery discipline

Modern Android treats background location as a sensitive capability. Homi therefore requests background behavior only from the explicit Live updates flow.

The current Android strategy uses:

- a foreground location service while live sharing is active;
- visible persistent notification;
- medium location accuracy rather than maximum accuracy;
- a 100 m movement threshold;
- spaced update requests rather than continuous maximum-frequency GPS.

This is intended to reduce battery cost, but exact battery behavior must be measured on real devices.

**Do not claim Life360-equivalent force-stop/reboot persistence until it has been proven.** Android may stop or restrict app processes depending on OS and manufacturer behavior. Full production-grade resilience may require additional native Android work, boot/restart handling, foreground-service policy validation and Google Play background-location review.

## Location history

Default architecture favours current state, not indefinite route history.

- latest location remains until replaced or sharing is revoked according to product policy;
- long-term route history is not enabled by default;
- any future recent breadcrumb/history feature must have a specific retention purpose, short retention by default and clear user-facing controls.

## Places and arrival/departure alerts

Places remain an architectural capability for later product implementation rather than an active current screen. Potential examples include Home, Work, School, Gym or a partner's home.

Any arrival/departure alert must be transparent, tied to an authorized location share and easy to disable. Homi must not add a hidden surveillance mode through Places.

## Safety boundaries

Homi is not:

- emergency-service dispatch;
- crash detection;
- a medical or child-safety guarantee;
- a covert tracker;
- proof that a person is safe merely because a recent location exists.

User-facing copy must avoid implying any of those capabilities.

## Notifications and sensitive data

People notifications can include connection activity and the sender name for a heart. They must not include precise coordinates, addresses or hidden household information in lock-screen text.

Notification delivery is not guaranteed emergency communication. Android power management, connectivity, notification permissions and FCM delivery can delay or suppress a message.

The normal People notification preference is separate from the persistent Android foreground-service notification required while live location updates are active.

## Google Play / Android release requirements

Before production release of background location:

- verify background location is essential to the user-facing People feature;
- provide contextual disclosure before permission requests;
- test foreground-only fallback;
- verify persistent-notification behavior;
- test screen off, app background, process recreation and device reboot where supported;
- prepare the Google Play background-location declaration/review material;
- verify all final permission wording against the Android/Play requirements current at release time.
