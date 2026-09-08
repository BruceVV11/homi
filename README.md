# Homi

Homi is a privacy-conscious, local-first household operating system for remembering, coordinating, and caring for the small things that keep a home running, with optional consensual location sharing for trusted people.

## Current status

Pre-release `0.1.0` first-installable source pass.

The repository now contains the branded Flutter application flow, onboarding, local-first profile state, authentication integration, foreground location/battery capture, Firebase/App Check integration code, Android bootstrap tooling and project documentation.

The Android host is generated on the development PC with the installed Flutter SDK so Gradle/Kotlin versions match the real Android Studio environment.

## Product promise

**Happy homes, easier days.**

Homi surfaces what needs attention when it becomes relevant: household routines, pets, supplies, maintenance, appliances, documents, repairs, utilities, trusted contacts, and optional location sharing with people the user chooses.

## Permanent identifiers

- Android application ID: `za.co.theconceptlab.homi`
- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Local project root: `C:\ConceptLab\Projects\homi`
- Repository: `BruceVV11/homi`

The previously created Google Cloud project `homi-508000` is not used by Homi.

## First installable pass

Start with:

- [`documentation/FIRST-INSTALLABLE-BUILD.md`](documentation/FIRST-INSTALLABLE-BUILD.md)
- [`documentation/START-HERE-v0.1.0.md`](documentation/START-HERE-v0.1.0.md)
- [`documentation/FIREBASE-CLOUD-SETUP.md`](documentation/FIREBASE-CLOUD-SETUP.md)

The approved Option 4 identity is the source of truth:

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito visual language
- Approved lowercase Homi `h` mark and Homi lockup

## Platform and development

Homi is a Flutter Android application. Open the project root in Android Studio:

`C:\ConceptLab\Projects\homi`

Do not open only the `android/` subfolder for normal Flutter development.

## Cloud architecture

The first implementation uses Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging and App Check in `homi-ee80a`. User-owned documents/media will use Google Drive. Trusted-person maps use Google Maps Platform and Android location services.

Realtime Database is not required for the first implementation. Homi will validate actual Firestore location write volume before introducing another database.

## Credentials

No service-account private key belongs in the Android app or public repository. Local Firebase, Maps and signing files are excluded through `.gitignore`.
