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

The profile/avatar entry now opens a full **Homi & account** centre rather than only a compact account sheet. Local-only users can access Help, Why Homi exists, privacy, location/safety, terms, about and local-data controls without being forced to sign in.

## Tasks vs routines

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

Overview **Quick add** is a destination launcher for Task, Routine, Supply and Home. Its sheet is scroll/height constrained so it remains usable on the S25 Ultra and smaller supported heights instead of overflowing the Android navigation area.

`When you have time` / Quick Reset prioritises due saved Routines, fills remaining time with rotating common household suggestions and never intentionally exceeds the chosen time budget.

## Local-first state

The following continue to work without an account:

- onboarding/home name/type
- legacy Quick Add reminders
- private/local one-off Tasks
- recurring Routines
- Supplies, quantities, status and expiry state
- Home Things
- maintenance/repair history
- utility readings
- cached current-device location state

Local records are encoded as version-tolerant JSON strings in SharedPreferences. Model changes preserve older records with safe defaults rather than requiring storage resets.

### Supply amount model

Supply quantity is deliberately optional so Homi does not turn unpacking groceries into admin.

A Supply may store:

- optional `quantity`;
- optional stable `SupplyUnit` (`item`, `loaf`, `bottle`, `carton`, `pack`, `bag`, `roll`, `egg`, `kg`, `g`, `L`, `mL`);
- stock status;
- expiry date;
- icon/category.

Legacy Supplies with no amount remain valid in status-only mode. Quantity can be updated by tapping the amount or using compact +/- controls. Common Quick Adds start with useful defaults such as Bread = 1 loaf and Eggs = 12 eggs. A tracked quantity of zero derives `Need to buy` without deleting the item.

## Shared cloud state

Cloud sharing remains additive and narrow. **Most Home/Routine/Supply data is not yet full cloud sync.** The low Firestore usage seen during development is therefore expected and must not be interpreted as a production cost benchmark.

### Trusted connections and private labels

`connections/{connectionId}` establishes that two authenticated users accepted a trusted-person connection. The connection alone grants no location or household access.

Each connection stores deterministic `aUid` and `bUid` participant fields. The client now issues two equality queries (`aUid == me` and `bUid == me`) and merges them locally. This replaced the previous `memberUids array-contains` listener after the S25 Ultra exposed a Firestore rules/query proof failure (`PERMISSION_DENIED`) despite the user being a member.

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

## People maps and focus

People has an embedded map and a full-screen map. The full-screen map was hardened in 0.7 with an explicitly full-route platform-view size after the S25 Ultra showed the map rendering only in a shallow strip with the remainder of the route blank.

Available people are represented by profile picture markers, with initials as fallback. Person chips let the user focus the map on a particular person. Selecting a marker can open location details with last update, address, coordinates, accuracy, battery and charging state.

Address and coordinates have individual copy actions; **Copy all** copies both and Google Maps opens the coordinates externally.

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

## Account, privacy and data controls

The Account centre separates four actions that must never be conflated:

- Sign in: enable identity/cloud features;
- Sign out: end the session without silently deleting local household data;
- Erase data from this phone: delete local household records and Homi cached location while keeping the cloud account;
- Delete Homi account: reauthenticate, delete Homi-managed cloud account data, delete Firebase Auth identity and explicitly erase the current device's Homi household/location cache.

`AccountDataService` is the central deletion inventory for the active Firestore schema. Add new account-linked cloud collections to this service in the same pass that introduces them.

For another person's shared Task, account deletion detaches/anonymises the deleting user's references rather than deleting a record owned by somebody else.

## Input / interaction standards

Stable fixed choices use Homi inline selection controls instead of awkward native dropdown menus. Dates and times use Homi-branded calendar/time controls rather than text fields. Numeric text entry is reserved for genuinely free-form numbers such as meter readings or optional Supply quantity.

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

## Commercial direction

Launch planning currently recommends **Free + Homi+** rather than multiple paid tiers. Billing is not implemented yet. See `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`.

## Verification state

Source is at the `0.7.0+7` feature-pass stage. The previous 0.6 analyzer/tests passed, but the new 0.7 source changes have not yet been run through Bruce's local `flutter analyze`, `flutter test` or S25 Ultra device build. Firestore rules also require a fresh deployment after the 0.7 query/account-deletion changes.
