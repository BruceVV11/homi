import 'dart:async';

import 'trusted_people_service.dart';

/// Trusted-people view used by household collaboration surfaces such as task
/// assignment. Friends remain visible on People/location but are omitted here.
class HouseholdPeopleService extends TrustedPeopleService {
  HouseholdPeopleService({required super.firebaseReady});

  @override
  Stream<List<TrustedConnection>> watchConnections() {
    final baseConnections = super.watchConnections();
    final basePreferences = super.watchPreferences();
    late final StreamController<List<TrustedConnection>> controller;
    StreamSubscription<List<TrustedConnection>>? connectionSub;
    StreamSubscription<Map<String, TrustedPersonPreference>>? preferenceSub;
    List<TrustedConnection>? connections;
    Map<String, TrustedPersonPreference>? preferences;

    void emit() {
      final current = connections;
      final prefs = preferences;
      final user = currentUser;
      if (current == null || prefs == null || user == null) return;
      controller.add(
        current.where((connection) {
          if (!connection.accepted) return true;
          final otherUid = connection.otherUid(user.uid);
          return prefs[otherUid]?.household == true;
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
        preferenceSub = basePreferences.listen(
          (value) {
            preferences = value;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await connectionSub?.cancel();
        await preferenceSub?.cancel();
      },
    );
    return controller.stream;
  }
}
