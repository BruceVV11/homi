import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'src/app.dart';
import 'src/services/emergency_region_service.dart';
import 'src/services/notification_service.dart';

const _defaultSentryDsn = 'https://20524d809d18b5444261c3d244dd93f8@o4512176028581888.ingest.de.sentry.io/4512177509105744';
const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: _defaultSentryDsn,
);
const _sentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: kReleaseMode ? 'production' : 'development',
);
const _sentrySmokeTest = bool.fromEnvironment('SENTRY_SMOKE_TEST');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_sentryDsn.isEmpty) {
    await _bootstrapHomi();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = _sentryEnvironment;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.1;
    },
    appRunner: _bootstrapHomi,
  );
}

Future<void> _bootstrapHomi() async {
  // Emergency numbers are an offline safety preference and must remain
  // available even when Firebase cannot initialize.
  await EmergencyRegionService.instance.initialize();

  var firebaseReady = false;
  Object? firebaseError;

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      homiFirebaseMessagingBackgroundHandler,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    firebaseReady = true;
  } catch (error, stackTrace) {
    firebaseError = error;
    if (_sentryDsn.isNotEmpty) {
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  if (_sentrySmokeTest && _sentryDsn.isNotEmpty) {
    await Sentry.captureException(
      StateError('Concept Lab Sentry smoke test'),
    );
  }

  runApp(
    HomiApp(
      firebaseReady: firebaseReady,
      firebaseError: firebaseError,
    ),
  );
}
