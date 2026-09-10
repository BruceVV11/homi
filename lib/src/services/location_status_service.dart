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
  static const _arrivalMonitoringEnabledKey =
      'homi.location.arrivalMonitoringEnabled';
  static const _minimumCloudWriteGap = Duration(seconds: 30);

  final bool firebaseReady;
  final Battery _battery = Battery();
  final StreamController<LocationStatusSnapshot> _updates =
      StreamController<LocationStatusSnapshot>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  LocationStatusSnapshot? _latest;
  DateTime? _lastCloudSyncAt;
  bool _cloudSyncInFlight = false;
  bool _liveSharingRequested = false;
  bool _arrivalMonitoringRequested = false;

  Stream<LocationStatusSnapshot> get updates => _updates.stream;
  LocationStatusSnapshot? get latest => _latest;

  /// Kept for the established People UI: this represents the user's explicit
  /// Live updates choice, not whether another feature is sharing the same
  /// Android foreground location stream.
  bool get isStreaming => _liveSharingRequested;

  bool get isBackgroundLocationActive => _positionSubscription != null;

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
    _liveSharingRequested = prefs.getBool(_continuousEnabledKey) ?? false;
    return _liveSharingRequested;
  }

  Future<bool> arrivalMonitoringEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _arrivalMonitoringRequested =
        prefs.getBool(_arrivalMonitoringEnabledKey) ?? false;
    return _arrivalMonitoringRequested;
  }

  /// Synchronizes the local check-in feature's user-scoped enabled state into
  /// the shared location-stream coordinator without opening a permission UI.
  Future<void> syncArrivalMonitoringPreference(bool enabled) async {
    _arrivalMonitoringRequested = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_arrivalMonitoringEnabledKey, enabled);
    if (!enabled && !await continuousSharingEnabled()) {
      await _stopPositionStream();
    }
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
    bool syncCloud = true,
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
    return _snapshotFromPosition(
      position,
      source: 'foreground_refresh',
      syncCloud: syncCloud,
    );
  }

  Future<void> startContinuousSharing() async {
    await _ensureBackgroundLocation(
      signInMessage:
          'Sign in to share your live location with people you trust.',
      permissionMessage:
          'For background sharing, set Homi location access to “Allow all the time” in Android Settings.',
    );

    _liveSharingRequested = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continuousEnabledKey, true);
    try {
      await _startPositionStream();
      final current = _latest;
      if (current != null) {
        await _syncIfSignedIn(current, source: 'continuous_start');
      }
    } catch (_) {
      _liveSharingRequested = false;
      await prefs.setBool(_continuousEnabledKey, false);
      rethrow;
    }
  }

  Future<void> startArrivalMonitoring() async {
    await _ensureBackgroundLocation(
      signInMessage: 'Sign in to use arrival check-ins.',
      permissionMessage:
          'For background check-ins, set Homi location access to “Allow all the time” in Android Settings.',
    );
    await _startPositionStream();
    await syncArrivalMonitoringPreference(true);
  }

  Future<bool> resumeContinuousSharingIfEnabled() async {
    final liveEnabled = await continuousSharingEnabled();
    final arrivalEnabled = await arrivalMonitoringEnabled();
    if (!liveEnabled && !arrivalEnabled) return false;
    if (!firebaseReady || FirebaseAuth.instance.currentUser == null) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) return false;
    await _startPositionStream();

    // Existing callers use this return value to render the explicit Live
    // updates switch. Arrival-only monitoring must not make that switch look on.
    return liveEnabled;
  }

  Future<void> stopContinuousSharing() async {
    _liveSharingRequested = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continuousEnabledKey, false);
    if (!await arrivalMonitoringEnabled()) {
      await _stopPositionStream();
    }
  }

  Future<void> stopArrivalMonitoring() async {
    await syncArrivalMonitoringPreference(false);
  }

  Future<void> _stopPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Clears location state stored by Homi on this device. Android's permission
  /// itself remains under the user's system settings and is never changed
  /// silently by an in-app data reset.
  Future<void> clearCachedStatus() async {
    _liveSharingRequested = false;
    _arrivalMonitoringRequested = false;
    await _stopPositionStream();
    _latest = null;
    _lastCloudSyncAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedStatusKey);
    await prefs.remove(_continuousEnabledKey);
    await prefs.remove(_arrivalMonitoringEnabledKey);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<void> _ensureBackgroundLocation({
    required String signInMessage,
    required String permissionMessage,
  }) async {
    if (!firebaseReady || FirebaseAuth.instance.currentUser == null) {
      throw StateError(signInMessage);
    }
    await _ensureLocationService();
    final permission = await _permission(requestIfNeeded: true);
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is disabled in Android Settings.');
    }
    if (permission != LocationPermission.always) {
      throw StateError(permissionMessage);
    }
  }

  Future<void> _startPositionStream() async {
    if (_positionSubscription != null) return;

    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
        intervalDuration: const Duration(minutes: 2),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Homi location',
          notificationText: 'Live location or arrival check-ins are active.',
          notificationChannelName: 'Live location',
          notificationIcon: const AndroidResource(
            name: 'homi_notification',
            defType: 'drawable',
          ),
          enableWifiLock: false,
          enableWakeLock: false,
          setOngoing: true,
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
            syncCloud: _liveSharingRequested,
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
        syncCloud: _liveSharingRequested,
      );
    } catch (_) {
      // The stream remains active even if the immediate refresh times out.
    }
  }

  Future<LocationStatusSnapshot> _snapshotFromPosition(
    Position position, {
    required String source,
    required bool syncCloud,
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
    if (syncCloud) {
      await _syncIfSignedIn(snapshot, source: source);
    }
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
    if (!firebaseReady || _cloudSyncInFlight) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('locations').doc(user.uid);
    _cloudSyncInFlight = true;
    try {
      if (_lastCloudSyncAt == null) {
        try {
          final existing = await ref.get();
          final remoteUpdatedAt = existing.data()?['updatedAt'];
          if (remoteUpdatedAt is Timestamp) {
            _lastCloudSyncAt = remoteUpdatedAt.toDate();
          }
        } catch (_) {
          // A read failure does not prevent the normal Firestore write/retry
          // path from operating when connectivity returns.
        }
      }

      final now = DateTime.now();
      final previous = _lastCloudSyncAt;
      if (previous != null && now.difference(previous) < _minimumCloudWriteGap) {
        return;
      }

      await ref.set({
        'latitude': snapshot.latitude,
        'longitude': snapshot.longitude,
        'accuracyMeters': snapshot.accuracyMeters,
        'batteryPercent': snapshot.batteryPercent,
        'isCharging': snapshot.isCharging,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': source,
      }, SetOptions(merge: true));
      _lastCloudSyncAt = now;
    } finally {
      _cloudSyncInFlight = false;
    }
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
    await _stopPositionStream();
    await _updates.close();
  }
}
