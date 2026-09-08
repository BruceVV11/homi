import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationStatusSnapshot {
  const LocationStatusSnapshot({
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
  final DateTime updatedAt;
}

class LocationStatusService {
  LocationStatusService({required this.firebaseReady});

  final bool firebaseReady;
  final Battery _battery = Battery();

  Future<LocationStatusSnapshot> captureCurrentStatus() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location is switched off on this phone.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was not granted.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is disabled in Android Settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final batteryPercent = await _battery.batteryLevel;
    final batteryState = await _battery.batteryState;

    final snapshot = LocationStatusSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      batteryPercent: batteryPercent,
      isCharging: batteryState == BatteryState.charging || batteryState == BatteryState.full,
      updatedAt: DateTime.now(),
    );

    await _syncIfSignedIn(snapshot);
    return snapshot;
  }

  Future<void> _syncIfSignedIn(LocationStatusSnapshot snapshot) async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('locations').doc(user.uid).set({
      'latitude': snapshot.latitude,
      'longitude': snapshot.longitude,
      'accuracyMeters': snapshot.accuracyMeters,
      'batteryPercent': snapshot.batteryPercent,
      'isCharging': snapshot.isCharging,
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'foreground_manual',
    }, SetOptions(merge: true));
  }
}
