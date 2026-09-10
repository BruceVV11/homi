# Homi pricing and unit economics

Date: 2026-09-10
Status: product recommendation for launch planning; billing is not enabled in the app yet.

## Recommended launch structure

Keep launch simple: **Free + Homi+**. Do not begin with three or four paid tiers.

### Homi Free — R0

The free version must be genuinely useful on one phone and must never make privacy controls a paid feature.

Include:

- local-first Tasks and Routines;
- local Supplies and expiry/quantity tracking;
- local Home Things, maintenance/repair history and utility readings;
- Overview / Quick Reset;
- account creation remains optional for local use;
- trusted-person connections;
- basic consensual location sharing and the ability to stop sharing;
- account deletion, data controls, privacy/legal information;
- no ads inside sensitive household/location surfaces at launch.

### Homi+ — recommended launch price

**R49.99 / month** or **R499.99 / year** for one household subscription.

Target household allowance: up to **6 household members**. Location-only friends should not consume a paid household seat merely because they are trusted location connections.

Homi+ should earn its price through cloud convenience and shared-home value rather than by withholding basic privacy or safety controls.

Initial Homi+ direction:

- full household cloud sync across devices for Tasks, Routines, Supplies and Home records once that sync layer is implemented;
- shared household activity / completion attribution across phones;
- multiple-device restore/continuity;
- richer Places and arrival/departure alerts when implemented;
- limited recent location history only if introduced with explicit retention controls;
- enhanced home-document organisation / Google Drive integration when implemented;
- future household automation and advanced insights.

Do **not** advertise a paid feature until it actually works in the release build.

## Why this price

Homi sits between lightweight household organisers and dedicated family-location products.

Public competitor reference points checked in September 2026:

- Tody: core single-person plan free; Premium $9.99/year; Premium+ household sync starts at $25/year for two people and $40/year for a six-person family. Source: https://todyapp.com/faq
- Life360: free tier plus Silver at $9.99/month, Gold at $16.99/month and Platinum at $24.99/month in its US offer. Those upper plans include services Homi does not currently provide, such as crash/emergency/roadside features. Source: https://www.life360.com/plans-pricing

R49.99/month positions Homi above a simple chore list but materially below a mature safety-service subscription. The R499.99 annual price gives the user a clear reason to pay annually without forcing an aggressive first-launch price.

Revisit pricing only after measuring real retention and feature usage. Do not increase complexity just to create additional tiers.

## How Android payments should work

For the first Google Play release, use **Google Play Billing** for Homi+ because Homi+ is a digital subscription that unlocks app/cloud functionality.

Google Play policy currently requires Play Billing for Play-distributed apps selling in-app digital functionality unless a specific exception/program applies. Source: https://support.google.com/googleplay/android-developer/answer/9858738

Current Google Play service-fee guidance says auto-renewing subscriptions in remaining markets use a 15% service fee while the newer global structure rolls out. Source: https://support.google.com/googleplay/android-developer/answer/112622

For South African Play Billing purchases, Google states that it determines, charges and remits South African VAT on the customer transaction. A South African developer may still have local VAT applied to Google's service fee. Source: https://support.google.com/googleplay/android-developer/answer/138000

Do not implement external card collection in the Android app as the first billing path. Alternative billing programs add policy, tax, support and reconciliation complexity that Homi does not need at launch.

### Billing implementation direction

When the product is ready for monetisation:

1. Create Homi+ monthly and annual subscription products in Play Console.
2. Integrate Google Play Billing through a maintained Flutter billing package.
3. Store entitlement state server-side as well as locally so reinstall/device changes do not lose access.
4. Verify purchase tokens server-side rather than trusting only a client flag.
5. Support purchase restore, grace period, pause, cancellation and expiry states.
6. Keep account deletion separate from subscription cancellation and explain both clearly.
7. Add an Account > Plans & billing surface only when the real products exist.

## Current cloud economics

The screenshots from 2026-09-10 show approximately:

- Firebase/Google Cloud project cost: **$0.00**;
- Firestore writes: **41**;
- Firestore reads: **5**;
- Firestore deletes: **0**;
- Cloud Firestore API requests: **37** over the selected 14-day view;
- Maps SDK for Android requests: **18**;
- Firebase App Check API calls showed errors in the development environment.

This very low Firestore usage is expected. Homi is still **local-first** for most household records. Routines, Supplies, Home records and most local Tasks are currently in SharedPreferences. Firestore currently carries only the cloud features that genuinely need it: account identity metadata, trusted connections/preferences, selected shared Tasks, location-share authorization and the latest shared location/battery snapshot.

Therefore the present usage **cannot** be used as a cost-per-production-household benchmark. The app has not yet implemented full household sync.

## Firestore free tier and scale

Firebase currently documents a Standard-edition free quota of:

- 50,000 document reads/day;
- 20,000 document writes/day;
- 20,000 document deletes/day;
- 1 GiB stored data;
- 10 GiB outbound data/month.

Source: https://firebase.google.com/docs/firestore/pricing

Firestore Standard charges by documents read/written/deleted plus storage/network use after the free quota. Real-time listeners count as document reads when documents are added or updated in their result set. Source: https://firebase.google.com/docs/firestore/standard-edition

### Location fan-out matters more than the single write

The current location design writes one latest-state document per sharing user. A location update is therefore roughly one Firestore document write. Each authorised real-time listener that receives that changed document creates read activity.

Example conceptually: if one person updates location and three trusted people are actively listening, the update has one write but can produce multiple reads. This fan-out matters more at scale than the tiny development usage shown today.

Homi should continue to reduce unnecessary location writes through movement thresholds, sensible intervals and foreground/background lifecycle discipline. Do not reduce privacy or freshness disclosure merely to save database reads.

## Other platform cost notes

### Firebase Authentication

Firebase Authentication on Blaze currently includes a no-cost tier up to 50,000 monthly active users for email/social/anonymous/custom providers before MAU charges apply. Source: https://firebase.google.com/docs/auth

### Google Maps

Google's current Maps pricing list shows the mobile **Maps SDK** SKU with unlimited free usage. Other Maps/Places/Routes SKUs can have separate free caps and paid pricing. Source: https://developers.google.com/maps/billing-and-pricing/pricing

Homi should not assume future Places/geocoding/route features are free merely because basic map display is currently a no-cost SKU.

## Business guardrails

- Put a Google Cloud billing budget and alert on `homi-ee80a` before public launch.
- Add non-sensitive operational metrics for operation counts/feature use; never put coordinates, addresses or household text into analytics.
- Measure Homi+ conversion and retention before adding more tiers.
- Keep location consent, stop-sharing, account deletion and privacy controls free.
- Do not claim emergency/safety guarantees in order to justify a higher price.
- A household subscription should cover the household, not charge every family member individually.
- Friends used only for consensual location check-ins should not become accidental paid seats.

## Next commercial milestone

Do not add Play Billing yet. First complete and prove:

1. household identity/membership;
2. safe cloud merge/sync for shared household state;
3. location reliability and Places scope;
4. account/data deletion end-to-end;
5. privacy/terms review;
6. release-quality retention/cost assumptions.

Once those are stable, implement Homi+ against actual working premium value rather than a placeholder paywall.
