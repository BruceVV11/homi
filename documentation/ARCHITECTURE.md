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

The exact Homi mark is the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move when swiping between primary destinations.

The Tasks destination contains two deliberately different concepts:

- **Tasks** — one-off jobs such as “Take the mince out to defrost”. A task may be left open or given a due date/time, may be assigned, remains visible after completion and records who completed it and when.
- **Routines** — repeating household work such as feeding pets or taking bins out. Routines recur daily, weekdays, selected weekdays or monthly, record completion attribution and calculate the next due occurrence.

One-off work must not be forced into a recurrence model merely to fit the old Routines page.

## Local-first state

The following continue to work without an account:

- onboarding/home name/type
- Quick Add reminders
- local one-off Tasks
- recurring Routines
- Supplies and expiry state
- Home Things
- maintenance/repair history
- utility readings
- cached current-device location state

Local records are encoded as version-tolerant JSON strings in SharedPreferences. Model changes must preserve old records with safe defaults instead of requiring a reset.

### Routine migration / recurrence

`RoutineCompletion` stores:

- completion timestamp
- completing person's display name
- optional Firebase UID
- optional `occurrenceDueAt`

`occurrenceDueAt` makes an accidental untick reversible. When a completed recurring Routine is reopened, Homi restores the same scheduled occurrence instead of losing it or advancing a second time. Older completion JSON without this field remains valid.

### Supply icon migration

Supply records now store a stable `iconKey`. Existing records with no icon key fall back to `inventory`. UI resolves the key through `SupplyIconCatalog`; raw framework icon codepoints are not persisted.

## Shared cloud state

Cloud sharing remains additive and intentionally narrow.

### Trusted connections

A `connections/{connectionId}` document establishes that two authenticated users have accepted a trusted-person connection. That relationship alone grants no location or household access.

Each user may privately classify a connected person under:

`peoplePreferences/{ownerUid}/people/{otherUid}`

The preference contains:

- relationship label such as Partner, Mother, Roommate or Friend
- scope: `household` or `friend`

Preferences are private to the owner. One person can describe the relationship differently from the other.

### Location-only friends

A person marked `friend` remains eligible for separately consented location sharing but is omitted from household task assignment. A trusted connection or friend label never grants access to Home, Supplies, Routines or other household records.

### Assigned one-off tasks

A household-labelled connected person can be assigned a single one-off task through `sharedTasks/{taskId}`.

A shared task contains only the fields needed for that task: title/note, creator, assignee, due time and completion state. Security rules restrict the document to its two members and require:

- an accepted trusted connection; and
- the creator's explicit `household` preference for the assignee.

This is intentionally **not** full household synchronization. Sharing one task does not expose the creator's Home, Supplies or Routine database.

Full household membership/sync for Routines, Supplies and Home requires a later merge/conflict model and must not be inferred from trusted-person connections.

## People / location architecture

The tracked device controls sharing.

- Foreground location can be enabled for the current device without starting a share to anyone.
- Live background updates require sign-in, Android background location permission and explicit user action.
- Android live sharing uses a visible foreground-service notification.
- The current strategy uses medium accuracy, a movement threshold and spaced update requests to reduce battery pressure.
- The latest current-device location is cached locally.
- Signed-in current location/battery status is written to `locations/{uid}`.
- A viewer may read another user's location only when an accepted connection exists **and** the owner has an active `locationShares/{ownerUid}/viewers/{viewerUid}` document.
- Long-term movement history is not stored by default.

A stored preference that says `household` does not enable location sharing. A location share does not enable household access. These are separate authorization decisions.

## People map and identity

- Homi codes are six-character exact-lookup connection identifiers.
- Homi codes cannot be used to browse a user directory.
- Accepted trusted people can be represented by profile-photo map markers, with initials as fallback.
- Location details can expose last update, address, coordinates, battery, charging state and accuracy to an authorized viewer.
- Address/coordinates can be copied and the coordinates can open in Google Maps.

## Home boundary

Home is the local operating record for the physical place:

- Things / appliances / equipment
- service and warranty dates
- maintenance and repair history
- utility readings

The Home UI explicitly explains that a trusted or location-only connection is not a Home member. Household-data sharing, when added, must use its own explicit membership and merge rules.

## Input / interaction standards

Stable fixed choices use Homi inline selection controls instead of awkward platform dropdown menus.

Dates and times use Homi-branded calendar/time controls rather than text fields. Numeric text entry is reserved for values that are genuinely numeric free-form data, such as a meter reading.

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

## Current verification state

Source is at the 0.5.0 feature-pass stage. GitHub is the tracked-source source of truth, but local `flutter analyze`, `flutter test` and real S25 Ultra device testing remain the authority for compile/runtime success. Do not call this pass device-verified until those checks succeed.
