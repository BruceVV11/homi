import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/arrival_check_in.dart';
import 'homi_cloud_actions.dart';
import 'location_status_service.dart';

class ArrivalCheckInService extends ChangeNotifier {
  ArrivalCheckInService({
    required this.firebaseReady,
    required this.locationService,
  }) : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  static const _storagePrefix = 'homi.arrivalCheckIns.v1';
  static const _defaultRadiusMeters = 250.0;
  static const _notificationCooldown = Duration(minutes: 60);

  final bool firebaseReady;
  final LocationStatusService locationService;
  final HomiCloudActions _cloudActions;

  SharedPreferences? _preferences;
  StreamSubscription<LocationStatusSnapshot>? _locationSubscription;
  StreamSubscription<User?>? _authSubscription;
  ArrivalCheckInConfig _config = const ArrivalCheckInConfig();
  String? _activeUid;
  String? _lastError;
  bool _initialized = false;
  bool _busy = false;
  final Map<ArrivalPlaceKind, bool> _inside = <ArrivalPlaceKind, bool>{};
  final Set<ArrivalPlaceKind> _sendInFlight = <ArrivalPlaceKind>{};

  ArrivalCheckInConfig get config => _config;
  String? get lastError => _lastError;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get activeUid => _activeUid;

  Future<void> initialize() async {
    if (_initialized) return;
    _preferences = await SharedPreferences.getInstance();
    _locationSubscription = locationService.updates.listen(
      (snapshot) => unawaited(_evaluate(snapshot)),
    );

    if (firebaseReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) => unawaited(_loadForUid(user?.uid)),
      );
      await _loadForUid(FirebaseAuth.instance.currentUser?.uid);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadForUid(String? uid) async {
    _activeUid = uid;
    _inside.clear();
    _lastError = null;

    if (uid == null) {
      _config = const ArrivalCheckInConfig();
      await locationService.syncArrivalMonitoringPreference(false);
      notifyListeners();
      return;
    }

    final raw = _preferences?.getString(_storageKey(uid));
    if (raw == null || raw.isEmpty) {
      _config = const ArrivalCheckInConfig();
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException();
        _config = ArrivalCheckInConfig.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      } catch (_) {
        _config = const ArrivalCheckInConfig();
        _lastError = 'Saved check-in settings could not be read.';
      }
    }

    await locationService.syncArrivalMonitoringPreference(_config.enabled);
    if (_config.enabled) {
      // This resume path never opens a permission prompt. If background access
      // was revoked, the Safety & check-ins screen explains how to restore it.
      await locationService.resumeContinuousSharingIfEnabled();
    }

