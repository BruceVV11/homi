# Homi Release Notes

## 0.1.0 - Foundation in progress

### Cloud foundation complete - 2026-09-08

- Locked Firebase / Google Cloud project to `homi-ee80a` (`883068189841`).
- Locked Android application ID to `za.co.theconceptlab.homi`.
- Linked Concept Lab Internal billing.
- Enabled required Firebase, Google Maps/Places, Drive and Google Cloud runtime APIs.
- Registered the Homi Android Firebase app.
- Verified Firestore `(default)` in `africa-south1` (Johannesburg).
- Created keyless backend runtime identity `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`.
- Applied initial Firestore and FCM runtime roles.
- Exported the initial Android Firebase configuration to Cloud Shell.
- Created no downloadable service-account private key.

### Next

- Enable Firebase Email/Password and Google authentication providers.
- Configure Google Auth Platform branding/audience for `homi-ee80a`.
- Generate the permanent Flutter Android host and approved Homi launcher/splash assets.
- Add debug SHA-1/SHA-256 to Firebase.
- Create the restricted Maps/Places Android API key.
- Integrate Firebase Auth, Firestore and App Check debug provider.
- Produce and device-test the first installable Homi build.
