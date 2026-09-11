enum HomiHouseholdRole {
  owner,
  member;

  static HomiHouseholdRole fromValue(Object? value) =>
      value == 'owner' ? HomiHouseholdRole.owner : HomiHouseholdRole.member;

  String get label => switch (this) {
        HomiHouseholdRole.owner => 'Owner',
        HomiHouseholdRole.member => 'Member',
      };
}

class HomiHousehold {
  const HomiHousehold({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.pendingInviteUids,
    required this.memberLimit,
  });

  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final List<String> pendingInviteUids;
  final int memberLimit;

  int get reservedSeats => memberUids.length + pendingInviteUids.length;
  int get availableSeats =>
      (memberLimit - reservedSeats).clamp(0, memberLimit).toInt();
  bool get full => availableSeats == 0;
  bool isOwner(String uid) => ownerUid == uid;
  bool contains(String uid) => memberUids.contains(uid);
}

class HomiHouseholdMember {
  const HomiHouseholdMember({
    required this.uid,
    required this.displayName,
    required this.role,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final HomiHouseholdRole role;
}

class HomiHouseholdInvite {
  const HomiHouseholdInvite({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.inviterUid,
    required this.inviterName,
    required this.inviteeUid,
    required this.inviteeName,
    this.inviteePhotoUrl,
    this.createdAt,
  });

  final String id;
  final String householdId;
  final String householdName;
  final String inviterUid;
  final String inviterName;
  final String inviteeUid;
  final String inviteeName;
  final String? inviteePhotoUrl;
  final DateTime? createdAt;
}
