# Homi privacy, legal and launch compliance draft

Date: 2026-09-10
Status: internal working product/legal draft. Obtain professional South African legal review before public production release.

## Product position

Homi is a household operating system with optional trusted-person location sharing and user-configured arrival check-ins. The app is intentionally local-first where practical and does not require an account for local-only household use or emergency-number shortcuts.

Homi must not be presented as:

- an emergency dispatch service;
- a covert tracker;
- proof that a person is safe;
- crash detection;
- a medical or child-safety guarantee;
- guaranteed delivery of an arrival/check-in notification.

Initial account eligibility should be positioned for adults (18+) until any minor-specific use case has undergone separate privacy, consent, Google Play Families and legal review.

## South African privacy baseline

Homi is developed in South Africa and must be assessed against the Protection of Personal Information Act 4 of 2013 (POPIA), including the security-safeguard requirement to use appropriate reasonable technical and organisational measures to protect personal information.

Official source: https://www.justice.gov.za/legislation/acts/2013-004.pdf

Before launch, the final privacy notice must identify the legally correct responsible party/operator details, physical/contact details where required, information-officer process and data-subject request channel. Do not guess those legal particulars in code.

## Data currently processed

### Local/device data

Current local-first records can include:

- home name/type;
- one-off Tasks;
- recurring Routines and completion attribution;
- Supplies, quantities, status and expiry dates;
- Home Things/appliances/equipment;
- maintenance/repair history;
- utility readings;
- legacy local reminders;
- latest cached current-device location/battery state;
- live-location preference state;
- Home and Work arrival-check-in coordinates, radius, selected trusted-recipient UIDs and most recent local check-in send time;
- Homi notification category preferences;
- a random Homi installation/device identifier used to associate a signed-in FCM token with that app installation;
- local scheduled-notification IDs and de-duplication keys.

Most household records above are stored in SharedPreferences and are not a full cloud backup unless the relevant product surface explicitly identifies them as shared.

Home/Work arrival coordinates are intentionally local to the device in the current architecture. They are not sent to `sendArrivalCheckIn` and are not added to the push payload.

### Cloud/account data

When a user signs in and uses relevant features, Firestore/Cloud Functions can process:

- Firebase UID and account/profile metadata;
- Homi connection code;
- trusted connection documents;
- private per-user relationship/scope preferences;
- narrowly shared household Tasks;
- per-person location-sharing authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, update time and source;
- per-device FCM registration token and notification-category preferences when notifications are enabled;
- developer notification campaign metadata only for authorised developer accounts;
- server rate-limit records for protected operations including arrival check-ins.

For an arrival check-in, the protected callable receives the place label (`home` or `work`) and the selected accepted trusted-recipient UIDs. It does not receive the user's saved Home/Work coordinates.

Firebase Authentication processes the authentication identity required for email/password or Google sign-in.

Server-only notification data can include short-lived heart anti-spam/cooldown and fixed-window rate-limit records. Client Firestore rules deny direct access to those records.

### Third-party processors/platforms

Current technical providers include:

- Google Firebase / Google Cloud for authentication, Firestore, Cloud Functions and Firebase Cloud Messaging;
- Google Maps Platform for maps;
- the user's telephone/network provider for emergency calls opened from Homi;
- Google Play for Android distribution and paid Android digital products when Homi+ is offered.

A final privacy policy must link/describe relevant provider processing accurately and align with the Play Console Data safety form.

## Emergency call shortcuts

Homi exposes South African emergency numbers as call shortcuts under People → Safety & check-ins. Tapping a shortcut hands the number to the device phone application through a `tel:` URI.

Homi does not:

- silently place the call;
- request direct-call permission for this feature;
- dispatch emergency responders;
- automatically send a user's location to emergency services;
- represent that an emergency call was connected or acted upon.

This distinction must remain visible in user-facing safety copy.

## Location purpose and notice

Homi location exists for consensual trusted-person location sharing and explicitly configured arrival check-ins. A trusted person may be a partner, relative, roommate, caregiver or friend.

The product must keep these decisions separate:

1. connecting two Homi accounts;
2. privately classifying the relationship/scope;
3. enabling location visibility for that individual person;
4. enabling live/background location updates on the sharing device;
5. selecting that person as a Home and/or Work arrival-check-in recipient;
6. enabling arrival check-ins.

