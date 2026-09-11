import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/homi_plus_plan.dart';

void main() {
  test('Homi+ sender-seat and viewer contract stays fixed', () {
    expect(HomiPlusPlans.free.continuousLocationSenderSeats, 0);
    expect(HomiPlusPlans.personal.continuousLocationSenderSeats, 1);
    expect(HomiPlusPlans.duo.continuousLocationSenderSeats, 2);
    expect(HomiPlusPlans.household.continuousLocationSenderSeats, 4);
    expect(homiPlusMaxTrustedLiveViewersPerSender, 5);
    expect(homiPlusDuoSeatReassignmentCooldownDays, 7);
  });

  test('approved South African monthly prices are represented in cents', () {
    expect(HomiPlusPlans.free.monthlyPriceCents, 0);
    expect(HomiPlusPlans.personal.monthlyPriceCents, 1999);
    expect(HomiPlusPlans.duo.monthlyPriceCents, 3499);
    expect(HomiPlusPlans.household.monthlyPriceCents, 4999);
    expect(HomiPlusPlans.household.annualPriceCents, 49999);
  });

  test('only Household includes the shared household product', () {
    expect(HomiPlusPlans.personal.sharedHouseholdEnabled, isFalse);
    expect(HomiPlusPlans.duo.sharedHouseholdEnabled, isFalse);
    expect(HomiPlusPlans.household.sharedHouseholdEnabled, isTrue);
  });

  test('plan slugs round-trip without depending on store product IDs', () {
    for (final definition in HomiPlusPlans.all) {
      expect(HomiPlusPlans.fromSlug(definition.slug), same(definition));
    }
    expect(HomiPlusPlans.fromSlug('unknown'), isNull);
  });
}
