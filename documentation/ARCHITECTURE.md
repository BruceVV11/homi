# Homi Architecture

## Permanent project identifiers

- Google Cloud / Firebase project ID: `homi-ee80a`
- Google Cloud / Firebase project number: `883068189841`
- Android application ID: `za.co.theconceptlab.homi`
- Local project root: `C:\ConceptLab\Projects\homi`
- GitHub repository: `BruceVV11/homi`
- Firestore region: `africa-south1` (Johannesburg)

These identifiers are locked for the Android/Firebase/Play lifecycle. The deleted `homi-508000` project is not part of Homi.

## Stack

- Flutter / Dart Android application
- Android minimum SDK 24
- SharedPreferences for version-tolerant local-first household records
- Firebase Authentication for optional identity and collaboration
- Cloud Firestore for narrowly scoped shared state
- Google Maps Flutter + Android location services for consensual trusted-person location
- Firebase App Check: debug provider during development, Play Integrity for release
- Google Drive direction remains user-owned files with `drive.file` only when document storage is implemented

## Primary shell

Primary destinations are:

**Overview · Tasks · Home · Supplies · People**

The exact Homi mark is the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move when swiping between destinations.

The bottom navigation uses a rounded white base plus a true circular white halo behind the active destination. The halo is generated as a geometric union rather than hand-drawn mound control points so edge destinations do not develop pointed corners.

## Tasks vs routines

The Tasks destination contains two deliberately different concepts.

### Tasks

Tasks are one-off jobs such as “Take the mince out to defrost”.

- optional due date/time or **No due time**
- optional assignee
- completion records who completed it and when
- completed tasks remain visible for 48 hours
- expired completed tasks are hidden immediately by the client and deleted on a later authorised cloud/local cleanup

A task assigned to **Me** remains private/local. A task assigned to another household person, or to **Anyone at home**, can be written as a household task visible to the creator's chosen Household people. Every viewer sees the assignee, completion person and due time. Location-only friends are excluded from household task assignment and visibility.

### Routines

Routines are repeating household responsibilities. Current recurrence options are:

- Daily
- Weekdays
- Weekly, including selected weekdays
- Bi-weekly, anchored to one weekday on a 14-day cadence
- Monthly

Routine completion stores the actor and timestamp and calculates the next occurrence. `RoutineCompletion.occurrenceDueAt` makes accidental unticks reversible: reopening restores the same occurrence rather than advancing the schedule twice.

Routine durations include the launch-facing **60+ min** option; internally it remains a 60-minute planning value for Quick Reset budgeting.

## Overview / Quick Reset

Overview aggregates real attention from open Tasks, due Routines, Supplies and Home service dates.

The Overview **Quick add** action is now a destination launcher rather than another unclassified reminder field. It routes the user to Task, Routine, Supply or Home so new information enters the correct product model. Existing legacy Quick Add reminder strings remain readable/removable for migration compatibility but new vague reminders are no longer created by the Overview UI.

`When you have time` / Quick Reset prioritises due saved Routines, fills remaining time with rotating common household suggestions and never intentionally exceeds the chosen time budget.

## Local-first state

The following continue to work without an account:

- onboarding/home name/type
- legacy Quick Add reminders
- private/local one-off Tasks
- recurring Routines
- Supplies and expiry state
- Home Things
- maintenance/repair history
- utility readings
- cached current-device location state

Local records are encoded as version-tolerant JSON strings in SharedPreferences. Model changes preserve older records with safe defaults rather than requiring storage resets.

## Shared cloud state

Cloud sharing remains additive and narrow.

### Trusted connections and private labels

`connections/{connectionId}` establishes that two authenticated users accepted a trusted-person connection. The connection alone grants no location or household access.

Each user may privately classify another connected person at:

`peoplePreferences/{ownerUid}/people/{otherUid}`

The preference stores a relationship label plus a scope of `household` or `friend`. Preferences are private to their owner.

### Household tasks

`sharedTasks/{taskId}` contains only one Task's title/note, creator, optional assignee, visibility member UIDs, due state and completion state.

The creator builds `memberUids` from people they explicitly marked Household. Tasks assigned to the creator do not enter this collection. A specific non-self assignee must be an accepted trusted connection that the creator marked Household.

This is still not full household database synchronization. Sharing one Task does not expose Home, Supplies or Routines.

## People / location architecture

The tracked device controls sharing.

- Foreground location may be enabled without sharing it with anybody.
- Live background updates require sign-in, Android background-location permission and explicit user action.
- Android live sharing uses a visible foreground-service notification.
- Current settings use medium accuracy, a 100 m movement threshold and spaced update requests to reduce battery pressure.
- The latest current-device location is cached locally and reused immediately when returning to People.
- Signed-in location/battery state is written to `locations/{uid}`.
- Another user may read it only when an accepted connection exists and the owner created an active `locationShares/{ownerUid}/viewers/{viewerUid}` share.
- Long-term movement history is not stored by default.

People uses keep-alive state plus the app-level `LocationStatusService` so swiping away and back should not briefly reset live-sharing UI to its initial state before the cache/stream catches up.

## People maps and focus

People now has two map surfaces:

1. the embedded People map, which remains pannable/zoomable and includes an **Open map** action;
2. a full-screen People map with branded back/focus controls.

Available people are represented by their profile picture as the map marker, with initials as fallback. Person chips let the user focus the map on a particular person. Selecting a marker can open location details with last update, address, coordinates, accuracy, battery and charging state.

Address and coordinates have individual copy actions; **Copy all** copies both and Google Maps opens the coordinates externally.

A sync failure does not erase the last known location state. People exposes a retry action and distinguishes secure-sync/unavailable errors from an actual lack of connections instead of presenting raw Firestore error codes.

## Home

Home remains the local operating record for the physical place:

- Things / appliances / equipment
- service and warranty dates
- maintenance and repair history
- electricity/water meter readings

Utility units are controlled choices rather than free-form text:

- electricity: `kWh`, `Wh`, `MWh`, `units`
- water: `kL`, `L`, `m³`, `units`

A trusted or location-only connection is not automatically a Home member.

## Supplies

Supply records persist a stable `iconKey` resolved through `SupplyIconCatalog`. Existing records without an icon key fall back to `inventory`. The catalog covers common food, cleaning, medical, pet, garden, hardware, utility and other household cases.

## Input / interaction standards

Stable fixed choices use Homi inline selection controls instead of awkward native dropdown menus. Dates and times use Homi-branded calendar/time controls rather than text fields. Numeric text entry is reserved for genuinely free-form numbers such as meter readings.

Destructive confirmations and action menus should use Homi sheets rather than unstyled platform popups wherever practical.

## Firestore collections in active use

```text
users/{uid}
users/{uid}/devices/{deviceId}
homiCodes/{code}
connections/{connectionId}
peoplePreferences/{ownerUid}/people/{otherUid}
sharedTasks/{taskId}
locationShares/{ownerUid}/viewers/{viewerUid}
locations/{ownerUid}
```

Anything not explicitly allowed by Firestore rules fails closed.

## Security / secrets

- No service-account private key is bundled in the app.
- Android Maps configuration remains in ignored local secret/config files.
- Sensitive location values must not be added to analytics or general diagnostic logs.
- App Check enforcement remains off until valid debug/release traffic is proven.
- No privacy or stop-sharing control may ever depend on payment.

## Verification state

Source is at the `0.6.0+6` feature-pass stage. GitHub is the tracked-source source of truth, but Bruce's local `flutter analyze`, `flutter test` and real Samsung S25 Ultra device run remain the authority for compile/runtime success. Do not call 0.6.0 device-verified until those checks succeed.
