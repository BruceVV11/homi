# Homi Google Places setup

Date: 2026-09-11
Applies to source: `0.9.2+13`

## Existing cloud setup

Homi uses the existing Google Cloud project:

- Project ID: `homi-ee80a`
- Project number: `883068189841`
- Android package: `za.co.theconceptlab.homi`

The established Cloud Shell bootstrap already enables:

- Maps SDK for Android
- Places API (New)
- API Keys API

The established key helper is:

```bash
cd ~/homi
git pull
bash scripts/create-android-maps-key.sh '<DEBUG_SHA1>'
```

It creates an Android-restricted credential for the Homi package + supplied SHA-1 and limits API usage to Maps SDK for Android and Places API (New).

Do not create an unrestricted browser/server Places key for the mobile app.

## Local secret

The development key belongs only in the ignored local file:

`C:\ConceptLab\Projects\homi\secrets.properties`

Expected entries:

```properties
MAPS_API_KEY=<private restricted key>
PLACES_API_KEY=<private restricted key>
```

Never paste the actual value into ChatGPT, GitHub, Dart source, documentation or a screenshot/log shared publicly.

## Flutter Places dependency

Homi uses `google_places_sdk_plus 1.1.0`, a maintained fork of the original `flutter_google_places_sdk` package that continues to use Google's native Places SDK on Android and supports Places API (New).

The original package path was abandoned after its published Android `0.2.2` implementation failed Kotlin compilation and the advertised `0.2.3` fix was not actually published to pub.dev. Do not restore the old `flutter_google_places_sdk_android: 0.2.3` override.

`google_places_sdk_plus 1.1.0` requires Dart >=3.11.0 and Flutter >=3.41.0, which matches Homi's Flutter 3.41.x toolchain. Its Android implementation remains a native SDK integration, so Homi can keep using an Android application-restricted Places key rather than an unrestricted browser/server key.

The resolved application lock file must be regenerated and committed after this dependency migration is validated on Bruce's Windows Flutter toolchain.

## Why one extra Flutter run setting is needed in 0.9.2

The existing Android Maps host reads the local key for the native map. The Flutter Places client is created from Dart, so the same restricted private key is supplied to Dart at build/run time using:

```text
--dart-define=HOMI_PLACES_API_KEY=<private PLACES_API_KEY value>
```

`HomiGooglePlacesService` reads only `HOMI_PLACES_API_KEY`. If it is absent, Homi does not crash or fall back to an unrestricted request; the address picker explains that Google address search is unavailable and **Set from here** remains available.

## Android Studio development configuration

After the Flutter/backend gates pass:

1. Open `C:\ConceptLab\Projects\homi\secrets.properties` locally.
2. Copy only the value after `PLACES_API_KEY=` to the clipboard. Do not send it in chat.
3. In Android Studio open **Run → Edit Configurations…**.
4. Select the existing Flutter configuration used to run `lib\main.dart`. If Android Studio has only the temporary Flutter configuration, create a normal **Flutter** configuration for this project first.
5. In **Additional run args**, enter:

   ```text
   --dart-define=HOMI_PLACES_API_KEY=<paste the private local value here>
   ```

6. Apply/save the configuration.
7. Keep the Android Studio run configuration local. Do not add a run-configuration file containing the key to Git.
8. Run Homi normally with the green Run button on the S25 Ultra.

This is a one-time development-machine setup until the key changes.

### Verification

When Android Studio starts Flutter, inspect the first command line. It must contain Homi's private Places define:

```text
--dart-define=HOMI_PLACES_API_KEY=...
```

Do not share the full generated command publicly if it contains the real key.

If the generated Flutter command does not contain `HOMI_PLACES_API_KEY`, the saved Android Studio Flutter run configuration is not supplying the Places key yet. Fix the run configuration before judging autocomplete behaviour.

## Production

Before a Play build:

- create/use the production credential restricted to `za.co.theconceptlab.homi` plus the Play App Signing SHA-1 as required by Google Maps/Places;
- keep Places API (New) and Maps SDK for Android as the only needed API targets for that key;
- supply the production key through the release build process/secrets environment, not committed source;
- verify Google Places autocomplete from a Play-installed Internal Testing build;
- review Places usage/billing and Cloud Billing alerts before broad release.

The Google Places integration requests only the minimal details needed after selection: Place ID, formatted address and location.
