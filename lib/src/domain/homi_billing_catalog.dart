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

/// Public Google Play identifiers are durable release infrastructure. The
/// catalog deliberately stays blank until each permanent subscription product
/// and base plan has been created and verified in Play Console.
class HomiPlayBillingCatalog {
  const HomiPlayBillingCatalog({required this.products});

  final List<HomiPlayProductRef> products;

  static const unconfigured = HomiPlayBillingCatalog(
    products: <HomiPlayProductRef>[
      HomiPlayProductRef(
        plan: HomiPlusPlan.personal,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.duo,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 4,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 5,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 6,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 7,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 8,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 9,
      ),
      HomiPlayProductRef(
        plan: HomiPlusPlan.household,
        productId: '',
        monthlyBasePlanId: '',
        annualBasePlanId: '',
        householdMemberLimit: 10,
      ),
    ],
  );

  static const current = unconfigured;

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
