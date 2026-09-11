import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/homi_household.dart';

void main() {
  group('HomiHousehold', () {
    test('counts members and pending invitations against the seat limit', () {
      const household = HomiHousehold(
        id: 'home-1',
        name: 'Our home',
        ownerUid: 'owner',
        memberUids: <String>['owner', 'member'],
        pendingInviteUids: <String>['pending'],
        memberLimit: 4,
      );

      expect(household.reservedSeats, 3);
      expect(household.availableSeats, 1);
      expect(household.full, isFalse);
      expect(household.isOwner('owner'), isTrue);
      expect(household.contains('member'), isTrue);
    });

    test('never reports negative available seats', () {
      const household = HomiHousehold(
        id: 'home-1',
        name: 'Our home',
        ownerUid: 'owner',
        memberUids: <String>['owner', 'a', 'b', 'c'],
        pendingInviteUids: <String>['stale-pending'],
        memberLimit: 4,
      );

      expect(household.availableSeats, 0);
      expect(household.full, isTrue);
    });
  });

  group('HomiHouseholdRole', () {
    test('parses owner explicitly and defaults other values to member', () {
      expect(
        HomiHouseholdRole.fromValue('owner'),
        HomiHouseholdRole.owner,
      );
      expect(
        HomiHouseholdRole.fromValue('member'),
        HomiHouseholdRole.member,
      );
      expect(
        HomiHouseholdRole.fromValue(null),
        HomiHouseholdRole.member,
      );
    });
  });
}