A connection alone must never start location sharing or arrival check-ins. Household status alone must never start either capability.

### Arrival check-in data minimisation

The current arrival detector runs locally against the latest device location and the user's locally saved Home/Work coordinates.

- initial inside/outside state is primed without sending a message;
- only an outside → inside transition produces a check-in;
- check-ins use an exit margin and local cooldown to reduce GPS-edge duplicates;
- the callable receives no saved latitude/longitude;
- the lock-screen payload contains no precise coordinate/address;
- no route history is created by the feature.

The recipient must already be an accepted Homi trusted connection. Server authorization re-checks that relationship at send time so an old local recipient selection cannot be used to notify a disconnected account.

### Background location disclosure

Before requesting background location in a production flow, clearly explain:

- why background access is needed to keep user-selected live location/check-ins working when Homi is not open;
- that the sharing/check-in user chooses who may see location or receive an arrival event;
- that Android shows a persistent foreground-service notification while Homi live location/check-ins are active;
- how to stop Homi live updates and arrival check-ins;
- how to revoke a specific person's access;
- that Android/device conditions can make location delayed or inaccurate;
- that force-stopping the app can interrupt background operation until Homi is opened again.

The disclosure must appear before the sensitive permission request, not only in a privacy policy.

## Location retention

Current product architecture stores latest-state location by default, not long-term route history.

Home/Work check-in coordinates and the last local check-in send time stay on the device in the current implementation. The backend receives only the event label and recipients for delivery/rate-limit processing.

If short location history is introduced, define the user purpose and retention before release of that capability, expose the retention/control in product copy, update the Data safety form and deletion pipeline, and revisit Firestore fan-out/cost/security rules.

## Notifications

### Purpose

Homi notifications have four distinct purposes:

- household attention such as due Tasks/Routines, out-of-stock Supplies, expiry and saved maintenance dates;
- trusted-person/collaboration events such as connection requests, shared-Task activity and a user-initiated heart;
- Home/Work arrival check-ins explicitly configured by the sender;
- product/service/security notices sent by an authorised Homi developer.

The persistent Android notification shown during live background location/check-ins is operational disclosure for the foreground service and is separate from optional reminder categories.

### Defaults, permission and control

On a fresh `0.9.0+11` installation, useful operational Homi categories default enabled in local app preferences:

- Household attention;
- Tasks & routines;
- People;
- Service & security.

The master operational-notification preference also defaults on. **Homi updates/product announcements remain off until explicitly enabled.**

Android controls whether Homi is actually allowed to display normal notifications. Homi asks for that system permission once on a fresh install; denial/dismissal is not repeatedly forced on later launches. The user can retry from Homi & account → Notifications or Android Settings.

Existing saved preferences remain authoritative. Homi must not silently reactivate notifications for an existing user who deliberately turned them off.

A master off switch applies to the current installation. The app must never make location consent, stop-sharing, privacy or account deletion conditional on notification permission.

### FCM tokens and topics

A Firebase Cloud Messaging registration token identifies an app installation for message routing. It must be treated as account/device delivery metadata rather than an advertising identifier.

For signed-in devices, registration is stored at `users/{uid}/devices/{deviceId}` only for the current installation and is managed through protected callable Functions. Sign-out/account deletion removes Homi-managed registration state.

Developer broadcasts use category topics (`homi_updates`, `homi_service`, `homi_security`) so local-only installations can receive user-enabled product/service notices without account creation. Topic membership follows the Homi category choices.

### Sensitive notification content

Lock-screen notification text can be visible without unlocking the phone. Therefore:

- do not put precise coordinates or addresses in push notification payloads;
- do not include saved Home/Work coordinates in arrival check-ins;
- do not include household Task titles in server-generated shared-Task lock-screen notifications;
- do not include household notes or Supply/Home content in developer broadcasts;
- a People heart may show the sender display name because that identity is the purpose of the check-in;
- an arrival check-in may show the sender name and Home/Work label because those are the explicitly selected event details;
- a developer broadcast should contain only the message the authorised developer explicitly composes.

Notification delivery is not an emergency mechanism and does not prove that the recipient saw a message.

## People hearts and arrival check-ins

A heart is a lightweight trusted-person interaction from the People map. Arrival check-ins are a separate opt-in Home/Work transition feature.

