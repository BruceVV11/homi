import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
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
  final Geocoding _geocoding = Geocoding();

  SharedPreferences? _preferences;
  StreamSubscription<LocationStatusSnapshot>? _locationSubscription;
  StreamSubscription<void>? _localDataClearSubscription;
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
    _localDataClearSubscription = locationService.localDataCleared.listen(
      (_) => unawaited(_clearCurrentLocalCheckInData()),
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

    if (_config.enabled && !_hasUsablePlace(_config)) {
      _config = _config.copyWith(enabled: false);
      await _save();
    }
    await locationService.syncArrivalMonitoringPreference(_config.enabled);
    if (_config.enabled) {
      // Startup resume never opens a permission prompt. Do not prime from a
      // cached point; the first fresh stream update establishes zone state.
      await locationService.resumeContinuousSharingIfEnabled();
    }
    notifyListeners();
  }

  Future<ArrivalCheckInPlace> saveCurrentLocationAs(
    ArrivalPlaceKind kind,
  ) async {
    _requireSignedIn();
    _setBusy(true);
    try {
      // Home/Work setup is local-only. It must not refresh the cloud latest
      // location document unless Live updates is independently on.
      final snapshot = await locationService.captureCurrentStatus(
        syncCloud: false,
      );
      final address = await _readableAddress(
        snapshot.latitude,
        snapshot.longitude,
      );
      final place = _replacePlace(
        kind: kind,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        address: address,
      );
      _inside[kind] = true;
      _lastError = null;
      await _save();
      notifyListeners();
      return place;
    } finally {
      _setBusy(false);
    }
  }

  Future<ArrivalCheckInPlace> saveAddressAs(
    ArrivalPlaceKind kind,
    String address,
  ) async {
    _requireSignedIn();
    final query = address.trim();
    if (query.length < 4) {
      throw StateError('Enter a street address or place first.');
    }

    _setBusy(true);
    try {
      final matches = await _geocoding.locationFromAddress(query);
      if (matches.isEmpty) {
        throw StateError('Homi could not find that address.');
      }
      final match = matches.first;
      final resolvedAddress = await _readableAddress(
        match.latitude,
        match.longitude,
        fallback: query,
      );
      final place = _replacePlace(
        kind: kind,
        latitude: match.latitude,
        longitude: match.longitude,
        address: resolvedAddress,
      );
      // An entered address may be somewhere other than the phone's current
      // position, so let the next fresh sample establish inside/outside state.
      _inside.remove(kind);
      _lastError = null;
      await _save();
      notifyListeners();
      return place;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(
        'Homi could not resolve that address right now. Check the address and your connection, then try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  ArrivalCheckInPlace _replacePlace({
    required ArrivalPlaceKind kind,
    required double latitude,
    required double longitude,
    required String address,
  }) {
    final existing = _config.place(kind);
    final place = ArrivalCheckInPlace(
      kind: kind,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: existing?.radiusMeters ?? _defaultRadiusMeters,
      recipientUids: existing?.recipientUids ?? const <String>[],
      address: address,
      lastNotifiedAt: existing?.lastNotifiedAt,
    );
    _config = _config.withPlace(place);
    return place;
  }

  Future<String> _readableAddress(
    double latitude,
    double longitude, {
    String? fallback,
  }) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String?>[
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // The coordinates remain valid even when the platform geocoder cannot
      // provide a friendly label at that moment.
    }
    final safeFallback = fallback?.trim();
    if (safeFallback != null && safeFallback.isNotEmpty) return safeFallback;
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
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
    if (_config.enabled && !_hasUsablePlace(_config)) {
      _config = _config.copyWith(enabled: false);
      await locationService.stopArrivalMonitoring();
    }
    await _save();
    notifyListeners();
  }

  Future<void> removePlace(ArrivalPlaceKind kind) async {
    _requireSignedIn();
    _config = _config.removePlace(kind);
    if (!_hasUsablePlace(_config)) {
      _config = _config.copyWith(enabled: false);
    }
    _inside.remove(kind);
    await _save();
    if (!_config.enabled) await locationService.stopArrivalMonitoring();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _requireSignedIn();
    if (enabled && !_hasUsablePlace(_config)) {
      throw StateError(
        'Set Home or Work and choose who should receive the check-in first.',
      );
    }

    final previous = _config;
    _inside.clear();
    _config = _config.copyWith(enabled: enabled);
    _lastError = null;

    if (enabled) {
      _setBusy(true);
      try {
        await locationService.startArrivalMonitoring();
        // Force a fresh local-only point so enabling never relies on a cached
        // position. A timeout is harmless; the stream will prime on its next
        // fresh update.
        try {
          await locationService.captureCurrentStatus(syncCloud: false);
        } catch (_) {}
      } catch (_) {
        _config = previous;
        _inside.clear();
        rethrow;
      } finally {
        _setBusy(false);
      }
    } else {
      await locationService.stopArrivalMonitoring();
    }

    await _save();
    notifyListeners();
  }

  bool _hasUsablePlace(ArrivalCheckInConfig config) {
    return config.configuredPlaces.any((place) => place.recipientUids.isNotEmpty);
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

  Future<void> _clearCurrentLocalCheckInData() async {
    final uid = _activeUid;
    if (uid != null && uid.isNotEmpty) {
      await _preferences?.remove(_storageKey(uid));
    }
    _config = const ArrivalCheckInConfig();
    _inside.clear();
    _lastError = null;
    notifyListeners();
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
      throw StateError('Set ${kind.label} first.');
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
    unawaited(_localDataClearSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}