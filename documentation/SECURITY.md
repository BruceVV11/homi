# Homi security architecture

Date: 2026-09-11
Current source: `0.9.2+13`

This document records Homi's active security boundaries and remaining production gates. It is an engineering document, not user-facing product copy.

## Security goals

Homi handles household information, trusted-person relationships, device notification tokens and precise location. The security model assumes a modified/automated client is hostile. UI checks are convenience only; sensitive authorization is enforced by Firebase Authentication, App Check, Cloud Functions, Firestore rules and IAM.

Primary goals:

- no user reads another user's private household/location state without an explicit allowed relationship;
- clients cannot forge identity, household membership, completion attribution or developer role;
- disconnecting/reclassifying a relationship removes derived access;
- arrival check-ins cannot become arbitrary-recipient notification primitives;
- arrival notifications never need Home/Work address/coordinates;
- exact saved Home/Work sharing requires its own explicit consent and remains narrower than ordinary connection membership;
- check-in-only background samples do not silently refresh cloud latest location when Live updates is off;
- public client credentials alone are not enough to perform cost-generating server actions;
- destructive account operations require recent authentication and remove Homi-managed cloud data;
- backend scale and high-frequency location writes remain bounded.

## Protected mutation boundary

Sensitive collaboration mutations use App-Check-protected callable Functions rather than direct client Firestore writes, including:

- identity/Homi code issuance and lookup;
- connection create/accept/remove;
- relationship/scope changes;
- per-person current-location share authorization;
- shared Task mutation;
- People hearts;
- Home/Work arrival delivery;
- exact Home/Work saved-place sharing;
- developer notification campaigns;
- push device registration/removal;
- cloud account-data deletion.

The only high-frequency collaboration write retained directly from Flutter is the owner's tightly schema/rate-constrained `locations/{uid}` latest-state write.

## Homi connection codes

The code directory is client-inaccessible. Six-character codes are claimed transactionally server-side. `connectWithHomiCode` requires authenticated, App-Check-protected, verified-password-email context and applies hourly/daily lookup limits plus maximum connection count.

## Trusted People separation

Connection, Household/Friend scope, current-location sharing, arrival-recipient selection and precise saved-place visibility are distinct permissions.

Changing Household→Friend removes household Task-derived membership. Removing a connection removes location-share/preference/heart metadata and shared Task-derived access. The replacement `onTrustedConnectionDeleted` trigger now also strips the disconnected UID from any `sharedPlaces` Home/Work viewer lists so a future reconnect cannot revive an old precise-place grant.

The stale historical HTTPS `onConnectionDeleted` export must not be restored.

## Shared Tasks

The server derives authoritative `memberUids` from accepted Household connections. Non-Household friends are excluded. Creator/completer identity comes from Firebase Authentication, not client-provided identity claims. Mutation and cleanup remain server-authorized/rate-limited.

## Latest location

A device can write only its own `locations/{uid}` document. Firestore validates exact allowed fields, coordinate/accuracy/battery bounds, source enum, server timestamp and minimum repeat-write interval.

A viewer reads another user's latest location only with both an accepted connection and active owner→viewer location share.

`LocationStatusService` coordinates one visible Android foreground stream for two independent explicit consumers: Live updates and Arrival check-ins. Arrival-only background samples remain local and do not update the cloud latest-location document.

## Arrival check-ins

The owner's full arrival configuration remains local-first and includes Home/Work coordinates, readable address, optional Google Place ID, radius, arrival recipients, precise-place sharing choice and cooldown state.

Google Places autocomplete is only a setup source. The app fetches the minimal Place ID/address/location fields needed for Homi. The private Android-restricted Places credential is provided outside source and must not be logged/committed.

`sendArrivalCheckIn` remains App-Check/auth protected and:

- requires verified email for password-provider accounts;
- accepts only `home` / `work`;
- accepts max 10 unique non-self recipients;
- revalidates accepted connections;
- skips stale/disconnected recipients;
- applies 20/hour and 60/day sender limits;
- reads at most 12 enabled devices per valid recipient;
- respects People-notification preference;
- receives/sends no saved coordinate or address.

## Exact Home/Work sharing

0.9.2 introduces the optional server-controlled collection:

`sharedPlaces/{ownerUid}/places/{home|work}`

It exists only when the owner explicitly turns on **Show this place to selected people** for that place.

`setSharedArrivalPlace`:

