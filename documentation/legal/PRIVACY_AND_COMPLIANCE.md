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
- live-location preference state.

Most household records above are currently stored in SharedPreferences and are **not yet full cloud backups**.

### Cloud/account data

When a user signs in and uses relevant features, Firestore can contain:

- Firebase UID and account/profile metadata;
- Homi connection code;
- trusted connection documents;
- private per-user relationship/scope preferences;
- narrowly shared household Tasks;
- per-person location-sharing authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, update time and source;
- per-device records under the account if/when written by active features.

Firebase Authentication also processes the authentication identity required for email/password or Google sign-in.

### Third-party processors/platforms

Current technical providers include:

- Google Firebase / Google Cloud for authentication and cloud data;
- Google Maps Platform for maps;
- Google Play for Android distribution and future Play Billing.

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

If short location history is introduced later:

- define a specific user purpose;
- choose a short default retention period;
- make retention visible in product copy;
- allow deletion/control;
- update the privacy notice, Data safety form and account-deletion pipeline;
- revisit Firestore cost/read fan-out and security rules.

## Data minimisation principles

- Do not put coordinates, precise addresses, household notes or task text into analytics/general logs.
- Do not collect contact books merely to find Homi users when Homi codes can work.
- Do not store raw passwords.
- Do not create hidden location history.
- Do not make friends Household members merely to enable location sharing.
- Do not make privacy, stop-sharing or account deletion dependent on a paid plan.

## User-facing notices implemented in 0.7

The Account/Homi area now provides in-app sections for:

- Why Homi exists;
- Help & support;
- Privacy & your data;
- Location & safety;
- Terms of use;
- About Homi;
- Erase data from this phone;
- Delete Homi account.

The detailed copy should continue to match actual source behaviour. If cloud sync expands, update the notice in the same pass.

## Account deletion

Google Play requires an app that allows account creation to provide:

- a readily discoverable in-app account-deletion path; and
- an external web resource where users can request account and associated-data deletion.

Official source: https://support.google.com/googleplay/android-developer/answer/13327111

Homi 0.7 adds the in-app deletion flow. The external deletion web resource is still a release blocker and must be published before production submission.

See `documentation/legal/ACCOUNT_DELETION.md`.

## Google Play Data safety preparation

Before public release, reconcile every answer against the exact release build and current SDK list. At minimum review disclosures for:

- precise location;
- account/user IDs;
- email/name/profile photo;
- app interactions/diagnostics if analytics/crash tools are active;
- user-generated household content that is cloud-synced in the eventual release;
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
- account deletion tested for Google and email/password accounts;
- external account-deletion page published;
- Data safety form completed from the actual release build;
- privacy policy hosted at a stable public URL;
- terms hosted at a stable public URL;
- location prominent disclosure reviewed against current Google Play policy;
- background-location declaration/review prepared if required;
- cloud billing budget/alerts configured;
- privacy/security incident response owner defined;
- final POPIA/privacy documents reviewed professionally.
