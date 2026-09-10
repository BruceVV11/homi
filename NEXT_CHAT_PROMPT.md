# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub is the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.8.1.md`
- `documentation/releases/0.8.1-cloud-shell-storage-fix.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a new pass compiled/worked on-device until Bruce's real Flutter/Android toolchain proves it.

## Permanent project context

- Local root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore region: `africa-south1`
- Flutter baseline: 3.41.5 stable
- Dart baseline: 3.11.3
- Development device: Samsung S25 Ultra
- JDK 21 / Gradle 8.14
- `android/` is intentionally local/untracked.
- Preserve local Firebase/Maps/signing files. Never ask Bruce to paste Maps keys or App Check debug tokens into chat.
- Deleted project `homi-508000` must never be used.

Bruce still has this safety stash:

`stash@{0}: On main: Homi pre-0.5.0 local tracked changes`

Do not automatically pop or delete it.

## Approved brand

- Coral `#FF6B5E`
- Peach `#FFB08A`
- Sage `#A7B89F`
- Cream `#FFF8F2`
- Slate `#2E2E2E`
- Nunito
- exact Homi logo/mark assets are under `assets/brand/`; never redraw them.

## Standing user-facing copy rule

All **user-visible** Homi wording must read as though Homi is a complete product. Never show “being built”, “pre-release”, “future feature”, “not yet implemented”, roadmap language or wording addressed to Bruce/developers.

Do not misrepresent unavailable capability. Describe current boundaries naturally, e.g. “This record stays on this phone unless it is shared.” Internal engineering docs should still state real blockers.

## Current source version

**`0.8.1+9`**

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## Confirmed product/device baseline

Bruce has reported the 0.8 product experience is where he wants it overall. On the S25 Ultra:

- normal Homi notifications are delivering;
- developer self-test notifications are delivering;
- the notification status icon uses the Homi mark;
- Developer notifications access is enabled for the intended account;
- Android Studio runtime is otherwise behaving correctly.

The **All enabled Homi devices** developer audience is implemented through FCM topics. It was intentionally withheld during the first proof to avoid an accidental broad send before self-test worked. It is not disabled. Perform one controlled broad test before public users exist.

## 0.8 notification system

Path: **Profile avatar → Homi & account → Notifications**.

Categories:

- Household attention
- Tasks & routines
- People
- Homi updates
- Service & security

Fresh/default **Homi updates are now OFF** until explicitly enabled. Unknown remote categories fail closed.

Local notifications cover due Tasks/Routines, Supply expiry warning/date, Home service warning/date and grouped new household attention.

Cloud notifications cover connection requests/acceptance, People hearts, shared Task creation/assignment/completion and developer broadcasts.

Developer access remains server-provisioned through `developerAdmins/{uid}`. Normal users cannot self-grant it.

## People hearts

`sendHeart` is a callable Function in `africa-south1`.

0.8.1 hardening adds:

- Firebase Authentication required;
- valid accepted trusted connection required;
- **App Check enforcement** at the callable Function;
- 1-minute sender→recipient cooldown;
- 40 hearts per sender per fixed 24-hour window;
- max 3 `sendHeart` instances.

The feature remains intentionally tiny: `{name} is thinking about you!`; do not turn it into chat unless Bruce asks.

## 0.8.1 security/cost hardening

Cloud Functions global `maxInstances` is **5**. Direct notification fan-out reads at most **12 enabled device records per user**.

All Homi Functions are now configured in source to run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

rather than the broad default Compute runtime service account. The dedicated account already has Homi's Firestore and Firebase Cloud Messaging application permissions. The next backend deployment must prove this identity works for all Functions before considering removal of the old Compute account's Editor role.

Server-only `serverRateLimits` suppresses excessive notification generation:

- connection request pushes: 20/hour per initiator;
- shared Task creation pushes: 60/hour per creator;
- shared Task completion pushes: 120/hour per completing user;
- developer self tests: 30/hour;
- developer broad sends: 6/hour and 20/24h.

`serverRateLimits` is client-inaccessible and account-deletion cleanup removes rate-limit records belonging to the deleted UID.

Firestore rules were tightened for:

- bounded user profile schema and immutable client-side Homi code after profile creation;
- notification device schema/lengths;
- developer campaign fields/lengths/enum values/server timestamp;
- Homi code length/schema;
- deterministic connection document ID/schema and restricted pending→accepted transition;
- People preferences only for accepted connections;
- Shared Task field/text bounds, completion attribution and deletion rules;
- location-share schema;
- latest-location field allow-list, coordinate/accuracy/battery bounds, server timestamp and capture-source allow-list;
- server-only rate-limit records.

### Automated Firestore rules gate

`security-tests/` contains emulator tests for critical allow/deny assumptions. Run:

