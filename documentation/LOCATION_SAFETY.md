# Homi Location & Safety

Date: 2026-09-11
Source candidate: `0.10.0+14`

## Non-negotiable privacy model

**Connection, relationship/scope, current-location sharing, arrival delivery and exact saved-place visibility are separate choices.**

- A Homi connection never starts location sharing automatically.
- Household/Friend classification never starts location sharing.
- Live location is granted per viewer by the sender.
- Arrival recipients are chosen per Home/Work place.
- Exact Home/Work visibility is separately off by default.
- Exact Home/Work visibility also requires an active owner-to-viewer location share.
- Arrival monitoring is separately enabled/disabled on the tracked device.
- Background use requires explicit Android background-location permission and a visible foreground-service notification.
- Homi has no stealth-sharing mode.
- Location, Home/Work coordinates and readable addresses must not enter analytics/general logs.
- Arrival push payloads never contain Home/Work coordinates or addresses.

## Continuous live location

The tracked device owns the decision to send.

- Authorization: `locationShares/{ownerUid}/viewers/{viewerUid}`.
- Latest location: `locations/{ownerUid}`.
- Authorized viewers can read only while the accepted connection and active share remain valid.
- Long-term route/breadcrumb history is not stored by default.

Android uses one visible foreground Geolocator stream at medium accuracy with roughly a 100 m movement threshold and roughly two-minute interval.

0.10.0 aligns cost protection with that intended cadence:

- client-side cloud sync gap: 90 seconds;
- Firestore minimum update interval: 90 seconds;
- maximum simultaneous outbound live-location viewers per sender: 5.

The five-viewer cap does not limit normal trusted connections. A user may keep other trusted connections without actively broadcasting to all of them.

Removing/stopping a live viewer is a privacy exit and must always remain possible even if the connection is stale, a rate limit is reached or a subscription later expires.

## Homi+ boundary

Once Google Play billing and authoritative server entitlements are active:

- receiving another person's authorized live location remains free;
- continuously sending your own location requires a Personal/Duo/Household sender seat;
- each sender seat gets the same five-viewer cap;
- no payment state can block stop-sharing, check-in disable, exact-place revoke, data erase or deletion.

0.10.0 adds the plan contract and cost caps but intentionally does not enforce paid entitlement before secure Play verification exists.

## Arrival check-ins

Arrival monitoring and live updates share the same Android foreground location stream but keep separate explicit local requirement flags.

- first fresh current position primes inside/outside state and sends nothing;
- only outside -> inside triggers an arrival;
- leaving requires distance greater than radius + 100 m;
- one-hour local cooldown reduces repeated edge sends;
- check-in-only sampling stays local and does not refresh `locations/{uid}` unless Live updates are independently active;
- turning either feature off leaves the stream running if the other still needs it;
- both off stops the foreground stream.

Arrival delivery uses the protected `sendArrivalCheckIn` callable with only `home|work` plus selected recipient UIDs. It contains no saved address or coordinate.

## Exact Home/Work sharing

A saved Home/Work location can be configured via Google Places or **Set from here**.

The owner sees their own local saved places. Another user sees an exact place only when:

1. the owner enabled **Show this place to selected people**;
2. the viewer is explicitly selected;
3. the connection is accepted;
4. the owner currently has location sharing active to that viewer.

The optional cloud representation is `sharedPlaces/{ownerUid}/places/{home|work}`. Direct client writes are denied. Turning the exact-place switch off removes the cloud copy without deleting local arrival configuration. Disconnect cleanup removes stale viewer access.

## Emergency regions

Emergency shortcuts are offline-first. The selected region is stored on the phone and does not depend on Firebase, mobile data or a location permission.

Onboarding now asks the user to confirm an Emergency region. Device locale may preselect a supported suggestion; the user remains in control and may change it later from the Safety surface.

Homi does not silently change emergency numbers because GPS/geocoding suggests another country. A future travel prompt may offer a change but must require confirmation.

The full map and Safety page use the same regional catalog. Regions without one reliable universal number show service-specific choices instead of an invented SOS target.

All emergency actions use an external `tel:` handoff. Homi does not:

- place the call silently;
- dispatch responders;
- state that responders received a request;
- automatically transmit Homi location data to responders.

The bundled catalog is audited source, not a guarantee of service availability. Public rollout to each country requires release-candidate verification against ITU-T E.129 and/or that country's official emergency authority.

## Google Places and travel

Google Places remains a setup tool for Home/Work, not an emergency-routing source. The private Android-restricted Places credential is provided outside source.

0.10.0 uses the selected region as a country bias for address suggestions. The user still chooses the Google result and can use **Set from here** independently.

## Emergency/local erase

Emergency-region preference is non-sensitive local configuration. Erase-data/account-deletion flows continue to remove the sensitive local/cloud state they own; privacy revocation remains independent from payment.

## Device acceptance still required

Before public release, verify on real devices:

- foreground/background permission progression;
- screen-off/multi-hour/process recreation/reboot behavior;
- Samsung power-saving behavior;
- representative-day battery use;
- real two-account Home/Work arrival transitions;
- five-viewer cap and sixth-viewer denial;
- deactivation at/after cap;
- emergency-region switching and representative dialer targets without completing test emergency calls;
- Play background-location disclosure/review requirements.
