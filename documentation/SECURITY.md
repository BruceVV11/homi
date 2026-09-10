# Homi security architecture

This document records Homi's active security boundaries and the remaining production gates. It is an engineering document, not user-facing product copy.

## Security goals

Homi handles household information, trusted-person relationships, device notification tokens and precise location. The security model therefore assumes that a modified or automated client is hostile. UI checks are convenience only; sensitive authorization is enforced by Firebase Authentication, App Check, Cloud Functions, Firestore rules and IAM.

Primary goals:

- one user must not be able to read another user's private household/location state without an explicit allowed relationship;
- a client must not be able to forge another user's identity, completion attribution, household membership or developer role;
- stopping a relationship or changing it to location-only must revoke household-derived access rather than leave stale task membership;
- public client credentials must not be sufficient to invoke cost-generating server actions without Authentication/App Check/rate limits;
- backend identities must have least privilege and bounded scale;
- destructive account operations require recent authentication and remove Homi-managed cloud data;
- high-frequency location writes must be schema constrained and cost bounded.

## Server-authorized mutation boundary

As of 0.8.2, sensitive collaboration mutations are not written directly from Flutter to Firestore. The app uses App-Check-protected callable Functions in `africa-south1` for:

- Homi identity/code issuance;
- exact Homi-code lookup and connection creation;
- accepting/removing trusted connections;
- Household/Friend relationship preferences;
- per-person location-share authorization;
- shared Task creation/completion/reopen/removal;
- developer notification campaign creation;
- Homi cloud account-data deletion;
- People heart check-ins.

Firestore clients retain read access only where needed for realtime UI. Server Admin SDK operations bypass Firestore rules and are constrained by the dedicated runtime IAM identity.

## Homi connection codes

The code directory is client-inaccessible. Six-character codes use an ambiguity-reduced alphabet and are claimed transactionally on the server.

`connectWithHomiCode` requires a signed-in, verified cloud account plus App Check and applies:

- 30 lookup/connection attempts per hour;
- 100 attempts per 24-hour fixed window;
- maximum 30 trusted connections per account;
- deterministic pair document IDs so duplicate pair records cannot be created.

A code is checked against both the server code document and the target user's current Homi profile before a connection is created.

## Trusted People and household separation

Connection, Household membership and location sharing remain separate concepts.

The backend requires an accepted connection before saving a relationship preference or location share. Changing a person from Household to Friend/location-only removes that person from Tasks created by the user. Removing a connection performs bilateral cleanup of:

- location-share authorizations;
- relationship preferences;
- People heart cooldowns;
- shared-Task membership derived from that relationship.

An `onConnectionDeleted` server trigger provides a cleanup backstop for an administrative/manual connection deletion.

## Shared Tasks

The client no longer supplies authoritative `memberUids`. When a shared Task is created, the backend derives members from the creator's accepted connections that the creator marked Household. Location-only friends are excluded.

The backend also derives creator/completer identity from Firebase Authentication instead of trusting names/UIDs from the client. A completed Task can be reopened only by its creator or the person who completed that occurrence. Active Tasks can be removed only by their creator; completed-history cleanup is server-authorized.

Creation/toggle/removal actions have fixed-window rate limits and Function instance caps.

## Location

Homi stores the latest shared location, not a default long-term route history.

A device can write only its own `locations/{uid}` document. Firestore validates:

- exact allowed fields;
- latitude/longitude bounds;
- accuracy and battery bounds;
- allowed capture-source values;
- server timestamp;
- minimum 30-second gap between updates to an existing document.

The normal Android live mode requests approximately two-minute updates with medium accuracy and a 100 m movement filter. The Flutter client avoids attempting cloud writes inside the Firestore minimum gap.

A different user can read a location only when there is both an accepted trusted connection and an active owner-to-viewer location-share record.

The foreground-service notification is intentionally visible while Android background live location is active. Homi does not implement a stealth mode.

**Production gate:** enforce Firebase App Check for Cloud Firestore after all current test installations send valid App Check traffic. Release builds must use Play Integrity, not the debug provider.

