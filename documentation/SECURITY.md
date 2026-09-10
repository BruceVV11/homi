# Homi security architecture

Date: 2026-09-10
Current source: `0.9.1+12`

This document records Homi's active security boundaries and remaining production gates. It is an engineering document, not user-facing product copy.

## Security goals

Homi handles household information, trusted-person relationships, device notification tokens and precise location. The security model assumes a modified or automated client is hostile. UI checks are convenience only; sensitive authorization is enforced by Firebase Authentication, App Check, Cloud Functions, Firestore rules and IAM.

Primary goals:

- one user must not be able to read another user's private household/location state without an explicit allowed relationship;
- a client must not be able to forge another user's identity, completion attribution, household membership or developer role;
- stopping a relationship or changing it to location-only must revoke household-derived access rather than leave stale Task membership;
- arrival check-ins must not become an arbitrary-notification or arbitrary-recipient primitive;
- Home/Work saved coordinates and readable addresses must not be sent to the arrival-notification backend simply to generate a check-in;
- check-in-only background sampling must not silently refresh cloud latest-location state when Live updates is off;
- public client credentials must not be sufficient to invoke cost-generating server actions without Authentication/App Check/rate limits;
- backend identities must have least privilege and bounded scale;
- destructive account operations require recent authentication and remove Homi-managed cloud data;
- high-frequency location writes must be schema constrained and cost bounded.

## Server-authorized mutation boundary

Sensitive collaboration mutations are not written directly from Flutter to Firestore. The app uses App-Check-protected callable Functions in `africa-south1` for:

- Homi identity/code issuance;
- exact Homi-code lookup and connection creation;
- accepting/removing trusted connections;
- Household/Friend relationship preferences;
- per-person location-share authorization;
- shared Task creation/completion/reopen/removal;
- developer notification campaign creation;
- Homi cloud account-data deletion;
- People heart check-ins;
- Home/Work arrival notification delivery;
- notification device registration/removal.

Firestore clients retain read access only where needed for realtime UI plus the bounded owner latest-location write path. Server Admin SDK operations bypass Firestore rules and are constrained by server authorization checks plus the dedicated runtime IAM identity.

## Homi connection codes

The code directory is client-inaccessible. Six-character codes use an ambiguity-reduced alphabet and are claimed transactionally on the server.

`connectWithHomiCode` requires a signed-in, verified cloud account plus App Check and applies:

- 30 lookup/connection attempts per hour;
- 100 attempts per 24-hour fixed window;
- maximum 30 trusted connections per account;
- deterministic pair document IDs so duplicate pair records cannot be created.

A code is checked against both the server code document and the target user's current Homi profile before a connection is created.

## Trusted People and household separation

Connection, Household scope, location sharing and arrival-recipient selection remain separate concepts.

The backend requires an accepted connection before saving a relationship preference or location share. Changing a person from Household to Friend/location-only removes that person from Tasks created by the user. Removing a connection performs bilateral cleanup of:

- location-share authorizations;
- relationship preferences;
- People heart cooldowns;
- shared-Task membership derived from that relationship.

`onTrustedConnectionDeleted` provides a server cleanup backstop for an administrative/manual connection deletion. The stale historical HTTPS `onConnectionDeleted` resource was replaced/deleted during the completed 0.8.2 deployment migration and must not be restored.

The 0.9.1 People UI restores the approved map-first experience and groups accepted people underneath it. This changes discoverability only; the existing server authorization model is unchanged.

## Shared Tasks

The client does not supply authoritative `memberUids`. When a shared Task is created, the backend derives members from the creator's accepted connections that the creator marked Household. Location-only friends are excluded.

The backend derives creator/completer identity from Firebase Authentication instead of trusting names/UIDs from the client. A completed Task can be reopened only by its creator or the person who completed that occurrence. Active Tasks can be removed only by their creator; completed-history cleanup is server-authorized.

Creation/toggle/removal actions have fixed-window rate limits and Function instance caps.

## Location

Homi stores latest shared location, not default long-term route history.

A device can write only its own `locations/{uid}` document. Firestore validates:

