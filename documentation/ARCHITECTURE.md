# Homi Architecture

## Permanent project identifiers

- Google Cloud / Firebase project: `homi-508000`
- Android application ID: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub repository: `BruceVV11/homi`

These identifiers are locked for the Android/Firebase/Play lifecycle.

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

Google Cloud project ID: `homi-508000`

Firebase is added to this existing Google Cloud project rather than creating a second backend project.

The default Firestore database should be provisioned in `africa-south1` (Johannesburg).

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
    features/
      today/
      home/
      routines/
      supplies/
      people/
    shell/
    theme/
    widgets/
android/
  # generated/maintained Flutter Android host
firebase/
  firestore.rules
  firestore.indexes.json
documentation/
scripts/
```

## Data boundaries

### Local-first data
Household preferences, local task state, cached home records, and UI preferences should remain usable without connectivity.

### Shared cloud state
Only data requiring collaboration should be synchronized: household memberships, shared routines, trusted-circle membership, location-sharing authorization, current location/battery snapshots, and notification state.

### User-owned media
Receipts, manuals, incident photos, meter evidence and backup files should be stored in the user's own Google Drive where feasible. Homi stores references/metadata rather than becoming the permanent owner of those files.

## Location architecture

The location system is consent-first:

- the tracked device/account must explicitly enable sharing;
- sharing authorization is evaluated in Firestore rules/server-side logic rather than trusted to the viewer client;
- v0.x stores the latest location/battery snapshot by default, not indefinite movement history;
- Android background location is requested only for continuous sharing and requires a visible foreground-service state where the platform requires it;
- location, battery and trusted-circle data are excluded from analytics/crash payloads.

## Security rules

- Every cloud collection/tree is authenticated by default.
- Authorization is membership/share based, never client-trusted.
- Location reads require an explicit active share from the subject to the viewer.
- Sensitive location data is excluded from analytics/crash payloads.
- App Check enforcement is enabled only after valid debug/release traffic has been confirmed.
- No service-account credential is bundled with the app.
- Google-hosted server workloads use attached service accounts/Application Default Credentials rather than downloaded long-lived private keys.

## Entitlements

Paid functionality is not yet defined, but the architecture distinguishes capabilities from UI from the beginning. Future entitlement checks must be additive and must never make account deletion, location-sharing controls, privacy controls, or emergency opt-out behavior dependent on payment.

## Brand asset rule

The approved Homi option-4 visual direction is the source of truth: coral/peach/sage/cream/slate, friendly rounded typography and the distinctive lowercase `h` house/person mark. Before the first installable build, one exact master logo asset must be locked and used to derive launcher, adaptive foreground/background, monochrome/themed icon, splash and in-app logo variants. Framework-drawn approximations are not acceptable.
