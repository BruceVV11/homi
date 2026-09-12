import 'homi_cloud_actions.dart';

class HomiDuoSeatResult {
  const HomiDuoSeatResult({
    required this.assigned,
    required this.canReassignAt,
  });

  final bool assigned;
  final DateTime? canReassignAt;
}

class HomiPlusManagementService {
  HomiPlusManagementService({required this.firebaseReady})
      : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  final HomiCloudActions _cloudActions;

  Future<HomiDuoSeatResult> setDuoSeat(String? secondaryUid) async {
    final data = await _cloudActions.call(
      'setHomiPlusDuoSeat',
      <String, dynamic>{'secondaryUid': secondaryUid?.trim() ?? ''},
    );
    return HomiDuoSeatResult(
      assigned: data['assigned'] == true,
      canReassignAt: DateTime.tryParse(data['canReassignAt']?.toString() ?? ''),
    );
  }
}
