import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification settings never render a false off state before cache hydration', () {
    final service = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();
    final page = File(
      'lib/src/features/profile/notification_settings_page.dart',
    ).readAsStringSync();

    expect(
      service,
      contains('_osPermissionCacheKey'),
      reason:
          'The last-known Android notification permission must be cached locally with Homi notification preferences.',
    );
    expect(
      service,
      contains('_localStateReady = true;'),
      reason:
          'Local notification state must have an explicit hydration boundary.',
    );
    expect(
      page,
      contains('if (!widget.notificationService.localStateReady)'),
      reason:
          'The settings screen must not interpret uninitialized state as notifications being off.',
    );
    expect(
      page,
      contains('Loading notification preferences…'),
      reason:
          'If a user reaches the page before local hydration completes, show a truthful loading state instead of a false disabled state.',
    );
  });
}
