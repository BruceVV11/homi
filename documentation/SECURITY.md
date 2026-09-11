# Homi security architecture

Date: 2026-09-11
Current source candidate: `0.10.0+14`

Homi handles trusted relationships, device push tokens, household records and precise location. A modified client is treated as hostile. UI checks are convenience only; sensitive authorization belongs in Firebase Authentication, App Check, Cloud Functions, Firestore rules and IAM.

## Security goals

- no private household/location read without an explicit allowed relationship;
- clients cannot forge identity, Household membership, completion attribution or developer role;
- disconnect/reclassification removes derived access;
- arrival delivery cannot become an arbitrary-recipient notification primitive;
- arrival notifications contain no saved Home/Work address/coordinate;
- exact saved-place sharing requires explicit consent and independent current-location authorization;
- check-in-only samples do not silently update cloud latest location;
- high-frequency writes and fan-out remain bounded;
- privacy exits remain available regardless of plan/payment state;
- destructive account operations require recent authentication and remove Homi-managed cloud data.

## Protected mutation boundary

Sensitive collaboration writes use App-Check-protected callable Functions, including identity/code issuance, connection lifecycle, relationship/scope, per-viewer location authorization, shared Tasks, People hearts, arrival delivery, exact saved-place sharing, developer campaigns, device registration and account deletion.

The only high-frequency collaboration write retained directly from Flutter is the owner's tightly validated `locations/{uid}` latest-state write.

## Continuous-location abuse/cost controls

0.10.0 hardens two server-enforced limits:

1. Firestore rejects an update to `locations/{uid}` if the previous server timestamp is less than 90 seconds old.
2. The protected `setLocationShare` callable allows at most five active outbound viewers for a single sender.

The client independently uses the same 90-second cloud gap and Android requests roughly two-minute / 100 m movement updates.

The five-viewer limit applies to active outgoing live authorization, not total trusted connections.

`setLocationShare(active:false)` is deliberately not blocked by accepted-connection validation or the activation rate limiter. A user must always be able to stop sharing. If no share document exists, deactivation is still safe/idempotent.

The callable's deployed name remains `setLocationShare`; the 0.10 module overrides the previous implementation in the Functions entrypoint so deployment does not create a second public API surface.

## Homi+ entitlement security target

`lib/src/domain/homi_plus_plan.dart` records commercial plan definitions only. It is not trusted authorization state.

Paid enforcement must not activate until Google Play purchases are:

- performed through Play Billing;
- sent to a protected Homi backend;
- verified server-side using the Google Play Developer API;
- represented by authoritative server-stored entitlement state;
- kept current through RTDN/Pub/Sub and authoritative Play lookups;
- tested through Play Internal Testing for renewal/cancel/grace/hold/expiry/refund/restore scenarios.

A local purchase callback, cached boolean or editable client record must never grant Homi+ by itself.

Future capability checks should answer server-authoritative questions such as `continuousLocationSender`, `sharedHousehold`, `householdMemberLimit` and `maxTrustedLiveViewers` rather than trusting scattered client `isPaid` flags.

## Location reads

A user writes only their own `locations/{uid}`. Rules validate the exact schema, coordinate/accuracy/battery bounds, allowed source and server timestamp.

A viewer reads another user's latest location only with both an accepted connection and active owner-to-viewer share.

Optional precise `sharedPlaces` reads require explicit viewer selection, accepted connection and active owner-to-viewer current-location share. Clients cannot mutate `sharedPlaces` directly.

## Arrival check-ins

`sendArrivalCheckIn` remains Auth/App-Check protected and validates recipients/server limits. It receives no saved Home/Work coordinate/address. Recipients are revalidated as accepted trusted connections and notification preferences are respected.

## Authentication recovery

`PeopleHubPage` recreates auth-scoped People state when Firebase identity changes/restores. `HomiCloudActions` retries one `unauthenticated` protected call after forced Firebase Auth + App Check refresh, then surfaces product language rather than raw codes.

## Emergency-region safety

Emergency numbers are source-controlled local data, not writable server authorization state. Homi fails closed for unsupported regions rather than inventing a fallback number.

Release governance requires every country offered publicly to be verified against ITU-T E.129 and/or an official national emergency source. Leading-zero numbers are strings.

Emergency taps only hand off to the system phone app with `tel:`. They do not silently place calls or transmit location.

## IAM and backend runtime

Functions run as `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`. The runtime identity must not receive Owner/Editor. Global bounded defaults remain max 5 instances, min 0, 256 MiB unless a smaller Function-specific cap is defined.

## Automated gates

`bash scripts/test-firestore-security.sh` runs the Firestore emulator security suite. 0.10.0 changes the location-rate test so a 60-second repeat is denied, a 120-second-old location can be updated, and an immediate second repeat is denied.

Flutter tests additionally guard the 90-second source/rules alignment and five-viewer Function constant.

Do not weaken collection-wide rules to make a client test pass. Fix the intended contract, rerun the security gate, then deploy.

## Production gates still required

- permanent release signing / Play App Signing fingerprints;
- Play-installed Google Sign-In;
- production Maps/Places key restrictions;
- Play Integrity App Check and later Firestore App Check enforcement after valid traffic metrics;
- billing alerts/spend/monitoring;
- public Privacy Policy/Terms/account-deletion URL;
- Google Play Data Safety and background-location declarations;
- authoritative Play Billing verification before Homi+ gating.
