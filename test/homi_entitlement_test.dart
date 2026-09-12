import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/homi_billing_catalog.dart';
import 'package:homi/src/domain/homi_entitlement.dart';
import 'package:homi/src/domain/homi_plus_plan.dart';
import 'package:homi/src/services/homi_billing_service.dart';

void main() {
  test('missing entitlement fails closed to Homi Free', () {
    final entitlement = HomiEntitlement.fromMap(null);

    expect(entitlement.plan, HomiPlusPlan.free);
    expect(entitlement.canSendContinuousLocation, isFalse);
    expect(entitlement.canUseSharedHousehold, isFalse);
    expect(entitlement.maxTrustedLiveViewers, 0);
  });

  test('only active or grace-period paid state grants capabilities', () {
    final active = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'active',
      'continuousLocationSender': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 5,
      'householdMemberLimit': 4,
    });
    final held = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'on_hold',
      'continuousLocationSender': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 5,
      'householdMemberLimit': 4,
    });

    expect(active.canSendContinuousLocation, isTrue);
    expect(active.canUseSharedHousehold, isTrue);
    expect(held.canSendContinuousLocation, isFalse);
    expect(held.canUseSharedHousehold, isFalse);
  });

  test('Play catalog is intentionally disabled until durable IDs are verified', () {
    expect(HomiPlayBillingCatalog.unconfigured.configured, isFalse);
    expect(HomiPlayBillingCatalog.unconfigured.productIds, isEmpty);
  });

  test('obfuscated billing account id is stable and does not expose the uid', () {
    const uid = 'firebase-user-123';
    final first = HomiBillingService.obfuscatedAccountId(uid);
    final second = HomiBillingService.obfuscatedAccountId(uid);

    expect(first, second);
    expect(first.length, 64);
    expect(first, isNot(contains(uid)));
  });
}