## Notifications and cost controls

Notification fan-out reads at most 12 enabled device registrations per account. Invalid FCM tokens are disabled automatically.

Server rate limits currently include:

- People hearts: one minute per sender/recipient pair and 40/day per sender;
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

Homi supports Google and email/password accounts. Email/password accounts must verify their email before using sensitive sharing callables.

`configure-auth-security.sh` enables:

- Firebase/Identity Toolkit improved email privacy (email enumeration protection);
- enforced new-password policy: 10-128 characters, uppercase, lowercase and a number;
- no forced password upgrade on existing test accounts at sign-in.

The Flutter create-account form mirrors the password policy, disables autocorrect/suggestions for credentials and uses enumeration-safe password-reset wording.

Account deletion requires Firebase recent reauthentication. The refreshed ID token is checked server-side using `auth_time` before cloud cleanup begins.

## Developer access

Developer notification access is provisioned server-side through `developerAdmins/{uid}`. Normal users can read only their own admin marker and cannot create/update/delete admin records.

Developer campaigns are created through an App-Check-protected callable. Campaign Firestore documents are client-read-only for active developer admins. The backend re-checks admin status before delivery.

## IAM

Cloud Functions run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

The runtime identity must not receive Owner or Editor. `prepare-function-runtime-iam.sh` grants only the application/runtime roles Homi needs and grants the deployer only the ability to act as this service account.

The legacy default Compute service account's broad permissions should be reviewed only after the dedicated runtime has been proven across all deployed Functions.

## Automated security gate

`bash scripts/test-firestore-security.sh` runs Firestore rules in the emulator before backend deployment. `deploy-notification-backend.sh` refuses to deploy when that gate fails.

The suite checks critical allow/deny boundaries including:

- owner-only location writes and explicit shared reads;
- server-only profile/code/connection/preference/share/Task/campaign mutation;
- member-only shared Task reads;
- developer-admin isolation;
- device-registration schema ownership;
- server-only rate-limit records.

Generated npm dependencies and caches use temporary storage so Cloud Shell's persistent disk does not accumulate release tooling.

## Data deletion

`deleteHomiAccountData` is App-Check protected, rate limited and requires a recent authentication timestamp. Server cleanup covers Homi profile/code state, trusted connections, relationship/share metadata, device registrations, latest location, Homi-created campaigns/rate-limit records and shared Tasks as appropriate.

The Firebase Authentication identity is deleted by the client only after server cleanup succeeds. Local household data is then cleared from that device.

An external account-deletion web resource remains a Google Play release requirement and must be published before production submission.

## Still required before public release

Security is layered rather than absolute. Before production rollout, complete all of these gates:

1. Run Flutter analyzer/tests for 0.8.2 and deploy the Functions/rules only after the emulator security suite passes.
2. Run `configure-auth-security.sh` and verify Authentication still works for Google, verified email/password, reset and verification flows.
3. Register every active debug tester's App Check token while debug builds are being used. Never share those tokens or commit them.
4. Move store builds to Play Integrity App Check and verify valid traffic from a Play-installed build.
5. Enforce App Check for Cloud Firestore and Authentication once legitimate traffic is verified; keep callable Functions' source enforcement enabled.
6. Configure Cloud Billing alerts and, where available, a project/service spend cap for Cloud Run functions. Instance/rate limits reduce exposure but are not a financial hard stop.
7. Review Cloud/Firebase metrics for abnormal authentication, Firestore, Function and notification activity.
8. Complete multi-device Household sync with a conflict-safe model before claiming household-wide sync for Routines, Supplies and Home.
9. Complete background-location screen-off/reboot/process-removal/battery testing on multiple Android devices.
10. Publish the Privacy Policy, Terms and external account-deletion resource and complete Google Play's Data Safety/background-location declarations.

Never weaken collection-wide rules merely to resolve one failing operation. Capture the exact operation, fix the data contract or server authorization path, rerun the security gate, and only then deploy.
