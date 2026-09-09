import 'dart:convert';

enum HomeEventType {
  maintenance,
  repair,
}

extension HomeEventTypeLabel on HomeEventType {
  String get label => this == HomeEventType.maintenance ? 'Maintenance' : 'Repair';
}

class HomeEvent {
  const HomeEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.completedByName,
    this.thingId,
    this.notes,
  });

  final String id;
  final HomeEventType type;
  final String title;
  final DateTime date;
  final String completedByName;
  final String? thingId;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'date': date.toIso8601String(),
        'completedByName': completedByName,
        'thingId': thingId,
        'notes': notes,
      };

  factory HomeEvent.fromJson(Map<String, dynamic> json) => HomeEvent(
        id: json['id'] as String? ?? '',
        type: HomeEventType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => HomeEventType.maintenance,
        ),
        title: json['title'] as String? ?? 'Home update',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        completedByName:
            (json['completedByName'] as String?)?.trim().isNotEmpty == true
                ? (json['completedByName'] as String).trim()
                : 'You',
        thingId: json['thingId'] as String?,
        notes: json['notes'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory HomeEvent.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Home event must be a JSON object.');
    }
    return HomeEvent.fromJson(Map<String, dynamic>.from(decoded));
  }
}
