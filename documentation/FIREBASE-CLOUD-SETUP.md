# Homi Firebase / Google Cloud Setup

Project ID: `homi-508000`  
Android package: `za.co.theconceptlab.homi`  
Local project root: `C:\ConceptLab\Projects\homi`  
Primary Firestore location: `africa-south1` (Johannesburg)

This document is the setup source of truth for the first Homi Android build.

## 1. Architecture decision for v0.x

Homi will use:

- Firebase Authentication: account identity, email/password and Google sign-in.
- Cloud Firestore Standard: household sync, trusted relationships, current location/battery snapshots, notification metadata and shared state.
- Firebase Cloud Messaging: push notifications.
- Firebase App Check with Play Integrity: production client attestation.
- Google Drive API: user-owned receipts, manuals, incident photos, meter photos and structured backup files.
- Maps SDK for Android: trusted-person map.
- Places API (New) / Places SDK for Android: selecting named Places such as Home, Work and School.
- Google Play services Location APIs: fused device location and geofencing on Android.
- Cloud Functions/Cloud Run later: trusted server-side notification and monetization operations.

Realtime Database is intentionally **not required in the first implementation**. Firestore supports real-time listeners and has a Johannesburg region. We will validate real-world location update volume before adding a second live-state database.

## 2. Credentials: what is actually required

| Capability | Credential | Secret? | Notes |
| --- | --- | --- | --- |
| Firebase Android SDK | `google-services.json` | No, but keep out of public repo | Download after Android app registration and refresh after SHA/Google sign-in changes. |
| Email/password auth | None | No | Firebase Authentication provider. |
| Google sign-in | Android OAuth client | Configuration | Tied to package + SHA-1. |
| Google Drive | OAuth consent + `drive.file` scope | User token | Do not use a service account for a person's private Drive. |
| Maps + Places Android | Restricted API key | Treat as sensitive configuration | Restrict by package, SHA-1 and APIs. |
| FCM Android receive | None | No | Firebase SDK handles device registration token. |
| FCM server send | Google runtime service account / ADC | No key file on Google Cloud | Homi creates a dedicated keyless runtime service account. |
| App Check | Play Integrity registration | No | Debug builds use a registered debug token later. |
| Geofencing | None | No | Part of Google Play services Location API, not a Cloud API key. |
| Battery status | None | No | Android platform data. |
| Camera | None | No | Android platform integration. |
| Contact picking | None | No | Use Android Contact Picker rather than broad cloud/contact access. |

**Do not generate a Firebase Admin JSON private key for the Android app.** A service-account credential must never be packaged into Homi.

## 3. Recommended first action: run the automated Cloud Shell bootstrap

The repository includes:

`scripts/bootstrap-google-cloud.sh`

It is designed to be safe to rerun. It performs the parts that are suitable for automation:

- selects `homi-508000`;
- optionally links a billing account when supplied;
- enables required Google/Firebase APIs;
- adds Firebase to the existing Google Cloud project if required;
- registers `za.co.theconceptlab.homi` as the Android Firebase app;
- downloads an initial `homi-google-services.json` into Cloud Shell;
- creates the default Firestore Standard database in `africa-south1` with delete protection;
- creates `homi-backend-runtime@homi-508000.iam.gserviceaccount.com`;
- grants the runtime only initial Firestore data and FCM send access;
- deliberately creates **no service-account private key**.

### Cloud Shell commands

```bash
git clone https://github.com/BruceVV11/homi.git
cd homi
bash scripts/bootstrap-google-cloud.sh
```

If the project does not yet have billing linked, first list billing accounts:

```bash
gcloud billing accounts list
```

Then rerun with the account ID:

```bash
HOMI_BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX bash scripts/bootstrap-google-cloud.sh
```

### Why billing should be linked now

Firebase's basic client products can start cheaply, but Google Maps Platform requires a billing account and Homi's later server-side functions will require the Firebase Blaze/pay-as-you-go relationship. Link billing, then immediately configure budget alerts and quotas. A budget alert warns; it is not a hard spending cap.

