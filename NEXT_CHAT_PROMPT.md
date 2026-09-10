# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub remains the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.8.2.md`
- `documentation/releases/0.8.2-functions-batching-fix.md`
- `documentation/releases/0.8.2-backend-deployment-complete.md`
- `documentation/releases/0.9.0.md`
- `documentation/releases/0.9.0-backend-deployment-complete.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/SECURITY.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- the latest affected source files.

Use the **mobile-app-development** workflow first. For Firebase/Cloud Shell release work also use Concept Lab release integrity. Do not use Bruce's reruns as a diagnostic mechanism; inspect source/log evidence first.

Preserve approved behaviour/design, exact Homi brand assets and existing user data. Never claim a feature works on-device until Bruce's physical-device evidence proves it.

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
- `android/` intentionally remains local/untracked.
- Preserve local Firebase/Maps/signing files. Never ask Bruce to paste Maps keys or App Check debug tokens into chat.
- Deleted project `homi-508000` must never be used.
- Safety stash remains: `stash@{0}: On main: Homi pre-0.5.0 local tracked changes`; do not pop/delete automatically.

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

Home remains centred with the exact Homi mark.

## Current version and exact validated candidate

Current source version: **`0.9.0+11`**.

The application/backend source candidate that Bruce validated and deployed is:

`c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`

Later `main` commits after this SHA are documentation-only release-state updates unless new source changes are explicitly made.

## 0.8.2 backend foundation — COMPLETED

Do not reopen old 0.8.2 deployment incidents unless new evidence points there.

Proven foundation includes:

- Node 22 guard;
- temporary Functions dependency workspace;
- synchronized generated lock;
- local `npm ci`;
- Function syntax gate;
- Firestore Emulator security suite 12/12;
- Firestore rules/index deployment;
- migration from stale HTTPS `onConnectionDeleted` to Firestore trigger `onTrustedConnectionDeleted`;
- dedicated runtime identity `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`;
- deterministic Function deployment in batches of five.

Normal helper remains:

```bash
bash scripts/deploy-notification-backend.sh
```

## 0.9 requested feature pass

Bruce requested, before running the app:

1. South African emergency-service speed-dial-style shortcuts;
2. Home/Work automatic arrival check-ins to selected loved/trusted people;
3. profile pictures in Task assignment plus separate Household / non-Household People sections;
4. operational notifications enabled by default for fresh installs.

All four are implemented in source.

### Emergency calls

People → **Safety & check-ins** includes:

- `112` — emergency from a mobile phone;
- `10111` — police emergency;
- `10177` — ambulance emergency.

Implementation uses `url_launcher` `tel:` handoff. Homi does not silently place calls, request direct-call permission, dispatch responders or automatically transmit location to emergency services.

Emergency shortcuts work without a Homi account.

### Arrival check-ins

New implementation includes:

- `lib/src/domain/arrival_check_in.dart`
- `lib/src/services/arrival_check_in_service.dart`
- `lib/src/features/people/safety_check_in_page.dart`
- `functions/check_in.js`

Flow:

1. sign in;
2. save Home and/or Work while physically there;
3. choose radius (150/250/500 m UI, 75 m–1 km model bounds);
4. choose accepted trusted recipients per place;
5. explicitly turn Arrival check-ins on.

Privacy/reliability contract:

- saved Home/Work coordinates are local and user-scoped;
- callable/push receives only `home`/`work` plus selected recipient UIDs;
- check-in-only background sampling does not refresh `locations/{uid}` unless Live updates is independently enabled;
- no default route history;
- first fresh location sample primes zone state and does not notify;
- only outside → inside transition sends;
- radius + 100 m exit hysteresis reduces GPS edge flapping;
- one-hour local per-place cooldown;
- local erase/account deletion clears saved Home/Work check-in data;
- stale/disconnected recipients are skipped server-side;
- if no selected recipient remains valid, send fails cleanly.

### Shared background location stream

`LocationStatusService` coordinates one visible Android foreground stream for two independent user choices:

- Live updates;
- Arrival check-ins.

Turning one off does not stop the other. When both are off, the stream stops. Startup resume occurs only if an explicit saved feature flag exists and Android background permission is already available; startup does not open a new permission prompt.

Force-stopping Android can interrupt this until the app is opened again. Never represent check-ins as emergency-grade monitoring.

### `sendArrivalCheckIn`

The App-Check-protected callable in `africa-south1`:

- requires Firebase Authentication;
- requires verified email for password-provider accounts;
- accepts only Home/Work event labels;
- accepts at most 10 selected recipient UIDs;
- revalidates accepted trusted relationships at send time;
- skips stale/disconnected recipients;
- rate limits 20/hour and 60/day per sender;
- reads no more than 12 enabled device registrations per valid recipient;
- respects recipient People-notification settings;
- sends no coordinate/address data.

## People / Tasks identity changes

Primary People destination is now a lightweight hub that separates:

- **Household**;
- **Friends & trusted people**.

Both use connection profile photos with safe fallbacks. Pending requests remain visible.

The existing detailed map/location/relationship People screen is preserved behind **Manage connections & live location**.

Task assignment shows:

- signed-in user's profile image where available;
- Household assignee profile images;
- initials/person/group fallback;
- existing Anyone at home option.

Non-Household friends remain excluded from Household task assignment.

## Notification defaults

Fresh-install defaults:

- master operational notifications ON;
- Household attention ON;
- Tasks & routines ON;
- People ON;
- Service & security ON;
- Homi Updates/product announcements OFF.

Android still controls runtime notification permission. Homi asks once when permission is absent. Existing saved preferences remain authoritative; an existing explicit OFF is not overwritten.

## 10 September 2026 validation / deployment state

### Flutter gate — COMPLETED

Bruce first ran dependency resolution/analyzer/tests, after which three analyzer findings were cleaned in source. Bruce then reran the final post-cleanup gate and confirmed:

- `flutter analyze` — all green / clean;
- `flutter test` — all tests passed.

Therefore the validated `0.9.0+11` source gate is complete.

### Backend deployment — USER-CONFIRMED COMPLETE

Bruce then ran the governed Cloud Shell helper against the same validated application/backend candidate and reported that deployment completed without any observed failure.

Record this as user-confirmed successful deployment. The full Cloud Shell log was not supplied, so do not claim independent line-by-line provider verification.

See `documentation/releases/0.9.0-backend-deployment-complete.md`.

Do **not** ask Bruce to deploy again unless device evidence points to a backend issue.

## Immediate next checkpoint — physical-device acceptance

Next step is to install/run the current 0.9 client on the Samsung S25 Ultra.

Before running, local Windows checkout should simply be current:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
```

