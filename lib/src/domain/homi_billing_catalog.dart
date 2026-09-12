import 'homi_plus_plan.dart';

enum HomiBillingCadence { monthly, annual }

class HomiPlayProductRef {
  const HomiPlayProductRef({
    required this.plan,
    required this.productId,
    required this.monthlyBasePlanId,
    this.annualBasePlanId,
  });

  final HomiPlusPlan plan;
  final String productId;
  final String monthlyBasePlanId;
  final String? annualBasePlanId;

  bool get configured =>
      productId.trim().isNotEmpty && monthlyBasePlanId.trim().isNotEmpty;

  String? basePlanIdFor(HomiBillingCadence cadence) {
    return switch (cadence) {
      HomiBillingCadence.monthly => monthlyBasePlanId,
      HomiBillingCadence.annual => annualBasePlanId,
    };
  }
}

/// Public Google Play identifiers are deliberately injected after the Play
/// catalog has been created and verified. They are not secrets, but product and
/// base-plan IDs are durable store infrastructure and should not be guessed by
/// the client before that external setup exists.
class HomiPlayBillingCatalog {
  const HomiPlayBillingCatalog({
    required this.personal,
    required this.duo,
    required this.household,
  });

  final HomiPlayProductRef personal;
  final HomiPlayProductRef duo;
  final HomiPlayProductRef household;

  static const unconfigured = HomiPlayBillingCatalog(
    personal: HomiPlayProductRef(
      plan: HomiPlusPlan.personal,
      productId: '',
      monthlyBasePlanId: '',
    ),
    duo: HomiPlayProductRef(
      plan: HomiPlusPlan.duo,
      productId: '',
      monthlyBasePlanId: '',
    ),
    household: HomiPlayProductRef(
      plan: HomiPlusPlan.household,
      productId: '',
      monthlyBasePlanId: '',
      annualBasePlanId: '',
    ),
  );

  // This is the one client-side switch used by the billing UI. It deliberately
  // remains disabled until the exact Play product/base-plan IDs have been
  // created and checked in Play Console. Once verified, replace this alias with
  // the source-controlled live catalog rather than scattering IDs through UI.
  static const current = unconfigured;

  List<HomiPlayProductRef> get products => <HomiPlayProductRef>[
        personal,
        duo,
        household,
      ];

  bool get configured => products.every((item) => item.configured) &&
      household.annualBasePlanId?.trim().isNotEmpty == true;

  Set<String> get productIds => products
      .map((item) => item.productId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  HomiPlayProductRef? forPlan(HomiPlusPlan plan) {
    for (final item in products) {
      if (item.plan == plan) return item;
    }
    return null;
  }
}
