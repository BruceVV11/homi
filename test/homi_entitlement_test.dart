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
    expect(entitlement.canCreateSharedTasks, isFalse);
    expect(entitlement.canCreateSharedRoutines, isFalse);
    expect(entitlement.canUseSharedHousehold, isFalse);
    expect(entitlement.maxTrustedLiveViewers, 0);
  });

  test('active paid state exposes projected capabilities', () {
    final personal = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'personal',
      'state': 'active',
      'validUntil': '2099-01-01T00:00:00Z',
      'continuousLocationSender': true,
      'sharedTasks': true,
      'sharedRoutines': true,
      'sharedHousehold': false,
      'maxTrustedLiveViewers': 3,
      'householdMemberLimit': 0,
    });
    final household = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'active',
      'validUntil': '2099-01-01T00:00:00Z',
      'continuousLocationSender': true,
      'sharedTasks': true,
      'sharedRoutines': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 3,
      'householdMemberLimit': 6,
    });

    expect(personal.canCreateSharedTasks, isTrue);
    expect(personal.canCreateSharedRoutines, isTrue);
    expect(personal.canUseSharedHousehold, isFalse);
    expect(personal.maxTrustedLiveViewers, 3);

    expect(household.canUseSharedHousehold, isTrue);
    expect(household.householdMemberLimit, 6);
  });

  test('paid term fails closed after its verified expiry', () {
    final entitlement = HomiEntitlement.fromMap(<String, dynamic>{
      'plan': 'household',
      'state': 'canceled',
      'validUntil': '2020-01-01T00:00:00Z',
      'continuousLocationSender': true,
      'sharedTasks': true,
      'sharedRoutines': true,
      'sharedHousehold': true,
      'maxTrustedLiveViewers': 3,
      'householdMemberLimit': 10,
    });

    expect(entitlement.state, HomiBillingState.expired);
    expect(entitlement.canSendContinuousLocation, isFalse);
    expect(entitlement.canCreateSharedTasks, isFalse);
    expect(entitlement.canUseSharedHousehold, isFalse);
  });

  test('approved launch pricing and household seat increments stay locked', () {
    expect(HomiPlusPlans.personal.monthlyPriceCents, 7999);
    expect(HomiPlusPlans.personal.annualPriceCents, 79999);
    expect(HomiPlusPlans.duo.monthlyPriceCents, 12999);
    expect(HomiPlusPlans.duo.annualPriceCents, 129999);
    expect(HomiPlusPlans.household.monthlyPriceCents, 19999);
    expect(HomiPlusPlans.household.annualPriceCents, 199999);
    expect(HomiPlusPlans.householdMonthlyPriceCents(4), 19999);
    expect(HomiPlusPlans.householdAnnualPriceCents(4), 199999);
    expect(HomiPlusPlans.householdMonthlyPriceCents(6), 29999);
    expect(HomiPlusPlans.householdAnnualPriceCents(6), 299999);
    expect(HomiPlusPlans.householdMonthlyPriceCents(10), 49999);
    expect(HomiPlusPlans.householdAnnualPriceCents(10), 499999);
    expect(HomiPlusPlans.normalizeHouseholdMemberCount(2), 4);
    expect(HomiPlusPlans.normalizeHouseholdMemberCount(12), 10);
    expect(homiPlusMaxTrustedLiveViewersPerSender, 3);
  });

  test('Play catalog is intentionally disabled until durable IDs are verified', () {
    expect(HomiPlayBillingCatalog.unconfigured.configured, isFalse);
    expect(HomiPlayBillingCatalog.unconfigured.productIds, isEmpty);
    expect(HomiPlayBillingCatalog.unconfigured.products.length, 9);
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
