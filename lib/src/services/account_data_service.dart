import 'package:firebase_auth/firebase_auth.dart';

import 'homi_cloud_actions.dart';

class AccountDeletionSummary {
  const AccountDeletionSummary({
    required this.connectionsRemoved,
    required this.sharedTasksRemoved,
    required this.sharedTasksDetached,
  });

  final int connectionsRemoved;
  final int sharedTasksRemoved;
  final int sharedTasksDetached;
}

/// Requests server-side deletion of the signed-in user's Homi cloud records.
///
/// The backend requires Firebase Authentication, App Check and a recent sign-in
/// before it removes cloud data. This keeps cross-user cleanup, server-only
/// metadata and shared-task detachment out of the mobile client's Firestore
/// permissions.
class AccountDataService {
  AccountDataService({required this.firebaseReady})
      : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  final bool firebaseReady;
  final HomiCloudActions _cloudActions;

  User _requireUser() {
    if (!firebaseReady) {
      throw StateError('Homi cloud services are unavailable on this device.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before deleting an account.');
    return user;
  }

  Future<AccountDeletionSummary> deleteCurrentAccountData() async {
    _requireUser();
    final result = await _cloudActions.call('deleteHomiAccountData');
    return AccountDeletionSummary(
      connectionsRemoved:
          (result['connectionsRemoved'] as num?)?.toInt() ?? 0,
      sharedTasksRemoved:
          (result['sharedTasksRemoved'] as num?)?.toInt() ?? 0,
      sharedTasksDetached:
          (result['sharedTasksDetached'] as num?)?.toInt() ?? 0,
    );
  }
}
