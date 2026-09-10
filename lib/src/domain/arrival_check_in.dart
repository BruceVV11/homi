enum ArrivalPlaceKind { home, work }

extension ArrivalPlaceKindLabel on ArrivalPlaceKind {
  String get storageKey => name;

  String get label => switch (this) {
        ArrivalPlaceKind.home => 'Home',
        ArrivalPlaceKind.work => 'Work',
      };

  String get arrivalLabel => switch (this) {
        ArrivalPlaceKind.home => 'arrived home',
        ArrivalPlaceKind.work => 'arrived at work',
      };
}

class ArrivalCheckInPlace {
  const ArrivalCheckInPlace({
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.recipientUids,
    this.address,
    this.lastNotifiedAt,
  });

  final ArrivalPlaceKind kind;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final List<String> recipientUids;
  final String? address;
  final DateTime? lastNotifiedAt;

  ArrivalCheckInPlace copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    List<String>? recipientUids,
    String? address,
    DateTime? lastNotifiedAt,
    bool clearAddress = false,
    bool clearLastNotifiedAt = false,
  }) {
    return ArrivalCheckInPlace(
      kind: kind,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      recipientUids: recipientUids ?? this.recipientUids,
      address: clearAddress ? null : (address ?? this.address),
      lastNotifiedAt:
          clearLastNotifiedAt ? null : (lastNotifiedAt ?? this.lastNotifiedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.storageKey,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'recipientUids': recipientUids,
        if (address != null && address!.trim().isNotEmpty)
          'address': address!.trim(),
        if (lastNotifiedAt != null)
          'lastNotifiedAt': lastNotifiedAt!.toIso8601String(),
      };

  factory ArrivalCheckInPlace.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final radius = json['radiusMeters'];
    final kind = json['kind'] == 'work'
        ? ArrivalPlaceKind.work
        : ArrivalPlaceKind.home;
    if (latitude is! num || longitude is! num || radius is! num) {
      throw const FormatException('Saved check-in place is incomplete.');
    }
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radius < 75 ||
        radius > 1000) {
      throw const FormatException('Saved check-in place is outside its limits.');
    }
    final recipients = (json['recipientUids'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .take(10)
            .toList(growable: false) ??
        const <String>[];
    final rawAddress = json['address'];
    final address = rawAddress is String && rawAddress.trim().isNotEmpty
        ? rawAddress.trim()
        : null;
    return ArrivalCheckInPlace(
      kind: kind,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      radiusMeters: radius.toDouble(),
      recipientUids: recipients,
      address: address,
      lastNotifiedAt: DateTime.tryParse(
        json['lastNotifiedAt'] as String? ?? '',
      ),
    );
  }
}

class ArrivalCheckInConfig {
  const ArrivalCheckInConfig({
    this.enabled = false,
    this.home,
    this.work,
  });

  final bool enabled;
  final ArrivalCheckInPlace? home;
  final ArrivalCheckInPlace? work;

  Iterable<ArrivalCheckInPlace> get configuredPlaces sync* {
    if (home != null) yield home!;
    if (work != null) yield work!;
  }

  ArrivalCheckInPlace? place(ArrivalPlaceKind kind) => switch (kind) {
        ArrivalPlaceKind.home => home,
        ArrivalPlaceKind.work => work,
      };

  ArrivalCheckInConfig withPlace(ArrivalCheckInPlace place) {
    return ArrivalCheckInConfig(
      enabled: enabled,
      home: place.kind == ArrivalPlaceKind.home ? place : home,
      work: place.kind == ArrivalPlaceKind.work ? place : work,
    );
  }

  ArrivalCheckInConfig removePlace(ArrivalPlaceKind kind) {
    return ArrivalCheckInConfig(
      enabled: enabled,
      home: kind == ArrivalPlaceKind.home ? null : home,
      work: kind == ArrivalPlaceKind.work ? null : work,
    );
  }

  ArrivalCheckInConfig copyWith({bool? enabled}) => ArrivalCheckInConfig(
        enabled: enabled ?? this.enabled,
        home: home,
        work: work,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        if (home != null) 'home': home!.toJson(),
        if (work != null) 'work': work!.toJson(),
      };

  factory ArrivalCheckInConfig.fromJson(Map<String, dynamic> json) {
    ArrivalCheckInPlace? readPlace(String key) {
      final value = json[key];
      if (value is! Map) return null;
      return ArrivalCheckInPlace.fromJson(Map<String, dynamic>.from(value));
    }

    return ArrivalCheckInConfig(
      enabled: json['enabled'] == true,
      home: readPlace('home'),
      work: readPlace('work'),
    );
  }
}

enum ArrivalZoneTransition { none, arrived, left }

ArrivalZoneTransition detectArrivalZoneTransition({
  required bool? wasInside,
  required double distanceMeters,
  required double radiusMeters,
  double exitMarginMeters = 100,
}) {
  if (wasInside == null) return ArrivalZoneTransition.none;
  if (!wasInside && distanceMeters <= radiusMeters) {
    return ArrivalZoneTransition.arrived;
  }
  if (wasInside && distanceMeters > radiusMeters + exitMarginMeters) {
    return ArrivalZoneTransition.left;
  }
  return ArrivalZoneTransition.none;
}