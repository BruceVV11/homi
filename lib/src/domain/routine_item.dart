import 'dart:convert';

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.category,
    required this.frequency,
    this.completed = false,
    this.lastCompletedAt,
  });

  final String id;
  final String title;
  final String category;
  final String frequency;
  final bool completed;
  final DateTime? lastCompletedAt;

  RoutineItem copyWith({
    bool? completed,
    DateTime? lastCompletedAt,
    bool clearLastCompletedAt = false,
  }) {
    return RoutineItem(
      id: id,
      title: title,
      category: category,
      frequency: frequency,
      completed: completed ?? this.completed,
      lastCompletedAt: clearLastCompletedAt
          ? null
          : (lastCompletedAt ?? this.lastCompletedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'frequency': frequency,
        'completed': completed,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      };

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    final completedAt = json['lastCompletedAt'] as String?;
    return RoutineItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Routine',
      category: json['category'] as String? ?? 'Home',
      frequency: json['frequency'] as String? ?? 'As needed',
      completed: json['completed'] == true,
      lastCompletedAt:
          completedAt == null ? null : DateTime.tryParse(completedAt),
    );
  }

  String encode() => jsonEncode(toJson());

  factory RoutineItem.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Routine item must be a JSON object.');
    }
    return RoutineItem.fromJson(Map<String, dynamic>.from(decoded));
  }
}