No `flutter pub get`, analyzer, test or backend deployment rerun is required unless source changes again.

Use Android Studio's normal Run action with the S25 Ultra selected, or the repository's established Flutter device workflow. Preserve local Android/Firebase/App Check configuration.

### First S25 Ultra acceptance pass

Validate in this practical order:

1. App launches with no red-screen/crash.
2. Existing account/session state loads correctly.
3. Overview / Tasks / Home / Supplies / People navigation remains intact.
4. People shows **Household** separately from **Friends & trusted people**.
5. Existing profile photos/fallbacks render correctly.
6. Task assignee picker shows Household identities with profile pictures and excludes non-Household friends.
7. Open People → Safety & check-ins.
8. Tap 112 / 10111 / 10177 one at a time and verify the phone app opens with the correct number. Do not complete an emergency call merely for testing.
9. Verify fresh-install notification behaviour separately when a true fresh install/test device is available; updating an existing install should preserve its previous notification choice.
10. Save Home from current location, choose recipient(s), set radius and enable check-ins.
11. Save Work independently when physically at Work or use a later real-world test; do not fake coordinates merely to satisfy the checklist.
12. Verify enabling check-ins cleanly explains/requests Android background location if needed.
13. Verify Live updates and Arrival check-ins switches do not incorrectly turn each other off.
14. Confirm no raw Firebase/App Check/permission exception appears in UI.

### Arrival event proof requires a real transition

Do not expect a Home arrival immediately after saving Home while already there. That is intentionally suppressed.

For a real proof, the device must first move outside the configured radius plus the 100 m exit hysteresis, then later enter the saved radius again. The selected trusted person's device must be signed in, registered for notifications and have People notifications enabled.

A second Android device is required before treating background check-in delivery as accepted.

## Existing protected-collaboration contract to preserve

Keep intact:

- server-side Homi identity/code issuance and lookup;
- protected connection create/accept/remove;
- protected relationship/scope changes;
- protected location-share authorization;
- protected shared Task create/toggle/remove;
- protected developer notification queue;
- protected cloud account deletion;
- protected push registration/removal;
- verified-email requirement for password-provider sharing actions;
- App Check on protected callables;
- server rate limits;
- Shared Task membership derived from accepted Household relationships;
- latest-location direct write as bounded high-frequency path only when Live updates requires it;
- no stealth tracking;
- no automatic location sharing merely because people connect.

## Remaining production gates

Read `documentation/RELEASE_READINESS.md` before considering Play deployment. Major unresolved gates still include:

- complete physical-device 0.9 regression;
- second-device background/check-in proof;
- `configure-auth-security.sh` proof if still unrecorded;
- Play Integrity App Check and later Firestore enforcement after valid-client metrics;
- full background-location multi-hour/reboot/battery testing;
- Google Play background-location declaration/review;
- Shared Household sync decision/implementation;
- release signing + Play App Signing SHA;
- production Google Sign-In/Maps restrictions;
- cloud billing alerts/monitoring;
- public Privacy Policy, Terms and external account-deletion URL;
- Play Data Safety/content rating/target audience/app access/assets;
- one controlled broad developer notification;
- Homi+ only after premium shared-cloud value exists.

Pricing remains planning only:

- Homi Free — R0
- Homi+ — R49.99/month or R499.99/year
- privacy, stop-sharing, arrival-check-in disable and account deletion are never paywalled.

## Documentation rule

After each pass, update the relevant docs/release note and refresh this file with actual proven state.
