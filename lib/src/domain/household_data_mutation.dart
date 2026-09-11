enum HouseholdDataDomain {
  routine,
  supply,
  homeThing,
  homeEvent,
  utilityReading,
}

extension HouseholdDataDomainValue on HouseholdDataDomain {
  String get cloudValue => switch (this) {
        HouseholdDataDomain.routine => 'routine',
        HouseholdDataDomain.supply => 'supply',
        HouseholdDataDomain.homeThing => 'homeThing',
        HouseholdDataDomain.homeEvent => 'homeEvent',
        HouseholdDataDomain.utilityReading => 'utilityReading',
      };

  static HouseholdDataDomain? fromCloudValue(String value) {
    for (final domain in HouseholdDataDomain.values) {
      if (domain.cloudValue == value) return domain;
    }
    return null;
  }
}

class HouseholdDataMutation {
  const HouseholdDataMutation.upsert({
    required this.domain,
    required this.itemId,
    required this.payload,
  }) : delete = false;

  const HouseholdDataMutation.delete({
    required this.domain,
    required this.itemId,
  })  : delete = true,
        payload = null;

  final HouseholdDataDomain domain;
  final String itemId;
  final Map<String, dynamic>? payload;
  final bool delete;
}

typedef HouseholdDataMutationSink = Future<void> Function(
  HouseholdDataMutation mutation,
);
