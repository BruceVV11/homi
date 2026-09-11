/// Commercial plan contract for Homi+.
///
/// This file deliberately contains no Google Play product IDs. Store product
/// identifiers are release infrastructure and are added only after the Play
/// catalog is created and verified.
enum HomiPlusPlan {
  free,
  personal,
  duo,
  household,
}

const int homiPlusMaxTrustedLiveViewersPerSender = 5;
const int homiPlusDuoSeatReassignmentCooldownDays = 7;
const int homiPlusHouseholdMemberLimit = 4;

class HomiPlusPlanDefinition {
  const HomiPlusPlanDefinition({
    required this.plan,
    required this.slug,
    required this.name,
    required this.monthlyPriceCents,
    required this.continuousLocationSenderSeats,
    required this.sharedHouseholdEnabled,
    required this.summary,
    this.annualPriceCents,
  });

  final HomiPlusPlan plan;
  final String slug;
  final String name;
  final int monthlyPriceCents;
  final int? annualPriceCents;
  final int continuousLocationSenderSeats;
  final bool sharedHouseholdEnabled;
  final String summary;

  bool get isPaid => plan != HomiPlusPlan.free;

  int get maxTrustedLiveViewersPerSender =>
      isPaid ? homiPlusMaxTrustedLiveViewersPerSender : 0;
}

abstract final class HomiPlusPlans {
  static const HomiPlusPlanDefinition free = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.free,
    slug: 'free',
    name: 'Homi Free',
    monthlyPriceCents: 0,
    continuousLocationSenderSeats: 0,
    sharedHouseholdEnabled: false,
    summary:
        'Use Homi locally, connect with trusted people, receive live locations and use privacy and safety controls.',
  );

  static const HomiPlusPlanDefinition personal = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.personal,
    slug: 'personal',
    name: 'Homi+ Personal',
    monthlyPriceCents: 1999,
    continuousLocationSenderSeats: 1,
    sharedHouseholdEnabled: false,
    summary:
        'Continuous live location for one sender, shareable with up to five trusted people.',
  );

  static const HomiPlusPlanDefinition duo = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.duo,
    slug: 'duo',
    name: 'Homi+ Duo',
    monthlyPriceCents: 3499,
    continuousLocationSenderSeats: 2,
    sharedHouseholdEnabled: false,
    summary:
        'Two continuous-location sender seats under one subscription. The two people do not need to live together.',
  );

  static const HomiPlusPlanDefinition household = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.household,
    slug: 'household',
    name: 'Homi+ Household',
    monthlyPriceCents: 4999,
    annualPriceCents: 49999,
    continuousLocationSenderSeats: homiPlusHouseholdMemberLimit,
    sharedHouseholdEnabled: true,
    summary:
        'Up to four shared Household members with continuous location plus synchronized Home, Tasks, Routines and Supplies.',
  );

  static const List<HomiPlusPlanDefinition> all = <HomiPlusPlanDefinition>[
    free,
    personal,
    duo,
    household,
  ];

  static HomiPlusPlanDefinition forPlan(HomiPlusPlan plan) =>
      all.firstWhere((definition) => definition.plan == plan);

  static HomiPlusPlanDefinition? fromSlug(String? value) {
    final slug = value?.trim().toLowerCase();
    if (slug == null || slug.isEmpty) return null;
    for (final definition in all) {
      if (definition.slug == slug) return definition;
    }
    return null;
  }
}
