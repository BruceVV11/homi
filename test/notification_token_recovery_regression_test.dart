import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification registration self-heals a stale FCM token', () {
    final client = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();
    final backend =
        File('functions/device_registration.js').readAsStringSync();

    expect(
      backend,
      contains('await messaging.send('),
      reason:
          'The backend must validate an FCM token before persisting it as a usable device registration.',
    );
    expect(
      backend,
      contains('true,'),
      reason:
          'FCM registration validation must be dry-run only and must not send a visible notification.',
    );
    expect(
      backend,
      contains('messaging/registration-token-not-registered'),
    );
    expect(
      client,
      contains('await messaging.deleteToken();'),
      reason:
          'A token explicitly rejected by FCM must be replaced by the client SDK.',
    );
    expect(
      client,
      contains('final replacementToken = await messaging.getToken();'),
    );
    expect(
      client,
      contains('await _registerPushToken(deviceId, replacementToken);'),
    );
  });
}
