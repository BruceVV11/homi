# Homi Release Notes

## 0.8.0 - Notifications, People hearts and critical Supply attention

- Rewrote the Homi & account user-facing copy so Homi speaks as a complete product rather than saying it is “being built”, “pre-release” or describing visible capabilities as roadmap work. Internal engineering docs still record real verification/release boundaries.
- Added `SupplyAttention` ranking: Need to buy → Expired → Use soon → Running low.
- Overview now previews the three most important Supply items and shows `+ N more need attention` instead of forcing the user to open/scroll Supplies just to discover what matters.
- Supplies now groups cards under Need to buy, Use soon, Running low and In stock while preserving the status line on every card.
- Added the full **Notifications** settings surface under Homi & account with master permission plus Household attention, Tasks & routines, People, Homi updates and Service & security categories.
- Added local notification scheduling for due Tasks/Routines, Supply expiry warnings/date and Home service warnings/date.
- Added de-duplicated grouped immediate household attention for newly critical out-of-stock, expiry and maintenance conditions instead of firing a burst of separate alerts.
- Added FCM device-token registration for signed-in enabled installations, token refresh handling, invalid-token cleanup and notification deep-link routing.
- Added People-map **heart** check-ins. An accepted trusted person can receive **“{name} is thinking about you!”** without changing location or household permissions; a server-side one-minute cooldown limits repetition.
- Added Cloud Functions notifications for connection requests, connection acceptance, shared Task assignment/creation/completion and People hearts.
- Added an admin-only **Developer notifications** composer with title/body, update/service/security type, self-test vs all-enabled audience, deep-link destination, priority and send history.
- Broad developer notices use opt-in FCM topics so local-only users can receive enabled Homi update/service/security notices without creating an account. Direct developer self-tests use the signed-in account's enabled device token(s).
- Added restrictive Firestore rules for `developerAdmins`, `notificationCampaigns` and server-only `heartCooldowns`; the client cannot self-grant developer access or forge campaign send state.
- Extended account deletion with notification token removal and server-side cleanup of heart cooldowns, developer-admin state and campaigns created by the deleted UID.
- Added `scripts/enable-notifications-android.ps1`, `scripts/deploy-notification-backend.sh` and `scripts/manage-developer-admin.sh` with permanent Homi project guards.
- Added notification/privacy architecture docs and notification/Supply-attention tests.
- App Check debug token has been registered privately. Enforcement remains intentionally off until valid debug/release traffic is confirmed.
- Bumped app version to `0.8.0+8`.

Full handoff: `documentation/releases/0.8.0.md`.

**Verification boundary:** 0.8 is a source pass until Bruce runs the Android-host notification helper, `flutter analyze`, `flutter test`, deploys the Firestore/Cloud Functions backend and verifies delivery/routing on the Samsung S25 Ultra.

## 0.7.0 - Account/data centre, supply amounts and sync hardening

- Added optional lightweight Supply quantities and stable units for items, loaves, bottles, cartons, packs, bags, rolls, eggs, kg/g and L/mL. Common Quick Adds start with useful amounts and existing Supply records remain compatible.
- Added compact Supply +/- controls and a branded amount editor with quick +1/+2/+6/+12 actions; a tracked amount of zero derives **Need to buy**.
- Fixed the Overview Quick Add 37px device overflow by making the sheet height-constrained and scrollable.
- Hardened the fullscreen People map with an explicit full-route Google Maps platform-view size after the S25 Ultra rendered only a shallow map strip.
- Replaced the failing trusted-connection `memberUids array_contains` listener with deterministic `aUid` / `bUid` equality queries merged client-side, and tightened matching Firestore rules instead of broadening collection access.
- Added the full **Homi & account** centre with Why Homi exists, Help & support, Privacy & your data, Location & safety, Terms of use, About Homi, local-data erasure, account deletion and sign-out.
- Added recent-auth account deletion for Google and email/password accounts plus `AccountDataService` cleanup for the active Homi cloud schema.
- Added separate local household/location-cache erasure so Sign out, local data deletion and account deletion remain distinct actions.
- Added internal privacy/POPIA/Google Play deletion documentation and a pricing/unit-economics recommendation.
- Current planning recommendation: Free + Homi+, with Homi+ at **R49.99/month or R499.99/year** once real household cloud sync and premium value are implemented. Billing is not enabled yet.
- Bumped app version to `0.7.0+7`.

Full handoff: `documentation/releases/0.7.0.md`.

**Verification boundary:** the previous 0.6 analyzer/tests passed, but 0.7 remains a source pass until Bruce runs `flutter analyze`, `flutter test`, deploys the new Firestore rules and re-tests on the Samsung S25 Ultra.

## 0.4.0 - Recurring home life, Home records and trusted live location

### Device feedback incorporated - 2026-09-09