Recommended initial Billing console alerts: 50%, 90% and 100% of a deliberately low monthly test budget.

## 4. APIs enabled by the bootstrap

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

Enabling an API does not mean Homi will immediately use or bill against it.

## 5. Firebase Console: manual settings after bootstrap

Open Firebase Console and select **homi** / `homi-508000`.

### Authentication

Go to:

**Security -> Authentication -> Get started -> Sign-in method**

Enable:

1. **Email/Password**
   - Enable Email/Password.
   - Leave Email link/passwordless disabled for v0.x.

2. **Google**
   - Enable Google.
   - Select the public support email.
   - Save.

Do not enable anonymous auth, phone auth or additional identity providers yet.

### Firestore

Go to:

**Databases & Storage -> Firestore**

Confirm:

- Database ID: `(default)`
- Edition: Standard
- Mode: Firestore Native
- Location: `africa-south1` / Johannesburg
- Delete protection: enabled

Do not switch to test/open rules.

The repo contains the security-rule baseline in:

`firebase/firestore.rules`

Once Firebase CLI is installed locally, deploy it with:

```powershell
firebase deploy --only firestore
```

from `C:\ConceptLab\Projects\homi`.

### Cloud Messaging

Go to:

**Project settings -> Cloud Messaging**

Confirm the Firebase Cloud Messaging API (HTTP v1) is enabled. The bootstrap enables the API; no legacy server key is required.

Homi server sends will use the Firebase Admin SDK/HTTP v1 with the attached Google runtime service account.

## 6. Google Auth Platform / OAuth consent

Google Drive needs end-user OAuth, not a service account.

In Google Cloud Console select project `homi-508000`, then open **Google Auth Platform**.

### Branding

Set:

- App name: `Homi`
- User support email: Concept Lab support/account email
- Developer contact email: Concept Lab development/support email
- Logo: add the final Homi master logo once the production asset is locked
- Homepage: may be added when Homi's public/legal site exists
- Privacy policy: required before production distribution, especially because Homi uses sensitive location data
- Terms: add before production

### Audience

Choose **External** unless Homi is deliberately limited to a single Google Workspace organization.

While the OAuth app remains in testing, add the Google accounts used for development as test users.

### Data access / scopes

Use only:

- `openid`
- user email/profile scopes required by Google sign-in
- `https://www.googleapis.com/auth/drive.file`

Do **not** request broad read/write access to the user's entire Drive. `drive.file` is the intended per-file/app-created-file scope and is a non-sensitive Drive scope.

The Drive permission will be requested only when the user chooses cloud backup/document storage, not during first launch.

## 7. Local Android project and SHA fingerprints

The permanent Android application ID is now locked as:

`za.co.theconceptlab.homi`

The next code pass will generate the Android host under:

`C:\ConceptLab\Projects\homi\android`

After that host exists, open PowerShell and run:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Copy the **debug SHA-1** and **debug SHA-256** values.

Then in Firebase Console:

**Project settings -> General -> Your apps -> Homi Android -> SHA certificate fingerprints**

Add both SHA values.

Why both:

- SHA-1: Google sign-in/OAuth and Android-restricted Maps credentials.
- SHA-256: App Check / Play Integrity and modern certificate verification.

After adding them, download a **fresh** `google-services.json` and put it here:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

The repository ignores this file.

## 8. Create the restricted Maps/Places key after SHA-1 exists

Do not create an unrestricted Maps key.

After obtaining the debug SHA-1, open Cloud Shell in the cloned Homi repo and run:

```bash
bash scripts/create-android-maps-key.sh 'AA:BB:CC:DD:...'
```

This creates a key restricted to:

- Android package `za.co.theconceptlab.homi`
- the supplied signing SHA-1
- Maps SDK for Android
- Places API (New)

On the Windows project PC, the returned key will go into a local `secrets.properties` file as:

```properties
MAPS_API_KEY=your_key_here
PLACES_API_KEY=your_key_here
```

`secrets.properties` is excluded from Git.