```bash
bash scripts/test-firestore-security.sh
```

The normal backend deployment helper now runs this security suite automatically before it deploys. A failed security test blocks deployment rather than publishing rules that failed the test gate.

### Cloud Shell storage incident / fix

The first 0.8.1 security-gate run on 2026-09-10 stopped with `ENOSPC: no space left on device` while npm was extracting the Firebase security-test dependencies into the Cloud Shell persistent `$HOME` disk. Runtime IAM preparation had already succeeded, but the deployment itself did **not** proceed past the security gate.

`test-firestore-security.sh` now removes any stale generated `security-tests/node_modules` tree and runs the disposable npm cache plus test dependencies from `${TMPDIR:-/tmp}` instead of the persistent Homi repository/home disk. The temp workspace is deleted automatically after the run.

On the affected Cloud Shell session, one-time recovery is:

```bash
cd ~/homi
rm -rf security-tests/node_modules
rm -rf ~/.npm/_cacache
rm -rf ~/.npm/_logs
df -h "$HOME"
git pull
bash scripts/deploy-notification-backend.sh
```

If space is still unexpectedly low, inspect before deleting anything else:

```bash
du -hs "$HOME"/.[!.]* "$HOME"/* 2>/dev/null | sort -h | tail -30
```

Do not delete the Homi repository to resolve this condition.

## App Check

Bruce registered the debug App Check token privately. Do not request it.

`sendHeart` now enforces App Check in source. **Firestore service enforcement remains a pre-release gate.** First verify legitimate debug traffic is valid, then configure/verify Play Integrity for the Play-signed release build, then enable Firestore enforcement before public release.

## Current cloud-sync truth

Trusted People/location and explicitly shared one-off Tasks use Firebase. Most household operational data is still device-local:

- Routines
- Supplies
- Home Things/history/readings
- private Tasks

This is the largest product-contract decision before release. If Homi launches as a genuinely shared Household app, build a real Household identity/membership model plus safe local↔cloud merge/sync before store deployment. Do not upload SharedPreferences and overwrite another device.

If the first launch stays local-first for those areas, store/in-app copy must state that boundary clearly.

The current direct Homi-code issuance/exact-lookup path is authenticated and tightly schema-restricted, but it is not server-rate-limited. Before broad public scale, strongly consider moving code issuance/lookup behind App-Check-protected callable Functions so code enumeration/write abuse can be rate-limited server-side.

## Release readiness

Read `documentation/RELEASE_READINESS.md` before deciding the app is ready for Play.

Major remaining gates include:

- 0.8.1 analyzer/tests/security-emulator/rules/functions verification;
- one controlled broad developer broadcast test;
- full Shared Household sync OR a deliberate local-first launch contract;
- background-location multi-hour/reboot/battery-optimiser testing;
- Google Play background-location declaration/review;
- release signing + Play App Signing SHA registration;
- production Google Sign-In from Play-installed build;
- production Maps key fingerprint restriction;
- Play Integrity App Check and Firestore App Check enforcement;
- prove dedicated least-privilege Cloud Functions runtime and then safely review old default Compute Editor access;
- Cloud billing alerts/spend controls and monitoring;
- public Privacy Policy, Terms and external account-deletion URL;
- Google Play Data Safety/content-rating/target-audience/app-access/store assets;
- decide whether first public release is free-only or includes Homi+ billing.

Current pricing direction remains planning only:

- Homi Free — R0
- Homi+ — R49.99/month or R499.99/year
- one household around six Household members
- location-only friends do not consume paid Household seats
- privacy/stop-sharing/account deletion never paywalled

Do not add a paywall before premium shared-cloud value exists.

## Immediate verification checkpoint for 0.8.1

Windows:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

If clean, Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

The deploy helper performs Function syntax validation and the Firestore Emulator security suite before publishing the stricter rules/Functions.

Then re-test on the S25 Ultra:

- notifications still register and deliver;
- People heart works with the registered debug App Check token;
- repeated heart is rate-limited cleanly;
- shared Task creation/completion works under stricter rules;
- connection request/acceptance works;
- live location writes and reads under stricter rules;
- developer self test still works;
- one controlled **All enabled Homi devices** test works for the enabled category;
- no raw permission errors appear.

If deployment reports `iam.serviceAccounts.actAs` for the dedicated runtime identity, grant only the required Service Account User/actAs permission to the actual deployer on `homi-backend-runtime` and retry. Do not restore broad Editor access to solve it.

If any rule returns `PERMISSION_DENIED`, capture the exact operation/log and fix the rule/data contract rather than weakening the whole collection.

## Documentation rule

At the end of every pass update relevant docs, add/update the release note under `documentation/releases/`, and refresh this file.
