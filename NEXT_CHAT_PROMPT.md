# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub remains the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.9.0.md`
- `documentation/releases/0.9.0-backend-deployment-complete.md`
- `documentation/releases/0.9.1.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/SECURITY.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/NOTIFICATIONS.md`
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

Home remains centred with the exact Homi mark. The Homi header/profile row and bottom navigation are persistent shell UI and must not be replaced by feature-page navigation.

## Current version

Current client source: **`0.9.1+12`**.

The previously validated and deployed 0.9.0 application/backend candidate was:

`c7e7b86656bc650ce1c8f0aabbb5a3129319db3c`

Bruce confirmed:

- final 0.9.0 `flutter analyze` clean;
- all 0.9.0 Flutter tests passed;
- governed Cloud Shell backend deployment completed without an observed failure.

The deployed backend includes `sendArrivalCheckIn`. Do not deploy it again unless new evidence points to a backend defect or backend source changes.

## 0.9.1 reason for change

The first S25 Ultra UI review rejected one product decision in 0.9.0: the new lightweight People hub displaced an already-approved map-first People page and pushed the old map/location experience behind a separate **Manage connections & live location** route. That also made the normal shell header/navbar feel absent when the nested manager was opened.

Bruce's explicit correction:

- People should open exactly in the old map-first structure;
- the map and existing live-location controls stay immediately visible;
- Household / non-Household connection grouping belongs underneath that existing experience;
- there is no need for a separate Manage connections & live location destination;
- Safety & check-ins can remain accessible from People, but lower down;
- trusted-person editing must be more obvious than a small pencil icon;
- arrival enable/disable should use the same visual/interaction language as Notifications;
- Home/Work should support typed address setup plus Set from here;
- oversized green/passive help boxes should be replaced by the Overview/Tasks **How it works** pattern.

## Current 0.9.1 implementation

### People restored map-first

`people_hub_page.dart` is now only a compatibility wrapper that returns the original `PeoplePage`; it no longer renders a separate hub UI.

`PeoplePage` again owns the visible People experience inside the normal Homi shell:

1. People title/subtitle;
2. embedded Google map immediately;
3. person focus chips / Open map;
4. current-device location and Live updates controls;
5. existing location How it works/help flow;
6. Homi code and connection requests;
7. accepted connection groups;
8. Safety & check-ins entry after connections.

Do not reintroduce a lightweight hub or separate manager page unless Bruce explicitly asks for it later.

### Connection grouping and editing

Accepted people are grouped on the same page as:

- **Household**;
- **Friends & trusted people**.

Existing connection profile images, per-person location share controls, location details and remove behavior remain.

Relationship editing now has an explicit labelled **Edit** action rather than relying on a small pencil icon alone.

Task assignment remains Household-only and keeps the 0.9 profile-photo improvement.

### Safety & check-ins UX

The detailed Safety & check-ins page remains a nested feature page opened from the lower People entry.

Emergency shortcuts remain:

- `112` — mobile emergency;
- `10111` — police emergency;
- `10177` — ambulance emergency.

No direct-call permission or silent calling.

Arrival enable/disable now mirrors Notifications:

- status hero;
- full-width **Enable arrival check-ins** button while off;
- preference-style row with switch while on;
- if Home/Work/recipients are missing, show a direct setup message;
- if Android background location is needed, use the Homi confirmation sheet, open settings and retry enabling when the user returns.

### Home/Work address setup

`ArrivalCheckInPlace` now includes an optional local `address` alongside latitude/longitude.

Two setup methods:

- **Enter address** — user types a street address/place; `geocoding` resolves it to coordinates and then a readable address;
- **Set from here** — captures current location locally and reverse-geocodes a readable address when available.

Important product/technical distinction: current 0.9.1 uses the existing device geocoding layer. It resolves submitted address text but is **not Google Places suggestion-as-you-type autocomplete**. Do not represent it as Places autocomplete. Adding official Google Places autocomplete would be a separate API/dependency/setup decision.

Older 0.9 saved place records without `address` remain readable.

Privacy remains unchanged:

- saved Home/Work coordinates and readable addresses stay local/user-scoped;
- `sendArrivalCheckIn` still receives only `home`/`work` plus selected recipient UIDs;
- push payloads contain no saved coordinate/address;
- no route history;
- local erase/account deletion clears these local saved place fields.

### How it works pattern

Passive oversized help containers were removed from the arrival-check-in page. Arrival education is behind a **How it works** text action opening a Homi bottom sheet with focused help points and a Got it action, consistent with Overview/Tasks.

Functional status/error UI can remain visible; do not confuse a state card with passive help content.

## Verification state

Because 0.9.1 changes Flutter client source after the last green 0.9.0 gate, the current 0.9.1 source is **not yet analyzer/test proven**.

Immediate next checkpoint:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter pub get
flutter analyze
flutter test
```

Success:

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed!**

No Firebase deployment follows a clean 0.9.1 gate because Functions/Firestore were not changed.

## Next device acceptance after green Flutter gate

On Samsung S25 Ultra verify first:

1. People opens map-first inside the normal Homi shell; top/profile bar and bottom navigation remain intact.
2. Existing embedded map, map chips, Open map, location card and Live updates behave as before.
3. Household and Friends & trusted people appear underneath the existing map/location area.
4. Profile images/fallbacks render correctly.
5. Edit relationship is obvious without relying on a pencil-only cue.
6. Safety & check-ins is lower on the same People flow.
7. Emergency shortcuts open the intended dialer numbers without placing calls automatically.
8. Arrival enable/disable visually and behaviorally matches Notifications.
9. Enter Home address resolves to the intended readable address/location.
10. Set from here resolves the current Home/Work location into a readable address where available.
11. How it works is used instead of the previous oversized help box.
12. Task assignment still shows Household profile images and excludes non-Household friends.
13. Existing live location, People hearts, connections and shared Tasks remain healthy.

Only after the static/client UX pass is accepted should the real outside→inside arrival test be repeated with two devices.

## Existing arrival/backend contract to preserve

- `sendArrivalCheckIn` is App-Check protected and authenticated;
- verified email required for password-provider sharing actions;
- only `home` / `work` labels accepted;
- at most 10 selected recipients;
- server revalidates accepted trusted connections;
- stale/disconnected recipients skipped;
- 20/hour + 60/day sender rate limits;
- max 12 enabled device registrations read per valid recipient;
- recipient People-notification preference respected;
- no coordinate/address sent to callable/push;
- first fresh location sample primes without notifying;
- only outside→inside arrival sends;
- radius + 100 m exit hysteresis;
- one-hour local place cooldown;
- Live updates and Arrival check-ins independently own the shared foreground location stream.

## Remaining production gates

Read `documentation/RELEASE_READINESS.md`. Major later gates still include:

- complete 0.9.1 physical-device regression;
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