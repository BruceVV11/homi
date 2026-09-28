import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Homi channels are created before icon-dependent plugin init', () {
    final service = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();

    final channelIndex = service.indexOf('await _createAndroidChannels();');
    final initIndex = service.indexOf('await _local.initialize(');

    expect(channelIndex, greaterThanOrEqualTo(0));
    expect(initIndex, greaterThan(channelIndex));
    expect(
      service,
      contains("throw StateError('Android local notification support is unavailable.')"),
    );
  });

  test('release preparation preserves the Homi notification icon', () {
    final script = File(
      'tool/prepare_android_notification_release.ps1',
    ).readAsStringSync();

    expect(script, contains('tools:keep="@drawable/homi_notification"'));
    expect(
      script,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
  });
}
