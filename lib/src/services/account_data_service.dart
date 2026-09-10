import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Deletes the cloud records Homi currently associates with the signed-in
/// account before Firebase Authentication identity deletion.
///
/// This intentionally knows about every active Homi Firestore collection. Add
/// new account-scoped collections here whenever the cloud schema grows.
class AccountDataService {
  AccountDataService({required this.firebaseReady});

  final bool firebaseReady;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User _requireUser() {
    if (!firebaseReady) {
      throw StateError('Homi cloud services are unavailable on this device.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before deleting an account.');
    return user;
  }

  Future<AccountDeletionSummary> deleteCurrentAccountData() async {
    final user = _requireUser();
    final uid = user.uid;

    // Read the identity before removing the user document because the Homi
    // code is stored there and must be deleted from the exact-lookup index.
    final userRef = _firestore.collection('users').doc(uid);
    final userSnapshot = await userRef.get();
    final homiCode = (userSnapshot.data()?['homiCode'] as String?)?.trim();

    final connectionSnapshots = await Future.wait([
      _firestore.collection('connections').where('aUid', isEqualTo: uid).get(),
      _firestore.collection('connections').where('bUid', isEqualTo: uid).get(),
    ]);
    final connections = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snapshot in connectionSnapshots) {
      for (final document in snapshot.docs) {
        connections[document.id] = document;
      }
    }

    final ownPreferences = await _firestore
        .collection('peoplePreferences')
        .doc(uid)
        .collection('people')
        .get();
    final ownShares = await _firestore
        .collection('locationShares')
        .doc(uid)
        .collection('viewers')
        .get();
    final devices = await userRef.collection('devices').get();
    final sharedTasks = await _firestore
        .collection('sharedTasks')
        .where('memberUids', arrayContains: uid)
        .get();

    var connectionsRemoved = 0;
    var sharedTasksRemoved = 0;
    var sharedTasksDetached = 0;

    // Remove bilateral relationship traces while the account is still
    // authenticated and therefore authorized to clean its side/subject data.
    for (final connection in connections.values) {
      final data = connection.data();
      final aUid = data['aUid'] as String?;
      final bUid = data['bUid'] as String?;
      final otherUid = aUid == uid ? bUid : aUid;
      if (otherUid != null && otherUid.isNotEmpty) {
        await _ignoreMissing(
          _firestore
              .collection('locationShares')
              .doc(otherUid)
              .collection('viewers')
              .doc(uid)
              .delete(),
        );
        await _ignoreMissing(
          _firestore
              .collection('peoplePreferences')
              .doc(otherUid)
              .collection('people')
              .doc(uid)
              .delete(),
        );
      }
      await connection.reference.delete();
      connectionsRemoved += 1;
    }

    for (final document in ownShares.docs) {
      await document.reference.delete();
    }
    for (final document in ownPreferences.docs) {
      await document.reference.delete();
    }

    // Tasks created by the deleted account are deleted. If the account is only
    // an assignee/viewer of someone else's task, detach and anonymise only the
    // deleted person's references so the creator does not lose their record.
    for (final document in sharedTasks.docs) {
      final data = document.data();
      final creatorUid = data['createdByUid'] as String?;
      if (creatorUid == uid) {
        await document.reference.delete();
        sharedTasksRemoved += 1;
        continue;
      }

      final members = (data['memberUids'] as List?)
              ?.whereType<String>()
              .where((memberUid) => memberUid != uid)
              .toList(growable: false) ??
          const <String>[];
      final update = <String, dynamic>{
        'memberUids': members,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (data['assigneeUid'] == uid) {
        update['assigneeUid'] = null;
        update['assigneeName'] = 'Unassigned';
      }
      if (data['completedByUid'] == uid) {
        update['completedByUid'] = null;
        update['completedByName'] = 'Former Homi user';
      }
      await document.reference.update(update);
      sharedTasksDetached += 1;
    }

    for (final device in devices.docs) {
      await device.reference.delete();
    }

    await _ignoreMissing(_firestore.collection('locations').doc(uid).delete());
    if (homiCode != null && homiCode.isNotEmpty) {
      await _ignoreMissing(
        _firestore.collection('homiCodes').doc(homiCode.toUpperCase()).delete(),
      );
    }
    await _ignoreMissing(userRef.delete());

    return AccountDeletionSummary(
      connectionsRemoved: connectionsRemoved,
      sharedTasksRemoved: sharedTasksRemoved,
      sharedTasksDetached: sharedTasksDetached,
    );
  }

  Future<void> _ignoreMissing(Future<void> operation) async {
    try {
      await operation;
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }
}
