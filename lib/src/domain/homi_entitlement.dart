import 'homi_plus_plan.dart';

enum HomiBillingState {
  free,
  active,
  gracePeriod,
  onHold,
  paused,
  canceled,
  expired,
  pending,
  unknown;

  static HomiBillingState fromValue(Object? value) {
    return switch (value?.toString()) {
      'active' => HomiBillingState.active,
      'grace_period' => HomiBillingState.gracePeriod,
      'on_hold' => HomiBillingState.onHold,
      'paused' => HomiBillingState.paused,
      'canceled' => HomiBillingState.canceled,
      'expired' => HomiBillingState.expired,
      'pending' => HomiBillingState.pending,
      'free' => HomiBillingState.free,
      _ => HomiBillingState.unknown,
    };
  }

  // Google Play reports a voluntarily canceled subscription as canceled while
  // the user remains entitled through the already-paid billing term. The
  // backend moves the record to expired when Play reports that term ended.
  bool get grantsPaidAccess =>
      this == HomiBillingState.active ||
      this == HomiBillingState.gracePeriod ||
      this == HomiBillingState.canceled;
}

class HomiEntitlement {
  const HomiEntitlement({
    required this.plan,
    required this.state,
    required this.continuousLocationSender,
    required this.sharedHousehold,
    required this.maxTrustedLiveViewers,
    required this.householdMemberLimit,
    this.purchaserUid,
    this.householdId,
    this.seatRole,
    this.duoSeatAssigneeUid,
    this.validUntil,
  });

  final HomiPlusPlan plan;
  final HomiBillingState state;
  final bool continuousLocationSender;
  final bool sharedHousehold;
  final int maxTrustedLiveViewers;
  final int householdMemberLimit;
  final String? purchaserUid;
  final String? householdId;
  final String? seatRole;
  final String? duoSeatAssigneeUid;
  final DateTime? validUntil;

  bool get isPaid => plan != HomiPlusPlan.free && state.grantsPaidAccess;

  bool get canSendContinuousLocation =>
      isPaid && continuousLocationSender;

  bool get canUseSharedHousehold => isPaid && sharedHousehold;

  static const free = HomiEntitlement(
    plan: HomiPlusPlan.free,
    state: HomiBillingState.free,
    continuousLocationSender: false,
    sharedHousehold: false,
    maxTrustedLiveViewers: 0,
    householdMemberLimit: 0,
  );

  factory HomiEntitlement.fromMap(Map<String, dynamic>? data) {
    if (data == null) return free;
    final definition = HomiPlusPlans.fromSlug(data['plan']?.toString());
    final state = HomiBillingState.fromValue(data['state']);
    if (definition == null || !state.grantsPaidAccess) {
      return HomiEntitlement(
        plan: definition?.plan ?? HomiPlusPlan.free,
        state: state == HomiBillingState.unknown
            ? HomiBillingState.free
            : state,
        continuousLocationSender: false,
        sharedHousehold: false,
        maxTrustedLiveViewers: 0,
        householdMemberLimit: 0,
        purchaserUid: _cleanString(data['purchaserUid']),
        householdId: _cleanString(data['householdId']),
        seatRole: _cleanString(data['seatRole']),
        duoSeatAssigneeUid: _cleanString(data['duoSeatAssigneeUid']),
        validUntil: _dateFrom(data['validUntil']),
      );
    }

    return HomiEntitlement(
      plan: definition.plan,
      state: state,
      continuousLocationSender: data['continuousLocationSender'] == true,
      sharedHousehold: data['sharedHousehold'] == true,
      maxTrustedLiveViewers:
          (data['maxTrustedLiveViewers'] as num?)?.toInt() ?? 0,
      householdMemberLimit:
          (data['householdMemberLimit'] as num?)?.toInt() ?? 0,
      purchaserUid: _cleanString(data['purchaserUid']),
      householdId: _cleanString(data['householdId']),
      seatRole: _cleanString(data['seatRole']),
      duoSeatAssigneeUid: _cleanString(data['duoSeatAssigneeUid']),
      validUntil: _dateFrom(data['validUntil']),
    );
  }

  static String? _cleanString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic candidate = value;
      final DateTime result = candidate.toDate() as DateTime;
      return result;
    } catch (_) {
      return null;
    }
  }
}
