import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('background location disclosure precedes background permission flows', () {
    final disclosure = File(
      'lib/src/widgets/homi_background_location_disclosure.dart',
    ).readAsStringSync();
    final people = File(
      'lib/src/features/people/people_page.dart',
    ).readAsStringSync();
    final checkIns = File(
      'lib/src/features/people/safety_check_in_page.dart',
    ).readAsStringSync();

    expect(
      disclosure,
      contains(
        'Homi collects location data to keep Live Location sharing and Home or Work arrival check-ins working even when Homi is closed or not in use.',
      ),
    );
    expect(
      disclosure,
      contains('_backgroundLocationDisclosureKey'),
      reason: 'Accepted disclosure should not interrupt the user every launch.',
    );

    final liveDisclosure =
        people.indexOf('showHomiBackgroundLocationDisclosure(context)');
    final livePermission =
        people.indexOf('await widget.locationService.startContinuousSharing();');
    expect(liveDisclosure, greaterThanOrEqualTo(0));
    expect(livePermission, greaterThan(liveDisclosure));

    final checkInToggle = checkIns.indexOf(
      'Future<void> _toggleCheckIns(bool value) async {',
    );
    final checkInDisclosure = checkIns.indexOf(
      'showHomiBackgroundLocationDisclosure(context)',
      checkInToggle,
    );
    final checkInPermission = checkIns.indexOf(
      'await widget.checkInService.setEnabled(value);',
      checkInToggle,
    );
    expect(checkInToggle, greaterThanOrEqualTo(0));
    expect(checkInDisclosure, greaterThan(checkInToggle));
    expect(checkInPermission, greaterThan(checkInDisclosure));
  });

  test('Household cloud mutations remain durable until exact write success', () {
    final service = File(
      'lib/src/services/household_data_sync_service.dart',
    ).readAsStringSync();

    expect(
      service,
      contains(r'homi.householdSync.pending.v$_pendingJournalVersion.$uid.$householdId'),
      reason:
          'Pending Household mutations must survive process death and remain scoped to the signed-in user and Household.',
    );
    expect(
      service,
      contains('await _replacePendingMutation(user.uid, household.id, pending);'),
      reason: 'Journal the local intent before attempting the cloud write.',
    );
    expect(
      service,
      contains('await _clearPendingMutationIfCurrent(uid, householdId, pending);'),
      reason:
          'Only the exact successful mutation may clear its durable journal entry.',
    );
    expect(
      service,
      contains('..._pendingUpserts[domain]!,'),
      reason:
          'Pending upserts must be preserved when authoritative cloud snapshots are applied.',
    );
    expect(
      service,
      isNot(contains('_pendingUpserts[domain]!.removeAll(cloudIds);')),
      reason:
          'Seeing an item ID in a cloud snapshot is not proof that the latest local payload synced.',
    );
    expect(
      service,
      isNot(contains('deleted.removeWhere((id) => !cloudIds.contains(id));')),
      reason:
          'Pending deletes must clear only after the exact delete succeeds.',
    );

    final controller = File(
      'lib/src/state/homi_app_controller.dart',
    ).readAsStringSync();
    expect(
      controller,
      contains("key.startsWith('homi.householdSync.')"),
      reason:
          'Erase-this-phone/account deletion must also remove pending sync payloads and Household sync metadata.',
    );
  });

  test('Android release preparation opts device-local Homi state out of backup', () {
    final script = File(
      'tool/prepare_android_release.ps1',
    ).readAsStringSync();

    expect(script, contains('-Name "allowBackup" -Value "false"'));
    expect(
      script,
      contains('-Name "fullBackupContent" -Value "@xml/backup_rules"'),
    );
    expect(
      script,
      contains(
        '-Name "dataExtractionRules" -Value "@xml/data_extraction_rules"',
      ),
    );
    expect(script, contains('<exclude domain="sharedpref" path="." />'));
    expect(script, contains('<device-transfer>'));
    expect(script, contains('tools:keep="@drawable/homi_notification"'));
  });
}
