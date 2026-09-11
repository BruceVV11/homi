# Homi

Homi is a privacy-conscious, local-first household operating system for remembering, coordinating and caring for the small things that keep a home running, with optional consensual location sharing for trusted people.

## Current status

Current source candidate: **`0.11.0+15`**.

Homi now includes the approved branded Flutter shell, local-first Tasks/Routines/Supplies/Home records, optional Firebase identity, trusted-person connections, consent-based live location, arrival check-ins, notifications, emergency-region shortcuts, Google Maps/Places integration and the first canonical shared-Household identity/membership layer.

The 0.11 source also uses bundled ISO country flags for emergency-region UI and fixes the full-map emergency sheet so service-specific numbers remain scrollable above Android system navigation.

Full synchronized Household Home/Routines/Supplies data and Google Play billing/entitlements are not claimed as complete yet. The canonical Household introduced in 0.11 is the identity layer those features will attach to.

The Android host is generated/maintained on the development PC with the installed Flutter SDK so Gradle/Kotlin versions match the real Android Studio environment. `android/` intentionally remains local/untracked because it contains machine-specific/private Firebase, Maps and signing configuration.

## Product promise

**Happy homes, easier days.**

Homi surfaces what needs attention when it becomes relevant: household routines, pets, supplies, maintenance, appliances, documents, repairs, utilities, trusted contacts and optional location sharing with people the user chooses.

## Permanent identifiers

- Android application ID: `za.co.theconceptlab.homi`
- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Firestore / Functions region: `africa-south1`
- Local project root: `C:\ConceptLab\Projects\homi`
- Repository: `BruceVV11/homi`

The deleted Google Cloud project `homi-508000` is not used by Homi and must never be reused.

## Current architecture and handoff

Start with:

- [`documentation/ARCHITECTURE.md`](documentation/ARCHITECTURE.md)
- [`documentation/MONETIZATION.md`](documentation/MONETIZATION.md)
- [`documentation/LOCATION_SAFETY.md`](documentation/LOCATION_SAFETY.md)
- [`documentation/releases/0.11.0.md`](documentation/releases/0.11.0.md)
- [`NEXT_CHAT_PROMPT.md`](NEXT_CHAT_PROMPT.md)

Historical first-install documentation remains under `documentation/` for setup provenance.

## Brand source of truth

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito visual language
- Approved lowercase Homi `h` mark and Homi lockup in `assets/brand/`

## Platform and development

Homi is a Flutter Android application. Open the project root in Android Studio:

`C:\ConceptLab\Projects\homi`

Do not open only the `android/` subfolder for normal Flutter development.

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

## Cloud architecture

Homi uses Firebase Authentication, Cloud Firestore, Cloud Functions 2nd gen, Firebase Cloud Messaging and App Check in `homi-ee80a`. Trusted-person maps use Google Maps Platform and Android location services. Home/Work address selection uses Places API (New).

Cloud collaboration is intentionally narrow and server-governed. Sensitive mutations such as connection lifecycle, Household membership/ownership, shared-task changes, location-share grants, arrival delivery, exact saved-place sharing, device registration and account deletion go through protected backend functions rather than arbitrary client writes.

Realtime Database is not currently required. Homi validates actual Firestore cost/write behaviour before introducing another datastore.

## Credentials

No service-account private key belongs in the Android app or public repository. Local Firebase, Maps/Places, App Check and signing material must remain outside tracked source.
