# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat GitHub as the source of truth for tracked source/docs. Before changing anything, inspect the current source plus:

- `documentation/releases/0.5.0.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/RELEASE_NOTES.md`

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
- Verified local Gradle profile on the development PC: 4 GB heap, one worker, parallel execution off
- Android host under `android/` is intentionally local/untracked at this stage.
- Existing local Firebase/Maps config must be preserved.
- Never ask Bruce to paste the Maps API key into chat.
- The deleted project `homi-508000` must never be used.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito typography
- Exact Homi logo/mark artwork already exists in `assets/brand/` and must never be redrawn or approximated with framework shapes.

## Product direction

Homi is a local-first household operating system with a broader trusted-person/location layer.

Primary navigation is now:

**Overview · Tasks · Home · Supplies · People**

Home remains the centre destination and uses the exact Homi mark.

The persistent Homi logo/profile header must stay fixed while swiping primary pages.

## Tasks vs Routines

This distinction is intentional and must be preserved:

### Tasks

Tasks happen once.

Examples:
- Take the mince out to defrost
- Put the bins at the gate tonight
- Call the plumber

A task can:
- have no due time, or an optional date/time;
- be local-only;
- be assigned to the user;
- be assigned to an accepted Homi person marked **Household**;
- remain visible in Completed after completion;
- record who completed it and when;
- be reopened if ticked by mistake.

Cloud-assigned tasks use `sharedTasks/{taskId}` and share only that task with creator/assignee. They do not grant Home/Supplies/Routine access.

### Routines

Routines are repeating jobs only:
- Daily
- Weekdays
- Selected weekdays
- Monthly

Each occurrence records who completed it and when, calculates the next due time, stays visible in Up to date after completion, and can be unticked/re-ticked for the same occurrence if it was marked by mistake.

`RoutineCompletion.occurrenceDueAt` exists specifically to make this reversible.

## Date/time controls

Do not bring back typed date/time fields or awkward dropdowns for stable choices.

Current reusable branded controls are in:

`lib/src/widgets/homi_date_time_controls.dart`

They include:
- Homi calendar sheet
- Homi 24-hour time wheel
- Homi day-of-month selector
- Homi date/time display fields

Use inline Homi choice controls for fixed categories/statuses/frequencies wherever practical.

## Supplies

Supplies now have:
- quick adds such as Milk, Bread, Eggs, Dog food, Toilet paper, Dishwashing liquid;
- a broad icon picker using `SupplyIconCatalog`;
- persisted `iconKey` with legacy fallback to `inventory`;
- inline category/status choices;
- branded expiry-date picker;
- expiry-derived Use soon/Expired behaviour.

Keep adding icons to the catalog when a real missing household use case appears rather than storing raw IconData codepoints in user data.

## Home

Home currently supports:
- Things/appliances/equipment
- service dates
- warranty dates
- maintenance/repair history
- utility readings

The page has a compact **How Home works** explanation. Trusted/location-only friends do not get Home access. Full household Home/Routine/Supply synchronization is not implemented yet and must not be implied.

## People / trusted location

People is intentionally broader than family/household.

A connected person can be privately labelled by the current user as:
- Partner
- Wife / Husband
- Mother / Father / Parent
- Son / Daughter / Child
- Sibling
- Roommate
- Friend
- Family
- Caregiver
- Trusted person

Each private relationship also has scope:
- **Household**
- **Friend · location only**

A location-only friend:
- may receive location only after the owner separately enables sharing;
- must not gain Home, Supplies, Routines or household records;
- must not appear as a household task assignee.

A Household person may be eligible for separately scoped collaboration such as an assigned task, but household status still does not start location sharing.

Connection acceptance, relationship scope and location consent are three separate decisions.

People currently includes:
- Homi codes
- connection requests / accept / remove
- private relationship/scope preferences
- current-location map
- profile-photo/initial map markers
- battery and charging state
- reverse-geocoded address
- coordinates
- copy-address button
- copy-coordinates button
- **Copy all**
- open in Google Maps
- explicit per-person Share mine / Stop my share
- opt-in Live updates with Android foreground-service notification

`LocationStatusService` currently uses medium accuracy, a 100 m distance filter and roughly two-minute requested Android updates while live sharing is active. This is designed to reduce battery pressure, but do not claim full Life360 force-stop/reboot resilience until it is actually implemented and proven on real devices.

Latest location is stored; long-term route history is not on by default.

## Important People regression

A prior red framework screen appeared after opening Connect and then closing it:

`'_dependents.isEmpty': is not true`

The Connect flow was rewritten as a stateful modal that owns/disposes its own TextEditingController. Re-test opening/closing Connect repeatedly on the real S25 Ultra before calling it fixed.

Raw Firestore permission codes should not appear in user-visible People UI. Friendly user wording is now used.

## Firestore rules

Current rules include:
- private user/device data
- exact-lookup Homi codes
- accepted trusted connections
- private per-user `peoplePreferences`
- `sharedTasks` creator/assignee authorization
- accepted-connection + household-scope requirement for shared task creation
- accepted-connection + explicit active location share for location reads
- latest location/battery only by default

**The latest rules have not yet been confirmed deployed after the 0.5.0 changes.** People previously showed `permission-denied` because source rules were ahead of deployed rules.

After analyzer/tests are clean, deploy from Google Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-firestore-rules.sh
```

Do not deploy before the local source checkpoint is clean unless specifically debugging rules.

## Navbar direction

Bruce wants the selected circular item to look like the supplied reference: a white navigation surface whose top edge forms a smooth symmetric dome around the active button, leaving an **equal visible white gap around the top and sides of the active circle**. The bar must not visually touch the top of the active circle, and first/last destinations must not look pinched.

Current source was reworked again in 0.5.0 but still requires physical-device screenshot approval. Do not call it visually locked until Bruce approves it.

## Current verification checkpoint

The 0.5.0 source has been implemented in GitHub but is **not yet compile/device verified**.

Bruce's next local commands are:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

If clean, deploy the Firestore rules from Cloud Shell, then use Android Studio → Samsung S25 Ultra → Run.

Re-test specifically:
- navbar: Overview, Tasks, Home, Supplies, People selected states, including first/last;
- Task create with no due time;
- Task create with Homi date/time pickers;
- completed Task remains visible and reopens cleanly;
- Household-person assignment;
- Friend/location-only person does not appear as task assignee;
- recurring Routine complete → untick → tick again;
- Routine time/weekdays/monthly selectors;
- Home service/warranty/maintenance/reading date/time pickers;
- Supplies icon picker + restart persistence;
- People Connect open/close repeatedly;
- People relationship/scoping;
- location details individual copy buttons + Copy all + Google Maps;
- People permission error after rules deployment;
- live-location foreground/background behaviour and battery impact.

If analyzer or build produces an error, fix the exact source/tooling layer that failed. Do not reset Firebase, JDK, Gradle, signing, Maps or Android host setup unless the error actually points there.

## Documentation rule

At the end of every pass:
- update relevant documentation;
- update a release note under `documentation/releases/`;
- refresh this top-level `NEXT_CHAT_PROMPT.md` with the newest source-of-truth state.
