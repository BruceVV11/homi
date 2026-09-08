# Homi v0.1.0 - Start Here

Use this sequence to prepare the first installable Android build.

## Project identities

These identifiers are authoritative for Homi:

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`

The previously created Google Cloud project `homi-508000` is not used. Do not configure credentials, OAuth clients, Maps keys, Firebase apps or App Check against it.

## Stage A - Update the local repository

Open PowerShell:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
```

For normal development, open `C:\ConceptLab\Projects\homi` in Android Studio.

## Stage B - Prepare Cloud Shell for the correct Firebase project

Open Google Cloud Shell and run:

```bash
gcloud config set project homi-ee80a
gcloud projects describe homi-ee80a --format='table(projectId,projectNumber,name)'
```

Expected identity:

```text
PROJECT_ID   PROJECT_NUMBER   NAME
homi-ee80a   883068189841     homi
```

If those values do not match, stop.

If the existing Cloud Shell clone is present:

```bash
cd ~/homi
git pull
```

If it is not present:

```bash
cd ~
git clone https://github.com/BruceVV11/homi.git
cd homi
```

## Stage C - Run the automated Firebase/Google Cloud bootstrap

The selected billing account for Homi is Concept Lab Internal:

`019579-54789E-55B8AF`

Run:

```bash
HOMI_BILLING_ACCOUNT=019579-54789E-55B8AF bash scripts/bootstrap-google-cloud.sh
```

The script is safe to rerun. It verifies both the project ID and project number before making changes.

Expected successful end-state:

- the existing Firebase project `homi-ee80a` is confirmed;
- required APIs are enabled in two batches;
- billing is linked to Concept Lab Internal;
- Firebase Android app `za.co.theconceptlab.homi` is registered;
- initial Android Firebase config is exported to `~/homi-google-services.json`;
- Firestore `(default)` exists in `africa-south1`;
- keyless runtime service account `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com` exists;
- initial runtime IAM roles are applied;
- no service-account JSON private key is created.

The final line should include:

```text
==> Bootstrap complete
```

## Stage D - Firebase Authentication

In Firebase Console, confirm **Project settings -> General -> Project ID** shows:

`homi-ee80a`

Then go to:

**Security -> Authentication -> Get started -> Sign-in method**

Enable:

1. Email/Password
2. Google

For Email/Password, leave Email Link disabled for now.

For Google, select the support email and save.

Do not enable Phone, Anonymous or other providers yet.

## Stage E - Google Auth Platform

Open Google Cloud Console with project `homi-ee80a` selected, then open **Google Auth Platform**.

Configure:

- App name: `Homi`
- Audience: `External`
- User support email: your Homi/Concept Lab support email
- Developer contact email: your Homi/Concept Lab development/support email
- Publishing status: Testing during development
- Test users: add the Google accounts used for development

The OAuth setup that may previously have been created under `homi-508000` does not carry over. Configure it again under `homi-ee80a`.

For Drive, Homi will later request only:

`https://www.googleapis.com/auth/drive.file`

Do not request full Drive access.

## Stage F - First Android host

The first installable code pass will create/maintain the Flutter Android host with package:

`za.co.theconceptlab.homi`

It must already contain the approved Homi branding:

- exact master logo;
- adaptive launcher icon;
- monochrome/themed launcher icon;
- splash/loading branding;
- in-app Homi mark.

No placeholder Flutter launcher artwork should ship in the first installable build.

## Stage G - Get certificate fingerprints

After the Android host exists:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Record the debug SHA-1 and SHA-256.

Add both in:

**Firebase Console -> Project settings -> General -> Homi Android -> SHA certificate fingerprints**

Then download a fresh `google-services.json` into:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

## Stage H - Maps/Places development key

Back in Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/create-android-maps-key.sh 'YOUR:DEBUG:SHA1'
```

Store the returned key locally in:

`C:\ConceptLab\Projects\homi\secrets.properties`

```properties
MAPS_API_KEY=...
PLACES_API_KEY=...
```

This file is ignored by Git.

## Stage I - App Check

After the first debug build launches:

1. obtain the App Check debug token from Android Studio Logcat;
2. register it in Firebase Console -> App Check -> Homi Android;
3. verify valid Firebase traffic;
4. keep enforcement OFF until expected debug/release traffic is known-good.

## Do not create

Do not create or commit:

- Firebase Admin/service-account JSON keys for the Android app;
- unrestricted Google Maps keys;
- signing keystores inside GitHub;
- `key.properties`;
- `secrets.properties`;
- long-lived OAuth access tokens.

## Current checkpoint

Run Stage C and send the Cloud Shell output from the project identity check through `Bootstrap complete`. After that, finish Stages D and E, then the Android host/fingerprint/Maps/App Check work can proceed.
