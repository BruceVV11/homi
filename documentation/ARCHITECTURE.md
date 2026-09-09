# Homi Architecture

## Permanent project identifiers

- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android application ID: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub repository: `BruceVV11/homi`

These identifiers are locked for the Android/Firebase/Play lifecycle.

The existing Firebase project `homi-ee80a` is the backend source of truth. The previously created Google Cloud project `homi-508000` is not part of the Homi architecture.

## Stack

- Flutter / Dart Android application developed from the project root in Android Studio
- Local-first persisted state for household data
- Firebase Authentication for account identity
- Cloud Firestore Standard for lightweight shared state and real-time listeners
- Firebase Cloud Messaging for notifications
- Firebase App Check with Play Integrity for production attestation
- Google Drive for user-owned documents, media and structured backup
- Google Maps Platform plus Android/Google Play services location APIs for consensual trusted-person location sharing
- Cloud Functions / Cloud Run later for trusted server-side notification, entitlement and automation operations

## Cloud project

The underlying Google Cloud project for Firebase is also `homi-ee80a`, project number `883068189841`.

The default Firestore database is provisioned in `africa-south1` (Johannesburg). Firestore location is treated as a permanent infrastructure decision rather than a runtime preference.

## Why Firestore first

The first Homi implementation uses Firestore for shared household state and current trusted-person location/battery snapshots. It provides real-time listeners while keeping the data layer simpler and regionally aligned with the rest of the backend.

Realtime Database is **not** required in v0.x. We will measure real device location-update frequency, battery behaviour and Firestore cost before deciding whether a dedicated high-churn live-state store adds enough value to justify a second database technology.

## Source structure

```text
lib/
  main.dart
  src/
    app.dart
    domain/
      location_snapshot.dart
      routine_item.dart
      supply_item.dart
    features/
      today/
      home/
      routines/
      supplies/
      people/
    services/
    shell/
    state/
    theme/
    widgets/
      homi_brand.dart
      homi_bottom_nav.dart
      homi_page.dart
android/
  # generated/maintained Flutter Android host
firebase/
  firestore.rules
  firestore.indexes.json
documentation/
scripts/
```

## Navigation shell

The primary app shell owns persistent chrome rather than each feature page recreating it:

- one persistent top row contains the exact Homi logo on the left and the account/profile control on the right;
- the five primary destinations are hosted in a `PageView`, so horizontal swiping changes page content without moving or duplicating the shell header;
- the custom Homi bottom navigation remains outside the page scrollers and mirrors the `PageView` index;
- the Home destination uses the exact approved Homi mark asset rather than a framework-drawn home icon;
- Android Back from a secondary primary destination returns to Today before root exit behavior;
- individual feature pages own only their scrollable title/content area and use clamped scrolling with normal bottom padding because the navigation bar already occupies layout space.

## Data boundaries

### Local-first data

Household preferences, local task state, cached home records and UI preferences remain usable without connectivity.

In v0.2.0 this includes:

- Quick Add reminders;
- Routine records with UUID, title, category, frequency, completion state and last-completed timestamp;
- Supply records with UUID, category, attention status and optional expiry date.

These records are persisted through `SharedPreferences` as version-tolerant JSON strings. Invalid legacy/corrupt entries are skipped during local decode instead of blocking app startup. Cloud collaboration for these records is intentionally deferred until a merge/conflict strategy exists.

### Shared cloud state

Only data requiring collaboration should be synchronized: household memberships, shared routines, trusted-circle membership, location-sharing authorization, current location/battery snapshots and notification state.

Local-first records must not be silently overwritten when shared Firestore sync is added. First-sync merge/conflict behavior must be documented before enabling it.

### User-owned media

Receipts, manuals, incident photos, meter evidence and backup files should be stored in the user's own Google Drive where feasible. Homi stores references/metadata rather than becoming the permanent owner of those files.

## Location architecture

The location system is consent-first:

- the tracked device/account must explicitly enable sharing;
- adding or inviting someone never starts location sharing automatically;
- sharing authorization is evaluated in Firestore rules/server-side logic rather than trusted to the viewer client;
- v0.x stores the latest location/battery snapshot by default, not indefinite movement history;
- Android background location is requested only for continuous sharing and requires a visible foreground-service state where the platform requires it;
- location, battery and trusted-circle data are excluded from analytics/crash payloads;
- the People UI keeps privacy information accessible without making a large privacy lecture the dominant page content.

## Security rules

- Every cloud collection/tree is authenticated by default.
- Authorization is membership/share based, never client-trusted.
- Location reads require an explicit active share from the subject to the viewer.
- Sensitive location data is excluded from analytics/crash payloads.
- App Check enforcement is enabled only after valid debug/release traffic has been confirmed.
- No service-account credential is bundled with the app.
- Google-hosted server workloads use attached service accounts/Application Default Credentials rather than downloaded long-lived private keys.

## Entitlements

Paid functionality is not yet defined, but the architecture distinguishes capabilities from UI from the beginning. Future entitlement checks must be additive and must never make account deletion, location-sharing controls, privacy controls or emergency opt-out behavior dependent on payment.

## Brand asset rule

The approved Homi option-4 visual direction is the source of truth: coral/peach/sage/cream/slate, friendly rounded typography and the distinctive lowercase `h` house/person mark. One exact master logo asset is used to derive launcher, adaptive foreground/background, monochrome/themed icon, splash, persistent header and in-app mark variants. Framework-drawn approximations are not acceptable.
