import 'homi_billing_catalog.dart';
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
    required this.sharedTasks,
    required this.sharedRoutines,
    required this.sharedHousehold,
    required this.maxTrustedLiveViewers,
    required this.householdMemberLimit,
    this.purchaserUid,
    this.householdId,
    this.seatRole,
    this.duoSeatAssigneeUid,
    this.cadence,
    this.startedAt,
    this.validUntil,
    this.autoRenewEnabled,
  });

  final HomiPlusPlan plan;
  final HomiBillingState state;
  final bool continuousLocationSender;
  final bool sharedTasks;
  final bool sharedRoutines;
  final bool sharedHousehold;
  final int maxTrustedLiveViewers;
  final int householdMemberLimit;
  final String? purchaserUid;
  final String? householdId;
  final String? seatRole;
  final String? duoSeatAssigneeUid;
  final HomiBillingCadence? cadence;
  final DateTime? startedAt;
  final DateTime? validUntil;
  final bool? autoRenewEnabled;

  bool get isPaid => plan != HomiPlusPlan.free && state.grantsPaidAccess;
  bool get canSendContinuousLocation => isPaid && continuousLocationSender;
  bool get canCreateSharedTasks => isPaid && sharedTasks;
  bool get canCreateSharedRoutines => isPaid && sharedRoutines;
  bool get canUseSharedHousehold => isPaid && sharedHousehold;

  static const free = HomiEntitlement(
    plan: HomiPlusPlan.free,
    state: HomiBillingState.free,
    continuousLocationSender: false,
    sharedTasks: false,
    sharedRoutines: false,
    sharedHousehold: false,
    maxTrustedLiveViewers: 0,
    householdMemberLimit: 0,
  );

  factory HomiEntitlement.fromMap(Map<String, dynamic>? data) {
    if (data == null) return free;
    final definition = HomiPlusPlans.fromSlug(data['plan']?.toString());
    final validUntil = _dateFrom(data['validUntil']);
    final reportedState = HomiBillingState.fromValue(data['state']);
    final paidTermState = reportedState == HomiBillingState.active ||
        reportedState == HomiBillingState.gracePeriod ||
        reportedState == HomiBillingState.canceled;
    final state = paidTermState &&
            (validUntil == null || !validUntil.isAfter(DateTime.now()))
        ? HomiBillingState.expired
        : reportedState;

    if (definition == null || !state.grantsPaidAccess) {
      return HomiEntitlement(
        plan: definition?.plan ?? HomiPlusPlan.free,
        state: state == HomiBillingState.unknown
            ? HomiBillingState.free
            : state,
        continuousLocationSender: false,
        sharedTasks: false,
        sharedRoutines: false,
        sharedHousehold: false,
        maxTrustedLiveViewers: 0,
        householdMemberLimit: 0,
        purchaserUid: _cleanString(data['purchaserUid']),
        householdId: _cleanString(data['householdId']),
        seatRole: _cleanString(data['seatRole']),
        duoSeatAssigneeUid: _cleanString(data['duoSeatAssigneeUid']),
        cadence: _cadenceFrom(data['cadence']),
        startedAt: _dateFrom(data['startedAt']),
        validUntil: validUntil,
        autoRenewEnabled: data['autoRenewEnabled'] is bool
            ? data['autoRenewEnabled'] as bool
            : null,
      );
    }

    return HomiEntitlement(
      plan: definition.plan,
      state: state,
      continuousLocationSender: data['continuousLocationSender'] == true,
      sharedTasks: data['sharedTasks'] == true,
      sharedRoutines: data['sharedRoutines'] == true,
      sharedHousehold: data['sharedHousehold'] == true,
      maxTrustedLiveViewers:
          (data['maxTrustedLiveViewers'] as num?)?.toInt() ?? 0,
      householdMemberLimit:
          (data['householdMemberLimit'] as num?)?.toInt() ?? 0,
      purchaserUid: _cleanString(data['purchaserUid']),
      householdId: _cleanString(data['householdId']),
      seatRole: _cleanString(data['seatRole']),
      duoSeatAssigneeUid: _cleanString(data['duoSeatAssigneeUid']),
      cadence: _cadenceFrom(data['cadence']),
      startedAt: _dateFrom(data['startedAt']),
      validUntil: validUntil,
      autoRenewEnabled: data['autoRenewEnabled'] is bool
          ? data['autoRenewEnabled'] as bool
          : null,
    );
  }

  static String? _cleanString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  static HomiBillingCadence? _cadenceFrom(Object? value) => switch (value?.toString()) {
        'monthly' => HomiBillingCadence.monthly,
        'annual' => HomiBillingCadence.annual,
        _ => null,
      };

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
