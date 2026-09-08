# Homi Location & Safety Concept

## Purpose

Homi can extend beyond the physical household by letting a user share location with trusted people they choose. This is intended to support everyday reassurance and coordination in the same warm, practical spirit as the rest of Homi.

This feature is **not limited to family or household members**. A trusted person may be a partner, friend, parent, child (subject to legal/guardian requirements), housemate, caregiver, or other person with whom the user has an appropriate relationship.

## Product principle

**Location sharing must always be explicit, visible, reversible, and understandable.**

No person should be trackable without clear opt-in from the device/account being tracked.

## Working feature name

The consumer-facing name should avoid sounding like surveillance. Current working candidates:
- Circle
- Close
- Nearby
- People
- Trusted

The underlying model will use `trustedCircles` and `locationShares` until naming is final.

## Core experience

A user can:
1. Create or join a trusted circle.
2. Invite another Homi user.
3. Choose whether to share live location.
4. Choose the sharing duration/state.
5. See exactly who can currently see their location.
6. Pause or stop sharing at any time.
7. See trusted people on a map when those people are actively sharing.

## Initial shared signals

When a trusted person explicitly shares them, Homi may display:
- latest latitude/longitude
- location timestamp / freshness
- approximate or precise location, depending on permission and user setting
- battery percentage
- charging state
- device online/offline freshness
- optional motion/activity state later, subject to platform permissions and value

Battery data should be treated as convenience information, not emergency-grade telemetry.

## Places and arrivals

Later passes may support user-defined Places such as:
- Home
- Work
- School
- Gym
- Partner's home

A user may opt into arrival/departure notifications for a specific trusted person and Place. These alerts must be mutually transparent and easy to disable.

## Privacy and safety rules

- Location sharing is opt-in per person/device.
- Inviting someone does not start sharing automatically.
- Background location requires a separate, contextual explanation and permission flow.
- The app must show an obvious persistent indicator/state when continuous sharing is enabled.
- A user can pause sharing without leaving a circle.
- A user can leave a circle and revoke access.
- Historical location should be minimized by default.
- Homi should not expose a hidden "stealth" mode.
- Homi should not silently restart sharing after a user has explicitly disabled it.
- Sensitive location data must never appear in analytics, crash reports, or general logs.
- Access rules must ensure only explicitly authorized participants can read a member's location data.

## Data-retention direction

Default architecture should favour **current-state location**, not indefinite history.

Recommended initial retention:
- latest location record: retained until replaced/revoked
- transient recent breadcrumbs: only if needed for reliable movement/arrival logic, with short TTL
- no long-term route history in v1

If paid history is introduced later, it should be a separate explicit product decision with clear retention controls.

## Suggested backend shape

```text
users/{uid}
trustedCircles/{circleId}
trustedCircles/{circleId}/members/{uid}
locationShares/{uid}/{viewerUid}
locations/{uid}/current
locations/{uid}/recent/{sampleId}   # optional TTL-limited
places/{uid}/{placeId}
placeAlerts/{ownerUid}/{alertId}
```

The sharing authorization must be evaluated server-side/security-rule-side; the client must never be trusted to decide who may read location.

## Update strategy

Continuous GPS polling would damage battery life and increase backend usage. Homi should use an adaptive strategy:
- foreground map open: higher-frequency updates
- moving in background: moderate updates
- stationary/background: substantially reduced updates
- low battery: reduce frequency unless user explicitly selects a higher-accuracy mode
- significant movement / platform location events where available

The exact intervals must be validated on real Android devices rather than hard-coded from assumptions.

## Android constraints

Modern Android requires foreground/background location permissions to be handled separately. Continuous background tracking generally requires a location foreground service with a persistent notification. Google Play also applies additional review/policy requirements when an app requests background location.

This means Homi must prove that background location is a core user-facing feature, explain it before requesting the permission, and provide meaningful functionality even when the user grants only foreground location.

## Battery information

Battery percentage and charging state can be collected locally and synchronized alongside the location heartbeat. The UI should show the last-updated time so stale battery values are not presented as live.

## Monetization fit

Location can support a future paid tier without paywalling basic safety controls.

Potential free layer:
- one trusted circle
- live/current location
- battery status
- limited Places

Potential paid layer later:
- more circles/people
- more Places and arrival alerts
- short location history
- advanced safety check-ins
- richer household backup/storage features

Pricing is deliberately not locked yet. The app architecture should use entitlement flags from the start so future paid features do not require a destructive data-model rewrite.

## Out of scope for first pass

- covert tracking
- indefinite location history
- driving-score/risk scoring
- crash detection
- emergency-service dispatch
- insurance integrations
- monitoring a non-Homi device without the device owner's consent
