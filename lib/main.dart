import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  } catch (error) {
    firebaseError = error;
  }

  runApp(
    HomiApp(
      firebaseReady: firebaseReady,
      firebaseError: firebaseError,
    ),
  );
}
