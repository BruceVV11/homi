# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat GitHub as the source of truth for tracked source/docs. Before changing anything, inspect:

- `documentation/releases/0.6.0.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and existing user data. Do not claim a pass compiled or worked on-device until Bruce's local Flutter/Android toolchain proves it.

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
- Verified local Gradle profile: 4 GB heap, one worker, parallel execution off
- Android host under `android/` is intentionally local/untracked at this stage.
- Preserve existing local Firebase/Maps files and never ask Bruce to paste the Maps key into chat.
- Deleted project `homi-508000` must never be used.

Bruce currently has a safety stash named:

`stash@{0}: On main: Homi pre-0.5.0 local tracked changes`

Do **not** automatically pop or delete that stash. It preserves old local source fixes; current GitHub already supersedes them.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito typography
- Exact Homi logo/mark artwork already exists in `assets/brand/`; never redraw/approximate it with framework shapes.

## Current product / navigation

Homi is a local-first household operating system with a broader trusted-person/location layer.

Primary navigation:

**Overview · Tasks · Home · Supplies · People**

Home remains centred and uses the exact Homi mark. The persistent Homi logo/profile header remains fixed while swiping primary pages.

Current source version: **`0.6.0+6`**.

## Tasks and Routines

Tasks and Routines are intentionally separate.

### Tasks

Tasks happen once.

- Optional due date/time or **No due time**.
- Completed Tasks show who completed them and when.
- Completed Tasks stay visible for 48 hours, then are hidden/purged by local/cloud cleanup.
- **Me** tasks remain private/local.
- A task assigned to another Household person, or **Anyone at home**, can be visible to the creator's chosen Household people through `sharedTasks/{taskId}`.
- Every household viewer sees the assignee/due/completion attribution.
- Location-only friends must not see household Tasks.
- Task explanatory copy now lives behind **How it works** instead of occupying page space.

### Routines

Routines repeat:

- Daily
- Weekdays
- Weekly / selected weekdays
- **Bi-weekly** / every second selected weekday
- Monthly

`RoutineCompletion.occurrenceDueAt` keeps complete → undo → complete-again reversible for the same occurrence.

Duration choices include **60+ min**.

## Overview

Overview **Quick add** is now a launcher rather than another vague reminder field.

It offers:

- Task
- Routine
- Supply
- Home

Task/Routine selections route into the correct Tasks subview. Supply/Home route to their primary page. Existing old Quick Add reminder strings remain readable/removable for migration but the Overview UI no longer creates new ambiguous reminder records.

`When you have time` continues to prioritise due Routines and rotate common household suggestions.

## Home

Home supports:

- Things/appliances/equipment
- service dates
- warranty dates
- maintenance/repair history
- utility readings

Utility unit input is now controlled, not free text:

- electricity: `kWh`, `Wh`, `MWh`, `units`
- water: `kL`, `L`, `m³`, `units`

Dates/times remain Homi-branded controls rather than typed fields/native dropdowns.

## Supplies

Supplies include quick adds, expiry logic and a broad persisted `SupplyIconCatalog`. Missing legacy icon keys fall back to `inventory`.

## People / trusted location

People intentionally supports partners, family, roommates **and friends**.

Each connected person can be privately classified with a relationship label plus scope:

- **Household**
- **Friend · location only**

Connection acceptance, household/friend scope and location consent are separate permissions.

Current People source includes:

- cached current location + live state reused immediately on return to the tab;
- `AutomaticKeepAliveClientMixin` to prevent tab-swipe state flicker;
- profile-photo map markers;
- embedded interactive map;
- **Open map** full-screen Google Map;
- pan/zoom on full map;
- person focus chips that centre a selected person;
- person card focus action;
- battery/charging/freshness;
- address + coordinate details;
- copy-address icon;
- copy-coordinates icon;
- **Copy all**;
- external Google Maps;
- Homi codes / connection requests;
- per-person Share mine / Stop my share;
- explicit Live updates with Android foreground-service notification;
- trusted-person sync retry that keeps last successful location data instead of collapsing to an empty state.

Raw Firestore permission errors should never be shown directly. A permission/sync problem must not be mislabeled as an internet problem.

The prior Connect-sheet red-screen regression (`'_dependents.isEmpty': is not true`) was addressed by giving the modal ownership of its controller. Continue real-device regression testing before declaring it permanently fixed.

## Location battery/safety boundary

Live sharing remains explicit and visible. Current Android strategy uses medium accuracy, a 100 m movement filter and roughly two-minute requested updates. Do not claim full Life360 force-stop/reboot persistence until proven/implemented. Long-term movement history is not enabled by default.

## Navbar direction

0.6 replaces the hand-drawn mound with a geometric union of:

- the rounded white navbar base; and
- a **true circular white halo** behind the active control.

This is specifically intended to remove the pointed/irregular shape Bruce saw when **Overview** or **People** was selected. Home remains the exact Homi mark. The physical S25 Ultra screenshot remains the authority; do not call this visually locked until Bruce approves it.

## Firestore rules

The current rules now include:

- private user/device data;
- exact-lookup Homi codes;
- accepted trusted connections;
- private per-user relationship preferences;
- household-visible `sharedTasks` member lists;
- specific non-self assignee validation against accepted Household connection;
- owner-controlled per-person location shares;
- latest location/battery access only to authorized viewers.

**The current 0.6 rules must be deployed after local analyzer/tests are clean and before testing household-shared Tasks or the People sync error.**

Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-firestore-rules.sh
```

## Immediate verification checkpoint

The 0.6 source was implemented in GitHub but has **not yet been compiled/device-verified**.

Bruce should first run:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

If clean, deploy Firestore rules from Cloud Shell, then Android Studio → Samsung S25 Ultra → Run.

Device-review priorities:

- Task How it works vs page breathing room;
- No due time wording;
- specific-person household Task visible to all Household members;
- Me Task remains private;
- Recently completed 48-hour section + reopen;
- Bi-weekly Routine and 60+ min duration;
- Overview Quick add routing;
- utility unit choices;
- People state no longer flashes back to initial state after swipe-away/back;
- trusted people Retry / no raw permission error after rules deployment;
- embedded map pan/zoom;
- Open map full-screen flow;
- person focus chips/markers/details;
- navbar circular halo on Overview, Home and People, especially edge geometry.

If analyzer/build reports an error, fix the exact source/tooling layer. Do not reset Firebase, JDK, Gradle, signing, Maps, or the Android host unless the error actually points there.

## Documentation rule

At the end of every pass:

- update relevant documentation;
- add/update a release note under `documentation/releases/`;
- refresh this top-level `NEXT_CHAT_PROMPT.md`.