- exact allowed fields;
- latitude/longitude bounds;
- accuracy and battery bounds;
- allowed capture-source values;
- server timestamp;
- minimum 30-second gap between updates to an existing document.

A different user can read a location only when there is both an accepted trusted connection and an active owner-to-viewer location-share record.

### Live updates versus arrival monitoring

`LocationStatusService` coordinates one visible Android foreground location stream for two independent explicit consumers:

- Live updates;
- Arrival check-ins.

The service stores separate local requirement flags. Turning one feature off does not stop the stream while the other still needs it. When neither feature requires it, the stream stops.

Cloud latest-location writes occur only when Live updates is explicitly active for the shared foreground stream. Arrival-only background sampling updates local state for zone detection but does not refresh `locations/{uid}`. Saving Home/Work from the device uses `captureCurrentStatus(syncCloud: false)`, so that action itself does not write the saved place coordinate to the cloud latest-location record.

If Live updates is independently on, its existing latest-location cloud behaviour remains active while the shared stream also serves check-ins.

The normal Android background stream requests approximately two-minute updates with medium accuracy and a 100 m movement filter. The foreground-service notification remains intentionally visible. Homi does not implement stealth mode.

**Production gate:** enforce Firebase App Check for Cloud Firestore only after all intended test installations send valid App Check traffic. Release builds must use Play Integrity, not the debug provider.

## Arrival check-ins

Home/Work arrival places are stored locally in user-scoped device preferences. The current architecture does not create a Firestore collection for saved Home/Work coordinates or readable addresses.

A place can be configured by:

- typed address resolution using the device geocoding layer; or
- Set from here using a local-only current-location capture plus reverse geocoding.

The local detector:

- primes initial inside/outside state without sending;
- emits only outside → inside arrival transitions;
- uses a 100 m exit hysteresis beyond the configured radius;
- applies a one-hour local per-place cooldown;
- creates no route history.

`sendArrivalCheckIn` is an App-Check-protected callable. It:

- requires Firebase Authentication;
- requires verified email for password-provider accounts;
- accepts only `home` / `work` place labels;
- accepts no more than 10 unique non-self selected recipients;
- revalidates every requested UID against an accepted deterministic Homi connection;
- skips stale/disconnected selected UIDs and never notifies them;
- fails if none of the selected UIDs remain valid connections;
- applies sender limits of 20/hour and 60/day;
- reads no more than 12 enabled device records per valid recipient;
- respects each recipient device's People-notification preference;
- receives no Home/Work latitude, longitude or readable address from the client;
- sends no coordinate/address in the push payload.

Arrival notifications are convenience communication, not emergency delivery or proof that the recipient saw the message.

The 0.9.1 address/People/check-in UX refinement does not change the callable request contract or Firestore rules and therefore does not require another backend deployment.

## Emergency call shortcuts

The Safety & check-ins UI uses external `tel:` handoff for the South African emergency shortcuts. Homi deliberately does not request Android direct-call permission or place a call silently.

No Homi server call, trusted-person notification or location transmission is triggered merely by tapping an emergency number. The phone/network handles the call action.

## Notifications and cost controls

Notification fan-out reads at most 12 enabled device registrations per account/recipient path. Invalid FCM tokens are disabled automatically.

Server rate limits currently include:

- People hearts: one minute per sender/recipient pair and 40/day per sender;
- arrival check-ins: one-hour local place cooldown plus 20/hour and 60/day server sender limits;
- connection request notification generation: 20/hour per initiator;
- shared Task creation notification generation: 60/hour per creator;
- Task completion notifications: 120/hour per completing user;
- developer self tests: 30/hour;
- developer broad campaigns: 6/hour and 20/day;
- developer campaign queue actions: 40/hour.

Global Cloud Functions `maxInstances` is 5; high-risk callables have smaller per-function caps. `minInstances` remains zero so Homi does not pay to keep idle instances warm.

Homi Update broadcasts are forced to normal Android delivery priority. Service/security messages may use important/high delivery when genuinely time-sensitive.

The `serverRateLimits` collection is server-only. Clients cannot read, reset or forge counters.

