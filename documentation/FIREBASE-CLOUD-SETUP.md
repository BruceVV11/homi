# Homi Firebase / Google Cloud Setup

Project ID: `homi-ee80a`  
Project number: `883068189841`  
Android package: `za.co.theconceptlab.homi`  
Local project root: `C:\ConceptLab\Projects\homi`  
Primary Firestore location: `africa-south1` (Johannesburg)

This document is the setup source of truth for the first Homi Android build.

## 1. Backend source of truth

The existing Firebase project `homi-ee80a` is Homi's backend. Its underlying Google Cloud project has the same project ID and project number `883068189841`.

The previously created Google Cloud project `homi-508000` is not used. Any OAuth, API or Firebase configuration formerly made there must be recreated against `homi-ee80a` if needed.

## 2. Architecture decision for v0.x

Homi will use:

- Firebase Authentication: email/password and Google sign-in.
- Cloud Firestore Standard: household sync, trusted relationships, current location/battery snapshots, notification metadata and shared state.
- Firebase Cloud Messaging: push notifications.
- Firebase App Check with Play Integrity: production client attestation.
- Google Drive API: user-owned receipts, manuals, incident photos, meter photos and structured backup files.
- Maps SDK for Android: trusted-person map.
- Places API (New): named Places such as Home, Work and School.
- Google Play services Location APIs: fused device location and geofencing on Android.
- Cloud Functions/Cloud Run later: trusted server-side notification and monetization operations.

Realtime Database is intentionally not required in the first implementation. Firestore real-time listeners will be validated on real devices before adding a second database technology.

## 3. Credentials required

| Capability | Credential/setup | Notes |
| --- | --- | --- |
| Firebase Android SDK | `google-services.json` | Download after Android app registration; refresh after SHA/Google sign-in changes. |
| Email/password auth | Firebase Authentication provider | No key to create. |
| Google sign-in | Android OAuth client | Tied to package + SHA-1. |
| Google Drive | OAuth consent + `drive.file` | User authorizes their own Drive. |
| Maps + Places Android | Restricted Android API key | Restrict by package, SHA-1 and APIs. |
| FCM Android receive | Firebase SDK | No legacy server key. |
| FCM server send | Google runtime service account / ADC | No downloadable key file required on Google Cloud. |
| App Check | Play Integrity registration | Debug builds use a registered debug token later. |
| Geofencing | Android/Play services | No Cloud API key. |
| Battery status | Android platform | No API key. |
| Camera | Android platform | No API key. |
| Contact picking | Android Contact Picker | No Google Contacts API required. |

Do not generate a Firebase Admin JSON private key for the Android app.

## 4. Automated Cloud Shell bootstrap

The repository includes:

`scripts/bootstrap-google-cloud.sh`

It performs the cloud operations suitable for automation:

- verifies project ID `homi-ee80a` and project number `883068189841`;
- links the supplied billing account;
- enables required APIs in batches that respect Google Service Usage limits;
- confirms Firebase is enabled;
- registers Android package `za.co.theconceptlab.homi` if absent;
- exports an initial Firebase Android config to `~/homi-google-services.json`;
- creates or verifies the default Firestore database in `africa-south1`;
- creates `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`;
- grants initial Firestore and FCM runtime roles;
- creates no service-account private key.

### Cloud Shell commands

If the repo is already cloned:

```bash
gcloud config set project homi-ee80a
cd ~/homi
git pull
HOMI_BILLING_ACCOUNT=019579-54789E-55B8AF bash scripts/bootstrap-google-cloud.sh
```

If the repo is not present:

```bash
gcloud config set project homi-ee80a
cd ~
git clone https://github.com/BruceVV11/homi.git
cd homi
HOMI_BILLING_ACCOUNT=019579-54789E-55B8AF bash scripts/bootstrap-google-cloud.sh
```

The supplied billing account is Concept Lab Internal.

The script is rerunnable. It first checks the immutable project identity before modifying anything.

## 5. APIs enabled by the bootstrap

Core Firebase:

- Firebase Management API
- Cloud Firestore API
- Firebase Rules API
- Identity Toolkit API
- Token Service API
- Firebase Cloud Messaging API
- Firebase App Check API
- Google Play Integrity API

Homi integrations:

- Google Drive API
- Maps SDK for Android
- Places API (New)
- API Keys API

Secure server-side foundation:

- IAM API
- IAM Service Account Credentials API
- Service Usage API
- Cloud Resource Manager API
- Cloud Billing API
- Secret Manager API
- Cloud Functions API
- Cloud Run API
- Cloud Build API
- Artifact Registry API
- Eventarc API
- Pub/Sub API

Enabling an API does not by itself mean Homi is actively consuming or billing against that API.

## 6. Firebase Console manual settings

Open Firebase Console and select the project whose Project ID is exactly `homi-ee80a`.

### Authentication

Go to:

**Security -> Authentication -> Get started -> Sign-in method**

Enable:

1. **Email/Password**
   - enable Email/Password;
   - leave Email link/passwordless disabled for v0.x.

2. **Google**
   - enable Google;
   - select the public support email;
   - save.

Do not enable anonymous auth, phone auth or additional providers yet.

### Firestore

Go to:

**Databases & Storage -> Firestore**

Confirm:

- Database ID: `(default)`
- Edition: Standard
- Mode: Firestore Native
- Location: `africa-south1` / Johannesburg
- Delete protection: enabled

