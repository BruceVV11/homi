import 'dart:convert';

/// Per-device Homi notification preferences.
///
/// Notifications are opt-in at the operating-system level. The category
/// switches below only decide which Homi events may notify this device after
/// permission has been granted.
class HomiNotificationPreferences {
  const HomiNotificationPreferences({
    this.enabled = false,
    this.householdAttention = true,
    this.tasksAndRoutines = true,
    this.people = true,
    this.homiUpdates = true,
    this.serviceNotices = true,
  });

  final bool enabled;
  final bool householdAttention;
  final bool tasksAndRoutines;
  final bool people;
  final bool homiUpdates;
  final bool serviceNotices;

  HomiNotificationPreferences copyWith({
    bool? enabled,
    bool? householdAttention,
    bool? tasksAndRoutines,
    bool? people,
    bool? homiUpdates,
    bool? serviceNotices,
  }) {
    return HomiNotificationPreferences(
      enabled: enabled ?? this.enabled,
      householdAttention: householdAttention ?? this.householdAttention,
      tasksAndRoutines: tasksAndRoutines ?? this.tasksAndRoutines,
      people: people ?? this.people,
      homiUpdates: homiUpdates ?? this.homiUpdates,
      serviceNotices: serviceNotices ?? this.serviceNotices,
    );
  }

  bool allowsCategory(String category) {
    if (!enabled) return false;
    return switch (category) {
      'household' || 'supply' || 'maintenance' => householdAttention,
      'task' || 'routine' => tasksAndRoutines,
      'people' || 'heart' || 'connection' => people,
      'update' || 'product' => homiUpdates,
      'service' || 'security' => serviceNotices,
      _ => true,
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'householdAttention': householdAttention,
        'tasksAndRoutines': tasksAndRoutines,
        'people': people,
        'homiUpdates': homiUpdates,
        'serviceNotices': serviceNotices,
      };

  factory HomiNotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool read(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    return HomiNotificationPreferences(
      enabled: read('enabled', false),
      householdAttention: read('householdAttention', true),
      tasksAndRoutines: read('tasksAndRoutines', true),
      people: read('people', true),
      homiUpdates: read('homiUpdates', true),
      serviceNotices: read('serviceNotices', true),
    );
  }

  String encode() => jsonEncode(toJson());

  factory HomiNotificationPreferences.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Notification preferences must be an object.');
    }
    return HomiNotificationPreferences.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }
}
