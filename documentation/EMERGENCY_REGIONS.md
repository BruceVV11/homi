# Homi emergency regions

Date: 2026-09-11
Applies from source line: `0.10.0+14`

## Product rule

Emergency-number shortcuts must work without Firebase, without mobile data and without granting location permission. Homi therefore bundles its emergency-region catalog inside the application binary.

The user chooses an **Emergency region** during onboarding. Homi may preselect a supported country from the device locale, but the user remains in control and can change the region later.

Homi must never silently replace an emergency region based on a single GPS/geocoder result.

## Safety behavior

- Homi opens the system phone app through `tel:` with the selected number ready.
- Homi does not silently place emergency calls.
- Homi does not dispatch responders.
- Homi does not claim that a call has connected or been received.
- Tapping an emergency number does not automatically transmit the Homi user's location.
- Regions with no safe single universal number must show the service-specific numbers rather than inventing an `SOS` fallback.
- Unsupported regions must fail closed and ask the user to choose a supported region; South Africa must never be used as a global fallback.

## Data governance

The global reference baseline is ITU-T E.129, which contains national important numbers reported by Member States. Where available, Homi should additionally review a country's official emergency-service, regulator or government source.

The bundled catalog is source-controlled so a release can be audited and emergency functionality remains available offline. It is not a promise that every service is reachable from every network or location.

**Before Homi is distributed in a country, that country's bundled entry must be reviewed for the release candidate.** A country not yet reviewed for store rollout must not be marketed as verified merely because a draft/baseline entry exists in source.

## 0.10.0 catalog foundation

The first coded catalog includes South Africa plus a broad initial set of major launch/travel regions, including the United States, Canada, United Kingdom, Australia, New Zealand, the EU 112 area and selected countries in Africa, Asia, the Middle East and Latin America.

The architecture is deliberately extensible to all countries, but public worldwide coverage remains a release-data verification task rather than an assumption.

Important special cases represented in source include:

- **South Africa:** 112 mobile emergency, 10111 police, 10177 ambulance;
- **Australia:** `000` is stored as a string so the leading zeros cannot be lost; 112 is listed as a mobile alternate;
- **European Union:** 112 universal emergency baseline;
- **Japan:** 110 police and 119 ambulance/fire; Homi does not invent a universal SOS number;
- **South Korea:** 112 police and 119 ambulance/fire;
- **Brazil:** 190 police, 192 ambulance and 193 fire; no invented universal SOS number.

## Travel behavior

A later refinement may offer a non-blocking prompt when Homi has reliable evidence that the user is in another country. Any such prompt must require user confirmation before changing the saved Emergency region and must not require location permission merely to use emergency-number settings.
