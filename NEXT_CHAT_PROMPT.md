# Homi - Next Chat Prompt

Continue development of **Homi** from the current GitHub `main` branch. Treat the repository as the source of truth and inspect the latest source plus `documentation/RELEASE_NOTES.md` before changing anything.

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

Homi is a local-first household operating system covering Overview, Routines, Home, Supplies and People. Account creation must remain optional for local-only use. Shared/cloud features should add sync/collaboration rather than gate basic value.

Trusted-person location is a first-class feature, but sharing must always be explicit, visible and reversible. Connecting or inviting someone must never automatically start tracking. Do not add hidden location collection or indefinite movement history by default.

All visible product copy should read as launch-ready Homi UI. Do not expose roadmap language such as `next pass`, `this build`, implementation foundations or messages addressed to the developer/user as a tester.

## Current implementation state after pass 0.3.0

The first real Android build already launched successfully on the Samsung S25 Ultra. The current local Gradle setup uses the verified project-specific JDK 21 / 4 GB heap configuration documented in the repo.

App version: `0.3.0+3`.

### Shell / navigation

- Persistent Homi logo remains top-left and account/profile control remains top-right across every primary page and horizontal swipe.
- Primary order is now **Overview, Routines, Home, Supplies, People**.
- Home is deliberately centred in the bottom navigation.
- The exact approved Homi mark is the Home icon.
- The bottom navigation uses a white custom-painted surface whose top edge rises into the currently selected circular destination, based on the user's approved reference direction rather than the older detached-bubble design.
- Android Back from a secondary primary destination returns to Overview before root exit behavior.

### Overview / Quick Reset

- The old user-facing `Today` navigation label is now `Overview`; the implementation file remains `today_page.dart` for source continuity.
- Placeholder/fake attention data has been removed. Overview shows real incomplete Routines, supply attention and Quick Add reminders only.
- `What needs attention` is the main status section.
- `Quick add` stores a lightweight local reminder.
- `When you have time` is now a functional **Quick Reset** planner.
- The user chooses 10 or 30 minutes. Homi prioritises incomplete saved Routines that fit the time budget using each Routine's estimated duration, then may fill spare time with simple built-in household suggestions.
- Completing a saved Routine in Quick Reset updates the persisted Routine. Built-in suggestions are session-only.
- A `How it works` sheet explains this directly to the user.

### Routines

- Routine model contains UUID, title, category, frequency, estimated minutes, completion state and last-completed time.
- Existing pre-0.3 routines safely default to 10 estimated minutes.
- Routine creation includes a `Usually takes` selector.
- The bottom of Routines now shows tappable real-world examples such as Feed the pets, Take the bins out, Change bed linen and Water indoor plants. Tapping pre-fills the editor.
- Current frequency values are descriptive/manual (`Daily`, `Weekly`, etc.). **They do not yet auto-roll into a due-date engine or automatically reopen themselves when the period changes. Do not imply that recurring scheduling is complete.**

### Supplies

- Supply cards use a small status dot + text rather than rounded status pills.
- Normal stock state is `In stock`; expiry attention is `Use soon`.
- An in-stock item becomes `Use soon` when within 3 days of its expiry date and `Expired` after the date passes.
- Manual `Running low` / `Need to buy` status takes precedence.
- Overview and Supply summary counts use the same expiry-aware logic.
- The first 0.3.0 Android compile attempt exposed a Dart scope error in the Supply card menu: `_editableStatuses` was declared as a static member of `SuppliesPage` but referenced unqualified inside `_SupplyCard`. This has been corrected to `SuppliesPage._editableStatuses`; the device build must be retried before 0.3.0 is called compiled successfully.

### Account / profile

- Clicking the persistent profile control opens an account sheet.
- Signed-in users see their name/email, verification status and provider identity.
- Google-authenticated users show a Google provider mark next to the name to make their sign-in method recognisable.
- Profile settings supports changing Firebase display name, seeing email/sign-in method/verification status, resending verification for email-password accounts, refreshing verification state and requesting a password reset where applicable.
- Google-only accounts should not be shown password controls.
- Firebase profile image is used when available.
- Basic local use remains possible without signing in.

### People / location

- People keeps the compact opt-in location disclosure instead of a large privacy lecture.
- Visible privacy wording is launch-ready: location sharing is opt-in, connecting with someone does not turn sharing on, current-location features use the latest location/battery state, and location history is not retained by default.
- Current foreground/manual location + battery capture and private latest-snapshot Firestore sync remain in place.
- Trusted-person invitations / mutual sharing UI is not yet implemented.

## Required verification before calling 0.3.0 complete

On the local machine:

```powershell
cd C:\ConceptLab\Projects\homi
git pull
flutter analyze
flutter test
```

Then run Homi from Android Studio on the Samsung S25 Ultra. Verify:

- the Supplies compile-scope hotfix is present and the Android build gets past `compileFlutterBuildDebug`;
- shaped bottom-nav mound in every selected state, especially centred Homi Home;
- Overview wording and empty/populated attention states;
- 10- and 30-minute Quick Reset generation and completion behavior;
- Routine creation with estimated duration, real example prefill and persistence after restart;
- expiry-driven Supply status and status-line styling;
- Google and email/password account sheets, Google provider indicator, verification state and Profile settings;
- persistent header, horizontal swipe, Android Back and three-button/gesture safe areas;
- local-only use and People current-location capture.

Do not claim 0.3.0 compiled/analyzed/tested successfully until these local checks are actually run.

## Suggested priorities after the 0.3.0 device review

1. Fix visual/device regressions from the 0.3.0 screenshots first, especially the custom nav shape, vertical alignment and Home mark treatment.
2. Expand **Home** into real local-first Things/appliances, maintenance records, repair history and utility meter readings instead of category-only cards.
3. Turn Routine frequency from descriptive metadata into a real recurrence/due-date model so completed daily/weekly/monthly routines become due again correctly without losing history.
4. Feed genuinely due Home maintenance items into Overview and Quick Reset once that domain exists; do not fake due data.
5. Design the first safe **Trusted people invite/share workflow** with explicit invite acceptance, separate location-sharing consent, active-share state and revoke controls. Keep continuous/background location separate from simple connection/invitation.
6. Connect Routines/Supplies/Home records to shared Firestore household state only after a clear local-vs-cloud merge/conflict strategy is documented and tested.
7. If the current hosted Google provider icon causes an offline/branding issue during device review, replace it with a bundled official Google provider asset rather than drawing an approximation.
8. Continue updating `documentation/RELEASE_NOTES.md`, architecture docs, tests and this top-level `NEXT_CHAT_PROMPT.md` in every pass.

Use the mobile-app-development workflow, preserve the approved visual language, and make the smallest coherent implementation pass rather than replacing the working architecture.
