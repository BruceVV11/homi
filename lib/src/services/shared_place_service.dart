import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/arrival_check_in.dart';

class HomiSharedPlace {
  const HomiSharedPlace({
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final ArrivalPlaceKind kind;
  final double latitude;
  final double longitude;
  final String address;
}

/// Reads Home/Work for the map details surface without broadening access.
///
/// The current user's own places come from local preferences. Another user's
/// place is read only from the narrow `sharedPlaces` document allowed by
/// Firestore rules for an explicitly selected viewer with an active location
/// share and accepted Homi connection.
class HomiSharedPlaceService {
  HomiSharedPlaceService({required this.firebaseReady});

  static const _localStoragePrefix = 'homi.arrivalCheckIns.v1';

  final bool firebaseReady;

  Future<Map<ArrivalPlaceKind, HomiSharedPlace>> placesFor(
    String ownerUid,
  ) async {
    final uid = ownerUid.trim();
    if (uid.isEmpty) return const <ArrivalPlaceKind, HomiSharedPlace>{};
    final currentUid = firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
    if (currentUid == uid) return _localPlaces(uid);
    if (currentUid == null) return const <ArrivalPlaceKind, HomiSharedPlace>{};

    final results = await Future.wait(
      ArrivalPlaceKind.values.map((kind) => _remotePlace(uid, kind)),
    );
    return <ArrivalPlaceKind, HomiSharedPlace>{
      for (final place in results)
        if (place != null) place.kind: place,
    };
  }

  Future<Map<ArrivalPlaceKind, HomiSharedPlace>> _localPlaces(
    String uid,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_localStoragePrefix.$uid');
    if (raw == null || raw.isEmpty) {
      return const <ArrivalPlaceKind, HomiSharedPlace>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <ArrivalPlaceKind, HomiSharedPlace>{};
      final config = ArrivalCheckInConfig.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return <ArrivalPlaceKind, HomiSharedPlace>{
        for (final place in config.configuredPlaces)
          place.kind: HomiSharedPlace(
            kind: place.kind,
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address?.trim().isNotEmpty == true
                ? place.address!.trim()
                : '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
          ),
      };
    } catch (_) {
      return const <ArrivalPlaceKind, HomiSharedPlace>{};
    }
  }

  Future<HomiSharedPlace?> _remotePlace(
    String ownerUid,
    ArrivalPlaceKind kind,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sharedPlaces')
          .doc(ownerUid)
          .collection('places')
          .doc(kind.storageKey)
          .get();
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final latitude = data['latitude'];
      final longitude = data['longitude'];
      final address = data['address'];
      if (latitude is! num || longitude is! num || address is! String) {
        return null;
      }
      return HomiSharedPlace(
        kind: kind,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        address: address.trim().isEmpty
            ? '${latitude.toDouble().toStringAsFixed(5)}, ${longitude.toDouble().toStringAsFixed(5)}'
            : address.trim(),
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'unavailable') {
        return null;
      }
      rethrow;
    }
  }
}
