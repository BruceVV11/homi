# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat GitHub as the source of truth for tracked source/docs. Before changing anything, inspect:

- `documentation/releases/0.6.0.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and existing user data. Do not claim a pass worked on-device until Bruce's local Android device proves it.

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

Bruce has a safety stash named:

`stash@{0}: On main: Homi pre-0.5.0 local tracked changes`

Do **not** automatically pop or delete it.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito typography
- Exact Homi logo/mark artwork already exists in `assets/brand/`; never redraw/approximate it.

## Current product state

Current source version: **`0.6.0+6`**.

Primary navigation:

**Overview · Tasks · Home · Supplies · People**

Home remains centred and uses the exact Homi mark. The persistent Homi logo/profile header remains fixed while swiping primary pages.

### Tasks

- One-off jobs, optional date/time or **No due time**.
- Completed Tasks show who completed them and when.
- Completed Tasks remain under **Recently completed** for 48 hours, then are hidden/purged by local/cloud cleanup.
- **Me** tasks remain private/local.
- Another Household assignee or **Anyone at home** can create a household-visible shared Task through `sharedTasks/{taskId}`.
- Location-only friends must not see household Tasks.
- Task explanatory copy is behind **How it works**.

### Routines

Supported recurrence:

- Daily
- Weekdays
- Weekly / selected weekdays
- Bi-weekly
- Monthly

`RoutineCompletion.occurrenceDueAt` keeps complete → undo → complete-again reversible for the same occurrence. Duration choices include **60+ min**.

### Overview

Overview **Quick add** launches Task, Routine, Supply or Home instead of creating a vague reminder. Existing legacy Quick Add reminder strings remain readable/removable only for migration safety.

`When you have time` still prioritises due Routines and rotates common household suggestions.

### Home

Supports Things/appliances/equipment, service dates, warranty dates, maintenance/repair history and utility readings.

Utility units are controlled choices:

- electricity: `kWh`, `Wh`, `MWh`, `units`
- water: `kL`, `L`, `m³`, `units`

### Supplies

Supplies include quick adds, expiry logic, branded date controls and persisted `SupplyIconCatalog`. Missing legacy icon keys fall back to `inventory`.

### People / trusted location

People supports partners, family, roommates and friends. Each connected person has a private relationship label and private scope:

- **Household**
- **Friend · location only**

Connection acceptance, household/friend scope and location consent are separate permissions.

Current People source includes:

- cached current location/live state reused immediately on return;
- state retention across PageView swipes;
- profile-photo/initial markers;
- embedded Google Map;
- **Open map** full-screen Google Map;
- pan/zoom and person focus controls;
- battery/charging/freshness;
- address/coordinates with individual copy actions, **Copy all**, and external Google Maps;
- Homi codes / connection requests;
- per-person Share mine / Stop my share;
- explicit Live updates with Android foreground-service notification;
- trusted-person sync retry preserving last successful state.

Raw Firestore permission errors must not be shown directly. A sync problem must not be mislabeled as an internet problem.

The prior Connect-sheet framework regression (`'_dependents.isEmpty': is not true`) was addressed by making the modal own/dispose its controller. Re-test repeatedly on the real S25 Ultra before calling it permanently fixed.

## Location safety boundary

Live sharing remains explicit, visible and reversible. Current Android strategy uses medium accuracy, a 100 m movement filter and roughly two-minute requested updates. Do not claim Life360-equivalent force-stop/reboot persistence until implemented and proven. Long-term movement history is not enabled by default.

## Navbar direction

0.6 replaces the hand-drawn mound with a geometric union of the rounded white navbar base and a **true circular white halo** behind the active control. This is specifically intended to remove the pointed/irregular edge shape Bruce saw on Overview/People. Physical S25 Ultra screenshots remain the visual authority.

## Firestore rules

Current rules include private user/device data, exact-lookup Homi codes, accepted trusted connections, private relationship preferences, household-visible `sharedTasks`, non-self assignee validation against accepted Household connection, owner-controlled per-person location shares and latest-location access only to authorised viewers.

The 0.6 rules still need deployment before testing household-shared Tasks or the People sync changes.

Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-firestore-rules.sh
```

## Current verification checkpoint

Bruce confirmed on **2026-09-10** that both local checks passed:

```powershell
flutter analyze
flutter test
```

Therefore the `0.6.0+6` source/analyzer/unit-test checkpoint is clean.

**Next checkpoint:** deploy Firestore rules from Cloud Shell, then run `0.6.0+6` from Android Studio on the Samsung S25 Ultra.

Device verification should focus on runtime rather than redoing setup: Task sharing/privacy/48-hour completion behaviour, bi-weekly Routine, Overview Quick add routing, utility units, People swipe-state retention, trusted-person Retry, embedded/full-screen map focus, Connect modal regression, location sharing controls and navbar edge geometry.

If a device/build error appears, fix the exact failing layer. Do not reset Firebase, JDK, Gradle, signing, Maps or Android host setup unless the error actually points there.

## Documentation rule

At the end of every pass update relevant documentation, update the release note under `documentation/releases/`, and refresh this file.
