# Homi — Release readiness

Date: 2026-09-28

Current accepted device baseline: **0.13.3+21**

Current source candidate: **0.13.4+22**

Build 21 accepted source before this pass:

```text
41ed58d6300c3a837bfc010a0d1fd34cc6bce669
```

Build 22 branch:

```text
homi-0.13.4-final-hardening
```

Status markers: **DONE**, **VERIFY**, **OPEN**, **BLOCKER**.

## 1. Build 21 acceptance

- **DONE** Google Play Internal Testing update installed successfully.
- **DONE** notification preferences now restore immediately instead of flashing a false disabled state.
- **DONE** real Homi push notifications are working again.
- **DONE** Homi Android notification channel/resource packaging issue repaired.
- **DONE** Homi notification settings no longer expose the unrequested transport-status card.
- **DONE** active Homi plan appears on the profile identity card.
- **DONE** final Build 21 analyzer and Flutter test gate passed before the release bundle was produced.

Build 21 is the current known-good installed baseline.

## 2. Build 22 purpose

Build 22 is a final hardening-only pass. It adds no new product features and does not redesign approved UI.

Source scope:

- **DONE in source / VERIFY device** prominent background-location disclosure before Live Location or Arrival Check-in permission flow;
- **DONE in source / VERIFY** durable Household pending-mutation journal across restart;
- **DONE in source / VERIFY** newer local Household edits cannot be falsely cleared merely because an older cloud document with the same ID exists;
- **DONE in source / VERIFY local Android host** explicit Android backup and device-transfer exclusions;
- **DONE in source** release documentation reconciled to the current Build 21/22 state;
- **DONE in source** Build 22 regression tests added;
- **VERIFY** final Windows analyzer/tests;
- **VERIFY** release AAB;
- **VERIFY** Play Internal Testing update over Build 21.

No Firebase Functions or Firestore Rules deployment is required for Build 22.

## 3. Android release-host contract

The Android host remains intentionally local/untracked.

