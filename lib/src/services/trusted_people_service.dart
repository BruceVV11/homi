import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrustedConnection {
  const TrustedConnection({
    required this.id,
    required this.initiatorUid,
    required this.recipientUid,
    required this.memberUids,
    required this.status,
    required this.aUid,
    required this.aName,
    required this.bUid,
    required this.bName,
    this.aPhotoUrl,
    this.bPhotoUrl,
  });

  final String id;
  final String initiatorUid;
  final String recipientUid;
  final List<String> memberUids;
  final String status;
  final String aUid;
  final String aName;
  final String? aPhotoUrl;
  final String bUid;
  final String bName;
  final String? bPhotoUrl;

  bool get accepted => status == 'accepted';
  bool get pending => status == 'pending';

  bool isIncomingFor(String uid) => pending && recipientUid == uid;

  String otherUid(String currentUid) => aUid == currentUid ? bUid : aUid;

  String otherName(String currentUid) => aUid == currentUid ? bName : aName;

  String? otherPhotoUrl(String currentUid) =>
      aUid == currentUid ? bPhotoUrl : aPhotoUrl;

  factory TrustedConnection.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return TrustedConnection(
      id: document.id,
      initiatorUid: data['initiatorUid'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      memberUids: (data['memberUids'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      status: data['status'] as String? ?? 'pending',
      aUid: data['aUid'] as String? ?? '',
      aName: data['aName'] as String? ?? 'Homi user',
      aPhotoUrl: data['aPhotoUrl'] as String?,
      bUid: data['bUid'] as String? ?? '',
      bName: data['bName'] as String? ?? 'Homi user',
      bPhotoUrl: data['bPhotoUrl'] as String?,
    );
  }
}

class TrustedPersonPreference {
  const TrustedPersonPreference({
    required this.relationship,
    required this.scope,
  });

  final String relationship;

  /// `household` means this person is part of the user's home context.
  /// `friend` means the connection is intentionally location/social only.
  final String scope;

  bool get household => scope == 'household';

  static const fallback = TrustedPersonPreference(
    relationship: 'Trusted person',
    scope: 'friend',
  );
}

class TrustedPersonLocation {
  const TrustedPersonLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.batteryPercent,
    required this.isCharging,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int batteryPercent;
  final bool isCharging;
  final DateTime? updatedAt;

  factory TrustedPersonLocation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const FormatException('No location is available.');
    }
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final accuracy = data['accuracyMeters'];
    final battery = data['batteryPercent'];
    if (latitude is! num ||
        longitude is! num ||
        accuracy is! num ||
        battery is! num) {
      throw const FormatException('Location data is incomplete.');
    }
    final timestamp = data['updatedAt'];
    return TrustedPersonLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracyMeters: accuracy.toDouble(),
      batteryPercent: battery.toInt().clamp(0, 100).toInt(),
      isCharging: data['isCharging'] == true,
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class HomiIdentity {
  const HomiIdentity({
    required this.code,
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });

  final String code;
  final String uid;
  final String displayName;
  final String? photoUrl;
}

class TrustedPeopleService {
  TrustedPeopleService({required this.firebaseReady});

  final bool firebaseReady;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Homi user';
  }

  Future<HomiIdentity> ensureIdentity() async {
    final user = _requireUser();
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final currentCode = (userDoc.data()?['homiCode'] as String?)?.trim();
    final name = _displayName(user);

    if (currentCode != null && currentCode.isNotEmpty) {
      final code = currentCode.toUpperCase();
      await _firestore.collection('homiCodes').doc(code).set({
        'uid': user.uid,
        'displayName': name,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return HomiIdentity(
        code: code,
        uid: user.uid,
        displayName: name,
        photoUrl: user.photoURL,
      );
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final codeRef = _firestore.collection('homiCodes').doc(code);
      try {
        await codeRef.set({
          'uid': user.uid,
          'displayName': name,
          'photoUrl': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await userRef.set({
          'homiCode': code,
          'displayName': name,
          'photoUrl': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return HomiIdentity(
          code: code,
          uid: user.uid,
          displayName: name,
          photoUrl: user.photoURL,
        );
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') rethrow;
      }
    }
    throw StateError('Homi could not create a connection code. Try again.');
  }

  Future<void> connectWithCode(String rawCode) async {
    final user = _requireUser();
    final own = await ensureIdentity();
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (code.length != 6) {
      throw StateError('Enter the 6-character Homi code.');
    }

    final targetDoc = await _firestore.collection('homiCodes').doc(code).get();
    final target = targetDoc.data();
    if (target == null) {
      throw StateError('That Homi code could not be found.');
    }
    final targetUid = target['uid'] as String?;
    if (targetUid == null || targetUid.isEmpty) {
      throw StateError('That Homi code is not available.');
    }
    if (targetUid == user.uid) {
      throw StateError('That is your own Homi code.');
    }

    final targetName = (target['displayName'] as String?)?.trim();
    final targetPhoto = target['photoUrl'] as String?;
    final ids = <String>[user.uid, targetUid]..sort();
    final connectionId = '${ids[0]}_${ids[1]}';
    final aIsCurrent = ids[0] == user.uid;
    final connectionRef = _firestore.collection('connections').doc(connectionId);

    try {
      await connectionRef.set({
        'memberUids': ids,
        'initiatorUid': user.uid,
        'recipientUid': targetUid,
        'status': 'pending',
        'aUid': ids[0],
        'aName': aIsCurrent
            ? own.displayName
            : (targetName?.isNotEmpty == true ? targetName : 'Homi user'),
        'aPhotoUrl': aIsCurrent ? own.photoUrl : targetPhoto,
        'bUid': ids[1],
        'bName': aIsCurrent
            ? (targetName?.isNotEmpty == true ? targetName : 'Homi user')
            : own.displayName,
        'bPhotoUrl': aIsCurrent ? targetPhoto : own.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        throw StateError('There is already a connection request for this person.');
      }
      rethrow;
    }
  }

  Stream<List<TrustedConnection>> watchConnections() {
    final user = currentUser;
    if (user == null) return Stream.value(const <TrustedConnection>[]);
    return _firestore
        .collection('connections')
        .where('memberUids', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      final connections = snapshot.docs
          .map(TrustedConnection.fromDocument)
          .toList(growable: false);
      connections.sort((a, b) {
        if (a.status == b.status) {
          return a.otherName(user.uid).compareTo(b.otherName(user.uid));
        }
        if (a.pending) return -1;
        if (b.pending) return 1;
        return 0;
      });
      return connections;
    });
  }

  Stream<Map<String, TrustedPersonPreference>> watchPreferences() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(const <String, TrustedPersonPreference>{});
    }
    return _firestore
        .collection('peoplePreferences')
        .doc(user.uid)
        .collection('people')
        .snapshots()
        .map((snapshot) {
      final result = <String, TrustedPersonPreference>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        result[document.id] = TrustedPersonPreference(
          relationship: (data['relationship'] as String?)?.trim().isNotEmpty == true
              ? (data['relationship'] as String).trim()
              : 'Trusted person',
          scope: data['scope'] == 'household' ? 'household' : 'friend',
        );
      }
      return result;
    });
  }

  Future<void> setPreference({
    required String otherUid,
    required String relationship,
    required String scope,
  }) async {
    final user = _requireUser();
    await _firestore
        .collection('peoplePreferences')
        .doc(user.uid)
        .collection('people')
        .doc(otherUid)
        .set({
      'relationship': relationship.trim().isEmpty
          ? 'Trusted person'
          : relationship.trim(),
      'scope': scope == 'household' ? 'household' : 'friend',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptConnection(TrustedConnection connection) async {
    final user = _requireUser();
    if (!connection.isIncomingFor(user.uid)) {
      throw StateError('Only the invited person can accept this request.');
    }
    await _firestore.collection('connections').doc(connection.id).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineOrRemoveConnection(TrustedConnection connection) async {
    final user = _requireUser();
    if (!connection.memberUids.contains(user.uid)) {
      throw StateError('This connection is not available to your account.');
    }
    final otherUid = connection.otherUid(user.uid);
    await _firestore.collection('connections').doc(connection.id).delete();
    try {
      await _firestore
          .collection('locationShares')
          .doc(user.uid)
          .collection('viewers')
          .doc(otherUid)
          .delete();
    } on FirebaseException {
      // Removing an absent share should not turn a successful disconnect into
      // an error.
    }
    try {
      await _firestore
          .collection('peoplePreferences')
          .doc(user.uid)
          .collection('people')
          .doc(otherUid)
          .delete();
    } on FirebaseException {
      // The preference is private convenience metadata and may not exist.
    }
  }

  Stream<bool> watchMyShareTo(String viewerUid) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _firestore
        .collection('locationShares')
        .doc(user.uid)
        .collection('viewers')
        .doc(viewerUid)
        .snapshots()
        .map((doc) => doc.data()?['active'] == true);
  }

  Stream<bool> watchTheirShareToMe(String ownerUid) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _firestore
        .collection('locationShares')
        .doc(ownerUid)
        .collection('viewers')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data()?['active'] == true);
  }

  Future<void> setMyLocationShare(String viewerUid, bool active) async {
    final user = _requireUser();
    await _firestore
        .collection('locationShares')
        .doc(user.uid)
        .collection('viewers')
        .doc(viewerUid)
        .set({
      'active': active,
      'ownerUid': user.uid,
      'viewerUid': viewerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<TrustedPersonLocation?> watchLocation(String ownerUid) {
    final user = currentUser;
    if (user == null) return Stream.value(null);
    return _firestore.collection('locations').doc(ownerUid).snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        try {
          return TrustedPersonLocation.fromDocument(doc);
        } catch (_) {
          return null;
        }
      },
    );
  }

  User _requireUser() {
    if (!firebaseReady) {
      throw StateError('Sign in to use trusted people.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to use trusted people.');
    return user;
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List<String>.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