When the Play Console app is created later, repeat the certificate setup for the **Play App Signing** certificate. Production credentials must allow the Play signing fingerprint, not only the local upload/debug certificate.

## 9. App Check - prepare, but do not enforce yet

In Firebase Console go to:

**Build/Security -> App Check**

Do not enforce App Check before the first installable build exists.

The first implementation will use:

- debug build: Firebase App Check Debug provider
- release build: Play Integrity provider

After the debug app is running:

1. capture the Firebase App Check debug token from Android Studio Logcat;
2. register it under App Check -> Homi Android -> Manage debug tokens;
3. verify Auth/Firestore/FCM calls show as valid;
4. later link the Play Console app to `homi-508000` and register the Play App Signing SHA-256;
5. only then enable enforcement, one Firebase product at a time.

## 10. Background location / Life360-style feature

No extra Google Cloud API key is required to read Android device location.

The application will use Android/Google Play services location APIs. The implementation will eventually require a controlled permission progression such as:

- coarse/fine foreground location;
- foreground service location permission;
- background location only when the user explicitly activates continuous trusted-person sharing;
- notification permission where Android requires it.

Homi must provide a prominent in-app explanation before requesting background location and the Play listing must make continuous trusted-person location a visible core feature.

Places/geofences are separate concepts:

- the map and place search use Maps/Places Platform credentials;
- Android geofencing itself does not require a Google Cloud API key.

## 11. Server-side service account design

The automated bootstrap creates:

`homi-backend-runtime@homi-508000.iam.gserviceaccount.com`

Initial roles:

- `roles/datastore.user`
- `roles/firebasecloudmessaging.admin`

This identity is intended to be **attached** to Google-hosted server workloads. It should use Application Default Credentials.

Do not click **Create key** for this service account merely for convenience. Long-lived JSON keys are avoided unless we later have a workload outside Google Cloud that cannot use Workload Identity Federation or another short-lived identity method.

If GitHub Actions is ever used for Cloud deployment, prefer GitHub OIDC + Workload Identity Federation rather than placing a Google service-account JSON secret in GitHub.

## 12. Google Drive design

Homi will not store a user's documents through a privileged server service account.

The user authorizes Homi to create/access the files Homi manages through `drive.file`. The app should create a user-visible Homi folder structure such as:

```text
Homi/
  Documents/
  Receipts/
  Repairs/
  Meter Photos/
  Backups/
```

This makes the data remain usable by the owner even if they stop using Homi.

A small structured backup file can also be stored in the user's Drive so local-first data can be restored after phone loss/replacement.

## 13. APIs we deliberately do not need now

- Firebase Storage: media belongs in the user's Google Drive for the current architecture.
- Realtime Database: not needed until real-world Firestore location load proves a reason to split live state.
- Google People API: use Android's privacy-preserving Contact Picker.
- Geocoding web service: use the native Android/Places experience first.
- Directions/Routes/Navigation SDK: Homi is not navigation software.
- Google Play Developer API: defer until subscriptions/in-app purchases are implemented.
- Ads APIs: Homi location data must never be collected just for advertising.

## 14. First-build checkpoint

Before the first installable `0.1.0` build, the required setup state is:

- [ ] Firebase added to `homi-508000`
- [ ] Billing linked and budget alerts configured
- [ ] Firebase Android app registered as `za.co.theconceptlab.homi`
- [ ] Firestore `(default)` created in `africa-south1`
- [ ] Email/Password provider enabled
- [ ] Google provider enabled
- [ ] OAuth branding/audience configured
- [ ] Drive API enabled with intended `drive.file` scope
- [ ] debug SHA-1 added to Firebase
- [ ] debug SHA-256 added to Firebase
- [ ] refreshed `google-services.json` copied to `android/app/`
- [ ] restricted development Maps/Places key created
- [ ] App Check configured but enforcement OFF
- [ ] no service-account JSON file in the Android project or GitHub

Once that checklist is complete, Homi can move into the first device-installable pass with the approved logo/app icon already included.
