import 'homi_plus_plan.dart';

enum HomiBillingCadence { monthly, annual }

class HomiPlayProductRef {
  const HomiPlayProductRef({
    required this.plan,
    required this.productId,
    required this.monthlyBasePlanId,
    required this.annualBasePlanId,
    this.householdMemberLimit = 0,
  });

  final HomiPlusPlan plan;
  final String productId;
  final String monthlyBasePlanId;
  final String annualBasePlanId;
  final int householdMemberLimit;

  bool get configured =>
      productId.trim().isNotEmpty &&
      monthlyBasePlanId.trim().isNotEmpty &&
      annualBasePlanId.trim().isNotEmpty;

  String basePlanIdFor(HomiBillingCadence cadence) {
    return switch (cadence) {
      HomiBillingCadence.monthly => monthlyBasePlanId,
      HomiBillingCadence.annual => annualBasePlanId,
    };
  }

  bool matchesBasePlan(String value) =>
      monthlyBasePlanId == value || annualBasePlanId == value;

  HomiBillingCadence? cadenceFor(String value) {
    if (value == monthlyBasePlanId) return HomiBillingCadence.monthly;
    if (value == annualBasePlanId) return HomiBillingCadence.annual;
    return null;
  }
}

/// Public Google Play identifiers are durable release infrastructure. These
/// permanent IDs were created and activated in Google Play Console for Homi's
/// South African 0.13 launch catalog on 2026-09-27.
class HomiPlayBillingCatalog {
  const HomiPlayBillingCatalog({required this.products});

  final List<HomiPlayProductRef> products;

  static const current = HomiPlayBillingCatalog(
    products: <HomiPlayProductRef>[
      HomiPlayProductRef(
        plan: HomiPlusPlan.personal,
        productId: 'homi_plus_personal',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.duo,
        productId: 'homi_plus_duo',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_4',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 4,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_5',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 5,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_6',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 6,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_7',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 7,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_8',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 8,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_9',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 9,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: 'homi_plus_household_10',
        monthlyBasePlanId: 'monthly',
        annualBasePlanId: 'annual',
        householdMemberLimit: 10,
      ),
    ],
  );

  bool get configured => products.isNotEmpty && products.every((item) => item.configured);

  Set<String> get productIds => products
      .map((item) => item.productId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  HomiPlayProductRef? forProductId(String productId) {
    for (final item in products) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  HomiPlayProductRef? forPlan(
    HomiPlusPlan plan, {
    int? householdMemberLimit,
  }) {
    for (final item in products) {
      if (item.plan != plan) continue;
      if (plan == HomiPlusPlan.household &&
          householdMemberLimit != null &&
          item.householdMemberLimit != householdMemberLimit) {
        continue;
      }
      return item;
    }
    return null;
  }
}
