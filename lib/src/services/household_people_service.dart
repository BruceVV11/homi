import 'dart:async';

import '../domain/homi_household.dart';
import 'household_service.dart';
import 'trusted_people_service.dart';

/// Trusted-people view used by Household collaboration surfaces such as task
/// assignment. A People label can never promote a friend into this list: an
/// accepted connection must also be a current member of the same canonical
/// Household.
class HouseholdPeopleService extends TrustedPeopleService {
  HouseholdPeopleService({required super.firebaseReady})
      : _householdService = HouseholdService(firebaseReady: firebaseReady);

  final HouseholdService _householdService;

  @override
  Stream<List<TrustedConnection>> watchConnections() {
    final baseConnections = super.watchConnections();
    final householdStream = _householdService.watchCurrentHousehold();
    late final StreamController<List<TrustedConnection>> controller;
    StreamSubscription<List<TrustedConnection>>? connectionSub;
    StreamSubscription<HomiHousehold?>? householdSub;
    List<TrustedConnection>? connections;
    HomiHousehold? household;
    var householdReady = false;

    void emit() {
      final current = connections;
      final user = currentUser;
      if (current == null || !householdReady || user == null) return;
      final memberUids = household?.memberUids.toSet() ?? const <String>{};
      controller.add(
        current.where((connection) {
          if (!connection.accepted) return false;
          return memberUids.contains(connection.otherUid(user.uid));
        }).toList(growable: false),
      );
    }

    controller = StreamController<List<TrustedConnection>>(
      onListen: () {
        connectionSub = baseConnections.listen(
          (value) {
            connections = value;
            emit();
          },
          onError: controller.addError,
        );
        householdSub = householdStream.listen(
          (value) {
            household = value;
            householdReady = true;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await connectionSub?.cancel();
        await householdSub?.cancel();
      },
    );
    return controller.stream;
  }
}
