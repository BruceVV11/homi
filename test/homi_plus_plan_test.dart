import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/homi_plus_plan.dart';

void main() {
  test('Homi+ sender-seat and viewer contract stays fixed', () {
    expect(HomiPlusPlans.free.continuousLocationSenderSeats, 0);
    expect(HomiPlusPlans.personal.continuousLocationSenderSeats, 1);
    expect(HomiPlusPlans.duo.continuousLocationSenderSeats, 2);
    expect(HomiPlusPlans.household.continuousLocationSenderSeats, 4);
    expect(homiPlusMaxTrustedLiveViewersPerSender, 3);
    expect(homiPlusDuoSeatReassignmentCooldownDays, 7);
  });

  test('approved South African launch prices are represented in cents', () {
    expect(HomiPlusPlans.free.monthlyPriceCents, 0);

    expect(HomiPlusPlans.personal.monthlyPriceCents, 7999);
    expect(HomiPlusPlans.personal.annualPriceCents, 79999);

    expect(HomiPlusPlans.duo.monthlyPriceCents, 12999);
    expect(HomiPlusPlans.duo.annualPriceCents, 129999);

    expect(HomiPlusPlans.household.monthlyPriceCents, 19999);
    expect(HomiPlusPlans.household.annualPriceCents, 199999);
    expect(HomiPlusPlans.householdMonthlyPriceCents(5), 24999);
    expect(HomiPlusPlans.householdAnnualPriceCents(5), 249999);
    expect(HomiPlusPlans.householdMonthlyPriceCents(10), 49999);
    expect(HomiPlusPlans.householdAnnualPriceCents(10), 499999);
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
