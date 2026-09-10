import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/arrival_check_in.dart';

void main() {
  group('arrival check-in zone transitions', () {
    test('initial location establishes state without announcing an arrival', () {
      expect(
        detectArrivalZoneTransition(
          wasInside: null,
          distanceMeters: 20,
          radiusMeters: 250,
        ),
        ArrivalZoneTransition.none,
      );
    });

    test('outside to inside is an arrival', () {
      expect(
        detectArrivalZoneTransition(
          wasInside: false,
          distanceMeters: 249,
          radiusMeters: 250,
        ),
        ArrivalZoneTransition.arrived,
      );
    });

    test('exit margin prevents GPS edge flapping', () {
      expect(
        detectArrivalZoneTransition(
          wasInside: true,
          distanceMeters: 330,
          radiusMeters: 250,
        ),
        ArrivalZoneTransition.none,
      );
      expect(
        detectArrivalZoneTransition(
          wasInside: true,
          distanceMeters: 351,
          radiusMeters: 250,
        ),
        ArrivalZoneTransition.left,
      );
    });
  });

  test('check-in config persists Google place and sharing choices safely', () {
    final source = ArrivalCheckInConfig(
      enabled: true,
      home: ArrivalCheckInPlace(
        kind: ArrivalPlaceKind.home,
        latitude: -29.8587,
        longitude: 31.0218,
        radiusMeters: 250,
        recipientUids: const <String>['trusted-a', 'trusted-b'],
        address: '12 Example Road, Durban, KwaZulu-Natal, South Africa',
        placeId: 'google-place-123',
        shareAddressWithRecipients: true,
        lastNotifiedAt: DateTime.utc(2026, 9, 10, 18, 30),
      ),
    );

    final restored = ArrivalCheckInConfig.fromJson(source.toJson());
    expect(restored.enabled, isTrue);
    expect(restored.home, isNotNull);
    expect(restored.home!.kind, ArrivalPlaceKind.home);
    expect(restored.home!.radiusMeters, 250);
    expect(restored.home!.recipientUids, <String>['trusted-a', 'trusted-b']);
    expect(
      restored.home!.address,
      '12 Example Road, Durban, KwaZulu-Natal, South Africa',
    );
    expect(restored.home!.placeId, 'google-place-123');
    expect(restored.home!.shareAddressWithRecipients, isTrue);
    expect(
      restored.home!.lastNotifiedAt,
      DateTime.utc(2026, 9, 10, 18, 30),
    );
  });

  test('older saved check-in places remain private and readable', () {
    final restored = ArrivalCheckInPlace.fromJson(<String, dynamic>{
      'kind': 'work',
      'latitude': -26.2041,
      'longitude': 28.0473,
      'radiusMeters': 250,
      'recipientUids': <String>['trusted-a'],
    });

    expect(restored.kind, ArrivalPlaceKind.work);
    expect(restored.address, isNull);
    expect(restored.placeId, isNull);
    expect(restored.shareAddressWithRecipients, isFalse);
    expect(restored.recipientUids, <String>['trusted-a']);
  });

  test('copyWith can revoke exact place sharing without changing arrival people', () {
    const source = ArrivalCheckInPlace(
      kind: ArrivalPlaceKind.home,
      latitude: -29.8,
      longitude: 31.0,
      radiusMeters: 250,
      recipientUids: <String>['trusted-a'],
      address: 'Home address',
      shareAddressWithRecipients: true,
    );

    final revoked = source.copyWith(shareAddressWithRecipients: false);
    expect(revoked.shareAddressWithRecipients, isFalse);
    expect(revoked.recipientUids, <String>['trusted-a']);
    expect(revoked.address, 'Home address');
  });
}
