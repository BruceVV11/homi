# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub is the source of truth for tracked source/docs. Before changing anything, inspect:

- `documentation/releases/0.8.0.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- latest affected source files

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a new pass compiled or worked on-device until Bruce's local Flutter/Android toolchain proves it.

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
- Preserve existing local Firebase/Maps/signing files. Never ask Bruce to paste Maps keys or App Check debug tokens into chat.
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
- exact Homi logo/mark assets in `assets/brand/`; never redraw them.

## Standing user-facing copy rule

Bruce explicitly requires all **user-visible** Homi wording to read as if Homi is a complete product. Do not show “being built”, “pre-release”, “future feature”, “not yet implemented”, roadmap language or wording addressed to Bruce/developers.

Do not lie about capabilities that do not exist. Describe the current product boundary directly and positively, for example “This record stays on this phone unless it is shared” rather than “cloud sync is not built yet”.

Internal engineering/release docs may and should still state verification blockers or unimplemented architecture truth.

## Current source version

**`0.8.0+8`**

Primary navigation:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## 0.7 baseline accepted by user

Bruce reported the 0.7 runtime experience was working well overall before asking for 0.8 refinements. The previous People full-map, Quick Add, Supply amount, People sync and account/legal work are therefore the baseline to preserve unless new device evidence contradicts it.

The App Check **debug token has now been registered privately**. App Check enforcement remains OFF until valid traffic is confirmed and release Play Integrity traffic is proven.

## 0.8 — Overview / Supplies attention

New `SupplyAttention` helper ranks actionable supplies:

1. Need to buy / zero tracked amount
2. Expired
3. Use soon
4. Running low

Overview now shows the three most critical Supply items with their concise status, plus `+ N more need attention` when necessary. The whole card opens Supplies.

Supplies now groups cards into:

- Need to buy
- Use soon
- Running low
- In stock

Each card still keeps its existing status line. Quantity, unit, +/- adjustment, Quick Adds, expiry and custom icon behaviour remain intact.

## Tasks / Routines / Home baseline

Tasks:

- one-off jobs;
- optional due date/time or No due time;
- optional Household assignee;
- completion attribution;
- Recently completed retention for 48 hours;
- Me-only Tasks remain private/local;
- household-visible shared Tasks use `sharedTasks`.

Routines:

- Daily / Weekdays / Weekly / Bi-weekly / Monthly;
- exact due time;
- actor/time completion history;
- reversible complete → undo → complete-again for the same occurrence;
- 60+ min duration option.

Home:

- Things/appliances/equipment;
- service and warranty dates;
- maintenance/repair history;
- utility readings with controlled units.

## People / location baseline

People supports partners, family, roommates and friends. Connection, relationship scope and location sharing remain separate permissions.

Scopes:

- Household
- Friend · location only

Current People features include:

- persistent embedded map;
- full-screen pannable/zoomable map;
- person focus chips;
- profile-photo/initial markers;
- battery/charging/freshness;
- address/coordinates with individual copy, Copy all and external Google Maps;
- Homi code connection requests;
- private relationship labels;
- per-person location sharing;
- explicit live background location with Android foreground-service notification;
- latest-state location rather than default route history.

Connection reads use two deterministic queries (`aUid == me` and `bUid == me`) merged client-side. Do not reintroduce the old `memberUids array_contains` query that produced a Firestore `PERMISSION_DENIED` on-device.

## 0.8 — People hearts

The full-screen People map now exposes a small heart action for the selected non-self trusted person.

`sendHeart` callable Cloud Function:

- region `africa-south1`;
- auth required;
- recipient must be an accepted trusted connection;
- one-minute sender→recipient cooldown in server-only `heartCooldowns`;
- sends **“{sender} is thinking about you!”**;
- People route on tap;
- does not change location share, Household/Friend scope or any other permission.

Do not turn this into chat/messaging unless Bruce explicitly asks. The charm is that it is deliberately tiny.

## 0.8 — Notification system

Read `documentation/NOTIFICATIONS.md` before modifying notification logic.

### User settings

Path:

**Profile avatar → Homi & account → Notifications**

Master notifications default OFF and are user enabled. Categories:

- Household attention
- Tasks & routines
- People
- Homi updates
- Service & security

Normal notification permission is not requested automatically at first launch.

### Local notifications

`HomiNotificationService` uses `flutter_local_notifications` for:

- Task due time;
- Routine next due time;
- Supply expiry warning (3 days before, 09:00 when schedulable);
- Supply expiry date (09:00);
- Home service warning (7 days before, 09:00 when schedulable);
- Home service due date (09:00);
- one grouped immediate household-attention notification when a Supply/Home record enters a new critical/warning state.

Immediate attention includes out/Need to buy, expired/use-soon and service-soon/due. It is de-duplicated while the condition remains active and groups up to three reasons plus a remaining count rather than firing many notifications.

Scheduled notifications use `AndroidScheduleMode.inexactAllowWhileIdle`; do not add exact-alarm permission unless product requirements change.

### Remote FCM

- top-level FCM background handler registered in `lib/main.dart`;
- foreground FCM is surfaced through Homi local notification channels;
- remote taps use `getInitialMessage` / `onMessageOpenedApp`;
- local notification taps use plugin launch/response callbacks;
- shell routes to Overview, Tasks, Routines, Home, Supplies, People or Homi & account.

Signed-in enabled devices register FCM token/preferences at:

`users/{uid}/devices/{deviceId}`

`deviceId` is random per Homi installation. Sign-out removes the direct account-specific token. Invalid FCM tokens are disabled server-side during direct delivery.

### Cloud event notifications

Cloud Functions send direct preference-aware notifications for:

- connection request;
- connection accepted;
- People heart;
- shared Task created/assigned;
- shared Task completed by another household member.

Shared Task lock-screen pushes deliberately omit Task title/content.

### General Homi developer broadcasts

Local-only installations can receive Homi product/service/security notices without an account through user-controlled FCM topics:

- `homi_updates`
- `homi_service`
- `homi_security`

Topic membership follows the local Homi Updates and Service & security switches.

## Developer notification centre

Developer notification access is server-provisioned only through:

`developerAdmins/{uid}`

Normal users cannot self-grant it.

An active developer gets **Developer notifications** under Homi & account, with:

- title ≤80 characters;
- body ≤280 characters;
- Homi update / Service or maintenance / Security category;
- Just this account test / All enabled Homi devices audience;
- deep-link destination;
- Normal / Important priority;
- recent campaign status/history;
- confirmation before broad sends.

Self-test uses developer account device tokens and can report direct sends/failures. Broad send uses FCM topic delivery and records FCM acceptance/message ID; do not claim topic acceptance is a per-device delivery/read count.

Client Firestore rules only allow active developer admin to create a tightly validated `queued` campaign. Client cannot update delivery status. Cloud Functions re-check developer access before delivery.

## Firestore additions

0.8 adds:

```text
developerAdmins/{uid}
notificationCampaigns/{campaignId}
heartCooldowns/{senderUid_recipientUid}  # server-only
```

Existing collections remain:

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

Cloud Functions Admin SDK bypasses client Firestore rules; every server function must perform its own authorization/validation where applicable.

## Account deletion / privacy

Keep Sign out, Erase this phone and Delete account distinct.

Notification lifecycle additions:

- signed-in push token is removed on sign-out;
- account deletion removes the device push registration before cloud/Auth deletion;
- existing user device subcollection deletion covers push-token docs;
- deleting `users/{uid}` triggers server cleanup for heart cooldowns involving the UID, `developerAdmins/{uid}` and developer notification campaigns created by that UID.

Do not include precise location/addresses in notification payloads. Do not put shared Task title/content on the lock screen. Hearts may show sender name by design.

External Google Play account-deletion web page is still a production-release requirement; do not put a URL into Play Console until the real page exists.

## Android notification host integration

`android/` is untracked, so 0.8 adds:

`scripts/enable-notifications-android.ps1`

It idempotently adds/verifies:

- `POST_NOTIFICATIONS`;
- `RECEIVE_BOOT_COMPLETED`;
- flutter_local_notifications scheduled/boot receivers;
- `drawable/homi_notification.png` from approved Homi monochrome artwork;
- multidex;
- core-library desugaring with `desugar_jdk_libs:2.1.4`.

It does not print/change Firebase, Maps, signing or secret values.

## Cloud Functions deployment

Functions source:

`functions/index.js`

Node runtime: 22
Region: `africa-south1`

Deploy helper:

```bash
bash scripts/deploy-notification-backend.sh
```

The helper locks the permanent project/project-number, runs npm install + `node --check`, then deploys Firestore and Functions.

Developer access helper:

```bash
bash scripts/manage-developer-admin.sh '<FIREBASE_AUTH_UID>' enable
```

Obtain the UID privately from **Firebase Console → Authentication → Users** and enter it directly in Cloud Shell. Do not ask Bruce to paste it into chat. Use `disable` to revoke.

## Pricing direction

Still planning only:

- Homi Free — R0
- Homi+ — R49.99/month or R499.99/year
- one household around six Household members
- location-only friends do not consume paid Household seats
- privacy/stop-sharing/account deletion never paywalled
- Google Play Billing is the intended Android subscription mechanism

Do not implement a paywall until premium shared-cloud value is working.

## Immediate verification checkpoint

0.7 had 19 tests passing before 0.8. 0.8 changes dependencies, Android host requirements, notification source, Cloud Functions and tests, so it is **not yet analyzer/test/backend/device verified**.

Windows:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\enable-notifications-android.ps1
flutter analyze
flutter test
```

If clean, Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

Then grant the intended developer account access privately:

```bash
bash scripts/manage-developer-admin.sh '<FIREBASE_AUTH_UID>' enable
```

Then Android Studio → Samsung S25 Ultra → Run.

Device/backend verification priorities:

- Overview shows 3 critical Supplies + remaining count;
- Supplies grouped by status while status remains on cards;
- Notifications settings requests permission only after user action and category switches persist;
- due local Task/Routine notification + tap route;
- new out-of-stock/expiry/service attention appears once and does not nag on every app refresh;
- People heart reaches another enabled trusted account with `{name} is thinking about you!` and respects cooldown;
- connection request/acceptance notifications;
- shared Task assignment/completion notifications;
- developer self-test notification first;
- one controlled broad developer notification only after self-test succeeds;
- foreground/background/terminated notification tap routing;
- App Check traffic after debug-token registration while enforcement remains OFF.

If Flutter analysis/build, Android host script or Cloud Functions deployment reports an error, fix the exact failing layer. Do not reset Firebase, JDK, Gradle, signing, Maps or Android setup unless the error points there.

## Documentation rule

At the end of every pass update relevant documentation, add/update the release note under `documentation/releases/`, and refresh this file.
