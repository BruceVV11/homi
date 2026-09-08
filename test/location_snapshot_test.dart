import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/location_snapshot.dart';

void main() {
  test('location snapshot round-trips through json', () {
    final now = DateTime.utc(2026, 9, 8, 5, 0);
    final snapshot = LocationSnapshot(
      userId: 'user-1',
      latitude: -29.8587,
      longitude: 31.0218,
      accuracyMeters: 12.5,
      batteryPercent: 82,
      isCharging: true,
      isPrecise: true,
      recordedAt: now,
    );

    final restored = LocationSnapshot.fromJson(snapshot.toJson());
    expect(restored.userId, 'user-1');
    expect(restored.latitude, snapshot.latitude);
    expect(restored.longitude, snapshot.longitude);
    expect(restored.batteryPercent, 82);
    expect(restored.isCharging, isTrue);
    expect(restored.isPrecise, isTrue);
    expect(restored.recordedAt, now);
  });
}