- requires Firebase Authentication + App Check;
- requires verified email for password-provider accounts;
- accepts only Home/Work;
- bounds latitude/longitude, address length and max 10 viewer UIDs;
- revalidates each viewer against an accepted deterministic Homi connection;
- removes the document when no valid viewer remains or the owner clears sharing;
- rate limits changes to 120/hour and 400/day;
- is the only client-facing write path to `sharedPlaces`.

Firestore denies all direct client create/update/delete. Exact reads are allowed to the owner or to another user only when:

1. their UID is present in the server-stored viewer list;
2. their connection to the owner is still accepted;
3. the owner→viewer current-location share is active.

Thus the saved-place document alone is insufficient authorization.

Account deletion has `onHomiUserSharedPlacesDeleted` as an owned-place cleanup backstop. Normal disconnection strips stale viewers via `onTrustedConnectionDeleted`.

## People authentication recovery

The first 0.9.1 device pass exposed a raw `UNAUTHENTICATED` UI state while the Android log also contained Firestore `UNAVAILABLE`/DNS resolution failures.

0.9.2 hardens both boundaries:

- `PeopleHubPage` watches Firebase ID-token identity and recreates the kept-alive map-first People destination when the UID changes/restores;
- `HomiCloudActions` performs one forced Firebase ID-token + App Check-token refresh and one retry after a callable `unauthenticated` response;
- callable codes are translated to finished-product recovery language instead of exposing raw backend identifiers;
- Firestore network/transport failures remain separate and should recover through realtime listeners without clearing last valid People state.

This retry is intentionally bounded to one attempt so broken authorization is not hidden behind loops.

## Emergency controls

Emergency shortcuts use external `tel:` handoff only. Homi does not request direct-call permission, place calls silently, dispatch responders or transmit location merely because an emergency number was tapped.

## Notifications and abuse/cost controls

Existing server limits remain, including People heart cooldowns, arrival limits, connection attempt limits, shared Task limits, developer campaign limits and bounded Function instances. New precise-place mutation limits are 120/hour and 400/day per owner.

Invalid push tokens are disabled. `serverRateLimits` remains server-only.

## Authentication and App Check

Homi supports Google and email/password. Password-provider accounts must verify email before sensitive sharing operations. Account deletion requires recent authentication.

Debug builds use the registered App Check debug provider; release builds must use Play Integrity. Firestore App Check enforcement remains a later production gate after valid-client metrics are proven.

The client-side protected-callable retry refreshes both Firebase Authentication and App Check proof once; it does not bypass either server requirement.

## IAM

Cloud Functions run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

The runtime identity must not receive Owner/Editor. Instance caps remain bounded with zero warm minimum where configured.

## Automated security gate

`bash scripts/test-firestore-security.sh` runs Firestore rules in the emulator and blocks governed deployment on failure.

0.9.2 expands the suite to assert that shared Home/Work:

- is owner-readable;
- is denied to a selected viewer without an accepted connection;
- remains denied with a connection but no active location share;
- becomes readable only with all required grants;
- remains denied to an unrelated account;
- cannot be directly created/updated/deleted by clients.

The actual expanded pass count must be recorded only after Bruce's Cloud Shell run proves it.

## Data deletion

`deleteHomiAccountData` remains App-Check protected, rate-limited and recent-auth protected. Owned precise Home/Work cloud copies are removed by the new server cleanup trigger when the user document is deleted.

**Erase data from this phone** clears local arrival settings and attempts to clear owned exact-place cloud copies. If the cloud is temporarily unreachable, a non-sensitive local pending-clear marker is retained for the next signed-in session. Firestore authorization still requires the connection and active current-location share in the meantime.

An external account-deletion web resource remains required before Play production submission.

## Validation gates for 0.9.2

Before treating 0.9.2 as accepted:

1. `flutter pub get`, `flutter analyze` and `flutter test` on Bruce's Windows toolchain.
2. Governed backend helper after Flutter validation; it must syntax-check Functions and pass the expanded Firestore emulator suite before deploying rules/new Functions.
3. Configure the existing private Android-restricted Places key for the debug run without committing it.
4. S25 Ultra regression: People auth/recovery, map SOS, Google address autocomplete, check-in toggle UI, recipient photos, self Home/Work details.
5. Second-account/device proof: precise-place grant, no-grant denial, location-share-off denial, disconnect revocation and arrival delivery.
6. Later production: Play Integrity, Firestore enforcement after metrics, background-location policy/evidence, cloud alerts, legal URLs/Data Safety and production signing.

Never weaken collection-wide rules merely to resolve one failing operation. Fix the specific contract, rerun the security gate, then deploy.