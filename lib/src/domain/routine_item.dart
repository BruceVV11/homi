import 'dart:convert';

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.category,
    required this.frequency,
    this.estimatedMinutes = 10,
    this.completed = false,
    this.lastCompletedAt,
  });

  final String id;
  final String title;
  final String category;
  final String frequency;
  final int estimatedMinutes;
  final bool completed;
  final DateTime? lastCompletedAt;

  RoutineItem copyWith({
    int? estimatedMinutes,
    bool? completed,
    DateTime? lastCompletedAt,
    bool clearLastCompletedAt = false,
  }) {
    return RoutineItem(
      id: id,
      title: title,
      category: category,
      frequency: frequency,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
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
        'estimatedMinutes': estimatedMinutes,
        'completed': completed,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      };

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    final completedAt = json['lastCompletedAt'] as String?;
    final rawMinutes = json['estimatedMinutes'];
    final minutes = rawMinutes is num ? rawMinutes.toInt() : 10;
    return RoutineItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Routine',
      category: json['category'] as String? ?? 'Home',
      frequency: json['frequency'] as String? ?? 'As needed',
      estimatedMinutes: minutes <= 0 ? 10 : minutes,
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
