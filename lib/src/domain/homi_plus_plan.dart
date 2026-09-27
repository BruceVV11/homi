/// Commercial plan contract for Homi+.
///
/// Store identifiers live in the dedicated Play catalog. This file owns the
/// product promise and launch pricing so UI, entitlement and backend policy can
/// be checked against one durable contract.
enum HomiPlusPlan {
  free,
  personal,
  duo,
  household,
}

const int homiPlusMaxTrustedLiveViewersPerSender = 3;
const int homiPlusDuoSeatReassignmentCooldownDays = 7;
const int homiPlusHouseholdIncludedMemberLimit = 4;
const int homiPlusHouseholdMaximumMemberLimit = 10;
const int homiPlusHouseholdExtraMemberMonthlyPriceCents = 5000;
const int homiPlusHouseholdExtraMemberAnnualPriceCents = 50000;

class HomiPlusPlanDefinition {
  const HomiPlusPlanDefinition({
    required this.plan,
    required this.slug,
    required this.name,
    required this.monthlyPriceCents,
    required this.continuousLocationSenderSeats,
    required this.sharedTasksEnabled,
    required this.sharedRoutinesEnabled,
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
  final bool sharedTasksEnabled;
  final bool sharedRoutinesEnabled;
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
    sharedTasksEnabled: false,
    sharedRoutinesEnabled: false,
    sharedHouseholdEnabled: false,
    summary:
        'Use Homi locally, connect with trusted people, receive shared location and keep all privacy and safety controls.',
  );

  static const HomiPlusPlanDefinition personal = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.personal,
    slug: 'personal',
    name: 'Homi+ Personal',
    monthlyPriceCents: 7999,
    annualPriceCents: 79999,
    continuousLocationSenderSeats: 1,
    sharedTasksEnabled: true,
    sharedRoutinesEnabled: true,
    sharedHouseholdEnabled: false,
    summary:
        'One Homi+ sender seat with up to three live viewers, plus trusted-person shared Tasks and Routines.',
  );

  static const HomiPlusPlanDefinition duo = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.duo,
    slug: 'duo',
    name: 'Homi+ Duo',
    monthlyPriceCents: 12999,
    annualPriceCents: 129999,
    continuousLocationSenderSeats: 2,
    sharedTasksEnabled: true,
    sharedRoutinesEnabled: true,
    sharedHouseholdEnabled: false,
    summary:
        'Two covered people with up to three live viewers each and two-way shared Tasks and Routines.',
  );

  static const HomiPlusPlanDefinition household = HomiPlusPlanDefinition(
    plan: HomiPlusPlan.household,
    slug: 'household',
    name: 'Homi+ Household',
    monthlyPriceCents: 19999,
    annualPriceCents: 199999,
    continuousLocationSenderSeats: homiPlusHouseholdIncludedMemberLimit,
    sharedTasksEnabled: true,
    sharedRoutinesEnabled: true,
    sharedHouseholdEnabled: true,
    summary:
        'Four members included with the full Shared Household workspace. Add members above four at R50/month or R500/year each.',
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

  static int normalizeHouseholdMemberCount(int value) {
    if (value < homiPlusHouseholdIncludedMemberLimit) {
      return homiPlusHouseholdIncludedMemberLimit;
    }
    if (value > homiPlusHouseholdMaximumMemberLimit) {
      return homiPlusHouseholdMaximumMemberLimit;
    }
    return value;
  }

  static int householdMonthlyPriceCents(int members) {
    final safe = normalizeHouseholdMemberCount(members);
    return household.monthlyPriceCents +
        (safe - homiPlusHouseholdIncludedMemberLimit) *
            homiPlusHouseholdExtraMemberMonthlyPriceCents;
  }

  static int householdAnnualPriceCents(int members) {
    final safe = normalizeHouseholdMemberCount(members);
    return household.annualPriceCents! +
        (safe - homiPlusHouseholdIncludedMemberLimit) *
            homiPlusHouseholdExtraMemberAnnualPriceCents;
  }
}
