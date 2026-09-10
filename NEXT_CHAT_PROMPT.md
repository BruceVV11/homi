# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub remains the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.9.2.md`
- `documentation/GOOGLE_PLACES_SETUP.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/SECURITY.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- latest affected Flutter/Functions/Firestore source.

Use **mobile-app-development** first. For Firebase/Cloud Shell release work also use Concept Lab release integrity. Preserve approved behaviour/design and do not use Bruce's reruns as the diagnostic mechanism; inspect source/log evidence before asking for another gate.

Never claim compiled/deployed/on-device success without Bruce's actual toolchain/provider/device evidence.

## Permanent project context

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore / Functions region: `africa-south1`
- Flutter: 3.41.5 stable
- Dart: 3.11.3
- Development device: Samsung S25 Ultra
- JDK 21 / Gradle 8.14
- Functions runtime: Node.js 22
- `android/` intentionally remains local/untracked.
- Preserve local Firebase/Maps/Places/signing files. Never ask Bruce to paste Maps/Places keys, App Check debug tokens or signing secrets into chat.
- Deleted project `homi-508000` must never be used.
- Safety stash remains `stash@{0}: On main: Homi pre-0.5.0 local tracked changes`; never pop/delete automatically.

## Approved brand / navigation

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito
- exact brand assets under `assets/brand/`; never redraw approximations.

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark. The persistent Homi header/profile row and bottom navigation are shell UI and must not be replaced by a feature-specific navigation pattern.

## Current version

Current source: **`0.9.2+13`**.

The previously validated/deployed 0.9.0 backend candidate was:

`c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`

Bruce later confirmed 0.9.1 Flutter analyzer/tests were green, but the first 0.9.1 S25 Ultra device review exposed additional People/Safety issues. 0.9.2 is the corrective pass and is not yet Flutter/backend/device proven.

## Device evidence that triggered 0.9.2

Bruce reported and supplied screenshots/logcat showing:

1. full People map needed emergency/SOS access within reach;
2. Person Details should include Home and Work, including self;
3. Safety/check-in UI still had an oversized green status card, a duplicate orange success card and missing information icon on How it works;
4. Home/Work should use proper Google Maps/Places address selection and selected arrival recipients should be shown visually with profile photos/names;
5. People surfaced raw `UNAUTHENTICATED` and appeared unusable.

The supplied Android log window itself showed Firestore `UNAVAILABLE` / DNS name-resolution failures rather than a logged Functions `UNAUTHENTICATED`. Source inspection also found an auth-lifecycle/callable-error problem that could expose an authentication code. 0.9.2 addresses both boundaries separately.

## 0.9.2 People authentication/recovery

### `PeopleHubPage`

The compatibility wrapper remains around the approved map-first `PeoplePage`, but now watches `FirebaseAuth.instance.idTokenChanges()` and re-keys `PeoplePage` when the authenticated UID changes/restores. This prevents kept-alive Firestore subscriptions from remaining bound to an old signed-out identity.

### `HomiCloudActions`

Protected callable actions now:

- require a current Firebase user;
- translate callable failures into finished-product language;
- on one `unauthenticated` response, force-refresh Firebase ID token + App Check token and retry once;
- never intentionally expose raw `UNAUTHENTICATED` as user-facing copy.

Full-map People hearts now use this same wrapper instead of bypassing it.

Firestore transport/network failures remain distinct; realtime listeners should recover and must not expose raw transport codes.

## Safety & check-ins UI

The Arrival check-ins section now uses one Notifications-style setting row at all times:

- title: **Arrival check-ins on this device**;
- switch directly reflects actual saved ON/OFF state;
- explanatory copy states that Homi monitors only configured Home/Work and selected people;
- turning it off stops monitoring but keeps saved places;
- there is no large green hero/status card;
- there is no redundant success box saying check-ins are on;
- success actions stay quiet;
- only actionable setup/permission/errors use inline notices.

**How it works** now uses an information icon and bottom sheet consistent with approved Homi contextual-help patterns.

## Google Places Home/Work setup

0.9.2 adds `flutter_google_places_sdk` and `HomiGooglePlacesService`.

Address setup now supports:

- Google Places autocomplete limited to South Africa;
- selecting a Google suggestion fetches only Place ID, formatted address and coordinate;
- Google attribution is rendered with the results;
- **Set from here** remains available and reverse-geocodes the current phone location.

The new plugin reads the private key from:

`--dart-define=HOMI_PLACES_API_KEY=<private restricted key>`

The actual key is never committed or pasted into chat. See `documentation/GOOGLE_PLACES_SETUP.md` for the exact Android Studio setup after Flutter/backend gates pass.

The established `homi-ee80a` cloud bootstrap already enables Places API (New), and the existing restricted key helper targets Homi package/SHA + Maps SDK + Places API (New).

## Arrival recipient presentation

Saved Home/Work cards show selected arrival recipients as profile photo/initial avatars with each name beneath. Do not revert to summary copy such as `notifies Casey`.

## Exact Home/Work visibility

Bruce requested Home/Work inside Person Details for self and trusted people. Privacy contract is intentionally narrower than normal connection/arrival selection.

The owner always sees their own saved Home/Work locally.

Another person sees exact Home/Work only if the owner explicitly enables **Show this place to selected people** for that place AND all server conditions remain true:

1. viewer is explicitly in that place's selected viewer list;
2. connection remains accepted;
3. owner currently has location sharing active to that viewer.

Arrival-recipient selection alone does **not** reveal the address.

Optional cloud document:

`sharedPlaces/{ownerUid}/places/{home|work}`

contains only owner UID, kind, lat/lng, readable address, explicit viewer UIDs and server timestamp.

Direct client writes are denied. Mutation is through new protected callable `setSharedArrivalPlace`.

Turning the per-place switch off removes the cloud copy while preserving local arrival settings. Disconnect cleanup strips stale saved-place viewers. User deletion removes owned Home/Work copies.

`sendArrivalCheckIn` itself is unchanged and still receives no saved address/coordinate.

## Full People map

The full-screen People map keeps existing markers/person chips/focus/heart/details and now adds lower thumb-reach emergency actions:

- **SOS · 112** — one tap opens the phone app with 112 ready;
- **Emergency numbers** — opens 112 / 10111 / 10177 choices without leaving the map first.

Homi still does not silently call, dispatch responders or automatically transmit location to emergency services.

Full-map Person Details now includes:

- Latest location;
- Home;
- Work.

Self places come from local arrival settings. Other people's Home/Work appears only when the exact-place Firestore authorization succeeds.

## New 0.9.2 backend/rules

New `functions/saved_places.js` exports:

- `setSharedArrivalPlace`
- `onHomiUserSharedPlacesDeleted`

`setSharedArrivalPlace`:

- Firebase Authentication + App Check;
- verified email for password-provider accounts;
- Home/Work only;
- bounded latitude/longitude/address;
- max 10 viewers;
- revalidates viewers as accepted Homi connections;
- 120/hour + 400/day owner change limits;
- deletes the saved-place document when clearing/no valid viewers remain.

`onTrustedConnectionDeleted` now strips a disconnected UID from shared Home/Work viewer lists.

Firestore rules add `sharedPlaces` and allow another user's exact document read only with explicit viewer membership + accepted connection + active owner→viewer location share. Client create/update/delete remains denied.

The Firestore emulator suite has a new shared-place privacy test. Do not claim the expanded suite passes until Cloud Shell proves it.

## Migration / deletion

Existing 0.9/0.9.1 arrival settings remain readable. New fields safely default:

- Place ID: null
- exact-place sharing: false

Therefore upgrading does not suddenly expose anyone's existing Home/Work.

Local erase clears local arrival data and attempts to remove optional owned shared-place cloud copies. If temporarily offline, Homi stores only a non-sensitive pending-clear marker and retries on next signed-in load. Firestore's independent connection/current-location-share requirements continue to block unauthorized reads.

## Immediate next gate — Windows Flutter toolchain

Run once:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter pub get
flutter analyze
flutter test
git diff --unified=3 -- pubspec.lock
```

