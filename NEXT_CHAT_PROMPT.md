# Homi - Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat GitHub as the source of truth for tracked source/docs and inspect the latest code plus `documentation/RELEASE_NOTES.md`, `documentation/ARCHITECTURE.md` and `documentation/LOCATION_SAFETY.md` before changing anything.

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and local user data. Do not claim a pass compiled or worked on device until Bruce's local Flutter/Android toolchain proves it.

## Permanent project context

- Local Windows project root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore region: `africa-south1` (Johannesburg)
- Flutter baseline: 3.41.5 stable
- Development phone: Samsung S25 Ultra
- Android host under `android/` is intentionally local/untracked at this stage.
- Existing local Firebase/Maps config must be preserved; never ask Bruce to paste the Maps key into chat.
- Approved brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito.
- Exact Homi logo/mark assets already exist in `assets/brand/`; never redraw or approximate them with framework shapes.

The deleted project `homi-508000` must never be used.

## Product direction

Homi is a local-first household operating system. Primary navigation is:

**Overview · Routines · Home · Supplies · People**

Home is deliberately the centre destination and uses the exact Homi mark.

Account creation must remain optional for basic/local-only household use. Cloud features should add sharing, backup and trusted-person functionality rather than gate local value.

All visible wording must read like production Homi copy, never like developer/tester instructions or roadmap notes.

Trusted-person location is a first-class Life360-style direction, but the privacy model is non-negotiable:

- connecting/inviting someone does not start location sharing;
- the tracked person explicitly controls each viewer's access;
- live/background sharing is separately opt-in and visibly active;
- stopping/revoking location must remain easy and never paywalled;
- no stealth tracking;
- no indefinite movement history by default.

## Current source state - 0.4.0+4

This 0.4 pass has been implemented in GitHub but has **not yet been locally analyzed/tested/compiled/device-reviewed**. Fix local verification issues before starting another broad feature pass.

### Navigation / branded controls

- Primary order remains **Overview, Routines, Home, Supplies, People** with Home centred.
- `HomiBottomNav` was rebuilt from Bruce's latest S25 Ultra/reference feedback.
- The selected destination now uses a circular active button integrated into a custom-painted rise/mound in the white navigation surface.
- Material ink/splash handling was removed from the custom nav to eliminate the grey rectangular selection block seen around selected items.
- Homi inline single/multi-choice controls now replace fixed-choice dropdowns in new/refined forms.
- `showHomiConfirmSheet` provides branded confirmations/destructive actions.
- Routines/Supplies/Home no longer use generic popup menus for their primary destructive/update flows.

### Routines

Routine frequency is now a real recurrence model, not descriptive metadata.

`RoutineItem` contains:

- UUID
- title/category
- estimated minutes
- repeat type: one-off, daily, weekdays, weekly, monthly
- selected weekly days / monthly day-of-month
- exact due hour/minute
- computed `nextDueAt`
- bounded `RoutineCompletion` history
- each completion includes exact timestamp, actor display name and optional Firebase UID

Creation uses inline Homi choices plus exact 24-hour schedule fields. Recurring cards show a repeat icon, previous completion (`Done 9 Sep · 14:00 by Bruce`) and `Due now` / next due timestamp.

Existing pre-0.4 Routine JSON is migrated from the older `frequency`, `completed` and `lastCompletedAt` shape where possible.

**Critical boundary:** Routines are still local-only. The completion attribution model exists, but Bruce's wife on another phone will NOT see the completion yet. Shared household membership + cloud Routine/Home/Supply synchronization is the major next architecture feature after 0.4 is stable.

### Supplies

- Common Quick Adds: Milk, Bread, Eggs, Dog food, Toilet paper, Dishwashing liquid.
- Quick Adds prefill the editor rather than saving blindly.
- Category/status use inline Homi choices, not dropdowns.
- Expiry input uses Homi-consistent numeric day/month/year fields rather than native date-picker UI.
- Expiry-aware `Use soon` / `Expired` behaviour remains.
- Status updates/removal use Homi-styled sheets.

### Overview / When you have time

- Overview considers actual due Routines, supply attention, Home service attention and Quick Add reminders.
- Quick Reset (`When you have time`) still honours a 10/30-minute budget.
- Due saved Routines are prioritised.
- Homi has a larger common-household suggestion pool which is shuffled every invocation, so repeated resets should not feel identical.
- Completing a saved recurring Routine from Quick Reset records who/when and computes next due.
- The `How it works` sheet explains this in user-facing copy.

### Home

Home is no longer placeholder cards.

Local-first features now include:

- **Things:** appliances/equipment/home items, category, room/location, optional brand/model, service date, notes.
- service due/soon status and Overview attention.
- **Maintenance & repairs:** history type, title, date, optional linked Thing, notes and who completed/logged it.
- **Utilities:** electricity/water readings, units, timestamps and recorder attribution.
- local persistence through SharedPreferences.

Google Drive/home-document UX remains intentionally unfinished rather than faked.

### People / trusted location

People was substantially expanded.

