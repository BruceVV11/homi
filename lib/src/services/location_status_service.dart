import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'batteryPercent': batteryPercent,
        'isCharging': isCharging,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LocationStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final accuracy = json['accuracyMeters'];
    final battery = json['batteryPercent'];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (latitude is! num ||
        longitude is! num ||
        accuracy is! num ||
        battery is! num ||
        updatedAt == null) {
      throw const FormatException('Location snapshot is incomplete.');
    }
    return LocationStatusSnapshot(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracyMeters: accuracy.toDouble(),
      batteryPercent: battery.toInt().clamp(0, 100).toInt(),
      isCharging: json['isCharging'] == true,
      updatedAt: updatedAt,
    );
  }
}

class LocationStatusService {
  LocationStatusService({required this.firebaseReady});

  static const _cachedStatusKey = 'homi.location.cachedStatus';
  static const _continuousEnabledKey = 'homi.location.continuousEnabled';

  final bool firebaseReady;
  final Battery _battery = Battery();
  final StreamController<LocationStatusSnapshot> _updates =
      StreamController<LocationStatusSnapshot>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  LocationStatusSnapshot? _latest;

  Stream<LocationStatusSnapshot> get updates => _updates.stream;
  LocationStatusSnapshot? get latest => _latest;
  bool get isStreaming => _positionSubscription != null;

  Future<LocationStatusSnapshot?> loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedStatusKey);
    if (raw == null || raw.isEmpty) return _latest;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _latest;
      _latest = LocationStatusSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return _latest;
    } catch (_) {
      return _latest;
    }
  }

  Future<bool> continuousSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_continuousEnabledKey) ?? false;
  }

  Future<LocationStatusSnapshot?> refreshIfAlreadyAllowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return loadCachedStatus();
    }
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return loadCachedStatus();
    }
    return captureCurrentStatus(requestPermission: false);
  }

  Future<LocationStatusSnapshot> captureCurrentStatus({
    bool requestPermission = true,
  }) async {
    await _ensureLocationService();
    final permission = await _permission(requestIfNeeded: requestPermission);
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw StateError('Location permission was not granted.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return _snapshotFromPosition(position, source: 'foreground_refresh');
  }

  Future<void> startContinuousSharing() async {
    if (!firebaseReady || FirebaseAuth.instance.currentUser == null) {
      throw StateError(
        'Sign in to share your live location with people you trust.',
      );
    }
    await _ensureLocationService();
    final permission = await _permission(requestIfNeeded: true);
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is disabled in Android Settings.',
      );
    }
    if (permission != LocationPermission.always) {
      throw StateError(
        'For background sharing, set Homi location access to “Allow all the time” in Android Settings.',
      );
    }

    await _startPositionStream();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continuousEnabledKey, true);
  }

  Future<bool> resumeContinuousSharingIfEnabled() async {
    if (!await continuousSharingEnabled()) return false;
    if (!firebaseReady || FirebaseAuth.instance.currentUser == null) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) return false;
    await _startPositionStream();
    return true;
  }

  Future<void> stopContinuousSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continuousEnabledKey, false);
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> _startPositionStream() async {
    if (_positionSubscription != null) return;

    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = const AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
        intervalDuration: Duration(minutes: 2),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Homi location sharing is on',
          notificationText:
              'Sharing your latest location with the people you chose.',
          enableWakeLock: false,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) async {
        try {
          await _snapshotFromPosition(
            position,
            source: 'continuous_foreground_service',
          );
        } catch (_) {
          // A single failed battery/network sync should not stop location
          // collection. The next position update retries naturally.
        }
      },
      onError: (_) async {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
      },
    );

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _snapshotFromPosition(
        position,
        source: 'continuous_start',
      );
    } catch (_) {
      // The stream remains active even if the immediate refresh times out.
    }
  }

  Future<LocationStatusSnapshot> _snapshotFromPosition(
    Position position, {
    required String source,
  }) async {
    final batteryPercent = await _battery.batteryLevel;
    final batteryState = await _battery.batteryState;
    final snapshot = LocationStatusSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      batteryPercent: batteryPercent,
      isCharging: batteryState == BatteryState.charging ||
          batteryState == BatteryState.full,
      updatedAt: DateTime.now(),
    );

    _latest = snapshot;
    await _persist(snapshot);
    await _syncIfSignedIn(snapshot, source: source);
    if (!_updates.isClosed) _updates.add(snapshot);
    return snapshot;
  }

  Future<void> _persist(LocationStatusSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedStatusKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> _syncIfSignedIn(
    LocationStatusSnapshot snapshot, {
    required String source,
  }) async {
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
      'source': source,
    }, SetOptions(merge: true));
  }

  Future<void> _ensureLocationService() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location is switched off on this phone.');
    }
  }

  Future<LocationPermission> _permission({
    required bool requestIfNeeded,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (requestIfNeeded && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _updates.close();
  }
}
