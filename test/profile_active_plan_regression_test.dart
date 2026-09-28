import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile card shows only the server-authoritative active Homi plan', () {
    final page = File(
      'lib/src/features/profile/profile_settings_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains('HomiEntitlementService'),
      reason:
          'The profile plan label must come from the server-authoritative entitlement stream.',
    );
    expect(
      page,
      contains('final activePlan = entitlement.isPaid'),
      reason:
          'Expired paid records must not be presented as an active paid plan.',
    );
    expect(
      page,
      contains('_ActivePlanPill(label: activePlan)'),
      reason: 'The current plan belongs on the profile identity card.',
    );
  });
}
