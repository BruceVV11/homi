# Homi privacy, legal and launch compliance draft

Date: 2026-09-10
Status: internal working product/legal draft. Obtain professional South African legal review before public production release.

## Product position

Homi is a household operating system with optional trusted-person location sharing. The app is intentionally local-first where practical and does not require an account for local-only household use.

Homi must not be presented as:

- an emergency dispatch service;
- a covert tracker;
- proof that a person is safe;
- crash detection;
- a medical or child-safety guarantee.

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
- Homi notification category preferences;
- a random Homi installation/device identifier used to associate a signed-in FCM token with that app installation;
- local scheduled-notification IDs and de-duplication keys.

Most household records above are stored in SharedPreferences and are not a full cloud backup unless the relevant product surface explicitly identifies them as shared.

### Cloud/account data

When a user signs in and uses relevant features, Firestore can contain:

- Firebase UID and account/profile metadata;
- Homi connection code;
- trusted connection documents;
- private per-user relationship/scope preferences;
- narrowly shared household Tasks;
- per-person location-sharing authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, update time and source;
- per-device FCM registration token and notification-category preferences when notifications are enabled;
- developer notification campaign metadata only for authorised developer accounts.

Firebase Authentication processes the authentication identity required for email/password or Google sign-in.

Server-only notification data can include short-lived heart anti-spam/cooldown records. Client Firestore rules deny direct access to those documents.

### Third-party processors/platforms

Current technical providers include:

- Google Firebase / Google Cloud for authentication, Firestore, Cloud Functions and Firebase Cloud Messaging;
- Google Maps Platform for maps;
- Google Play for Android distribution and paid Android digital products when Homi+ is offered.

A final privacy policy must link/describe relevant provider processing accurately and align with the Play Console Data safety form.

## Location purpose and notice

Homi location exists for consensual trusted-person check-ins. A trusted person may be a partner, relative, roommate, caregiver or friend.

The product must keep these decisions separate:

1. connecting two Homi accounts;
2. privately classifying the relationship/scope;
3. enabling location visibility for that individual person;
4. enabling live/background updates on the sharing device.

A connection alone must never start location sharing. Household status alone must never start location sharing.

### Background location disclosure

Before requesting background location in a production flow, clearly explain:

- why background access is needed to keep user-selected live location current when Homi is not open;
- that the sharing user chooses who may see the location;
- that Android shows a persistent foreground-service notification while Homi live updates are active;
- how to stop Homi live updates;
- how to revoke a specific person's access;
- that Android/device conditions can make location delayed or inaccurate.

The disclosure must appear before the sensitive permission request, not only in a privacy policy.

## Location retention

Current product architecture stores latest-state location by default, not long-term route history.

If short location history is introduced, define the user purpose and retention before release of that capability, expose the retention/control in product copy, update the Data safety form and deletion pipeline, and revisit Firestore fan-out/cost/security rules.

## Notifications

### Purpose

Homi notifications have three distinct purposes:

- household attention such as due Tasks/Routines, out-of-stock Supplies, expiry and saved maintenance dates;
- trusted-person/collaboration events such as connection requests, shared-Task activity and a user-initiated heart;
- product/service/security notices sent by an authorised Homi developer.

The persistent Android notification shown during live background location sharing is operational disclosure for the foreground service and is separate from optional reminder categories.

### Consent and control

Normal notification permission is not requested at first launch. The user enables notifications from Homi & account and can separately control:

- Household attention;
- Tasks & routines;
- People;
- Homi updates;
- Service & security.

A master off switch applies to the current installation. The app must not make location consent, stop-sharing, privacy or account deletion conditional on notification permission.

### FCM tokens and topics

A Firebase Cloud Messaging registration token identifies an app installation for message routing. It must be treated as account/device delivery metadata rather than an advertising identifier.

For signed-in devices, the token is stored at `users/{uid}/devices/{deviceId}` only while the installation has Homi notifications enabled. Sign-out removes the token from that account/device record. Account deletion removes the device records.

Developer broadcasts use category topics (`homi_updates`, `homi_service`, `homi_security`) so local-only installations can receive user-enabled product/service notices without account creation. Topic membership is changed when the user changes those Homi categories.

### Sensitive notification content

Lock-screen notification text can be visible without unlocking the phone. Therefore:

- do not put precise coordinates or addresses in push notification payloads;
- do not include household Task titles in server-generated shared-Task lock-screen notifications;
- do not include household notes or Supply/Home content in developer broadcasts;
- a People heart may show the sender display name because that identity is the purpose of the check-in;
- a developer broadcast should contain only the message the authorised developer explicitly composes.

Notification delivery is not an emergency mechanism and does not prove that the recipient saw a message.

## People hearts

A heart is a lightweight trusted-person interaction from the People map.

- sender must be authenticated;
- recipient must be an accepted trusted connection;
- heart sending does not change location sharing or household scope;
- server-side sender→recipient cooldown reduces accidental/spam repetition;
- recipient notification can identify the sender by display name;
- the feature is not an emergency/safety acknowledgement.

## Data minimisation principles

- Do not put coordinates, precise addresses, household notes or task text into analytics/general logs.
- Do not collect contact books merely to find Homi users when Homi codes can work.
- Do not store raw passwords.
- Do not create hidden location history.
- Do not make friends Household members merely to enable location sharing.
- Do not make privacy, stop-sharing or account deletion dependent on a paid plan.
- Do not keep dead FCM registration tokens indefinitely; disable/remove tokens that FCM reports as invalid/unregistered.
- Do not use developer notifications as an unrestricted marketing backdoor. User category controls must be respected.

## User-facing notices implemented in 0.8

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

User-facing product wording must read as finished-product copy. Internal engineering/legal documents may still identify verification or release obligations so unfinished infrastructure is not misrepresented to the team.

## Account deletion

Google Play requires an app that allows account creation to provide:

- a readily discoverable in-app account-deletion path; and
- an external web resource where users can request account and associated-data deletion.

Official source: https://support.google.com/googleplay/android-developer/answer/13327111

The in-app deletion flow removes account-linked client-visible notification device data. A server-side user-deletion trigger also removes Homi notification metadata that clients cannot access directly, including heart cooldown records, developer-admin access for the deleted UID and developer campaign records created by that account.

The external deletion web resource remains a production-release blocker and must be published before store submission.

See `documentation/legal/ACCOUNT_DELETION.md`.

## Google Play Data safety preparation

Before public release, reconcile every answer against the exact release build and SDK list. At minimum review disclosures for:

- precise location;
- account/user IDs;
- email/name/profile photo;
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
- notification delivery limitations;
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

- App Check valid traffic confirmed, then enforcement enabled deliberately;
- release/Play App Signing SHA credentials registered;
- Firestore rules tested against allowed and denied paths;
- Cloud Functions notification triggers/callable functions tested with valid and invalid users;
- developer notification admin provisioning/revocation tested;
- notification category opt-outs verified for direct sends and broadcast topics;
- account deletion tested for Google and email/password accounts, including server-only notification metadata cleanup;
- external account-deletion page published;
- Data safety form completed from the actual release build;
- privacy policy hosted at a stable public URL;
- terms hosted at a stable public URL;
- location prominent disclosure reviewed against current Google Play policy;
- background-location declaration/review prepared if required;
- cloud billing budget/alerts configured;
- privacy/security incident response owner defined;
- final POPIA/privacy documents reviewed professionally.
