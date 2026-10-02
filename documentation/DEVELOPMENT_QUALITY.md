# Homi development quality layer

## FVM

Homi is pinned to Flutter 3.41.5, matching the toolchain already documented by the project.

Use:

```text
task setup
task check
task run
```

Android Studio should point to:

```text
<project>/.fvm/flutter_sdk
```

## Maestro

The first Maestro flow is deliberately non-destructive. It proves the installed Homi package can be launched through the device automation layer.

Run:

```text
task maestro
```

Add user-journey flows only after stable visible labels/test IDs are confirmed. High-value next flows are authentication, notification preference persistence, household connection and back-navigation regression.

## Sentry

Sentry is wired but disabled unless a DSN is supplied.

Development example:

```text
fvm flutter run --dart-define=SENTRY_DSN=<dsn> --dart-define=SENTRY_ENVIRONMENT=development
```

Release builds should use `SENTRY_ENVIRONMENT=production` through the governed release process.

No Sentry auth token belongs in the app. The DSN is only the SDK ingest endpoint identifier.

Sentry captures uncaught Flutter/native failures automatically. Homi also explicitly reports caught Firebase bootstrap failures when Sentry is enabled.

For agent/MCP diagnosis, use Sentry's API/MCP from the server/tooling side with a separately governed read-only credential; never place that credential in the mobile app.
