# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub is the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.8.1.md`
- `documentation/releases/0.8.1-cloud-shell-storage-fix.md`
- `documentation/releases/0.8.2.md`
- `documentation/releases/0.8.2-functions-batching-fix.md`
- `documentation/SECURITY.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. For Cloud Shell/Firebase release work, also use the Concept Lab release-integrity workflow. A user rerun is not a diagnostic tool: inspect the full failing phase and all discoverable stale contracts before asking Bruce for another deployment attempt.

Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a source pass compiled, deployed or worked on-device until Bruce's real Flutter/Android/Firebase toolchain proves it.

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
- Functions runtime: Node.js 22
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

**`0.8.2+10`**

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## Confirmed product/device baseline

Bruce reported the 0.8 product experience is where he wants it overall. Before the 0.8.2 security-closure pass, the Samsung S25 Ultra proved:

- normal Homi notifications deliver;
- developer self-test notifications deliver;
- the notification status icon uses the Homi mark;
- Developer notifications access is enabled for the intended account;
- Android Studio runtime otherwise behaves correctly.

The **All enabled Homi devices** developer audience exists through FCM topics. It was intentionally withheld during the first proof to avoid an accidental broad send. Perform one controlled broad test before public users exist.

## 0.8 notification system

Path: **Profile avatar → Homi & account → Notifications**.

Categories:

- Household attention
- Tasks & routines
- People
- Homi updates
- Service & security

Fresh/default **Homi updates are OFF** until explicitly enabled. Unknown remote categories fail closed.

Local notifications cover due Tasks/Routines, Supply expiry warning/date, Home service warning/date and grouped household attention.

Cloud notifications cover connection requests/acceptance, People hearts, shared Task creation/assignment/completion and developer broadcasts.

Developer access remains server-provisioned through `developerAdmins/{uid}`. Normal users cannot self-grant it.

## People hearts

`sendHeart` is a callable Function in `africa-south1`.

Hardening includes:

- Firebase Authentication required;
- accepted trusted connection required;
- App Check enforcement;
- 1-minute sender→recipient cooldown;
- 40 hearts per sender per fixed 24-hour window;
- max 3 `sendHeart` instances.

The feature remains intentionally tiny: `{name} is thinking about you!`; do not turn it into chat unless Bruce asks.

## 0.8.2 security closure

Sensitive collaboration writes now go through App-Check-protected callable Functions instead of broad cross-user client Firestore writes.

Server-controlled operations include:

- Homi identity/code issuance;
- exact Homi-code lookup and connection creation;
- connection acceptance/removal;
- trusted-person relationship/scope changes;
- location-sharing authorization;
- shared Task creation/toggle/removal;
- developer notification campaign queueing;
- cloud account-data deletion;
- push notification device registration/removal.

Password-provider sharing operations require verified email. Connection/code/share/task/deletion/developer actions are rate-limited. Shared Task membership is derived server-side from accepted Household relationships.

Cloud Functions are configured to run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Global defaults remain bounded (`maxInstances: 5`, `minInstances: 0`, `256MiB`) with lower caps on selected high-risk callables. Direct notification fan-out reads at most 12 enabled device records per user.

Latest location remains the high-frequency record written directly by the device. It is owner-only, schema bounded and limited by Firestore rules to one update of an existing document per 30 seconds. Normal live updates remain approximately two minutes / 100 m.

## Automated Firestore security gate

`security-tests/server.boundary.test.js` is run through:

```bash
bash scripts/test-firestore-security.sh
```

The deployment helper runs it automatically and blocks deployment on failure.

### Confirmed 10 September 2026 result

Latest Cloud Shell runs proved:

- **12 tests**
- **12 passed**
- **0 failed**

The `PERMISSION_DENIED` messages inside negative tests are expected; the final test summary is authoritative.

The stricter 0.8.2 Firestore rules compile successfully and are live in the default database in `homi-ee80a`.

## Current Cloud Functions deployment state — important

The 0.8.2 backend deployment is **partially deployed and pending final batched verification**.

### Already proven healthy

- disposable Functions dependency-lock preparation;
- local `npm ci` using the same lock Cloud Build receives;
- Function syntax checks;
- Firestore security suite: **12/12**;
- Firestore indexes/rules deployment;
- Functions source packaging/upload;
- dedicated project identity guards.

### One-time trigger migration — COMPLETED

A stale deployed HTTPS Function previously occupied the name `onConnectionDeleted`, while 0.8.2 required a Firestore deletion backstop. Firebase cannot mutate an HTTPS trigger into a background trigger in place.

The repository migrated safely:

- replacement background Function is `onTrustedConnectionDeleted`;
- replacement was deployed successfully in `africa-south1`;
- Google Cloud reported the replacement `ACTIVE`;
- only then was stale HTTPS `onConnectionDeleted` deleted successfully;
- future helper runs automatically skip this completed migration.

Do not recreate the old `onConnectionDeleted` export.

### Latest remaining deployment failure

After the successful trigger migration, the broad Functions deploy attempted roughly twenty 2nd-gen Function updates together.

**13 updates completed successfully.** The following seven failed at the Cloud Functions v2 API request/update stage without a per-function build/source/runtime error being reported:

- `onConnectionAccepted`
- `onHomiUserDocumentDeleted`
- `onNotificationCampaignCreated`
- `onSharedTaskCreated`
- `onSharedTaskUpdated`
- `registerNotificationDevice`
- `removeNotificationDevice`

The Firebase CLI printed generic `Failed to make request` messages while the other Functions in the same deployment succeeded. Do not interpret this as seven separate source bugs.

Firebase's current guidance recommends named Function deployments when a project contains more than five Functions and groups of ten or fewer for larger deployments to avoid deployment-rate/control-plane failures. The exact HTTP response code was not printed in Bruce's log, so record this as a provider request/concurrency pattern rather than claiming a specific quota code.

### Batching repair now on `main`

`scripts/deploy-notification-backend.sh` now:

1. verifies local Node.js major version 22;
2. prepares the synchronized disposable Functions lock;
3. proves it with local `npm ci`;
4. runs Function syntax checks;
5. runs the mandatory 12/12 Firestore security gate;
6. skips the completed stale-trigger migration when no legacy resource exists;
7. deploys Firestore rules/indexes as their own surface;
8. derives current Function names directly from `functions/entrypoint.js`;
9. deploys Functions in deterministic batches of **5** instead of one broad burst;
10. stops on a failed batch and leaves already-successful deployments intact/resumable.

See `documentation/releases/0.8.2-functions-batching-fix.md`.

This batching repair is **fixed in source and pending Cloud Shell proof**.

## Cloud Shell storage rules

Functions npm cache and Firestore security-test dependencies use `${TMPDIR:-/tmp}` instead of persistent `$HOME`. Generated `node_modules` trees and the untracked generated Functions lock are removed automatically.

If persistent storage is unexpectedly low, inspect before deleting anything. Do not delete the Homi repository.

Safe cleanup helper:

```bash
bash scripts/cleanup-cloud-shell.sh
```

## App Check

Bruce registered the development debug App Check token privately. Do not request it.

Protected callables enforce App Check in source. Firestore service enforcement remains a release gate: verify legitimate debug traffic, configure/verify Play Integrity for the Play-signed build, then deliberately enable Firestore enforcement before public release.

## Current cloud-sync truth

Trusted People/location and explicitly shared one-off Tasks use Firebase. Most household operational data remains device-local:

- Routines
- Supplies
- Home Things/history/readings
- private Tasks

This remains the largest product-contract decision before release. If Homi launches as a genuinely shared Household app, build a real Household identity/membership model plus conflict-safe local↔cloud merge/sync before store deployment. Never upload SharedPreferences wholesale or blindly let one device overwrite another.

If the first launch stays local-first for those areas, store/in-app copy must state that boundary clearly.

## Release readiness

Read `documentation/RELEASE_READINESS.md` before deciding Homi is ready for Play.

Major remaining gates include:

- complete the 0.8.2 batched Functions deployment using the dedicated runtime identity;
- run/verify `configure-auth-security.sh`;
- Flutter analyzer/tests and 0.8.2 physical-device regression;
- one controlled broad developer broadcast test;
- full Shared Household sync OR a deliberate local-first launch contract;
- background-location multi-hour/reboot/battery-optimiser testing;
- Google Play background-location declaration/review;
- release signing + Play App Signing SHA registration;
- production Google Sign-In from Play-installed build;
- production Maps key fingerprint restriction;
- Play Integrity App Check and Firestore App Check enforcement;
- safely review old default Compute Editor access only after every Function is proven on the dedicated runtime identity;
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

## Immediate continuation checkpoint

Do **not** manually delete Functions, run manual npm repair commands, weaken Firestore rules, or use broad deployment force flags.

The normal helper now owns the recovery. From Cloud Shell:

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

Expected high-level sequence:

1. Node 22 guard passes;
2. dependency lock preparation passes;
3. local `npm ci` and Function syntax checks pass;
4. Firestore security gate reports **12/12**;
5. completed stale-trigger migration is skipped;
6. Firestore deploy succeeds;
7. helper discovers the current Function export set;
8. Functions deploy in batches of **5**;
9. already-current Functions may report `Skipped (No changes detected)`;
10. remaining Function updates complete;
11. helper prints `Homi backend deployment completed.`

If a batch fails, capture that batch's exact output. Do not immediately rerun the whole command until the failure has been classified.

After Functions deploy succeeds, apply/verify the Authentication security helper and then retest on the S25 Ultra:

- notification registration/delivery;
- People heart with registered App Check debug token;
- repeated heart rate limiting;
- Homi code identity/load/connect/accept/remove;
- Household ↔ Friend scope changes;
- shared Task create/complete/reopen/remove;
- live location share on/off and viewer reads;
- developer self test;
- one controlled **All enabled Homi devices** test;
- account deletion on disposable accounts;
- no raw permission errors.

Old 0.8.1 debug APKs must not be used to judge protected collaboration after the stricter 0.8.2 Firestore rules; the 0.8.2 client uses the new server-authorized paths.

## Documentation rule

At the end of every pass update relevant docs, add/update the release note under `documentation/releases/`, and refresh this file.
