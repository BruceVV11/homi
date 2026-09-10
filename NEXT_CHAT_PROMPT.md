# Homi — Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. GitHub is the source of truth for tracked source/docs.

Before changing anything, inspect:

- `documentation/releases/0.8.1.md`
- `documentation/releases/0.8.1-cloud-shell-storage-fix.md`
- `documentation/releases/0.8.2.md`
- `documentation/SECURITY.md`
- `documentation/RELEASE_READINESS.md`
- `documentation/NOTIFICATIONS.md`
- `documentation/ARCHITECTURE.md`
- `documentation/LOCATION_SAFETY.md`
- `documentation/legal/PRIVACY_AND_COMPLIANCE.md`
- `documentation/legal/ACCOUNT_DELETION.md`
- `documentation/business/PRICING_AND_UNIT_ECONOMICS.md`
- the latest affected source files

Use the **mobile-app-development** workflow first. For Cloud Shell/Firebase release work, also follow the repository-first release-integrity workflow: diagnose the complete failing stage before asking Bruce for another run, preserve the working project/runtime identities and keep deployment commands simple and resumable.

Preserve approved behaviour/design, exact brand assets and existing user data. Never claim a new pass compiled/worked on-device until Bruce's real Flutter/Android toolchain proves it.

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

**`0.8.2+10`**

Primary navigation remains:

**Overview · Tasks · Home · Supplies · People**

Home remains centred with the exact Homi mark.

## Confirmed product/device baseline

Bruce has reported the 0.8 product experience is where he wants it overall. On the S25 Ultra before the 0.8.2 security-closure source pass:

- normal Homi notifications were delivering;
- developer self-test notifications were delivering;
- the notification status icon used the Homi mark;
- Developer notifications access was enabled for the intended account;
- Android Studio runtime was otherwise behaving correctly.

The **All enabled Homi devices** developer audience is implemented through FCM topics. It was intentionally withheld during the first proof to avoid an accidental broad send before self-test worked. It is not disabled. Perform one controlled broad test before public users exist.

## 0.8 notification system

Path: **Profile avatar → Homi & account → Notifications**.

Categories:

- Household attention
- Tasks & routines
- People
- Homi updates
- Service & security

Fresh/default **Homi updates are OFF** until explicitly enabled. Unknown remote categories fail closed.

Local notifications cover due Tasks/Routines, Supply expiry warning/date, Home service warning/date and grouped new household attention.

Cloud notifications cover connection requests/acceptance, People hearts, shared Task creation/assignment/completion and developer broadcasts.

Developer access remains server-provisioned through `developerAdmins/{uid}`. Normal users cannot self-grant it.

## People hearts

`sendHeart` is a callable Function in `africa-south1`.

Hardening includes:

- Firebase Authentication required;
- valid accepted trusted connection required;
- App Check enforcement at the callable Function;
- 1-minute sender→recipient cooldown;
- 40 hearts per sender per fixed 24-hour window;
- max 3 `sendHeart` instances.

The feature remains intentionally tiny: `{name} is thinking about you!`; do not turn it into chat unless Bruce asks.

## 0.8.2 security closure

0.8.2 moves sensitive collaboration mutations behind App-Check-protected callable Functions rather than permitting cross-user client writes.

Server-controlled operations now include:

- Homi identity/code issuance;
- exact Homi-code lookup and connection creation;
- connection acceptance/removal;
- trusted-person relationship/scope changes;
- per-person location-sharing authorization;
- shared Task creation/toggle/removal;
- developer notification campaign queueing;
- cloud account-data deletion;
- push notification device registration/removal.

Password-provider sharing operations require verified email. Connection/code/share/task/deletion/developer operations have server-side abuse limits. Shared Task membership is derived server-side from accepted Household relationships rather than trusted from the client.

Cloud Functions remain configured to run as:

`homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`

Global Functions defaults remain bounded (`maxInstances: 5`, `minInstances: 0`, `256MiB`), with smaller caps on selected high-risk Functions. Direct notification fan-out reads at most 12 push-enabled device records per user.

Latest location remains the one high-frequency collaboration record written directly by the device. It is owner-only, schema-bounded and limited by Firestore rules to no more than one update of an existing document per 30 seconds. Normal live updates remain approximately two minutes / 100 m.

## Automated Firestore security gate

`security-tests/server.boundary.test.js` covers critical server/client boundaries. Run through:

```bash
bash scripts/test-firestore-security.sh
```

The normal backend helper runs this suite automatically and blocks deployment on failure.

### Confirmed 10 September 2026 result

The latest Cloud Shell run passed:

- **12 tests**
- **12 passed**
- **0 failed**

The expected `PERMISSION_DENIED` messages inside negative tests are normal; the final test summary is authoritative.

The 0.8.2 Firestore rules then compiled successfully and were released to the default Firestore database in `homi-ee80a`.