Before every Build 22 release AAB, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\prepare_android_release.ps1
```

The script must confirm:

- Homi notification drawable exists;
- notification drawable is kept from release resource shrinking;
- Firebase default notification icon metadata exists;
- `android:allowBackup="false"`;
- Android 11-and-lower `fullBackupContent` points to Homi exclusion rules;
- Android 12+ `dataExtractionRules` points to Homi cloud-backup and device-transfer exclusion rules.

Homi local Household state, cached location/check-in state and device registration state are intentionally not migrated through Android backup/device transfer.

## 4. Authentication and account lifecycle

- **DONE** email/password sign-in;
- **DONE** Google sign-in;
- **DONE** email verification;
- **DONE** password reset;
- **DONE** provider-aware profile controls;
- **DONE** sign-out;
- **DONE** recent reauthentication before destructive account deletion;
- **DONE** server-side Homi account-data cleanup;
- **DONE** local-device erase is distinct from cloud account deletion;
- **DONE** account deletion explains that Google Play subscription cancellation is separate;
- **OPEN public launch** external account/data-deletion web page.

## 5. Firebase and security

- **DONE** sensitive mobile mutations use authenticated/App-Check-protected callable Functions.
- **DONE** Firestore rules fail closed outside reviewed per-user/Household/location surfaces.
- **DONE** verified-email boundary remains required for location/sharing capabilities.
- **DONE** Google Play subscription entitlement remains server-authoritative.
- **DONE** raw Google Play purchase state remains backend-only.
- **DONE** current callable/backend production surface is already deployed from the accepted billing/notification pass.
- **OPEN public launch** stage Firestore/App Check enforcement after validating known-good Play Integrity traffic.
- **OPEN public launch** confirm Cloud Billing budgets/alerts and operational monitoring.

## 6. Household/local-first data

- **DONE** local Household data persists independently of cloud availability.
- **DONE** canonical Household data plane remains nested beneath the authoritative Household.
- **DONE** legacy device-only records are not silently uploaded merely because a user joins another Household.
- **DONE in Build 22 source / VERIFY** pending shared-data upserts and deletes are journaled before Firestore submission.
- **DONE in Build 22 source / VERIFY** pending writes survive app restart and are protected from authoritative cloud replacement until the exact operation succeeds.
- **VERIFY when available** true second-physical-device propagation and conflict behavior.

## 7. People, location and check-ins

- **DONE** location sharing is opt-in and connection creation does not automatically start tracking.
- **DONE** background Live Location and Arrival Check-ins use a visible Android foreground-service notification.
- **DONE** saved Home/Work location sharing is separately controlled.
- **DONE** users can stop location sharing independently of billing.
- **DONE in Build 22 source / VERIFY Play review flow** prominent disclosure appears before background-location runtime permission.
- **VERIFY** store-installed reboot/background behavior under normal Samsung battery management.
- **BLOCKER public launch** Google Play background-location declaration and review video using the actual Build 22 disclosure/runtime-permission flow.
- **BLOCKER public launch** Privacy Policy must explicitly cover background location collection, use and sharing.

## 8. Notifications

- **DONE** device registration and FCM delivery repaired.
- **DONE** Build 21 creates Homi notification channels correctly.
- **DONE** notification resource survives release shrinking.
- **DONE** Homi notification preferences persist correctly across restart.
- **DONE** server delivery diagnostics remain internal.
- **VERIFY Build 22 regression** notification delivery remains unchanged after final hardening.

## 9. Homi+ billing

- **DONE** nine Google Play subscription products/base-plan contract established.
- **DONE** purchase verification is server-authoritative through Android Publisher.
- **DONE** RTDN refresh path exists.
- **DONE** subscription replacement and entitlement projection architecture exist.
- **DONE** account deletion strips Homi-side billing mappings/tokens without pretending to cancel Google Play.
- **DONE** current Play Internal Testing Personal purchase/renewal/base-plan switch path has been exercised.
- **OPEN** Duo seat lifecycle acceptance.
- **OPEN** Household coverage/member-capacity lifecycle acceptance.
- **OPEN** restore/reinstall/cancellation/grace/hold/expiry acceptance as required for launch confidence.
- **OPEN** final replacement-lineage and stale-token acceptance.
- **IMPORTANT** paid enforcement remains intentionally **OFF** until the lifecycle gate is accepted.
- **IMPORTANT** privacy exits, revoke/leave/erase/delete controls must remain available regardless of Homi+ state.

## 10. Public Google Play launch blockers

These are not reasons to keep changing the product UI.

- **BLOCKER** live Homi Privacy Policy URL;
- **BLOCKER** live Terms URL;
- **BLOCKER** external account/data deletion page;
- **BLOCKER** Google Play background-location declaration/video;
- **BLOCKER** Data Safety form;
- **OPEN** content rating, app access, target audience and ads declarations as applicable;
- **OPEN** final store listing assets/screenshots;
- **OPEN** staged App Check enforcement after valid release-client metrics;
- **OPEN** final Homi+ lifecycle acceptance and paid-enforcement decision;
- **OPEN** final Build 22 real-device regression.

## 11. Build 22 acceptance checklist

Build 22 may be called the final app-development candidate when all are true:

1. Android release-preparation script passes;
2. `flutter analyze` passes;
3. complete `flutter test` passes;
4. tracked source remains clean;
5. release AAB builds from the exact accepted SHA;
6. Build 22 installs as a Google Play Internal Testing update over Build 21;
7. existing local data remains intact;
8. notification preferences remain instant after restart;
9. developer/real notifications still arrive;
10. background-location disclosure appears before the Android permission flow;
11. declining disclosure leaves the feature off;
12. accepting disclosure continues into the normal Android permission flow;
13. disclosure acknowledgement is not repeatedly shown during normal later use;
14. Live Location can still be stopped cleanly;
15. Arrival Check-ins can still be stopped cleanly;
16. Household create/update/delete/local persistence shows no regression;
17. offline-to-online recovery shows no local data loss.

Once this checklist is green, further app changes should be driven by an observed defect or an explicit product decision, not additional speculative polishing.
