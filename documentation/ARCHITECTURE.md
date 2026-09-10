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
- Firebase Cloud Messaging for remote push delivery
- Firebase Cloud Functions 2nd gen in `africa-south1` for trusted-person/task notification events and developer campaigns
- `flutter_local_notifications` for local due/attention reminders and foreground push presentation
- Google Maps Flutter + Android location services for consensual trusted-person location
- Firebase App Check: debug provider during development, Play Integrity for release
- Google Drive direction remains user-owned files with `drive.file` only when document storage is implemented

## Primary shell

Primary destinations are:

**Overview · Tasks · Home · Supplies · People**

The exact Homi mark is the centre Home icon. The persistent Homi logo/profile row remains outside the PageView so it does not move when swiping between destinations.

The profile/avatar entry opens the full **Homi & account** centre. Local-only users can access Why Homi exists, Notifications, Help, privacy, location/safety, terms, about and local-data controls without being forced to sign in.

Notification taps are routed by the shell to Overview, Tasks, Routines, Home, Supplies, People or Homi & account.

## Tasks vs routines

### Tasks

Tasks are one-off jobs such as “Take the mince out to defrost”.

- optional due date/time or **No due time**
- optional assignee
- completion records who completed it and when
- completed tasks remain visible for 48 hours
- expired completed tasks are hidden immediately by the client and deleted on a later authorised cloud/local cleanup

A task assigned to **Me** remains private/local. A task assigned to another household person, or to **Anyone at home**, can be written as a household task visible to the creator's chosen Household people. Every viewer sees the assignee, completion person and due time. Location-only friends are excluded from household task assignment and visibility.

Local due Tasks can schedule device notifications. Shared Task creation/completion can also produce direct cloud push notifications through trusted authenticated membership.

### Routines

Routines are repeating household responsibilities. Current recurrence options are:

- Daily
- Weekdays
- Weekly, including selected weekdays
- Bi-weekly, anchored to one weekday on a 14-day cadence
- Monthly

Routine completion stores the actor and timestamp and calculates the next occurrence. `RoutineCompletion.occurrenceDueAt` makes accidental unticks reversible: reopening restores the same occurrence rather than advancing the schedule twice.

Routine durations include the launch-facing **60+ min** option; internally it remains a 60-minute planning value for Quick Reset budgeting.

The next due occurrence can schedule a local Tasks & routines notification when the user enables that category.

## Overview / Quick Reset

Overview aggregates real attention from open Tasks, due Routines, Supplies and Home service dates.

For Supplies, Overview no longer shows only a generic count. `SupplyAttention` ranks actionable items in this order:

1. Need to buy / zero tracked quantity
2. Expired
3. Use soon
4. Running low

Overview previews the three highest-priority Supplies and shows a `+ N more need attention` line when additional items exist.

Overview **Quick add** is a destination launcher for Task, Routine, Supply and Home. Its sheet is scroll/height constrained so it remains usable on supported Android heights without overflowing the system navigation area.

`When you have time` / Quick Reset prioritises due saved Routines, fills remaining time with rotating common household suggestions and never intentionally exceeds the chosen time budget.

## Supplies

Supply quantity is deliberately optional so Homi does not turn unpacking groceries into admin.

A Supply may store:

- optional `quantity`;
- optional stable `SupplyUnit` (`item`, `loaf`, `bottle`, `carton`, `pack`, `bag`, `roll`, `egg`, `kg`, `g`, `L`, `mL`);
- stock status;
- expiry date;
- icon/category.

Legacy Supplies with no amount remain valid in status-only mode. Quantity can be updated by tapping the amount or using compact +/- controls. Common Quick Adds start with useful defaults such as Bread = 1 loaf and Eggs = 12 eggs. A tracked quantity of zero derives `Need to buy` without deleting the item.

The Supplies page groups cards by action state while retaining each card's status indicator:

1. Need to buy
2. Use soon / expired
3. Running low
4. In stock

Within attention sections the same `SupplyAttention` ranking keeps the most urgent items first.

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
- local notification preferences/schedules once Android notification permission is enabled
- general Homi update/service/security topic subscriptions when enabled on the installation

Local records are encoded as version-tolerant JSON strings in SharedPreferences. Model changes preserve older records with safe defaults rather than requiring storage resets.

## Shared cloud state

Cloud sharing remains additive and narrow. Most Home/Routine/Supply data is still local rather than full shared-household cloud sync. The low Firestore usage seen during development is therefore expected and is not a production cost benchmark.

### Trusted connections and private labels

`connections/{connectionId}` establishes that two authenticated users accepted a trusted-person connection. The connection alone grants no location or household access.

Each connection stores deterministic `aUid` and `bUid` participant fields. The client issues two equality queries (`aUid == me` and `bUid == me`) and merges them locally. This replaced the previous `memberUids array-contains` listener after device testing exposed a Firestore rules/query proof failure (`PERMISSION_DENIED`) despite the user being a member.

Each user may privately classify another connected person at:

`peoplePreferences/{ownerUid}/people/{otherUid}`

The preference stores a relationship label plus a scope of `household` or `friend`. Preferences are private to their owner.

### Household tasks