## Current Cloud Functions deployment state — important

The same 10 September 2026 deployment became a **partial backend deployment**:

- Firestore security gate: **PASS 12/12**;
- Firestore rules compilation: **PASS**;
- Firestore indexes: **deployed**;
- Firestore rules: **released/live**;
- Functions source upload: **succeeded**;
- Functions Cloud Build: **failed before deployment completed**.

Every targeted Function create/update was reported failed. Firebase skipped deletes, so existing previously deployed Functions were not intentionally removed by this failed run.

### Root cause

Cloud Build uses `npm ci` when a Functions `package-lock.json` is present. GitHub does **not** currently track `functions/package-lock.json`, but Bruce's Cloud Shell checkout contained an older untracked lock generated by earlier deployments.

The original smooth Homi deploy helper used normal `npm install --prefix functions`, which kept that local lock synchronized before Firebase packaged the directory. The Cloud Shell storage fix later added `--package-lock=false`; that protected persistent storage but accidentally stopped refreshing the stale lock while Firebase still uploaded it.

Cloud Build therefore saw:

- manifest: `firebase-admin` `14.1.0`, `firebase-functions` `7.3.2`;
- stale lock: `firebase-admin` `14.3.0` plus an incomplete transitive graph;
- result: `npm ci` `EUSAGE` and all Function builds failed.

### Source repair now on main

`scripts/deploy-notification-backend.sh` now restores the useful old deployment behaviour while keeping the storage protections:

1. remove an untracked stale Functions lock before preparation;
2. generate a fresh lock from the current `functions/package.json` with `npm install --package-lock-only` using a temporary npm cache;
3. run local `npm ci` from that lock before any security/deployment stage;
4. run Functions syntax checks;
5. run the mandatory Firestore security suite;
6. deploy Firestore + Functions only after all preflight stages pass;
7. remove generated `node_modules`, the untracked generated lock and temporary npm cache when the helper exits.

This specifically preflights the same install mode Cloud Build uses, so another manifest/lock mismatch should fail locally before Firebase upload instead of consuming a Cloud Build deployment attempt.

## Cloud Shell storage rules

The npm cache and security-test workspace use `${TMPDIR:-/tmp}` rather than accumulating large caches in persistent `$HOME` storage. Generated `node_modules` trees are removed after the run.

If persistent storage is unexpectedly low, inspect first. Do not delete the Homi repository.

One-time cleanup helper remains:

```bash
bash scripts/cleanup-cloud-shell.sh
```

## App Check

Bruce registered the development debug App Check token privately. Do not request it.

Protected callables enforce App Check in source. Firestore service enforcement remains a release gate: first verify legitimate debug traffic, then configure/verify Play Integrity for the Play-signed build, then deliberately enable Firestore enforcement before public release.

## Current cloud-sync truth

Trusted People/location and explicitly shared one-off Tasks use Firebase. Most household operational data is still device-local:

- Routines
- Supplies
- Home Things/history/readings
- private Tasks

This remains the largest product-contract decision before release. If Homi launches as a genuinely shared Household app, build a real Household identity/membership model plus conflict-safe local↔cloud merge/sync before store deployment. Do not upload SharedPreferences wholesale or let one device blindly overwrite another.

If the first launch stays local-first for those areas, store/in-app copy must state that boundary clearly.

## Release readiness

Read `documentation/RELEASE_READINESS.md` before deciding the app is ready for Play.

Major remaining gates include:

- complete the 0.8.2 Functions deployment using the dedicated runtime identity;
- run/verify `configure-auth-security.sh`;
- Flutter analyzer/tests and new 0.8.2 physical-device regression;
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

The current deployment failure is fixed **in source but not yet proven by Cloud Shell**.

From the existing Cloud Shell checkout:

```bash
cd ~/homi
git pull
bash scripts/deploy-notification-backend.sh
```

Do not run manual `npm install`, `npm ci`, `--force` or `--legacy-peer-deps` around the helper. The helper now owns dependency-lock preparation and validation.

Expected sequence:

1. Functions dependency lock prepared;
2. local `npm ci` succeeds;
3. Functions syntax check succeeds;
4. Firestore security gate again reports 12/12;
5. Firebase deployment reaches Function Cloud Build using the synchronized generated lock;
6. all Functions create/update successfully;
7. helper prints `Homi backend deployment completed.`

If the Functions deploy reports `iam.serviceAccounts.actAs` for the dedicated runtime identity, grant only the required Service Account User/actAs permission to the actual deployer on `homi-backend-runtime` and retry. Do not restore broad Editor access to solve it.

If another failure occurs, capture the exact failing stage. Do not weaken the Firestore rules or security tests merely to make a deployment pass.

After Functions deploy succeeds, continue the same 0.8.2 pass by verifying/applying the Authentication security helper and then retesting on the S25 Ultra:

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
