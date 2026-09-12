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

  test('active grace and unexpired canceled states keep capabilities', () {
    final active = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'active',
      'continuousLocationSender': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 5,
      'householdMemberLimit': 4,
    });
    final canceled = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'canceled',
      'validUntil': '2099-01-01T00:00:00Z',
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
    expect(canceled.canSendContinuousLocation, isTrue);
    expect(canceled.canUseSharedHousehold, isTrue);
    expect(held.canSendContinuousLocation, isFalse);
    expect(held.canUseSharedHousehold, isFalse);
  });

  test('stale canceled paid term fails closed even before RTDN refresh', () {
    final entitlement = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'canceled',
      'validUntil': '2020-01-01T00:00:00Z',
      'continuousLocationSender': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 5,
      'householdMemberLimit': 4,
    });

    expect(entitlement.state, HomiBillingState.expired);
    expect(entitlement.canSendContinuousLocation, isFalse);
    expect(entitlement.canUseSharedHousehold, isFalse);
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
