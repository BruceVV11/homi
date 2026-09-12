# Homi privacy, legal and launch compliance draft

Date: 2026-09-12
Status: internal working product/legal draft for `0.13.0+17`. Obtain professional South African legal review before public production release.

## Product position

Homi is a household operating system with local-first household tools, optional Shared Household synchronization, trusted-person location sharing, user-configured arrival check-ins, separately optional exact Home/Work sharing and optional Homi+ subscriptions through Google Play.

Local household use and emergency-number shortcuts do not require an account. Homi must not be represented as emergency dispatch, covert tracking, proof that somebody is safe, crash detection, medical/child-safety guarantee or guaranteed check-in delivery.

Initial account eligibility should remain adults (18+) until any minor-specific use case receives separate privacy/consent/Google Play Families/legal review.

## South African privacy baseline

Homi is developed in South Africa and must be assessed against POPIA, including appropriate reasonable technical and organisational safeguards.

Before launch, the final notice must identify the legally correct responsible party/operator details, contact details, information-officer process and data-subject request channel. Do not invent these values in code.

## Local/device data

Depending on features used, Homi can store locally:

- home name/type;
- private/shared Tasks and attribution;
- Routines;
- Supplies;
- Home Things, maintenance/repair history and utility readings;
- cached current-device location/battery;
- background location preference state;
- Home/Work arrival coordinates, readable address, optional Place ID, radius, recipients, exact-place sharing preference and cooldown state;
- notification preferences;
- installation/push registration context;
- local Shared Household synchronization lineage.

SharedPreferences remains the immediate local-first persistence layer. From 0.12, selected canonical Shared Household domains can also synchronize to Firestore.

Local-only mode does not start Shared Household synchronization merely because Firebase still has a cached identity.

Pre-existing unmatched device records are not silently uploaded merely because somebody joins a Household. The narrow automatic first-import case requires the first owner, a device that has not synchronized another Household and an authoritative server read confirming an empty Household data collection. Otherwise older unmatched records remain device-private until an explicit future import/merge choice.

## Cloud/account data

When the user signs in and enables relevant features, Firebase/Google Cloud can process:

- Firebase UID/account/profile metadata;
- reusable Homi connection code;
- trusted connection records and private relationship labels;
- canonical Household identity/membership/ownership/invitations;
- Shared Household Routines, Supplies, Home Things, maintenance/repair and utility records;
- shared one-off Tasks and assignment/completion attribution;
- per-person current-location authorization;
- latest shared latitude/longitude, accuracy, battery, charging state, source/update time;
- FCM device registration/notification preferences;
- rate-limit/cooldown metadata;
- optional exact Home/Work cloud copies when explicitly enabled;
- Homi+ entitlement/billing metadata described below.

Shared Household records use:

`households/{householdId}/data/{domain--itemId}`

Access requires the signed-in account to remain a current canonical member through both the membership pointer and parent Household member list.

## Homi+ / Google Play billing data

0.13 introduces Google Play subscription processing. Homi does **not** collect card/bank details. Google Play handles checkout/payment method/tax/customer transaction processing according to Google's terms.

Homi processes only the subscription information required to associate and verify Homi+ access, including:

- Google Play subscription product/base-plan identifier;
- purchase token received from the Play Billing client and stored only in backend-restricted Homi billing state;
- SHA-256-derived token hash/internal lookup identifiers;
- Google Play order/lifecycle/acknowledgement metadata returned by Android Publisher;
- a SHA-256-derived opaque Homi account identifier used as Play's obfuscated external account identifier rather than the raw Firebase UID;
- Homi purchaser UID inside server-restricted billing records;
- Homi+ plan/state/capability projection;
- Duo secondary-seat account where applicable;
- canonical Household identifier/members covered by Household Homi+ where applicable;
- subscription validity/expiry metadata;
- Pub/Sub/RTDN processing metadata needed to refresh lifecycle state.

Client Firestore access is restricted to the signed-in user's own narrow `entitlements/{uid}` projection. Raw purchase tokens, purchaser mapping, billing-account links and per-source coverage are backend-only.

The Homi client never grants paid access merely because a device reports a successful purchase. The backend verifies current state against Google Play and acknowledges the purchase where required before authoritative entitlement is projected.

RTDN notifications are treated as change signals; Homi re-fetches authoritative state from Android Publisher rather than treating the notification payload itself as entitlement truth.

A person may have multiple entitlement sources, such as their own Personal subscription plus coverage from another purchaser's Household plan. Backend-only coverage records are reduced into one entitlement projection so ending one source does not erase a separate still-valid source.

### Account deletion and subscriptions

Deleting a Homi account and canceling a Google Play subscription are separate operations. Homi deletion removes Homi-side billing mappings/coverage but does not silently cancel the Play subscription. User-facing deletion UI and the public account-deletion page must state this clearly and provide Google Play subscription-management guidance.

## Google Places processing

For Home/Work setup, Homi can use Google Places API (New) through the native Places SDK wrapper. Homi sends the user's autocomplete query to Google Places and, after selection, requests only the Place ID, formatted address and coordinate required to save the place. Google's attribution is displayed with results.

