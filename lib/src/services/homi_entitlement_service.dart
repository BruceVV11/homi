import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/homi_entitlement.dart';

/// Read-only client boundary for server-authoritative Homi+ capabilities.
///
/// Flutter never grants itself paid access. Missing, expired, malformed or
/// unreadable entitlement state fails closed to Homi Free. All entitlement
/// writes are owned by the billing backend.
class HomiEntitlementService {
  const HomiEntitlementService({required this.firebaseReady});

  final bool firebaseReady;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  Stream<HomiEntitlement> watchCurrent() async* {
    final user = currentUser;
    if (user == null) {
      yield HomiEntitlement.free;
      return;
    }
    try {
      await for (final snapshot in FirebaseFirestore.instance
          .collection('entitlements')
          .doc(user.uid)
          .snapshots()) {
        yield HomiEntitlement.fromMap(snapshot.data());
      }
    } catch (_) {
      yield HomiEntitlement.free;
    }
  }

  Future<HomiEntitlement> getCurrent() async {
    final user = currentUser;
    if (user == null) return HomiEntitlement.free;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('entitlements')
          .doc(user.uid)
          .get();
      return HomiEntitlement.fromMap(snapshot.data());
    } catch (_) {
      return HomiEntitlement.free;
    }
  }
}
