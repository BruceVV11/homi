import 'dart:convert';

enum UtilityType {
  electricity,
  water,
}

extension UtilityTypeDetails on UtilityType {
  String get label => this == UtilityType.electricity ? 'Electricity' : 'Water';

  String get defaultUnit => this == UtilityType.electricity ? 'kWh' : 'kL';

  List<String> get unitOptions => this == UtilityType.electricity
      ? const <String>['kWh', 'Wh', 'MWh', 'units']
      : const <String>['kL', 'L', 'm³', 'units'];
}

class UtilityReading {
  const UtilityReading({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    required this.recordedByName,
    this.notes,
  });

  final String id;
  final UtilityType type;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final String recordedByName;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'value': value,
        'unit': unit,
        'recordedAt': recordedAt.toIso8601String(),
        'recordedByName': recordedByName,
        'notes': notes,
      };

  factory UtilityReading.fromJson(Map<String, dynamic> json) {
    final type = UtilityType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => UtilityType.electricity,
    );
    final rawValue = json['value'];
    return UtilityReading(
      id: json['id'] as String? ?? '',
      type: type,
      value: rawValue is num ? rawValue.toDouble() : 0,
      unit: (json['unit'] as String?)?.trim().isNotEmpty == true
          ? (json['unit'] as String).trim()
          : type.defaultUnit,
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
      recordedByName:
          (json['recordedByName'] as String?)?.trim().isNotEmpty == true
              ? (json['recordedByName'] as String).trim()
              : 'You',
      notes: json['notes'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory UtilityReading.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Utility reading must be a JSON object.');
    }
    return UtilityReading.fromJson(Map<String, dynamic>.from(decoded));
  }
}