- Rebuilt the bottom navigation again from the Samsung S25 Ultra feedback. The selected destination now sits in a circular button inside a cleaner custom-painted rise in the white navigation surface, closely following the supplied reference while retaining Homi colours, typography and the centred exact Homi Home mark.
- Removed Material ink/splash selection handling from the custom nav interaction so a grey/rectangular selection block should no longer appear around the active item.
- Kept the primary order **Overview, Routines, Home, Supplies, People**, with Home centred.
- Added reusable Homi inline choice controls and branded confirmation sheets so fixed-choice forms and destructive actions do not fall back to awkward native-style dropdown/popup treatments where a Homi treatment is practical.

### Routines - real recurrence and completion attribution

- Replaced descriptive-only Routine frequency with an actual recurrence model: one-off/as-needed, daily, weekdays, weekly and monthly.
- Routine creation now supports exact due time, selected weekly days, monthly day-of-month and estimated duration.
- Fixed choices such as category, repeat type, weekdays and duration now use Homi inline selectors rather than dropdown menus.
- Added a repeat icon to recurring Routine cards.
- Recurring Routine cards show when the Routine is currently due and the calculated next due date/time after completion.
- Routine completion now records an attribution entry containing the exact completion time, display name and optional Firebase UID of the signed-in person who completed it.
- Routine cards show user-facing history such as `Done 9 Sep · 14:00 by Bruce` so another person can immediately understand what happened once shared household sync is added.
- Kept a bounded completion history rather than only a single completed boolean.
- Existing locally stored Routine JSON is migrated from the older frequency/completed/last-completed fields where possible, with safe defaults for missing duration and schedule information.
- Common Routine examples now include realistic schedules such as feeding pets daily, bins on a selected weekly day, bed linen weekly and plant watering weekly.
- Replaced the old generic remove popup flow with Homi-styled Routine options and a branded destructive confirmation sheet.

**Important current boundary:** Routine data is still local-first on one device. Completion attribution is implemented in the data model, but another household member on a different phone will not yet see it until the shared household membership/synchronisation layer is built. This pass does not pretend that cross-device household Routine sync already exists.

### Supplies - quick starts and cleaner fixed choices

- Added common household Quick Adds for **Milk, Bread, Eggs, Dog food, Toilet paper and Dishwashing liquid**.
- Tapping a Quick Add opens the normal Supply editor prefilled with the item/category so the user can adjust status or expiry before saving.
- Replaced Supply category/status dropdowns with Homi inline choices.
- Replaced native-style date picker dependency in this flow with compact day/month/year fields so the form stays visually consistent with Homi.
- Retained the quieter semantic status line rather than rounded status chips.
- Expiry-aware `Use soon` / `Expired` behaviour remains active.
- Supply options/status changes and removal now use Homi-styled sheets and confirmation controls rather than popup menus.

### Overview and Quick Reset

- Overview now counts only Routines that are actually due according to the recurrence model rather than every incomplete Routine.
- Home service/maintenance attention is now another real Overview source.
- Expanded the built-in Quick Reset suggestion pool with common household jobs such as laundry, fridge checks, mirrors, counters, recycling, one-surface resets and tidying small areas.
- Built-in Quick Reset suggestions are shuffled on each invocation so repeated 10- or 30-minute resets do not keep returning the same fixed list.
- Due saved Routines are still prioritised before Homi suggestions and the total planned time cannot exceed the selected budget.
- Completing a saved Routine inside Quick Reset records the real Routine completion attribution and computes its next due occurrence.
- Updated the in-app `How it works` explanation to describe rotating suggestions, due Routines, attribution and next-due behaviour in launch-ready wording.

### Home - first real household records

- Replaced the previous Home placeholders with a real local-first Home domain.
- Added **Things** for appliances, equipment and other home items with name, category, room/location, optional brand/model, optional next service date and notes.
- Things show when service is due or approaching and can surface this attention on Overview.
- Added **Maintenance & repairs** history with maintenance/repair type, date, optional linked Thing, notes and who logged/completed the work.
- Added **Utilities** with electricity/water meter readings, unit, timestamp and who recorded the reading.
- Added branded removal confirmations for Home Things, history entries and utility readings.
- Home records persist locally and survive app restart without requiring an account.
- User-owned home documents/Google Drive remain an intended Homi capability but are not exposed as a completed feature in this pass.

### People - persistent map and trusted connections

- Reworked People around a persistent Google Map rather than a manual location-check card as the dominant experience.
- The user's most recent location/battery state is cached locally and displayed immediately when available.
- If foreground location permission has already been granted, People refreshes location automatically rather than requiring the user to press `Check my location` every visit.
- Added profile-picture map markers for the current user and trusted people; initials are used when no profile photo is available.
- Tapping a marker opens a Homi location detail sheet with last update, battery percentage/charging state, accuracy, reverse-geocoded address and coordinates.
- Address/coordinates can be copied and the coordinates can be opened directly in external Google Maps.
- Added a six-character **Homi code** for signed-in accounts and an authenticated connection-request flow.
- The invited person must explicitly accept the connection.
- Connection acceptance and location sharing are deliberately separate: becoming trusted people does **not** automatically make either person's location visible.
- Each connected user controls a separate `Share mine` / `Stop my share` state for that individual person.
- Updated Firestore rules so exact Homi-code lookups are authenticated but the code directory cannot be listed, connections are readable only by their members, and location documents are readable only with an active owner-controlled share.

