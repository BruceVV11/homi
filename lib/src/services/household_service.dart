import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/homi_household.dart';
import 'homi_cloud_actions.dart';

class HouseholdService {
  HouseholdService({required this.firebaseReady})
      : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  final bool firebaseReady;
  final HomiCloudActions _cloudActions;

  Stream<HomiHousehold?>? _currentHouseholdStream;
  Stream<List<HomiHouseholdInvite>>? _incomingInvitesStream;
  Stream<List<HomiHouseholdInvite>>? _outgoingInvitesStream;
  final Map<String, Stream<List<HomiHouseholdMember>>> _memberStreams =
      <String, Stream<List<HomiHouseholdMember>>>{};
  String? _streamOwnerUid;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  void _ensureStreamOwner(String uid) {
    if (_streamOwnerUid == uid) return;
    _streamOwnerUid = uid;
    _currentHouseholdStream = null;
    _incomingInvitesStream = null;
    _outgoingInvitesStream = null;
    _memberStreams.clear();
  }

  Stream<HomiHousehold?> watchCurrentHousehold() {
    final user = currentUser;
    if (user == null) return Stream.value(null);
    _ensureStreamOwner(user.uid);
    return _currentHouseholdStream ??= _firestore
        .collection('households')
        .where('memberUids', arrayContains: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return _householdFromDocument(snapshot.docs.first);
    });
  }

  Stream<List<HomiHouseholdMember>> watchMembers(String householdId) {
    final user = currentUser;
    final cleanHouseholdId = householdId.trim();
    if (user == null || cleanHouseholdId.isEmpty) {
      return Stream.value(const <HomiHouseholdMember>[]);
    }
    _ensureStreamOwner(user.uid);
    return _memberStreams.putIfAbsent(
      cleanHouseholdId,
      () => _firestore
          .collection('households')
          .doc(cleanHouseholdId)
          .collection('members')
          .snapshots()
          .map((snapshot) {
        final members = snapshot.docs
            .map(_memberFromDocument)
            .toList(growable: false);
        members.sort((a, b) {
          if (a.role != b.role) {
            return a.role == HomiHouseholdRole.owner ? -1 : 1;
          }
          return a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        });
        return members;
      }),
    );
  }

  Stream<List<HomiHouseholdInvite>> watchIncomingInvites() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(const <HomiHouseholdInvite>[]);
    }
    _ensureStreamOwner(user.uid);
    return _incomingInvitesStream ??= _firestore
        .collection('householdInvites')
        .where('inviteeUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final invites = snapshot.docs
          .map(_inviteFromDocument)
          .toList(growable: false);
      invites.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return invites;
    });
  }

  Stream<List<HomiHouseholdInvite>> watchOutgoingInvites() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(const <HomiHouseholdInvite>[]);
    }
    _ensureStreamOwner(user.uid);
    return _outgoingInvitesStream ??= _firestore
        .collection('householdInvites')
        .where('inviterUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(_inviteFromDocument)
            .toList(growable: false));
  }

  Future<String> createHousehold(String name) async {
    _requireUser();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('Give your Household a name.');
    if (trimmed.length > 60) {
      throw StateError('Keep the Household name under 60 characters.');
    }
    final data = await _cloudActions.call('createHousehold', <String, dynamic>{
      'name': trimmed,
    });
    final householdId = (data['householdId'] as String?)?.trim();
    if (householdId == null || householdId.isEmpty) {
      throw StateError(
        'Homi created the Household but could not refresh it yet.',
      );
    }
    return householdId;
  }

  Future<void> renameHousehold(String name) async {
    _requireUser();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('Give your Household a name.');
    if (trimmed.length > 60) {
      throw StateError('Keep the Household name under 60 characters.');
    }
    await _cloudActions.call('renameHousehold', <String, dynamic>{
      'name': trimmed,
    });
  }

  Future<void> inviteMember(String inviteeUid) async {
    _requireUser();
    await _cloudActions.call('inviteHouseholdMember', <String, dynamic>{
      'inviteeUid': inviteeUid,
    });
  }

  Future<void> respondToInvite(String inviteId, {required bool accept}) async {
    _requireUser();
    await _cloudActions.call('respondHouseholdInvite', <String, dynamic>{
      'inviteId': inviteId,
      'action': accept ? 'accept' : 'decline',
    });
  }

  Future<void> cancelInvite(String inviteId) async {
    _requireUser();
    await _cloudActions.call('cancelHouseholdInvite', <String, dynamic>{
      'inviteId': inviteId,
    });
  }

  Future<void> removeMember(String memberUid) async {
    _requireUser();
    await _cloudActions.call('removeHouseholdMember', <String, dynamic>{
      'memberUid': memberUid,
    });
  }

  Future<void> leaveHousehold() async {
    _requireUser();
    await _cloudActions.call('leaveHousehold');
  }

  Future<void> transferOwnership(String memberUid) async {
    _requireUser();
    await _cloudActions.call('transferHouseholdOwnership', <String, dynamic>{
      'memberUid': memberUid,
    });
  }

  Future<void> deleteHousehold() async {
    _requireUser();
    await _cloudActions.call('deleteHousehold');
  }

  HomiHousehold _householdFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final members = (data['memberUids'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final pending = (data['pendingInviteUids'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final configuredLimit = data['memberLimit'];
    return HomiHousehold(
      id: document.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'My Household',
      ownerUid: data['ownerUid'] as String? ?? '',
      memberUids: members,
      pendingInviteUids: pending,
      memberLimit: configuredLimit is num ? configuredLimit.toInt() : 4,
    );
  }

  HomiHouseholdMember _memberFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final name = (data['displayName'] as String?)?.trim();
    return HomiHouseholdMember(
      uid: data['uid'] as String? ?? document.id,
      displayName: name == null || name.isEmpty ? 'Homi user' : name,
      photoUrl: data['photoUrl'] as String?,
      role: HomiHouseholdRole.fromValue(data['role']),
    );
  }

  HomiHouseholdInvite _inviteFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    return HomiHouseholdInvite(
      id: document.id,
      householdId: data['householdId'] as String? ?? '',
      householdName: data['householdName'] as String? ?? 'Homi Household',
      inviterUid: data['inviterUid'] as String? ?? '',
      inviterName: data['inviterName'] as String? ?? 'Homi user',
      inviteeUid: data['inviteeUid'] as String? ?? '',
      inviteeName: data['inviteeName'] as String? ?? 'Homi user',
      inviteePhotoUrl: data['inviteePhotoUrl'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  User _requireUser() {
    if (!firebaseReady) {
      throw StateError('Sign in to use a shared Household.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to use a shared Household.');
    return user;
  }
}
