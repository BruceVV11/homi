# Homi — Next Chat Prompt

Continue **Homi** from GitHub `main`. GitHub is the tracked source of truth. Use **mobile-app-development** first; for Firebase/Cloud Shell/release work also use **concept-lab-release-integrity**. Diagnose source/log evidence before asking Bruce to rerun anything.

## Permanent project identity

- Local root: `C:\ConceptLab\Projects\homi`
- Repo: `BruceVV11/homi`
- Android package: `za.co.theconceptlab.homi`
- Firebase/GCP: `homi-ee80a`
- Project number: `883068189841`
- Firestore/Functions region: `africa-south1`
- Flutter 3.41.5 / Dart 3.11.3
- JDK 21 / Gradle 8.14
- Functions Node 22
- Runtime identity: `homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com`
- Device: Samsung S25 Ultra / SM-S938B
- `android/` is intentionally local/untracked.
- Never request/expose Maps/Places keys, App Check debug tokens, signing secrets or private Firebase configuration.
- Deleted project `homi-508000` must never be used.
- Safety stash `stash@{0}: On main: Homi pre-0.5.0 local tracked changes` must not be popped/deleted automatically.

## Approved product/design contract

Brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito and exact `assets/brand/` artwork.

Primary nav: **Overview · Tasks · Home · Supplies · People**. People remains map-first. Local-first use remains available. Connection, Household membership, location sharing, arrival recipients and exact Home/Work visibility are separate choices. Privacy/revoke/stop-sharing/delete controls are never paywalled.

## Proven 0.10 baseline

0.10 Windows Flutter gate passed on its accepted source: analyze clean and 41/41 tests passed. The 0.10 governed backend deployment passed Node 22/project guards, Firestore emulator 13/13 and deployed 24 Functions/rules. Google Places uses the existing private `HOMI_PLACES_API_KEY` Dart define; never ask Bruce to paste it. A previously exposed development key must be rotated before production.

## Current candidate — 0.11.0+15

0.11 closes the S25 Ultra emergency-sheet overflow and implements the first **canonical shared Household identity**.

### Emergency UI

- Added `country_flags: 4.1.2` and `HomiCountryFlag` so supported emergency regions show bundled ISO flags rather than country-code placeholders.
- Emergency-region picker and onboarding selected-region card use flags.
- Full People-map emergency sheet is now scroll-controlled, SafeArea-aware and height-bounded to avoid the yellow/black bottom RenderFlex overflow above Android navigation.
- The flag library supports the broad ISO flag set, but Homi intentionally does **not** invent emergency numbers for every flag. Only source-reviewed emergency regions remain selectable.

### Canonical Household

Collections:

- `households/{householdId}`
- `households/{householdId}/members/{uid}`
- `householdMemberships/{uid}`
- `householdInvites/{householdId}_{inviteeUid}`

Rules/behavior:

- one canonical Household per account;
- up to four occupied/reserved seats;
- owner/member roles;
- invite requires an existing accepted trusted-person connection;
- invitee still explicitly accepts;
- create, rename, invite, accept/decline, cancel invite, remove member, leave, transfer ownership and eligible Household deletion implemented through App-Check-protected callables;
- direct client Household/membership/invite mutation denied by Firestore;
- member/invite reads are scope-limited;
- ownership-change trigger rebinds pending invite ownership to the current owner;
- Homi account deletion has Household cleanup/owner-transfer support;
- shared Household management is available from **Homi & account -> Household** and from profile settings;
- joining/creating does not delete or silently upload existing local Home/Routines/Supplies data.

Important boundary: 0.11 creates the real Household identity layer, but **full cross-device Home/Routines/Supplies synchronization and Google Play billing are not yet claimed complete**. Existing selected shared Tasks remain the older narrow collaboration path until the shared data-plane migration is implemented.

### Backend governance

- Functions export guard now expects **35** exports and deploys in batches of five.
- Functions lint includes `households.js` and `household_invite_owner_sync.js`.
- Firestore security harness now runs original + Household boundary suites serially.
- New Household unit test covers seat/role model.
- No new Firebase/GCP project or runtime identity.

Local static evidence available before Bruce's Windows run: new ownership-sync JS syntax and updated Firestore security shell helper syntax were checked successfully in Node/Bash. Full Flutter analyze/tests and Firestore emulator behavior are still intentionally unclaimed until the real toolchains run.

## Immediate validation — do this once

Bruce should run on Windows:

```powershell
cd C:\ConceptLab\Projects\homi
git pull --ff-only
flutter clean
flutter pub get
flutter analyze
flutter test
```

`country_flags` is new, so `flutter pub get` should update `pubspec.lock`. If analyze/tests are green, commit only the lockfile:

```powershell
git add pubspec.lock
git commit -m "Lock country flag dependencies"
git push
```

If anything fails, inspect the complete output and all likely related failures before asking Bruce to rerun.

After the lock commit, re-fetch exact `main` SHA before backend deployment. Then use the governed `scripts/deploy-notification-backend.sh` Cloud Shell path. It must prove Node 22, project `homi-ee80a` / `883068189841`, Functions lint, exactly 35 exports, both Firestore emulator suites, Firestore deploy and all Function batches before calling 0.11 backend accepted.

## S25 Ultra acceptance after backend PASS

Verify the emergency sheet has no overflow and can scroll to its final disclaimer; flags display in region UI; emergency actions still only open the dialer; Household page opens; create Household; invite/accept with a second trusted account; member/seat state updates; ownership transfer keeps pending invitations manageable; remove/leave does not alter location sharing; existing local Home/Tasks/Routines/Supplies stay intact; People/live/check-ins/Places remain healthy.

## Next major implementation after 0.11 acceptance

Build the shared Household **data plane** on the canonical `householdId`, with an explicit first-sync merge/conflict strategy for existing local data. Prioritize Tasks/Routines/Supplies/Home and supported activity/history. Then add a centralized capability/entitlement layer, followed by Google Play Billing, backend purchase verification, RTDN/Pub/Sub and Internal Testing lifecycle proof before paid enforcement.

Commercial contract remains: Personal R19.99/month, Duo R34.99/month, Household R49.99/month or R499.99/year; Household currently targets four members. Receiving location stays free; paid continuous senders may share to up to five trusted viewers. Do not activate paid entitlement based only on client purchase state.