Both require:

- an authenticated sender;
- an accepted trusted connection to the recipient;
- server-side abuse controls;
- recipient People-notification eligibility.

Neither capability silently changes location visibility or Household/Friend scope.

## Data minimisation principles

- Do not put coordinates, precise addresses, household notes or Task text into analytics/general logs.
- Do not send saved Home/Work coordinates through the arrival callable merely to generate a notification.
- Do not collect contact books merely to find Homi users when Homi codes can work.
- Do not store raw passwords.
- Do not create hidden location history.
- Do not make friends Household members merely to enable location sharing/check-ins.
- Do not make privacy, stop-sharing or account deletion dependent on a paid plan.
- Do not keep dead FCM registration tokens indefinitely; disable/remove invalid/unregistered tokens.
- Do not use developer notifications as an unrestricted marketing backdoor. User category controls must be respected.

## User-facing controls

The Account/Homi area provides in-app sections for:

- Why Homi exists;
- Notifications;
- Help & support;
- Privacy & your data;
- Location & safety;
- Terms of use;
- About Homi;
- Erase data from this phone;
- Delete Homi account.

People now also provides **Safety & check-ins** for emergency shortcuts and Home/Work check-in configuration.

User-facing wording must read as finished-product copy. Internal engineering/legal documents may still identify verification or release obligations so unfinished infrastructure is not misrepresented to the team.

## Account deletion

Google Play requires an app that allows account creation to provide:

- a readily discoverable in-app account-deletion path; and
- an external web resource where users can request account and associated-data deletion.

Official source: https://support.google.com/googleplay/android-developer/answer/13327111

The Homi shell clears user-scoped local arrival-check-in settings after successful in-app account deletion. Server-side account cleanup removes Homi-managed collaboration/notification/rate-limit data according to the account deletion pipeline.

The external deletion web resource remains a production-release blocker and must be published before store submission.

See `documentation/legal/ACCOUNT_DELETION.md`.

## Google Play Data safety preparation

Before public release, reconcile every answer against the exact release build and SDK list. At minimum review disclosures for:

- precise/background location;
- locally saved Home/Work check-in places;
- account/user IDs;
- email/name/profile photo;
- trusted connection relationships and arrival-recipient selections;
- device/app identifiers used for push delivery;
- notification/Firebase Cloud Messaging processing;
- app interactions/diagnostics if analytics/crash tools are active;
- user-generated household content that is cloud-synced in the release;
- data encryption in transit;
- account deletion availability;
- optional vs required collection;
- sharing vs service-provider processing.

Do not copy another app's Data safety answers.

## Terms topics requiring formal review

Final Terms of Use should cover at least:

- adult account eligibility;
- lawful/consensual use;
- prohibition on covert tracking/harassment;
- no emergency or safety guarantee;
- emergency-shortcut limitations;
- notification/check-in delivery limitations;
- service availability limitations;
- user responsibility for entered content;
- subscription/renewal/cancellation terms once Homi+ exists;
- intellectual property/licence;
- acceptable use;
- limitation of liability to the extent lawful;
- governing law/jurisdiction;
- material-change notice;
- termination/account deletion;
- support/contact details.

## Security/release checklist

Before production:

- App Check valid traffic confirmed, then enforcement enabled deliberately where planned;
- release/Play App Signing SHA credentials registered;
- Firestore rules tested against allowed and denied paths;
- Cloud Functions protected callables tested with valid and invalid users;
- `sendArrivalCheckIn` tested for valid recipients, disconnected recipients, App Check rejection and rate limiting;
- People notification opt-out verified for arrival check-ins;
- Home/Work coordinates verified absent from callable/push payloads/logs;
- developer notification admin provisioning/revocation tested;
- notification category opt-outs verified for direct sends and broadcast topics;
- account deletion tested for Google and email/password accounts, including local arrival settings and server-only metadata cleanup;
- external account-deletion page published;
- Data safety form completed from the actual release build;
- privacy policy hosted at a stable public URL;
- terms hosted at a stable public URL;
- location prominent disclosure reviewed against current Google Play policy;
- background-location declaration/review prepared if required;
- cloud billing budget/alerts configured;
- privacy/security incident response owner defined;
- final POPIA/privacy documents reviewed professionally.