`flutter pub get` is required because 0.9.2 adds the Google Places Flutter dependency.

Expected:

- dependency resolution succeeds;
- `flutter analyze` → **No issues found!**;
- `flutter test` → **All tests passed!**;
- send the complete output, including the final `pubspec.lock` diff.

The lock diff is needed because the assistant environment does not have Flutter/Dart and therefore cannot safely invent the resolved dependency lock.

If analyzer/tests fail, inspect/fix all related errors in one source pass before asking Bruce for another validation.

## After a clean Flutter gate — Cloud Shell IS required

Unlike 0.9.1, 0.9.2 changes Functions and Firestore rules. After the Flutter source/lock is settled, use the existing governed helper:

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

The helper must:

- verify Node 22/project identity;
- prepare/install Function dependencies;
- syntax-check all Function modules including `saved_places.js`;
- run the expanded Firestore emulator security suite;
- deploy Firestore rules/indexes;
- deploy Functions in existing batches.

Important new resources expected include:

- `setSharedArrivalPlace`
- `onHomiUserSharedPlacesDeleted`

and the updated `onTrustedConnectionDeleted` code/rules.

Capture the full Cloud Shell result. Do not weaken rules to make deployment/tests pass.

## After backend deployment — local Places key, then S25 Ultra

Follow `documentation/GOOGLE_PLACES_SETUP.md` locally. Never paste the key in chat.