- Persistent Google Map.
- cached latest self location/battery state.
- if foreground location permission already exists, People refreshes automatically without requiring a repeated `Check my location` action.
- custom person markers use profile photo when available, otherwise initials.
- tapping a marker opens Homi location details with last update, battery/charging, accuracy, reverse-geocoded address and coordinates.
- address/coordinates can be copied and opened externally in Google Maps.
- signed-in users receive a six-character Homi code.
- Homi-code connection request -> recipient accepts/declines.
- accepted connection alone grants no location access.
- each user independently chooses `Share mine` / `Stop my share` for each trusted person.
- Firestore rules enforce the owner-controlled share before `/locations/{uid}` is readable by another user.

### Live/background sharing

A signed-in user may explicitly enable `Live updates`.

Current Android source configuration:

- Geolocator Android foreground-service location stream
- Android `Allow all the time` permission required for background updates
- visible foreground-service notification
- medium accuracy
- 100 m distance filter
- approximately 2-minute requested interval
- wake lock disabled
- latest snapshot only; no default route-history collection
- explicit Stop clears the stored live-sharing preference
- sign-out stops live updates
- previously opted-in live sharing attempts to resume on a later signed-in app session if Android still grants the needed permission

Do **not** claim full Life360-grade process resilience yet. Force-stop, reboot, OEM battery optimisation, long-stationary behaviour and Google Play background-location review still need release hardening and real-device validation.

### Firestore rules added for trusted people

Updated `firebase/firestore.rules` now includes:

- self-only user profiles
- authenticated exact Homi-code lookup, with directory listing denied
- two-member pending/accepted connection documents
- only recipient can accept pending connection
- connection and location consent remain separate
- location owner controls each viewer's share document
- latest location readable by another user only when that active share exists
- unspecified data remains fail-closed

These rules must be deployed before trusted-person/Homi-code testing.

### Android host integration

Because the generated Android host is local/untracked, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\enable-location-map-android.ps1
```

The script idempotently enforces:

- Internet permission
- coarse/fine location
- background location
- foreground service + foreground service location
- notifications
- Google Maps metadata pointing to the existing local `@string/google_maps_key`
- Android min SDK 24

It does not print or replace the API key.

## Immediate verification checkpoint

First pull and verify 0.4 locally:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\enable-location-map-android.ps1
flutter analyze
flutter test
```

Do not run `flutter clean` unless an actual cache-related problem appears.

If analyze/test pass, run normally from Android Studio on the S25 Ultra.

Before testing Homi-code/trusted-person connections, deploy current Firestore rules from Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-firestore-rules.sh
```

For explicit live-background testing, if Homi asks for stronger Android location permission, use:

**Android Settings → Apps → Homi → Permissions → Location → Allow all the time**

The app should offer an `Open settings` action; it cannot silently grant this permission.

## Device review checklist

Review the actual S25 Ultra screenshots/behaviour before any further visual redesign:

- nav selected in Overview, Routines, Home and a side destination; compare mound/active-circle treatment against Bruce's supplied reference;
- no grey rectangular selection block around a nav item;
- Routine editor fixed choices, weekly/monthly scheduling and exact time;
- completed recurring Routine showing who/when and next due;
- Routine branded removal flow;
- Supply Quick Adds and inline editor controls;
- Home Things, service attention, maintenance/repair history and utility readings;
- Overview Home attention and rotating 10/30-minute Quick Reset;
- People map, own marker, trusted-person markers, location detail copy/Google Maps action;
- Homi-code request/accept flow on two signed-in accounts if available;
- per-person share grant/revoke;
- foreground auto refresh after permission is already granted;
- live updates, visible Android foreground-service notification, backgrounding/reopening Homi;
- local-only use remains valid;
- sign-out stops live location.

## Priorities after 0.4 is stable

1. Fix every analyzer/test/device regression first; do not stack new architecture on a broken pass.
2. Refine the nav only from the new physical-device screenshots if the shape/alignment still differs from the approved reference.
3. Build **shared household membership + merge/sync** for Routines, Supplies and Home so multiple household phones genuinely see the same state and `who completed it` works across devices. Define first-sync/local-vs-cloud conflict behaviour before writing data automatically.
4. Harden location lifecycle: reboot/process death/OEM battery restrictions, notification behaviour, stale/offline states and realistic battery measurements across devices.
5. Add Places / arrivals / departures only after live-current sharing is stable and consent UX remains explicit.
6. Build Home documents/manuals/receipts around user-owned Google Drive with narrow `drive.file` scope.
7. Continue replacing any remaining generic/native notice/toast/modal treatment with reusable Homi UI where practical without fighting unavoidable Android permission/system screens.
8. Prepare Play Store background-location disclosure/privacy policy evidence before production release.
9. Continue updating `documentation/RELEASE_NOTES.md`, architecture/location docs, tests and this top-level `NEXT_CHAT_PROMPT.md` in every pass.

Preserve the working architecture; prefer additive migrations over resets. Never delete local user data to simplify a model change unless Bruce explicitly approves it.
