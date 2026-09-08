# Homi v0.1.0 - Start Here

Use this sequence to prepare the first installable Android build.

## Project identities

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Google Cloud / Firebase: `homi-508000`
- Android package: `za.co.theconceptlab.homi`

## Stage A - Get the repository locally

The local Homi folder is currently intended to be the repository root.

If `C:\ConceptLab\Projects\homi` is empty, open PowerShell and run:

```powershell
cd C:\ConceptLab\Projects
Remove-Item -Path .\homi -Force -Recurse

git clone https://github.com/BruceVV11/homi.git homi
cd .\homi
```

Do not run the removal command if the folder contains files you need to preserve.

For normal development, open `C:\ConceptLab\Projects\homi` in Android Studio.

## Stage B - Automate Google Cloud/Firebase provisioning

Open Google Cloud Shell while `homi-508000` is selected and run:

```bash
gcloud billing accounts list
git clone https://github.com/BruceVV11/homi.git
cd homi
HOMI_BILLING_ACCOUNT=YOUR-BILLING-ACCOUNT-ID bash scripts/bootstrap-google-cloud.sh
```

If billing is already linked and you do not want the script to change it:

```bash
bash scripts/bootstrap-google-cloud.sh
```

Expected successful end-state:

- Firebase attached to `homi-508000`
- required APIs enabled
- Firebase Android app `za.co.theconceptlab.homi` registered
- Firestore `(default)` created in Johannesburg
- keyless runtime service account created
- initial Firebase Android config exported to `~/homi-google-services.json`

## Stage C - Manual console switches

Complete the steps in `documentation/FIREBASE-CLOUD-SETUP.md`:

1. Firebase Authentication -> enable Email/Password.
2. Firebase Authentication -> enable Google.
3. Google Auth Platform -> configure Homi branding/audience/test users.
4. Confirm Firestore exists in `africa-south1`.
5. Confirm Cloud Messaging HTTP v1 is enabled.
6. Leave App Check enforcement OFF for now.

## Stage D - First Android host

The first installable code pass will create/maintain the Flutter Android host with package:

`za.co.theconceptlab.homi`

It must already contain the approved Homi branding:

- exact master logo
- adaptive launcher icon
- monochrome/themed launcher icon
- splash/loading branding
- in-app Homi mark

No placeholder Flutter launcher artwork should ship in the first installable build.

## Stage E - Get certificate fingerprints

After the Android host exists:

```powershell
cd C:\ConceptLab\Projects\homi\android
.\gradlew signingReport
```

Record the debug SHA-1 and SHA-256.

Add both in Firebase Console:

**Project settings -> General -> Homi Android -> SHA certificate fingerprints**

Then download a fresh `google-services.json` to:

`C:\ConceptLab\Projects\homi\android\app\google-services.json`

## Stage F - Maps/Places development key

Back in Cloud Shell:

```bash
cd ~/homi
bash scripts/create-android-maps-key.sh 'YOUR:DEBUG:SHA1'
```

Store the returned value locally in:

`C:\ConceptLab\Projects\homi\secrets.properties`

```properties
MAPS_API_KEY=...
PLACES_API_KEY=...
```

This file is ignored by Git.

## Stage G - App Check debug registration

After the first debug build launches and App Check is integrated:

1. obtain the App Check debug token from Android Studio Logcat;
2. add it in Firebase Console -> App Check -> Homi Android -> Manage debug tokens;
3. verify valid Firebase traffic;
4. keep enforcement OFF until all expected debug/release requests are known-good.

## What not to create

Do not create or commit:

- Firebase Admin/service-account JSON keys for the Android app
- unrestricted Google Maps keys
- signing keystores inside GitHub
- `key.properties`
- `secrets.properties`
- long-lived OAuth access tokens

## Checkpoint before application feature implementation

When Stages B and C are complete, capture the final Cloud Shell output and Firebase Authentication screen. The Android host can then be finished, fingerprints registered, and the first installable Homi build completed.