If a default database already exists in a different region, stop before adding app data and review that separately.

The repo contains security rules in:

`firebase/firestore.rules`

Do not switch the database to open/test rules.

### Cloud Messaging

Go to:

**Project settings -> Cloud Messaging**

Confirm Firebase Cloud Messaging API (HTTP v1) is enabled. Homi does not require a legacy server key.

## 7. Google Auth Platform / OAuth consent

Open Google Cloud Console with project `homi-ee80a` selected, then open **Google Auth Platform**.

Configuration made previously under deleted/unused project `homi-508000` does not transfer.

### Branding

Set:

- App name: `Homi`
- User support email: Homi/Concept Lab support email
- Developer contact email: Homi/Concept Lab development/support email
- Logo: final Homi master logo when locked
- Homepage: add when Homi's public site exists
- Privacy policy: required before production distribution
- Terms: add before production distribution

### Audience

Choose **External**.

Keep publishing status **Testing** during development and add the Google accounts used for testing.

### Data access

Use only the minimum scopes required:

- OpenID/email/profile scopes required by Google sign-in
- `https://www.googleapis.com/auth/drive.file`

Do not request broad read/write access to the user's entire Google Drive.

Drive permission should be requested contextually when the user chooses Homi backup/document storage, not on first launch.

## 8. Android app registration and SHA fingerprints

The permanent Android application ID is:

`za.co.theconceptlab.homi`

The bootstrap registers this Firebase Android app if it does not already exist.

After the Android host exists, run on Windows:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Record the debug SHA-1 and SHA-256.

Add them in:

**Firebase Console -> Project settings -> General -> Your apps -> Homi Android -> SHA certificate fingerprints**

Then download a fresh `google-services.json` to:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

Why both:

- SHA-1: Google sign-in/OAuth and Android-restricted Maps credentials.
- SHA-256: App Check / Play Integrity and modern certificate verification.

When the app is later created in Google Play, also register the Play App Signing certificate fingerprints.

## 9. Restricted Maps/Places key

After obtaining the debug SHA-1, run in Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/create-android-maps-key.sh 'AA:BB:CC:DD:...'
```

The script creates a key restricted to:

- project `homi-ee80a`;
- Android package `za.co.theconceptlab.homi`;
- supplied signing SHA-1;
- Maps SDK for Android;
- Places API (New).

Store the returned value locally in:

`C:\ConceptLab\Projects\homi\secrets.properties`

```properties
MAPS_API_KEY=your_key_here
PLACES_API_KEY=your_key_here
```

`secrets.properties` is excluded from Git.

## 10. App Check

Prepare App Check but do not enforce it before the first installable build exists.

Planned providers:

- debug build: Firebase App Check Debug provider;
- release build: Play Integrity provider.

After a debug build is running:

1. capture the App Check debug token from Android Studio Logcat;
2. register it under Firebase Console -> App Check -> Homi Android;
3. verify valid Auth/Firestore/FCM traffic;
4. later register Play App Signing SHA-256;
5. only then enable enforcement one Firebase product at a time.

## 11. Background location / trusted people

No Google Cloud API key is required to obtain Android device location.

Homi will use Android/Google Play services location APIs. Continuous trusted-person sharing eventually requires a controlled permission progression:

- coarse/fine foreground location;
- foreground service location permission;
- background location only when the user explicitly activates continuous sharing;
- notification permission where Android requires it.

Homi must explain background location before requesting it and provide an obvious persistent sharing state. The map/Place search uses Google Maps/Places credentials; geofencing itself does not need an additional Cloud API key.

## 12. Server-side service account

The bootstrap creates:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Initial roles:

- `roles/datastore.user`
- `roles/firebasecloudmessaging.admin`

This identity is intended to be attached directly to Google-hosted workloads using Application Default Credentials.

Do not click **Create key** for this service account merely for convenience. If external CI/CD later needs Google Cloud access, prefer short-lived federation/OIDC rather than a long-lived JSON private key.

## 13. Google Drive design

Homi does not use a privileged backend service account to browse a person's private Drive.

The person authorizes Homi through `drive.file`. Homi can then create/manage its own user-visible structure such as:

```text
Homi/
  Documents/
  Receipts/
  Repairs/
  Meter Photos/
  Backups/
```

A small structured backup file can restore local-first data after phone loss/replacement.

## 14. APIs deliberately not required now

- Firebase Storage
- Firebase Realtime Database
- Google People API
- Directions API / Routes API / Navigation SDK
- broad Geocoding web API
- Google Play Developer API until monetization is implemented
- advertising APIs

## 15. First-build checkpoint

Before the first installable `0.1.0` build:

- [ ] Firebase project confirmed as `homi-ee80a` / `883068189841`
- [ ] billing linked to the intended account
- [ ] Firebase Android app registered as `za.co.theconceptlab.homi`
- [ ] Firestore `(default)` confirmed in `africa-south1`
- [ ] Email/Password enabled
- [ ] Google provider enabled
- [ ] Google Auth Platform branding/audience configured in `homi-ee80a`
- [ ] Drive API enabled
- [ ] debug SHA-1 added to Firebase
- [ ] debug SHA-256 added to Firebase
- [ ] refreshed `google-services.json` copied to `android/app/`
- [ ] restricted development Maps/Places key created
- [ ] App Check configured but enforcement OFF
- [ ] no service-account JSON file in the Android project or GitHub

Once complete, Homi can move into the first device-installable pass with the approved logo/app icon already included.
