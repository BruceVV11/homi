# Homi

Homi is a privacy-conscious, local-first household operating system for remembering, coordinating, and caring for the small things that keep a home running, with optional consensual location sharing for trusted people.

## Current status

Pre-release foundation (`0.1.x`). The repository contains the product model, approved brand direction, Flutter app shell, local-first architecture, Firebase/Google Cloud bootstrap tooling, and the trusted-person location/safety foundation.

## Product promise

**Keep your home in order without keeping it all in your head.**

Homi surfaces what needs attention when it becomes relevant: household routines, pets, supplies, maintenance, appliances, documents, repairs, utilities, trusted contacts, and optional location sharing with people the user chooses.

## Permanent identifiers

- Android application ID: `za.co.theconceptlab.homi`
- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Local project root: `C:\ConceptLab\Projects\homi`
- Repository: `BruceVV11/homi`

These identifiers are the source of truth for Firebase Android registration, Google sign-in, Maps restrictions, App Check, Play Console and signing configuration.

The previously created Google Cloud project `homi-508000` is not used by Homi and must not be referenced by new configuration.

## Platform and development

Homi is a Flutter Android application intended to be opened from the project root in Android Studio:

`C:\ConceptLab\Projects\homi`

Do not open only the generated `android/` subfolder for normal Flutter development.

## Cloud architecture

The first implementation uses Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging and App Check in `homi-ee80a`. User-owned documents/media use Google Drive. Trusted-person maps use Google Maps Platform and Android location services.

Realtime Database is not required for the first implementation. Homi will first validate Firestore real-time listeners and actual location write volume before introducing another live-state database.

## Documentation

Start with:

- [`documentation/START-HERE-v0.1.0.md`](documentation/START-HERE-v0.1.0.md)
- [`documentation/FIREBASE-CLOUD-SETUP.md`](documentation/FIREBASE-CLOUD-SETUP.md)
- [`documentation/ARCHITECTURE.md`](documentation/ARCHITECTURE.md)
- [`documentation/LOCATION_SAFETY.md`](documentation/LOCATION_SAFETY.md)
- [`documentation/PRODUCT_VISION.md`](documentation/PRODUCT_VISION.md)

## Credentials

No service-account private key belongs in the Android app or public repository. Local Firebase/Maps/signing files are excluded through `.gitignore`.