    final latest = locationService.latest;
    if (latest != null) _primeZoneState(latest);
    notifyListeners();
  }

  Future<ArrivalCheckInPlace> saveCurrentLocationAs(
    ArrivalPlaceKind kind,
  ) async {
    _requireSignedIn();
    _setBusy(true);
    try {
      final snapshot = await locationService.captureCurrentStatus();
      final existing = _config.place(kind);
      final place = ArrivalCheckInPlace(
        kind: kind,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        radiusMeters: existing?.radiusMeters ?? _defaultRadiusMeters,
        recipientUids: existing?.recipientUids ?? const <String>[],
        lastNotifiedAt: existing?.lastNotifiedAt,
      );
      _config = _config.withPlace(place);
      _inside[kind] = true;
      _lastError = null;
      await _save();
      notifyListeners();
      return place;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> setRadius(
    ArrivalPlaceKind kind,
    double radiusMeters,
  ) async {
    final place = _requirePlace(kind);
    if (radiusMeters < 75 || radiusMeters > 1000) {
      throw StateError('Choose a check-in radius between 75 m and 1 km.');
    }
    _config = _config.withPlace(place.copyWith(radiusMeters: radiusMeters));
    _inside.remove(kind);
    final latest = locationService.latest;
    if (latest != null) _primePlace(kind, latest);
    await _save();
    notifyListeners();
  }

  Future<void> setRecipients(
    ArrivalPlaceKind kind,
    Iterable<String> recipientUids,
  ) async {
    final place = _requirePlace(kind);
    final ownUid = _requireSignedIn();
    final recipients = recipientUids
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != ownUid)
        .toSet()
        .take(10)
        .toList(growable: false);
    _config = _config.withPlace(place.copyWith(recipientUids: recipients));
    await _save();
    notifyListeners();
  }

  Future<void> removePlace(ArrivalPlaceKind kind) async {
    _requireSignedIn();
    _config = _config.removePlace(kind);
    if (_config.configuredPlaces.every((place) => place.recipientUids.isEmpty)) {
      _config = _config.copyWith(enabled: false);
    }
    _inside.remove(kind);
    await _save();
    if (!_config.enabled) await locationService.stopArrivalMonitoring();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _requireSignedIn();
    if (enabled) {
      final usable = _config.configuredPlaces
          .where((place) => place.recipientUids.isNotEmpty)
          .toList(growable: false);
      if (usable.isEmpty) {
        throw StateError(
          'Set Home or Work and choose who should receive the check-in first.',
        );
      }
      _setBusy(true);
      try {
        await locationService.startArrivalMonitoring();
      } finally {
        _setBusy(false);
      }
    }

    _config = _config.copyWith(enabled: enabled);
    _lastError = null;
    final latest = locationService.latest;
    _inside.clear();
    if (latest != null) _primeZoneState(latest);
    await _save();
    if (!enabled) await locationService.stopArrivalMonitoring();
    notifyListeners();
  }

  void _primeZoneState(LocationStatusSnapshot snapshot) {
    for (final place in _config.configuredPlaces) {
      _primePlace(place.kind, snapshot);
    }
  }

  void _primePlace(ArrivalPlaceKind kind, LocationStatusSnapshot snapshot) {
    final place = _config.place(kind);
    if (place == null) return;
    final distance = Geolocator.distanceBetween(
      snapshot.latitude,
      snapshot.longitude,
      place.latitude,
      place.longitude,
    );
    _inside[kind] = distance <= place.radiusMeters;
  }

  Future<void> _evaluate(LocationStatusSnapshot snapshot) async {
    if (!_config.enabled || _activeUid == null) return;

    for (final place in _config.configuredPlaces) {
      if (place.recipientUids.isEmpty) continue;
      final distance = Geolocator.distanceBetween(
        snapshot.latitude,
        snapshot.longitude,
        place.latitude,
        place.longitude,
      );
      final previous = _inside[place.kind];
      if (previous == null) {
        _inside[place.kind] = distance <= place.radiusMeters;
        continue;
      }

      final transition = detectArrivalZoneTransition(
        wasInside: previous,
        distanceMeters: distance,
        radiusMeters: place.radiusMeters,
      );
      switch (transition) {
        case ArrivalZoneTransition.none:
          break;
        case ArrivalZoneTransition.left:
          _inside[place.kind] = false;
          break;
        case ArrivalZoneTransition.arrived:
          _inside[place.kind] = true;
          await _sendArrival(place.kind);
          break;
      }
    }
  }

  Future<void> _sendArrival(ArrivalPlaceKind kind) async {
    if (_sendInFlight.contains(kind)) return;
    final place = _config.place(kind);
    if (place == null || place.recipientUids.isEmpty) return;

    final last = place.lastNotifiedAt;
    if (last != null && DateTime.now().difference(last) < _notificationCooldown) {
      return;
    }

    _sendInFlight.add(kind);
    try {
      await _cloudActions.call('sendArrivalCheckIn', <String, dynamic>{
        'place': kind.storageKey,
        'recipientUids': place.recipientUids,
      });
      final sentAt = DateTime.now();
      final refreshed = _config.place(kind);
      if (refreshed != null) {
        _config = _config.withPlace(refreshed.copyWith(lastNotifiedAt: sentAt));
        await _save();
      }
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = _friendly(error);
      notifyListeners();
    } finally {
      _sendInFlight.remove(kind);
    }
  }

  Future<void> _save() async {
    final uid = _activeUid;
    if (uid == null) return;
    await _preferences?.setString(_storageKey(uid), jsonEncode(_config.toJson()));
  }

  Future<void> clearStoredForUid(String uid) async {
    if (uid.trim().isEmpty) return;
    await _preferences?.remove(_storageKey(uid));
    if (_activeUid == uid) {
      _config = const ArrivalCheckInConfig();
      _inside.clear();
      await locationService.stopArrivalMonitoring();
      notifyListeners();
    }
  }

  String _storageKey(String uid) => '$_storagePrefix.$uid';

  String _requireSignedIn() {
    if (!firebaseReady) throw StateError('Sign in to use arrival check-ins.');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to use arrival check-ins.');
    return user.uid;
  }

  ArrivalCheckInPlace _requirePlace(ArrivalPlaceKind kind) {
    _requireSignedIn();
    final place = _config.place(kind);
    if (place == null) {
      throw StateError('Set ${kind.label} from your current location first.');
    }
    return place;
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  String _friendly(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    unawaited(_locationSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