**Set from here** remains a separate route using current device location/reverse geocoding where available.

The Maps/Places Android credential is package/SHA restricted and must not be committed or logged.

## Third-party processors/platforms

Current providers/features include:

- Google Firebase / Google Cloud: Auth, Firestore, Cloud Functions, FCM and Pub/Sub;
- Google Maps Platform: Maps SDK and Places API (New);
- Android/device location/geocoding services;
- user's telephone/network provider for emergency calls opened externally;
- Google Play: Android distribution, Play Billing, subscription lifecycle, Android Publisher API and RTDN if Homi+ is activated.

Final privacy/Data Safety declarations must match the exact release binary and enabled provider configuration.

## Household membership and consent separation

The product keeps these distinct:

1. connecting Homi accounts;
2. editing a private relationship label;
3. creating/joining canonical Shared Household through invite/accept;
4. synchronizing supported Household data;
5. granting current-location visibility to a person;
6. enabling background live updates;
7. choosing arrival recipients;
8. enabling arrival monitoring;
9. separately sharing exact Home/Work;
10. purchasing/receiving Homi+ entitlement.

A connection label never grants Household access. Household membership never turns on location sharing. Homi+ must not convert one permission into another.

## Household synchronization and retention

Shared data remains locally persisted while synchronized. Different IDs merge naturally; same-record conflicts settle to the last server-acknowledged Firestore value and listening devices persist that value.

Removing/leaving a Household revokes future cloud access but cannot reliably erase copies previously delivered to another device. Public wording must not promise retroactive endpoint erasure.

Deleting a canonical Household triggers bounded cleanup of nested shared data plus newer canonical shared Tasks, but device-local copies may remain until separately erased.

## Arrival check-in minimisation

Arrival detection runs locally against the saved Home/Work boundary.

- initial state primes without sending;
- only outside→inside triggers arrival;
- hysteresis/cooldown reduces duplicates;
- arrival callable/push contains no saved precise address/coordinate;
- no default route history is created;
- recipients are revalidated as accepted trusted connections.

## Background location disclosure

Before production background-location permission, Homi must clearly explain:

- why background access is needed for user-selected live updates/check-ins;
- who can see location/receive arrivals;
- persistent Android foreground-service notification;
- how to stop/revoke sharing and check-ins;
- separate exact Home/Work sharing control;
- device/network/power/force-stop limitations.

This prominent disclosure must be contextual before the sensitive permission flow, not only in a privacy policy.

## Emergency shortcuts

Emergency-region data is bundled local data. Only verified/supported regions should be offered publicly. Tapping hands the number to the external phone app; Homi does not silently place calls, dispatch responders, automatically send location or promise successful emergency action.

## Notifications

Operational notification categories remain distinct from product announcements. Homi Updates stays off by default. Arrival notifications may show sender name and Home/Work label but not precise saved address/coordinate on the lock screen.

The foreground-service notification for active background location is platform disclosure, not an optional marketing notification.

## Data minimisation principles

- no precise coordinates/addresses/Household notes/Task text in analytics/general logs;
- no raw passwords;
- no hidden route history;
- no contact-book collection merely to discover users when Homi codes suffice;
- no automatic Household conversion for location/check-ins;
- no automatic upload of unmatched old Household records merely because a user joins another Household;
- no client-readable raw Google Play purchase tokens;
- no raw Firebase UID sent to Play as obfuscated account ID;
- no privacy/revoke/delete paywall;
- remove/disable dead push tokens;
- RTDN is reverified, not trusted directly.

## User-facing controls

Homi & account provides Household, Notifications, Help, Privacy & your data, Location & safety, Terms, About, local erase and account deletion. Profile Settings in 0.13 also exposes **Homi+ → Plans & billing** for subscription/coverage management.

People remains map-first. Connections expose **My code** and **Connect** on demand. Household membership is managed only through Shared Household.

## Play Data Safety preparation

Before public release, reconcile Play Data Safety against the exact submitted build, including:

- precise/background location;
- optional exact Home/Work cloud storage;
- Maps/Places processing;
- account IDs, email/name/profile photo;
- connections/Household membership/invites;
- push identifiers;
- Shared Household content and shared Tasks;
- Google Play billing/subscription verification metadata;
- encryption in transit;
- account deletion and external deletion request path;
- optional/required collection and service-provider processing.

Do not copy another app's Data Safety answers.

## Production privacy/security checklist

Before production:

- final 0.12 Shared Household backend accepted;
- final 0.13 billing lifecycle accepted from a Play Internal Testing install;
- Play Integrity App Check valid traffic proven, with Firestore enforcement staged deliberately;
- release/Play signing fingerprints registered;
- Maps/Places restrictions verified;
- external account-deletion page published;
- stable Privacy Policy and Terms URLs published;
- account-deletion UI explicitly separates Homi deletion from Play subscription cancellation;
- background-location disclosure/declaration/review evidence accepted;
- Data Safety completed from the actual release binary;
- Cloud Billing budgets/alerts/monitoring active;
- final POPIA/privacy wording professionally reviewed.
