# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub is the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.8.2.md`
- `documentation/releases/0.8.2-functions-batching-fix.md`
- `documentation/releases/0.8.2-backend-deployment-complete.md`
- `documentation/releases/0.9.0.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. For Firebase/Cloud Shell release work also use Concept Lab release integrity. Do not use Bruce's reruns as a diagnostic mechanism; inspect all discoverable source/tests/deployment contracts first.

Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a source pass compiled, deployed or worked on-device until Bruce's real Flutter/Android/Firebase toolchain proves it.

## Permanent project context

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore / Functions region: `africa-south1`
- Flutter baseline: 3.41.5 stable
- Dart baseline: 3.11.3
- Development device: Samsung S25 Ultra
- JDK 21 / Gradle 8.14
- Functions runtime: Node.js 22
- `android/` is intentionally local/untracked.
- Preserve local Firebase/Maps/signing files. Never ask Bruce to paste Maps keys or App Check debug tokens into chat.
- Deleted project `homi-508000` must never be used.

Bruce still has this safety stash:

`stash@{0}: On main: Homi pre-0.5.0 local tracked changes`

Do not automatically pop or delete it.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito
- exact Homi logo/mark assets are under `assets/brand/`; never redraw them.

## Standing user-facing copy rule

All user-visible Homi wording must read as a complete product. Never expose “being built”, “pre-release”, “future feature”, “not yet implemented”, roadmap/developer language.

Do not misrepresent unavailable capability. Internal docs must still state real blockers.

## Current source version

**`0.9.0+11`**

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## 0.8.2 backend — COMPLETED

Bruce confirmed on 10 September 2026 that the corrected 0.8.2 backend deployment completed successfully.

The proven path includes:

- Node 22 guard;
- temporary/disposable Functions dependency workspace;
- synchronized generated package lock;
- local `npm ci`;
- Function syntax gate;
- Firestore Emulator security suite **12/12**;
- Firestore rules/index deployment;
- safe migration from stale HTTPS `onConnectionDeleted` to active Firestore trigger `onTrustedConnectionDeleted`;
- dedicated runtime identity `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`;
- Function deployment in batches of five.

Do not reopen the old dependency/lock/trigger/broad-deployment incidents unless new evidence specifically points there.

The deployment helper remains:

```bash
bash scripts/deploy-notification-backend.sh
```

and owns dependency preparation, syntax checks, the Firestore security gate, Firestore deployment and batched Function deployment.

## Current 0.9 source pass

Bruce requested four additions before running the new app build:

1. South African emergency-service speed-dial style shortcuts;
2. automatic Home/Work arrival check-ins to selected trusted people;
3. profile pictures in Task assignment plus clear Household vs non-Household grouping on People;
4. app operational notifications on by default for fresh installs.

These are implemented in GitHub source and documented.

### 10 September 2026 first Flutter validation

Bruce pulled source through `679bc649602f6a681208e64e92d7f11b62b87231` and ran:

```powershell
flutter pub get
flutter analyze
flutter test
```

Results:

- dependency resolution completed successfully;
- **30 Flutter tests passed**;
- analyzer found **no compile errors**;
- analyzer found two deprecation infos in `safety_check_in_page.dart` for the old `RadioListTile` group API;
- analyzer found one unused `_primePlace` warning in `arrival_check_in_service.dart`.

Those three analyzer findings were then fixed on `main`:

- `_primePlace` was removed;
- the radius selector now uses Homi's existing `HomiChoiceGroup<double>` instead of the deprecated radio group API.

The current head therefore needs only one short **post-fix** `flutter analyze` + `flutter test` rerun before Cloud Shell deployment. Do not claim the current head is analyzer-clean until Bruce proves that rerun.

### Safety & emergency calls

New People → **Safety & check-ins** surface.

Current South African call shortcuts:

- `112` — emergency from a mobile phone;
- `10111` — police emergency;
- `10177` — ambulance emergency.

Implementation uses `url_launcher` with a `tel:` URI and opens the device phone app with the number ready. Homi deliberately does not request direct-call permission or silently place calls.

User-facing copy must continue to state that Homi does not dispatch responders and does not automatically send location to emergency services.

Emergency shortcuts work without a Homi account.

### Arrival check-ins

New source:

- `lib/src/domain/arrival_check_in.dart`
- `lib/src/services/arrival_check_in_service.dart`
- `lib/src/features/people/safety_check_in_page.dart`
- `functions/check_in.js`

The user explicitly configures check-ins:

1. sign in;
2. save Home and/or Work while physically there;
3. choose radius (current UI: 150/250/500 m; bounded model: 75 m–1 km);
4. choose accepted trusted recipients per place;
5. turn Arrival check-ins on.

Privacy architecture:

- Home/Work coordinates remain local and user-scoped in SharedPreferences;
- no Home/Work coordinates are sent to the callable or FCM payload;
- cloud receives only `home`/`work` plus selected recipient UIDs;
- check-in-only background sampling does not refresh `locations/{uid}` unless Live updates is independently on;
- no route history is created;
- initial position primes state and never sends an arrival merely because Homi starts inside a zone;
- outside → inside is the arrival transition;
- user must move beyond radius + 100 m before the place is considered left again;
- one-hour local place cooldown limits duplicate edge sends;
- local erase/account deletion clears the user-scoped saved Home/Work check-in coordinates.

### Shared background location stream

Do not build a second hidden tracker.

`LocationStatusService` coordinates one Android foreground location stream with two independent explicit requirements:

- Live updates;
- Arrival check-ins.

Each has its own persisted requirement flag. Turning one off does not stop the stream while the other still needs it. When neither needs background location, the stream stops.

Startup resume does not prompt for permissions; it resumes only if an explicit feature flag exists and Android `always` location permission is already available.

Foreground notification wording is neutral because the stream may serve either/both features.

Force-stopping Android can interrupt background operation until the user opens Homi again. Never represent arrival notifications as emergency-grade or guaranteed.

### `sendArrivalCheckIn`

New App-Check-protected callable in `africa-south1`.

It:

- requires Firebase Authentication;
- requires verified email for password-provider users;
- accepts only Home/Work event labels;
- accepts at most 10 selected recipient UIDs;
- revalidates accepted trusted connections at send time;
- skips stale/disconnected selections rather than notifying them or letting one stale selection block other valid recipients;
- fails cleanly if none remain valid;
- rate-limits sender to 20/hour and 60/day;
- reads at most 12 enabled device registrations per valid recipient;
- respects recipient People-notification settings;
- includes no coordinates/address in the push;
- routes notifications to People.

The existing batched deployment helper discovers this new export automatically from `functions/entrypoint.js`.

### People hub

New `lib/src/features/people/people_hub_page.dart` is now the primary People destination.

It separates accepted connections into:

- **Household** — preference scope `household`;
- **Friends & trusted people** — accepted non-Household connections.

Both sections use existing connection profile photos with fallbacks. Pending requests remain visible.

The approved existing detailed `PeoplePage` map/location/relationship implementation is preserved behind **Manage connections & live location**; do not delete or rewrite it merely because the hub exists.

Safety & check-ins also opens from this hub.

### Task assignee photos

`RoutinesPage` Task assignment receives `actorPhotoUrl` and renders:

- signed-in user's profile photo where available;
- each Household assignee's trusted-connection profile photo;
- initials/person/group fallback when unavailable;
- existing Anyone at home option.

Task membership/authorization is unchanged. `HouseholdPeopleService` remains the assignee source, so non-Household friends are not exposed as Task assignees.

### Notification defaults

Fresh-install `HomiNotificationPreferences` defaults:

- master operational notifications ON;
- Household attention ON;
- Tasks & routines ON;
- People ON;
- Service & security ON;
- Homi Updates/product announcements OFF.

The last category remains separately opt-in because it is product/update messaging rather than operational household/safety delivery.

Android still controls actual runtime notification permission. On a fresh install Homi asks once when operational notifications are enabled but OS permission is absent. If denied/dismissed, Homi does not repeatedly interrupt on every launch; the user can enable later from Homi & account → Notifications/Android Settings.

Existing persisted user preferences remain authoritative. An explicit existing OFF is not silently overwritten.

## Existing 0.8 protected collaboration contract

Continue preserving:

- server-side Homi identity/code issuance and lookup;
- protected connection create/accept/remove;
- protected relationship/scope changes;
- protected location-share authorization;
- protected shared Task create/toggle/remove;
- protected developer notification queue;
- protected cloud account-data deletion;
- protected push registration/removal;
- verified-email requirement for password-provider sharing operations;
- App Check on protected callables;
- server-side rate limits;
- Shared Task membership derived from accepted Household relationships;
- latest-location direct write as the bounded high-frequency path;
- no stealth tracking;
- no automatic location sharing merely because people connect.

## Notifications baseline

Previously proven on Samsung S25 Ultra before the 0.9 pass:

- normal Homi notifications delivered;
- developer self-test notifications delivered;
- Homi status icon displayed correctly;
- Developer notifications access worked for intended account.

The **All enabled Homi devices** FCM-topic path still needs one controlled broad test before public users exist.

## Current cloud-sync truth

Firebase currently covers trusted People/location, arrival event delivery after the new callable is deployed, and explicitly shared one-off Tasks.

Most household operational data remains local-first:

- Routines;
- Supplies;
- Home Things/history/readings;
- private Tasks.

If Homi launches publicly as a genuinely shared Household system, build a real Household identity/membership model plus conflict-safe sync for those areas. Never upload SharedPreferences wholesale or blindly overwrite another device.

## Immediate verification checkpoint for 0.9

### 1. Windows — post-fix Flutter gate

From the existing project checkout:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

`flutter pub get` already succeeded in the immediately preceding validation and does not need to be repeated unless `git pull` changes dependencies.

Success condition:

- analyzer: **No issues found!**
- tests: **All tests passed!**

### 2. Cloud Shell after Flutter is clean

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

Expected: existing 0.8.2 Functions mostly skip as unchanged; new/changed 0.9 Functions deploy through the already-proven batches of five. Do not manually run npm repair, delete Functions, or weaken security rules.

### 3. Physical-device regression

At minimum verify on Samsung S25 Ultra, then a second Android device for background/check-in behaviour:

- fresh-install notification permission prompt and default settings;
- existing explicit notification OFF remains OFF after update;
- 112 / 10111 / 10177 each open the phone app with the correct number;
- People shows Household separately from Friends & trusted people;
- profile photos/fallbacks render correctly;
- Task assignment shows only Household identities and their photos;
- save Home current location + recipients;
- save Work independently;
- enable check-ins with Android background permission;
- app start while already inside Home does not send a false arrival;
- real outside → inside Home arrival sends exactly once;
- Work arrival sends independently;
- People notification OFF suppresses recipient arrival push;
- a disconnected stale recipient is skipped while still-valid recipients can receive;
- Live updates OFF does not stop active Arrival check-ins;
- Arrival check-ins OFF does not stop explicit Live updates;
- both OFF stops the foreground location stream;
- existing hearts, connections, shared Tasks, live location, developer notifications and account deletion still work;
- no raw permission errors appear.

## Production gates still open

Read `documentation/RELEASE_READINESS.md`. Major gates still include:

- `configure-auth-security.sh` proof if not already recorded;
- Play Integrity App Check / Firestore enforcement after valid-client metrics;
- full background-location multi-hour/reboot/battery tests;
- Google Play background-location declaration/review;
- Shared Household sync decision/implementation;
- release signing + Play App Signing SHA;
- production Google Sign-In/Maps restrictions;
- cloud billing alerts/monitoring;
- public Privacy Policy, Terms and external account-deletion URL;
- Play Data Safety/content rating/target audience/app access/assets;
- one controlled broad developer notification;
- Homi+ decision only after premium shared-cloud value exists.

Pricing remains planning only:

- Homi Free — R0
- Homi+ — R49.99/month or R499.99/year
- privacy, stop-sharing, arrival-check-in disable and account deletion are never paywalled.

## Documentation rule

At the end of every pass update relevant docs, add/update the release note under `documentation/releases/`, and refresh this file.
