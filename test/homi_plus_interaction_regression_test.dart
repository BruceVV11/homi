import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Homi+ purchase UX keeps explicit current, covered and loading states', () {
    final page = File(
      'lib/src/features/profile/homi_plus_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains('_HomiPlusPurchaseOverlay'),
      reason: 'Purchases must show a branded blocking progress state.',
    );
    expect(
      page,
      contains('activeOwnedPlan &&'),
      reason: 'The current active plan must not be offered again below.',
    );
    expect(
      page,
      contains('_CoveredSeatCard'),
      reason:
          'Duo/Household recipients need a covered-seat state instead of purchase CTAs.',
    );
    expect(
      page,
      contains('Manage or cancel in Google Play'),
      reason: 'Cancellation must be visible from the Homi+ surface.',
    );
    expect(
      page,
      contains('Switch to annual'),
      reason: 'Monthly subscribers need an in-app annual switch path.',
    );
    expect(
      page,
      contains('Switch to monthly'),
      reason: 'Annual subscribers need an in-app monthly switch path.',
    );
    expect(
      page,
      contains('Icons.person_outline_rounded'),
      reason: 'Personal should have its own plan icon.',
    );
    expect(
      page,
      contains('Icons.people_alt_outlined'),
      reason: 'Duo should have its own plan icon.',
    );
    expect(
      page,
      contains('Icons.home_work_outlined'),
      reason: 'Household should have its own plan icon.',
    );
  });
}
