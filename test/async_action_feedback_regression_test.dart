import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slow app actions always expose visible progress', () {
    final controls =
        File('lib/src/widgets/homi_controls.dart').readAsStringSync();
    final people =
        File('lib/src/features/people/people_page.dart').readAsStringSync();
    final routines =
        File('lib/src/features/routines/routines_page.dart').readAsStringSync();
    final household = File(
      'lib/src/features/profile/household_settings_page.dart',
    ).readAsStringSync();
    final account =
        File('lib/src/features/profile/account_hub_page.dart').readAsStringSync();
    final profile = File(
      'lib/src/features/profile/profile_settings_page.dart',
    ).readAsStringSync();
    final safety = File(
      'lib/src/features/people/safety_check_in_page.dart',
    ).readAsStringSync();

    expect(
      controls,
      contains('class HomiActionLabel extends StatelessWidget'),
    );
    expect(
      controls,
      contains('class HomiBlockingProgressOverlay extends StatelessWidget'),
    );
    expect(people, contains('HomiActionLabel('));
    expect(routines, contains('_taskActionById[task.id]'));
    expect(routines, contains('_routineActionById[item.id]'));
    expect(household, contains('HomiBlockingProgressOverlay('));
    expect(account, contains('HomiBlockingProgressOverlay('));
    expect(profile, contains('HomiBlockingProgressOverlay('));
    expect(safety, contains('HomiBlockingProgressOverlay('));
  });
}
