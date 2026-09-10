# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat GitHub as the source of truth for tracked source/docs. Before changing anything, inspect:

- `documentation/releases/0.7.0.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a new pass compiled/worked on-device until Bruce's local Flutter/Android toolchain proves it.

## Permanent project context

- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore region: `africa-south1` (Johannesburg)
- Flutter baseline: 3.41.5 stable
- Dart baseline: 3.11.3
- Development device: Samsung S25 Ultra
- JDK 21 / Gradle 8.14
- Android host under `android/` is intentionally local/untracked.
- Preserve existing local Firebase/Maps files and never ask Bruce to paste Maps/App Check tokens into chat.
- Deleted project `homi-508000` must never be used.

Bruce has a safety stash:

`stash@{0}: On main: Homi pre-0.5.0 local tracked changes`

Do **not** automatically pop or delete it.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito
- Exact Homi logo/mark assets already exist in `assets/brand/`; never redraw them.

## Current source version

**`0.7.0+7`**

Primary navigation:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## 0.7 device issues/fixes

### People full-screen map

The S25 Ultra showed the full-screen map only in a shallow top strip with the rest of the route blank. `PeopleMapPage` now gives the Google Maps Android platform view the explicit full route width/height and keeps map gestures/focus overlays on top.

This requires real-device verification. If it still reproduces, inspect whether the embedded People map remaining alive under the pushed route is causing a multiple-platform-view issue and suspend/dispose the embedded map while full screen is open rather than defending the current fix.

### Overview Quick add

The S25 Ultra showed a 37px bottom overflow. Quick Add is now `isScrollControlled`, constrained to 82% of device height and scrollable.

### Trusted People permission error

Exact device log before 0.7:

`connections where memberUids array_contains <uid> ... PERMISSION_DENIED`

The connection listener no longer uses that query. `TrustedPeopleService` now listens separately to:

- `aUid == currentUid`
- `bUid == currentUid`

and merges/deduplicates the results. Firestore connection list rules now authorize through the deterministic `aUid`/`bUid` participant fields.

**The 0.7 Firestore rules must be deployed before judging this fix.**

## Supplies amounts

Supply amount tracking is optional and designed to minimise admin.

New `SupplyUnit` values:

- item
- loaf
- bottle
- carton
- pack
- bag
- roll
- egg
- kilogram / gram
- litre / millilitre

Quick defaults:

- Milk = 1 bottle
- Bread = 1 loaf
- Eggs = 12 eggs
- Dog food = 1 bag
- Toilet paper = 1 pack
- Dishwashing liquid = 1 bottle

Supply cards can use compact +/- controls; tapping amount opens a branded update sheet with direct amount, +1/+2/+6/+12 and unit selection. Users can choose **Status only** instead. Quantity zero derives **Need to buy**. Legacy Supply JSON without quantity/unit remains valid.

## Account / legal / privacy

The profile/avatar now opens a full **Homi & account** centre, including for local-only users.

It contains:

- Profile settings/sign-in
- Why Homi exists
- Help & support
- Privacy & your data
- Location & safety
- Terms of use
- About Homi
- Erase data from this phone
- Delete Homi account
- Sign out

`Why Homi exists` explicitly explains both the household operating-state problem and consensual check-ins with people you care about, including trusted friends.

The legal copy is a working product draft and needs professional South African review before production. POPIA/security and Google Play account-deletion obligations are tracked in `documentation/legal/`.

## Account/data lifecycle

Keep these distinct:

- **Sign out**: ends auth session, does not silently erase local household data.
- **Erase data from this phone**: clears local household data + Homi cached location, leaves cloud account intact.
- **Delete Homi account**: destructive permanent flow with reauthentication, cloud cleanup, Firebase Auth deletion and explicit current-device household/location cleanup.

New `AccountDataService` currently covers active Firestore account-linked collections. Whenever a new cloud collection is introduced, extend deletion in the same pass.

Password account deletion asks for the current password only for Firebase reauthentication and never stores it. Google accounts reauthenticate through Google.

Google Play additionally requires an external account-deletion web resource. The intended direction `https://theconceptlab.co.za/homi/delete-account` is only a proposed path: do **not** put it in Play Console until a working page exists.

## Current cloud-sync truth

Most household data is **still local** in SharedPreferences:

- Routines
- Supplies
- Home Things/history/readings
- private/local Tasks

Firestore currently carries only account identity metadata, Homi codes, trusted connections/preferences, explicitly shared one-off Tasks, location authorization and latest location/battery state.

This explains the tiny Firebase screenshot (about 41 writes / 5 reads). It is expected and does not mean full multi-device household sync exists.

The next major data-layer milestone after 0.7 stabilization is explicit household identity/membership + safe local↔cloud merge/sync for Routines, Supplies, Home and shared household state. Do not simply upload SharedPreferences and overwrite another device.

## Location / App Check

Background location remains explicit and visible. Current Android settings use medium accuracy, 100m movement threshold and roughly two-minute requested updates. Long-term route history is not enabled by default.

The Google Cloud screenshot showed Firebase App Check API calls failing in debug. App Check enforcement remains OFF. Before enforcement, register the debug token privately in Firebase Console and confirm valid App Check traffic. Never ask Bruce to paste that token into chat or commit it.

## Pricing direction

Current launch recommendation is documented, not implemented:

- **Homi Free — R0**
- **Homi+ — R49.99/month or R499.99/year**
- one household plan aimed at ~6 household members
- location-only friends should not consume paid household seats
- privacy/stop-sharing/account-deletion controls remain free
- use Google Play Billing for Android digital subscription

Do not add a paywall until real premium value such as household cloud sync exists and is proven.

## Immediate verification checkpoint

0.6 analyzer/tests previously passed. 0.7 has new source changes and is **not yet analyzer/test/device verified**.

Windows:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

If clean, deploy the updated 0.7 Firestore rules:

```bash
cd ~/homi
git pull
bash scripts/deploy-firestore-rules.sh
```

Then Android Studio → Samsung S25 Ultra → Run.

Verify:

- Quick Add no overflow;
- Bread/eggs/multi-unit Supply amounts and persistence;
- zero amount → Need to buy;
- full-screen People map fills the route and pans/zooms;
- People no longer logs the old `memberUids array_contains` connection permission denial;
- profile/avatar opens Homi & account for signed-in and local-only users;
- Why Homi/privacy/location/terms/help/about pages scroll and respect system insets;
- erase-local-data only on disposable test data;
- account deletion only on disposable test accounts;
- new Firestore rules successfully deploy and account-cleanup rules compile.

If Flutter analysis/build or Firebase rules deployment reports an error, fix the exact failing layer. Do not reset Firebase, JDK, Gradle, signing, Maps or Android host setup unless the error points there.

## Documentation rule

At the end of every pass update relevant documentation, add/update the release note under `documentation/releases/`, and refresh this file.
