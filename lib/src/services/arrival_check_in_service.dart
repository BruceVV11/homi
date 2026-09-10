import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/arrival_check_in.dart';
import 'google_places_service.dart';
import 'homi_cloud_actions.dart';
import 'location_status_service.dart';

class ArrivalCheckInService extends ChangeNotifier {
  ArrivalCheckInService({
    required this.firebaseReady,
    required this.locationService,
  }) : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  static const _storagePrefix = 'homi.arrivalCheckIns.v1';
  static const _pendingCloudClearPrefix =
      'homi.arrivalCheckIns.pendingPlaceClear.v1';
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

    await _flushPendingSharedPlaceClear(uid);

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
      final snapshot = await locationService.captureCurrentStatus(
        syncCloud: false,
      );
      final address = await _readableAddress(
        snapshot.latitude,
        snapshot.longitude,
      );
      final candidate = _replacementCandidate(
        kind: kind,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        address: address,
        placeId: null,
      );
      await _syncCandidateIfShared(candidate);
      _config = _config.withPlace(candidate);
      _inside[kind] = true;
      _lastError = null;
      await _save();
      notifyListeners();
      return candidate;
    } finally {
      _setBusy(false);
    }
  }

  Future<ArrivalCheckInPlace> saveGooglePlaceAs(
    ArrivalPlaceKind kind,
    HomiResolvedPlace resolved,
  ) async {
    _requireSignedIn();
    _setBusy(true);
    try {
      final candidate = _replacementCandidate(
        kind: kind,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
        address: resolved.address,
        placeId: resolved.placeId,
      );
      await _syncCandidateIfShared(candidate);
      _config = _config.withPlace(candidate);
      _inside.remove(kind);
      _lastError = null;
      await _save();
      notifyListeners();
      return candidate;
    } finally {
      _setBusy(false);
    }
  }

  /// Retained as a non-Google fallback for older flows/tests. The primary 0.9.2
  /// address picker uses Google Places Autocomplete and saveGooglePlaceAs.
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
      final candidate = _replacementCandidate(
        kind: kind,
        latitude: match.latitude,
        longitude: match.longitude,
        address: resolvedAddress,
        placeId: null,
      );
      await _syncCandidateIfShared(candidate);
      _config = _config.withPlace(candidate);
      _inside.remove(kind);
      _lastError = null;
      await _save();
      notifyListeners();
      return candidate;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(
        'Homi could not resolve that address right now. Check the address and your connection, then try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  ArrivalCheckInPlace _replacementCandidate({
    required ArrivalPlaceKind kind,
    required double latitude,
    required double longitude,
    required String address,
    required String? placeId,
  }) {
    final existing = _config.place(kind);
    return ArrivalCheckInPlace(
      kind: kind,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: existing?.radiusMeters ?? _defaultRadiusMeters,
      recipientUids: existing?.recipientUids ?? const <String>[],
      address: address,
      placeId: placeId,
      shareAddressWithRecipients:
          existing?.shareAddressWithRecipients ?? false,
      // A moved place is a new arrival boundary. The old place cooldown must
      // not suppress the first legitimate arrival at the new location.
      lastNotifiedAt: null,
    );
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
      // Coordinates remain valid even when reverse geocoding is unavailable.
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

    final candidate = place.copyWith(
      recipientUids: recipients,
      shareAddressWithRecipients:
          recipients.isEmpty ? false : place.shareAddressWithRecipients,
    );

    // If precise-place visibility is already on, update the cloud ACL before
    // changing local truth so removing a viewer cannot leave stale access.
    if (place.shareAddressWithRecipients ||
        candidate.shareAddressWithRecipients) {
      await _syncSharedPlace(candidate);
    }

    _config = _config.withPlace(candidate);
    if (_config.enabled && !_hasUsablePlace(_config)) {
      _config = _config.copyWith(enabled: false);
      await locationService.stopArrivalMonitoring();
    }
    await _save();
    notifyListeners();
  }

  Future<void> setShareAddressWithRecipients(
    ArrivalPlaceKind kind,
    bool enabled,
  ) async {
    final place = _requirePlace(kind);
    if (enabled && place.recipientUids.isEmpty) {
      throw StateError(
        'Choose at least one trusted person for ${kind.label} first.',
      );
    }
    final candidate = place.copyWith(shareAddressWithRecipients: enabled);

    // Cloud first for both grant and revoke so the switch always reflects the
    // actual privacy boundary, not only a local preference.
    await _syncSharedPlace(candidate);
    _config = _config.withPlace(candidate);
    await _save();
    notifyListeners();
  }

  Future<void> removePlace(ArrivalPlaceKind kind) async {
    _requireSignedIn();
    final place = _requirePlace(kind);
    if (place.shareAddressWithRecipients) {
      await _clearSharedPlace(kind);
    }
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

  Future<void> _syncCandidateIfShared(ArrivalCheckInPlace candidate) async {
    if (!candidate.shareAddressWithRecipients) return;
    await _syncSharedPlace(candidate);
  }

  Future<void> _syncSharedPlace(ArrivalCheckInPlace place) async {
    if (!place.shareAddressWithRecipients || place.recipientUids.isEmpty) {
      await _clearSharedPlace(place.kind);
      return;
    }
    final address = place.address?.trim();
    if (address == null || address.isEmpty) {
      throw StateError('Set a readable ${place.kind.label} address first.');
    }
    await _cloudActions.call('setSharedArrivalPlace', <String, dynamic>{
      'kind': place.kind.storageKey,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'address': address,
      'viewerUids': place.recipientUids,
    });
  }

  Future<void> _clearSharedPlace(ArrivalPlaceKind kind) async {
    await _cloudActions.call('setSharedArrivalPlace', <String, dynamic>{
      'kind': kind.storageKey,
      'clear': true,
    });
  }

  Future<void> _flushPendingSharedPlaceClear(String uid) async {
    if (_preferences?.getBool(_pendingCloudClearKey(uid)) != true) return;
    try {
      await _clearSharedPlace(ArrivalPlaceKind.home);
      await _clearSharedPlace(ArrivalPlaceKind.work);
      await _preferences?.remove(_pendingCloudClearKey(uid));
    } catch (_) {
      // Keep the non-sensitive pending-revocation marker for the next signed-in
      // session. Firestore still independently enforces active location share.
    }
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
      var cloudCleared = false;
      try {
        await _clearSharedPlace(ArrivalPlaceKind.home);
        await _clearSharedPlace(ArrivalPlaceKind.work);
        cloudCleared = true;
      } catch (_) {
        await _preferences?.setBool(_pendingCloudClearKey(uid), true);
      }
      if (cloudCleared) {
        await _preferences?.remove(_pendingCloudClearKey(uid));
      }
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
    await _preferences?.remove(_pendingCloudClearKey(uid));
    if (_activeUid == uid) {
      _config = const ArrivalCheckInConfig();
      _inside.clear();
      await locationService.stopArrivalMonitoring();
      notifyListeners();
    }
  }

  String _storageKey(String uid) => '$_storagePrefix.$uid';
  String _pendingCloudClearKey(String uid) => '$_pendingCloudClearPrefix.$uid';

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
