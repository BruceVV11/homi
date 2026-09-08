# Homi Architecture

## Stack

- Flutter / Dart mobile application
- Local-first persisted state for household data
- Firebase Authentication for account identity
- Firebase Realtime Database and/or Firestore for lightweight shared state
- Firebase Cloud Messaging for notifications
- Firebase App Check before production enforcement
- Google Drive for user-owned documents and media
- Google Maps / platform location services for consensual trusted-person location sharing

## Cloud project

Google Cloud project ID: `homi-508000`

The intended setup is to add Firebase services to this existing Google Cloud project rather than create a separate backend project.

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
documentation/
```

## Data boundaries

### Local-first data
Household preferences, local task state, cached home records, and UI preferences should remain usable without connectivity.

### Shared cloud state
Only data requiring collaboration should be synchronized: household memberships, shared routines, trusted-circle membership, location-sharing authorization, current location snapshots, and notification state.

### User-owned media
Receipts, manuals, incident photos, and meter evidence should be stored in the user's own Google Drive where feasible, with Homi storing references/metadata rather than becoming the permanent owner of those files.

## Security rules

- Every cloud collection/tree is authenticated by default.
- Authorization is membership/share based, never client-trusted.
- Location reads require an explicit active share from the subject to the viewer.
- Sensitive location data is excluded from analytics/crash payloads.
- App Check enforcement is enabled only after valid production traffic has been confirmed.
- No service-account credential is bundled with the app.

## Entitlements

Paid functionality is not yet defined, but the architecture should distinguish capabilities from UI from the beginning. The future entitlement model should be additive and must never make account deletion, location-sharing controls, privacy controls, or emergency opt-out behavior dependent on payment.

## Irreversible identifier still to lock

Before Android host generation/Firebase Android registration, confirm the permanent Android application ID. Suggested convention is `za.co.theconceptlab.homi`, but this is **not yet approved or committed**.
