# Homi public-launch compliance

Date: 2026-09-29

Accepted app baseline: **Homi 0.13.4+22**

Accepted Build 22 source:

```text
535dcf46606e0fea4642ad7fcc2863a4f3af5696
```

Build 22 has passed Google Play Internal Testing device acceptance, including data persistence, notification delivery, background-location disclosure, Live Location / Arrival Check-ins, offline Household recovery, Maps, authentication, reboot persistence and general UI regression.

## Public legal site

The repository now contains a static Firebase Hosting site under `hosting/`.

Planned default URLs after deployment to project `homi-ee80a`:

- Home: `https://homi-ee80a.web.app/`
- Privacy: `https://homi-ee80a.web.app/privacy/`
- Terms: `https://homi-ee80a.web.app/terms/`
- External account deletion: `https://homi-ee80a.web.app/delete-account/`

A custom domain can be added later without changing the source content.

The public pages intentionally contain no analytics, advertising or cookies.

## Account deletion

Homi supports:

1. direct in-app deletion from **Homi & account → Delete Homi account**;
2. external deletion requests from the public deletion page.

The external page routes a request through the Concept Lab contact form and instructs the requester to provide the Homi account email but never a password or payment information.

Google Play Homi+ subscription cancellation remains separate from Homi account deletion.

## Google Play fields after the site is live

Use the live URLs above for:

- Store listing / App content privacy policy URL;
- Data safety account-deletion web resource;
- any Play review field that requests the app privacy-policy resource.

## Background-location declaration

Homi Build 22 contains `ACCESS_BACKGROUND_LOCATION` and the accepted prominent disclosure.

The Play declaration should use **one** background-location feature only, as required by Google Play. The strongest Homi candidate is **Arrival Check-ins** because it requires detecting a Home/Work arrival while Homi is not in use and provides an explicit user-facing check-in result.

The review video should be 30 seconds or shorter where possible and show:

1. opening Homi;
2. navigating to **People → Safety & check-ins**;
3. attempting to enable Arrival Check-ins;
4. the Homi prominent disclosure;
5. accepting the disclosure;
6. the Android background-location permission/settings flow;
7. Arrival Check-ins enabled in Homi;
8. the visible Android foreground-service notification / active background behaviour where practical.

Do not declare both Live Location and Arrival Check-ins in the Play declaration form; Google asks for one representative background-location feature.

## Remaining public-launch work

- deploy and verify the legal Firebase Hosting site;
- add the live privacy policy URL to Homi in-app navigation if required for the final background-location review;
- complete Play background-location declaration and review video;
- complete Data Safety;
- complete App content declarations;
- complete store listing assets/screenshots;
- stage App Check enforcement after valid Play Integrity traffic is confirmed;
- finish Homi+ lifecycle acceptance before enabling paid enforcement;
- confirm Cloud Billing budgets/alerts and operational monitoring.

No Firebase Functions or Firestore Rules change is part of the legal-site deployment.
