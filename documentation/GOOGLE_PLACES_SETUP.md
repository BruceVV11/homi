# Homi Google Places setup

Date: 2026-09-11
Applies to source: `0.10.0+14`

## Permanent cloud identity

- Project ID: `homi-ee80a`
- Project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`

Homi uses Maps SDK for Android + Places API (New). The mobile credential must remain Android package/SHA restricted; do not create an unrestricted browser/server key for the app.

## Local secret

Development values remain only in ignored local configuration:

`C:\ConceptLab\Projects\homi\secrets.properties`

Expected names:

```properties
MAPS_API_KEY=<private restricted key>
PLACES_API_KEY=<private restricted key>
```

Never paste the values into ChatGPT, GitHub, Dart source or screenshots/logs shared publicly.

A previously shown development key appeared in a screenshot and should be rotated/restricted before production acceptance.

## Flutter Places dependency

Homi uses `google_places_sdk_plus 1.1.0`, with the resolved Android implementation pinned through `pubspec.lock` by Flutter dependency resolution.

The abandoned `flutter_google_places_sdk` path must not be restored. Its published Android 0.2.2 implementation failed Kotlin compilation and the advertised 0.2.3 fix was not available through pub.dev.

## Dart define

The native Google Map and Dart Places client receive configuration differently. The Places client needs:

```text
--dart-define=HOMI_PLACES_API_KEY=<private PLACES_API_KEY value>
```

Android Studio development configuration:

1. **Run -> Edit Configurations...**
2. Select the Homi Flutter configuration launching `lib\main.dart`.
3. In **Additional run args**, enter the full `--dart-define=HOMI_PLACES_API_KEY=...` form.
4. Paste only the private value after the final `=`.
5. Keep **Store as project file** disabled so the key is not committed.
6. Apply, stop the running process, then Run again; hot reload is not enough for a compile-time Dart define.

Do not share the generated Flutter command once it contains the key.

## Address search behavior

Homi fetches only the Place ID, formatted address and coordinate required for saved Home/Work.

In 0.10.0 the address picker is internationalized with the selected Homi Emergency region as its country restriction, replacing the previous hardcoded South Africa restriction. This is a product default for the current selected region; **Set from here** remains available independently.

The picker retains Google's required attribution asset.

## Production

Before a Play build:

- use a production credential restricted to `za.co.theconceptlab.homi` and the relevant Play App Signing fingerprint;
- keep Maps SDK for Android + Places API (New) as the intended API targets;
- inject the key through the release build/secrets process, never committed source;
- verify Maps and autocomplete from a Play-installed Internal Testing build;
- configure Cloud Billing budgets/alerts before broad rollout;
- rotate any development key that was exposed in screenshots/logs.