`sharedTasks/{taskId}` contains only one Task's title/note, creator, optional assignee, visibility member UIDs, due state and completion state.

The creator builds `memberUids` from people they explicitly marked Household. Tasks assigned to the creator do not enter this collection. A specific non-self assignee must be an accepted trusted connection that the creator marked Household.

Sharing one Task does not expose Home, Supplies or Routines.

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

## People maps, focus and hearts

People has an embedded map and a full-screen map. Available people are represented by profile picture markers, with initials as fallback. Person chips let the user focus the map on a particular person. Selecting a marker can open location details with last update, address, coordinates, accuracy, battery and charging state.

Address and coordinates have individual copy actions; **Copy all** copies both and Google Maps opens the coordinates externally.

On the full People map, a selected non-self trusted person exposes a small heart action. The callable `sendHeart` Cloud Function verifies that the sender and recipient have an accepted trusted connection and applies a one-minute sender→recipient cooldown. The recipient's People-enabled devices receive **“{sender} is thinking about you!”**. A heart does not change location authorization, household membership or any other relationship permission.

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

## Notification architecture

See `documentation/NOTIFICATIONS.md` for the full operational matrix.

### User preferences

`HomiNotificationPreferences` is stored per installation. The master switch defaults off, while category defaults are ready for the user to enable explicitly:

- Household attention
- Tasks & routines
- People
- Homi updates
- Service & security

Signed-in devices mirror their FCM token and category flags at:

`users/{uid}/devices/{deviceId}`

The random `deviceId` is an app-installation identifier, not a hardware/advertising identifier.

### Local notifications

`HomiNotificationService` uses local notifications for:

- due local Tasks;
- due Routines;
- expiry warnings/date;
- service warnings/date;
- newly critical grouped household attention.

Immediate household attention is state-de-duplicated. Need-to-buy, expiry/expired and service-soon/due conditions are combined into one notification with up to three visible reasons rather than producing a burst of separate alerts.

Scheduled reminders use `inexactAllowWhileIdle`, avoiding exact-alarm permission.

### Remote notifications

FCM is used for:

- trusted connection request/acceptance;
- People hearts;
- shared Task assignment/creation/completion;
- developer product/service/security notices.

Foreground remote pushes are rendered through Homi local channels. Background/terminated notification messages use the Android/FCM path. Local and remote notification taps converge on the shell route handler.

### Developer notification control

Developer access is server provisioned at:

`developerAdmins/{uid}`

Client rules prevent self-granting. An active developer sees **Developer notifications** in Homi & account and can compose:

- title/message;
- type: update/service/security;
- audience: own account test or all opted-in installations;
- deep-link destination;
- normal/important priority;
- recent campaign history/status.

Queued campaigns are stored at `notificationCampaigns/{id}` and processed by Cloud Functions. Direct self-tests use the developer's enabled device tokens. Broad campaigns use opt-in FCM topics (`homi_updates`, `homi_service`, `homi_security`) so local-only installations can receive general Homi notices without needing an account.

Cloud Functions re-check developer authorization before delivery. Client rules allow developers to create validated queued campaigns but not edit send state/results.

### Android host

Because `android/` remains intentionally local/untracked, `scripts/enable-notifications-android.ps1` configures Android notification permission, scheduled/boot receivers, the approved Homi monochrome status icon, multidex and core-library desugaring without exposing/changing secrets.

## Account, privacy and data controls

The Account centre separates four actions that must never be conflated:

- Sign in: enable identity/cloud features;
- Sign out: end the session without silently deleting local household data; direct account-specific push registration is removed from that signed-in user;
- Erase data from this phone: delete local household records and Homi cached location while keeping the cloud account;
- Delete Homi account: reauthenticate, delete Homi-managed cloud account data, delete Firebase Auth identity and explicitly erase the current device's Homi household/location cache.

`AccountDataService` is the central client deletion inventory for the active Firestore schema. A server-side user-document deletion trigger removes server-only notification metadata such as heart cooldowns, developer-admin access and campaigns created by the deleted UID.

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
developerAdmins/{uid}
notificationCampaigns/{campaignId}
heartCooldowns/{senderUid_recipientUid}   # server-only
```

Anything not explicitly allowed by Firestore rules fails closed. Cloud Functions Admin SDK operations bypass client rules and must revalidate authorization in server code.

## Security / secrets

- No service-account private key is bundled in the app.
- Android Maps configuration remains in ignored local secret/config files.
- Sensitive location values must not be added to analytics or general diagnostic logs.
- Developer-admin access cannot be granted by the client app.
- Developer broadcasts cannot use personal People/Task categories.
- App Check debug token is registered privately; enforcement remains off until valid traffic is confirmed and release App Check is proven.
- No privacy or stop-sharing control may ever depend on payment.

## Commercial direction

Launch planning currently recommends **Free + Homi+** rather than multiple paid tiers. Billing is intentionally not part of this notification pass. See `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`.

## Verification state

Source is at the `0.8.0+8` notification/attention pass. This source has not yet been run through Bruce's local `flutter analyze`, `flutter test`, Android host notification patch, S25 Ultra runtime or live Cloud Functions deployment. Do not call notifications backend/device verified until those checkpoints pass.