For Android Studio's Flutter run configuration, Additional run args must include:

`--dart-define=HOMI_PLACES_API_KEY=<private local PLACES_API_KEY>`

Then run normally on the S25 Ultra.

## 0.9.2 S25 Ultra acceptance matrix

Verify together:

1. People opens map-first with persistent Homi shell/header/nav.
2. Existing embedded map/location/live-share behavior still works.
3. No raw `UNAUTHENTICATED`; Homi code/connections/relationship Edit/location share all work.
4. Network loss/recovery gives product wording and recovers state.
5. Full map has reachable SOS · 112 and Emergency numbers controls.
6. 112 / 10111 / 10177 each open intended dialer number; do not complete test emergency calls.
7. Arrival screen has one toggle card in both ON/OFF states; no green status hero or redundant success message.
8. How it works has information icon and bottom sheet.
9. Google Home/Work autocomplete returns appropriate South African suggestions and selected place is correct.
10. Set from here independently works.
11. Saved-place recipients show photo/initial + name.
12. Self Person Details shows local Home/Work.
13. Other person does not see Home/Work without explicit exact-place sharing.
14. Exact-place sharing + active location share exposes only selected Home/Work.
15. Turning current-location share off blocks remote Home/Work immediately.
16. Turning exact-place switch off removes remote Home/Work without deleting local arrival setup.
17. Disconnect removes stale exact-place access.
18. People heart works through protected callable wrapper.
19. Existing task assignee photos/Household-only eligibility remain healthy.
20. Live updates / Arrival check-ins continue to own shared background stream independently.

Real arrival delivery still needs outside→inside movement and a second trusted account/device before acceptance.

## Existing production gates

After 0.9.2 device proof, major later gates still include:

- multi-hour/screen-off/reboot/Samsung power tests;
- Google Play background-location declaration/prominent disclosure;
- Shared Household sync decision/implementation before household-wide marketing claims;
- production signing / Play App Signing SHAs;
- Play-installed Google Sign-In and production Maps/Places restrictions;
- Play Integrity App Check and later Firestore enforcement after valid metrics;
- cloud billing alerts/monitoring;
- public Privacy Policy, Terms and external account-deletion page;
- Play Data Safety/content rating/audience/app-access/assets;
- one controlled broad developer notification;
- Homi+ only once real premium shared-cloud value exists.

Pricing remains planning only:

- Homi Free — R0
- Homi+ — R49.99/month or R499.99/year

Privacy, stop-sharing, exact-place revoke, arrival-check-in disable and deletion are never paywalled.

## Documentation rule

After every source/backend/device pass, update the relevant docs/release note and this handoff with only the state actually proven.