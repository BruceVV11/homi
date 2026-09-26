import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'homi_cloud_actions.dart';

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
  TrustedPeopleService({required this.firebaseReady})
      : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  static final RegExp _homiCodePattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

  final bool firebaseReady;
  final HomiCloudActions _cloudActions;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  Future<HomiIdentity> ensureIdentity() async {
    final user = _requireUser();

    // The signed-in user's profile is already self-readable in Firestore and
    // the backend writes homiCode + its lookup index atomically. Reuse that
    // established code first so a populated People page does not depend on a
    // fresh protected callable merely to display an existing reusable code.
    // The callable remains the provisioning fallback for a genuinely new or
    // incomplete profile.
    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      final existing = _identityFromData(user, profile.data());
      if (existing != null) return existing;
    } catch (_) {
      // Fall through to the protected provisioning path. A transient profile
      // read failure should not prevent the backend from repairing identity.
    }

    final data = await _cloudActions.call('ensureHomiIdentity');
    final provisioned = _identityFromData(user, data);
    if (provisioned == null) {
      throw StateError('Homi could not load your connection code. Try again.');
    }
    return provisioned;
  }

  HomiIdentity? _identityFromData(
    User user,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final code = (data['homiCode'] ?? data['code'])
        ?.toString()
        .trim()
        .toUpperCase();
    if (code == null || !_homiCodePattern.hasMatch(code)) return null;

    final storedName = data['displayName']?.toString().trim();
    final authName = user.displayName?.trim();
    final email = user.email?.trim();
    final emailName = email != null && email.contains('@')
        ? email.split('@').first.trim()
        : null;
    final displayName = storedName?.isNotEmpty == true
        ? storedName!
        : authName?.isNotEmpty == true
            ? authName!
            : emailName?.isNotEmpty == true
                ? emailName!
                : 'Homi user';
    final storedPhoto = data['photoUrl']?.toString().trim();

    return HomiIdentity(
      code: code,
      uid: user.uid,
      displayName: displayName,
      photoUrl: storedPhoto?.isNotEmpty == true ? storedPhoto : user.photoURL,
    );
  }

  Future<void> connectWithCode(String rawCode) async {
    _requireUser();
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (!_homiCodePattern.hasMatch(code)) {
      throw StateError('Enter the 6-character Homi code.');
    }
    await _cloudActions.call('connectWithHomiCode', <String, dynamic>{
      'code': code,
    });
  }

  /// Watches both deterministic participant fields rather than relying on an
  /// array-contains query. The matching Firestore rule can therefore prove
  /// that every document returned to a query belongs to the signed-in user.
  Stream<List<TrustedConnection>> watchConnections() {
    final user = currentUser;
    if (user == null) return Stream.value(const <TrustedConnection>[]);

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? aSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? bSubscription;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> aDocs = const [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bDocs = const [];
    var aReady = false;
    var bReady = false;

    late final StreamController<List<TrustedConnection>> controller;

    void emit() {
      if (!aReady || !bReady || controller.isClosed) return;
      final byId = <String, TrustedConnection>{};
      for (final document in <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...aDocs,
        ...bDocs,
      ]) {
        byId[document.id] = TrustedConnection.fromDocument(document);
      }
      final connections = byId.values.toList(growable: false);
      connections.sort((a, b) {
        if (a.status == b.status) {
          return a.otherName(user.uid).compareTo(b.otherName(user.uid));
        }
        if (a.pending) return -1;
        if (b.pending) return 1;
        return 0;
      });
      controller.add(connections);
    }

    controller = StreamController<List<TrustedConnection>>(
      onListen: () {
        aSubscription = _firestore
            .collection('connections')
            .where('aUid', isEqualTo: user.uid)
            .snapshots()
            .listen(
          (snapshot) {
            aDocs = snapshot.docs;
            aReady = true;
            emit();
          },
          onError: controller.addError,
        );
        bSubscription = _firestore
            .collection('connections')
            .where('bUid', isEqualTo: user.uid)
            .snapshots()
            .listen(
          (snapshot) {
            bDocs = snapshot.docs;
            bReady = true;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await aSubscription?.cancel();
        await bSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<List<TrustedConnection>> getConnections() async {
    final user = _requireUser();
    final snapshots = await Future.wait([
      _firestore
          .collection('connections')
          .where('aUid', isEqualTo: user.uid)
          .get(),
      _firestore
          .collection('connections')
          .where('bUid', isEqualTo: user.uid)
          .get(),
    ]);
    final byId = <String, TrustedConnection>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        byId[document.id] = TrustedConnection.fromDocument(document);
      }
    }
    return byId.values.toList(growable: false);
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
    _requireUser();
    final cleanRelationship = relationship.trim().isEmpty
        ? 'Trusted person'
        : relationship.trim();
    if (cleanRelationship.length > 40) {
      throw StateError('Keep the relationship label under 40 characters.');
    }
    await _cloudActions.call('setTrustedPersonPreference', <String, dynamic>{
      'otherUid': otherUid,
      'relationship': cleanRelationship,
      'scope': scope == 'household' ? 'household' : 'friend',
    });
  }

  Future<void> acceptConnection(TrustedConnection connection) async {
    final user = _requireUser();
    if (!connection.isIncomingFor(user.uid)) {
      throw StateError('Only the invited person can accept this request.');
    }
    await _cloudActions.call('acceptTrustedConnection', <String, dynamic>{
      'connectionId': connection.id,
    });
  }

  Future<void> declineOrRemoveConnection(TrustedConnection connection) async {
    final user = _requireUser();
    if (!connection.memberUids.contains(user.uid)) {
      throw StateError('This connection is not available to your account.');
    }
    await _cloudActions.call('removeTrustedConnection', <String, dynamic>{
      'connectionId': connection.id,
    });
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
    _requireUser();
    await _cloudActions.call('setLocationShare', <String, dynamic>{
      'viewerUid': viewerUid,
      'active': active,
    });
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
}