### Opt-in live/background location

- Added an explicit **Live updates** mode for signed-in users who choose to keep their shared location current while Homi is in the background.
- Android live sharing uses a visible foreground-service notification as required by the platform.
- The current battery-conscious configuration requests medium accuracy, a 100 m movement filter, roughly two-minute update spacing and no wake lock.
- Only the latest location/battery state is written by default; no hidden route-history/breadcrumb collection was introduced.
- Homi stores whether the user explicitly enabled live updates and attempts to resume that mode on a later signed-in app session only when Android still grants the required permission.
- Explicitly stopping live updates clears the saved preference, and signing out stops the active location stream before ending the Firebase session.
- Added an in-app location FAQ explaining background permission, the Android notification, battery-conscious update choices, no-default-history behaviour and how to stop/revoke sharing.

**Release-hardening boundary:** the foreground-service core is implemented in source, but Life360-grade resilience across force-stop, reboot, OEM battery optimisers and long stationary periods is not yet claimed. Those scenarios require real-device/release validation and additional lifecycle work where necessary. Google Play background-location disclosure/review also remains a release task.

### Android/native integration

- Added `google_maps_flutter`, geocoding and external-link support for the People experience.
- Raised the Android minimum SDK target for this integration to 24.
- Added `scripts/enable-location-map-android.ps1` because the current generated Android host remains intentionally local/untracked.
- The helper idempotently verifies/adds coarse/fine/background location, foreground-service/location-service, notifications and Internet permissions, Maps API-key metadata referencing the existing ignored local `@string/google_maps_key`, and min SDK 24.
- The helper never prints or rewrites the actual Maps API key value.
- Updated Android bootstrap so a newly generated host also receives the Homi Maps/location integration.

### Data model and test coverage

- Added `RoutineRepeat`, `RoutineCompletion` and real next-occurrence calculation.
- Added `HomeThing`, `HomeEvent`, `UtilityReading` and their creation payloads.
- Added cached/current location serialization plus trusted connection/location models.
- Expanded tests for recurring Routine persistence, actor attribution, weekly scheduling, legacy Routine migration, expiry-aware Supplies, Quick Reset budget behaviour, Home Things, Home history and Utility readings.
- Bumped the Flutter application version to `0.4.0+4`.

### 0.4.0 verification checkpoint

This is a **source pass only** until Bruce's local Flutter/Android toolchain proves it. It must not be called compiled/device-verified yet.

Local checkpoint:

1. pull latest `main`;
2. resolve new Flutter dependencies with `flutter pub get`;
3. run `scripts/enable-location-map-android.ps1` against the existing local Android host;
4. run `flutter analyze` and resolve every error;
5. run `flutter test` and resolve every failure;
6. deploy the updated Firestore rules before testing Homi-code/trusted-person connections;
7. run Homi on the Samsung S25 Ultra and review the nav, inline forms, recurring Routine scheduling/completion attribution, Supply Quick Adds, Home records, People map and current-location refresh;
8. test live updates only after explicitly granting Android background location (`Allow all the time`) and confirm the foreground-service notification remains visible;
9. recheck local-only use, sign-out behaviour and per-person share revocation.

## 0.3.0 - Navigation identity, Quick Reset and profile controls

- Centred Home in **Overview, Routines, Home, Supplies, People** and kept the exact Homi mark as the Home icon.
- Added the first custom raised navigation treatment, real Quick Reset planning, per-Routine estimated duration, Routine/Supply persistence, expiry-derived Supply attention and profile/account settings.
- Added Google provider identity, Firebase verification state and launch-copy cleanup.
- Fixed the first 0.3 compile blocker caused by an unqualified Supply status member.
- The 0.4 pass supersedes the 0.3 Routine frequency model and first raised-nav treatment while preserving the local data migration path.

## 0.2.0 - Shell refinement and local household tools

- First Samsung S25 Ultra build launched successfully after Gradle/JDK/memory setup was stabilised.
- Moved the exact Homi logo/profile control into persistent shell chrome and enabled horizontal primary-page swiping.
- Added the first local Routine and Supply models, create/update/remove flows and SharedPreferences persistence.
- Reduced blank-scroll space and compacted People privacy wording.
- Added top-level `NEXT_CHAT_PROMPT.md` continuity handoff.

## 0.1.0 - First installable source pass

- Locked Firebase project `homi-ee80a`, Android package `za.co.theconceptlab.homi`, Firestore Johannesburg and keyless backend identity.
- Added exact Homi branding, launcher/splash generation, onboarding, optional local-only mode, email/password + Google authentication and the initial five-page shell.
- Added App Check provider selection, initial Firestore location-share rules and foreground location/battery capture.
- Stabilised the local Android toolchain on JDK 21 / Gradle 8.14 with a verified 4 GB Gradle daemon after diagnosing the original 512 MB fallback/BOM issue.
- Registered debug signing fingerprints, installed Firebase Android config locally and rotated any Maps key exposed during setup before local use.
