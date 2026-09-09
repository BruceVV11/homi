# Homi Architecture

## Permanent project identifiers

- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android application ID: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub repository: `BruceVV11/homi`

These identifiers are locked for the Android/Firebase/Play lifecycle. The deleted `homi-508000` project is not part of Homi.

## Stack

- Flutter / Dart Android application
- Android minimum SDK 24 for the current Google Maps Flutter integration
- SharedPreferences for version-tolerant local-first household records
- Firebase Authentication for optional account identity
- Cloud Firestore in `africa-south1` for authenticated shared state and latest trusted-person location
- Firebase Cloud Messaging for later notifications
- Firebase App Check: Debug provider during development, Play Integrity for release
- Google Maps Flutter for People map UI
- Geolocator for foreground and opt-in Android foreground-service location updates
- Platform geocoding for human-readable location details
- Google Drive direction remains user-owned home documents/media; Drive document UX is not yet exposed as a completed feature

## Primary navigation

The persistent shell owns the Homi logo/profile header and the custom five-destination navigation:

1. Overview
2. Routines
3. Home
4. Supplies
5. People

Home remains deliberately centred and uses the exact approved Homi mark. Primary pages remain inside a horizontally swipeable `PageView`. Android Back from a secondary primary destination returns to Overview before root exit.

The bottom navigation uses a custom-painted white surface with a raised integrated mound around the active circular destination. Taps use Homi-controlled gesture handling rather than Material ink/splash selection blocks.

## Overview and Quick Reset

Overview shows real state only:

- Routines that are actually due according to their recurrence schedule
- Supplies needing attention, including expiry-derived `Use soon` / `Expired` state
- Home Things with service due or approaching
- local Quick Add reminders

`QuickResetPlanner` powers **When you have time**. The user chooses a time budget such as 10 or 30 minutes. Due saved Routines are prioritised, then a shuffled pool of common household suggestions may fill spare time. The plan never exceeds the selected budget. Built-in suggestions rotate each invocation and remain session-only; saved Routines update their real completion record.

## Local-first household data

### Routines

`RoutineItem` now models actual recurrence instead of only a descriptive frequency label:

- stable UUID
- title/category
- estimated duration
- repeat type: one-off, daily, weekdays, weekly, monthly
- weekly day set or monthly day-of-month
- exact due hour/minute
- computed next-due timestamp
- bounded completion history
- each completion stores time, display name and optional Firebase UID

After a recurring Routine is completed, Homi computes its next occurrence and shows both the previous completion attribution and next due time. Older Routine JSON is migrated from the previous `frequency`, `completed` and `lastCompletedAt` fields where possible.

The completion attribution is already suitable for shared household records, but Routine records remain local in this pass. Cross-device household Routine synchronization must not be claimed until a household membership + merge/conflict strategy is implemented and tested.

### Supplies

Supply records contain name, category, stock state and optional expiry date. Fixed choices use Homi inline controls instead of dropdown menus. Common household Quick Adds prefill the editor for items such as milk, bread, eggs, dog food, toilet paper and dishwashing liquid.

Manual `Running low` / `Need to buy` states take precedence. Otherwise an in-stock item becomes `Use soon` within three days of expiry and displays `Expired` after its expiry date.

### Home

Home is now a real local-first domain rather than placeholder category cards.

`HomeThing` stores:

- appliance/equipment/item name
- category and location in the home
- optional brand/model
- optional next service date
- optional warranty date and notes in the model

`HomeEvent` stores maintenance or repair history with date, optional linked Thing, notes and who completed/logged the work.

`UtilityReading` stores electricity/water readings, unit, timestamp and who recorded the reading.

Overview can surface Things whose service date is due or approaching.

### Persistence

Quick Add, Routines, Supplies, Home Things, Home Events and Utility Readings are stored locally as JSON strings in SharedPreferences. Invalid/corrupt legacy entries are skipped rather than blocking startup. Local-only use remains fully valid without Firebase Authentication.

## Authentication and profile identity

Firebase Authentication remains optional for core local use. Email/password and Google are supported.

Signed-in UI shows:

- display name/email
- Firebase email verification state
- Google provider identity where applicable
- Google profile photo when available
- profile settings, verification resend/refresh and password reset only where applicable

Sign-out stops active live-location updates before ending the Firebase session.

## Trusted people and location

Trusted-person connection and location consent are intentionally separate capabilities.

### Connection flow

Signed-in users receive a random 6-character Homi code. `/homiCodes/{code}` is an authenticated exact-lookup contact card and collection listing is denied by Firestore rules.

A code creates a pending `/connections/{pairId}` relationship. The recipient must explicitly accept. Either member can later remove the connection.

**Accepting a connection does not grant location access.**

### Per-person location consent

The location owner separately controls:

`/locationShares/{ownerUid}/viewers/{viewerUid}`

A viewer may read `/locations/{ownerUid}` only when that share document is active. The client cannot bypass this rule by merely being connected.

### Current location model

Homi stores only the latest location/battery snapshot by default:

- latitude/longitude
- accuracy
- battery percentage
- charging state
- server-updated timestamp
- source mode

No default breadcrumb/route history collection exists.

People displays a persistent Google Map. Map markers use the person's profile photo where available, or an initials fallback. Selecting a marker exposes last update, battery, accuracy, reverse-geocoded address and coordinates. Address/coordinates can be copied and the location can be opened externally in Google Maps.

### Foreground vs live background sharing

Foreground location permission is enough for an explicit/current-location refresh. Once permission already exists, People refreshes automatically rather than requiring the user to press `Check my location` every visit.

Live sharing is a second explicit opt-in. On Android it uses Geolocator's location foreground-service configuration with:

- medium location accuracy
- 100 metre distance filter
- approximately two-minute requested interval
- no wake lock
- visible Homi foreground-service notification

The user must grant Android `Allow all the time` location access for background updates. If live sharing was previously enabled, Homi attempts to resume it on the next app session without re-prompting; an explicit stop clears that preference.

This is deliberately battery-conscious, but actual battery behaviour and Android delivery cadence must be validated on real devices. Force-stop/reboot resilience is a separate release-hardening concern and is not assumed merely because a foreground service works while the app is backgrounded.

## Android host requirements

The local Android host is generated/untracked, so `scripts/enable-location-map-android.ps1` idempotently enforces the native requirements after pulling this pass:

- `INTERNET`
- coarse/fine location
- `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_LOCATION`
- `POST_NOTIFICATIONS`
- Google Maps API-key metadata referencing the existing local `@string/google_maps_key`
- min SDK 24

The script never prints or rewrites the actual Maps API key value.

## Firestore security

- account profile documents remain self-only
- Homi codes are exact authenticated lookups, not listable
- connection documents are readable only by their two members
- only the invited recipient may move a connection from pending to accepted
- location-share documents are controlled by the location owner
- location reads require an explicit active share
- all unspecified paths fail closed
- no service-account credential is bundled in the app

The new Firestore rules must be deployed before testing Homi-code connections.

## Shared household sync boundary

Routines/Home/Supplies are not silently uploaded just because a user signs in. Multi-user household data needs a defined household membership model plus first-sync merge/conflict rules. Completion attribution is implemented in the local model now, but another household member will not see those Routine updates on a different phone until that shared household synchronization layer is built.

## Brand and UI rule

The approved Homi logo assets under `assets/brand/` remain the only brand source of truth. Fixed choices prefer Homi inline selection controls. Destructive actions and important confirmations use Homi-styled sheets rather than generic popup menus/dialogs wherever practical. Framework-drawn approximations of the Homi mark are not acceptable.
