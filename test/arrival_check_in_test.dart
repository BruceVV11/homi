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

  test('check-in config persists local place settings safely', () {
    final source = ArrivalCheckInConfig(
      enabled: true,
      home: ArrivalCheckInPlace(
        kind: ArrivalPlaceKind.home,
        latitude: -29.8587,
        longitude: 31.0218,
        radiusMeters: 250,
        recipientUids: const <String>['trusted-a', 'trusted-b'],
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
      restored.home!.lastNotifiedAt,
      DateTime.utc(2026, 9, 10, 18, 30),
    );
  });
}
