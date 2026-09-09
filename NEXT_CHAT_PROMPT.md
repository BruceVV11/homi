# Homi - Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat the repository as the source of truth and inspect the latest source and `documentation/RELEASE_NOTES.md` before changing anything.

## Permanent project context

- Local Windows project root: `C:\ConceptLab\Projects\homi`
- GitHub: `BruceVV11/homi`
- Android application ID: `za.co.theconceptlab.homi`
- Firebase / Google Cloud project: `homi-ee80a`
- Firebase project number: `883068189841`
- Firestore region: `africa-south1`
- Flutter: 3.41.5 stable
- Approved brand: coral `#FF6B5E`, peach `#FFB08A`, sage `#A7B89F`, cream `#FFF8F2`, slate `#2E2E2E`, Nunito typography.
- Exact Homi logo / mark assets already exist under `assets/brand/`. Never redraw or approximate them with framework shapes.

## Product direction

Homi is a local-first household operating system covering Today, Home, Routines, Supplies and People. Account creation must remain optional for local-only use. Shared/cloud features should add sync/collaboration rather than gate basic value.

Trusted-person location is a first-class feature, but sharing must always be explicit, visible and reversible. Inviting someone must never automatically start tracking. Do not add hidden location collection or indefinite movement history by default.

## Current implementation state after pass 0.2.0

The first real Android device build has already launched successfully on the Samsung S25 Ultra after the Gradle daemon configuration was corrected to a verified 4 GB heap on JDK 21.

Pass 0.2.0 changes the application shell and begins real local household functionality:

- The Homi logo now lives only in a persistent top-left shell header, with the account/profile control aligned top-right.
- That shell header remains in place while changing or horizontally swiping between the five primary pages.
- The Today greeting now begins below the persistent header.
- Page scrolling was tightened so short pages do not expose the old large dead-space tail.
- The bottom navigation is now a custom raised-bubble design rather than the stock Material NavigationBar.
- The exact Homi mark is used as the **Home** destination icon with the Home label retained.
- Routines now support local add, completion toggle and removal, with category/frequency metadata persisted through SharedPreferences.
- Supplies now support local add, status changes, optional expiry date and removal, persisted through SharedPreferences.
- Today surfaces real routine/supply attention counts when the user has created those records.
- The People page no longer starts with a large location lecture. A compact opt-in disclosure opens a fuller privacy/location bottom sheet instead.
- Current location/battery capture and private latest-snapshot Firestore sync remain intact.
- App version is `0.2.0+2`.

## Required verification before calling 0.2.0 complete

On the local machine, pull `main`, then run:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

Then run Homi on the Samsung S25 Ultra from Android Studio. Verify:

- persistent logo/profile header across every tab and during horizontal swipes;
- no duplicate logo on Today;
- no artificial blank scroll tail on short pages;
- custom bottom-nav animation and Homi Home icon sizing;
- Android Back from secondary primary destinations returns to Today before exiting;
- add/complete/remove Routine survives app restart;
- add/status/remove Supply and optional expiry date survive app restart;
- People location disclosure modal, permission flow and location/battery capture;
- local-only and signed-in states;
- gesture navigation / three-button safe-area behavior where practical.

Do not claim this pass compiled successfully until those local checks are actually run.

## Suggested next functional priorities after the 0.2.0 device review

1. Fix any visual/device regressions found from 0.2.0 screenshots first.
2. Expand **Home** into real local-first Things / appliances, maintenance records, repair history and utility meter readings rather than placeholder category cards.
3. Build the first safe **Trusted people invite/share workflow** only after defining explicit per-person sharing consent, active-share state and revoke behavior. Keep continuous/background location separate from simple invitation.
4. Connect Routines/Supplies/Home records to shared Firestore household state only after a clear local-vs-cloud merge strategy is documented and tested.
5. Continue updating `documentation/RELEASE_NOTES.md`, architecture docs, tests and this top-level `NEXT_CHAT_PROMPT.md` in every pass.

Use the mobile-app-development workflow, preserve the approved visual language, and make the smallest coherent implementation pass rather than replacing the working architecture.