## Authentication

Homi supports Google and email/password accounts. Email/password accounts must verify their email before using sensitive sharing/check-in callables.

`configure-auth-security.sh` configures improved email privacy and the server password policy. The Flutter create-account form mirrors the password baseline, disables inappropriate credential autocorrect/suggestions and uses enumeration-safe password-reset wording.

Account deletion requires Firebase recent reauthentication. The refreshed ID token is checked server-side using `auth_time` before cloud cleanup begins.

## Developer access

Developer notification access is provisioned server-side through `developerAdmins/{uid}`. Normal users can read only their own admin marker and cannot create/update/delete admin records.

Developer campaigns are created through an App-Check-protected callable. Campaign Firestore documents are client-read-only for active developer admins. The backend re-checks admin status before delivery.

## IAM

Cloud Functions run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

The runtime identity must not receive Owner or Editor. The legacy default Compute service account's broad permissions should be reviewed only after all active Functions are proven on the dedicated runtime.

## Automated security gate and deployment

`bash scripts/test-firestore-security.sh` runs Firestore rules in the emulator before backend deployment. `deploy-notification-backend.sh` refuses to deploy when that gate fails.

The suite checks critical allow/deny boundaries including:

- owner-only location writes and explicit shared reads;
- server-only profile/code/connection/preference/share/Task/campaign mutation;
- member-only shared Task reads;
- developer-admin isolation;
- device-registration ownership;
- server-only rate-limit records.

Generated npm dependencies/caches use temporary storage. The deployment helper validates Node 22, prepares a synchronized disposable package lock, runs local `npm ci`, syntax-checks all Function modules, runs the Firestore gate, deploys Firestore separately and deploys discovered Function exports in batches of five.

Bruce confirmed the corrected 0.8.2 backend deployment completed successfully on 10 September 2026. Bruce then confirmed the governed 0.9.0 backend deployment completed without an observed failure, including `sendArrivalCheckIn`.

## Data deletion

`deleteHomiAccountData` is App-Check protected, rate limited and requires recent authentication. Server cleanup covers Homi profile/code state, trusted connections, relationship/share metadata, device registrations, latest location, Homi-created campaigns/rate-limit records and shared Tasks as appropriate.

The Firebase Authentication identity is deleted by the client only after server cleanup succeeds. The shell also clears that UID's locally stored Home/Work check-in configuration after successful deletion, including local readable addresses.

**Erase data from this phone** also clears the signed-in user's local Home/Work check-in configuration and stops local background requirements through the location reset flow. Android permission itself remains controlled by Android.

An external account-deletion web resource remains a Google Play release requirement and must be published before production submission.

## Still required before public release

Security is layered rather than absolute. Before production rollout:

1. Run `flutter analyze` and `flutter test` for the 0.9.1+12 client refinement on Bruce's real Flutter toolchain.
2. Re-run physical-device acceptance on the S25 Ultra. Do not redeploy Firebase unless new backend source changes.
3. Verify Authentication security configuration and Google/email/password flows.
4. Register every active debug tester's App Check token while debug builds are used; never share/commit those tokens.
5. Prove valid App Check traffic and arrival callable authorization/opt-out behaviour.
6. Move store builds to Play Integrity App Check and verify valid traffic from a Play-installed build.
7. Enforce App Check for Cloud Firestore only after legitimate traffic is verified.
8. Configure Cloud Billing alerts/monitoring and review abnormal Function/Firestore activity.
9. Complete multi-device Household sync before claiming household-wide sync for Routines, Supplies and Home.
10. Complete background-location/check-in screen-off, multi-hour, reboot, process-removal and battery testing on multiple Android devices.
11. Publish Privacy Policy, Terms and external account-deletion resource and complete Google Play Data Safety/background-location declarations.
12. Verify local data erasure removes Home/Work check-in coordinates/readable addresses and stops arrival monitoring without weakening explicit Live updates controls.

Never weaken collection-wide rules merely to resolve one failing operation. Capture the exact operation, fix the data contract or server authorization path, rerun the security gate, and only then deploy.