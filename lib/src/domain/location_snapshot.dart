class LocationSnapshot {
  const LocationSnapshot({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.batteryPercent,
    required this.isCharging,
    required this.isPrecise,
  });

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
  final int? batteryPercent;
  final bool? isCharging;
  final bool isPrecise;

  bool get isFresh => DateTime.now().difference(recordedAt) < const Duration(minutes: 10);

  Map<String, Object?> toJson() => {
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'batteryPercent': batteryPercent,
        'isCharging': isCharging,
        'isPrecise': isPrecise,
      };

  factory LocationSnapshot.fromJson(Map<String, Object?> json) {
    return LocationSnapshot(
      userId: json['userId']! as String,
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt']! as String),
      accuracyMeters: (json['accuracyMeters']! as num).toDouble(),
      batteryPercent: json['batteryPercent'] as int?,
      isCharging: json['isCharging'] as bool?,
      isPrecise: json['isPrecise'] as bool? ?? true,
    );
  }
}
