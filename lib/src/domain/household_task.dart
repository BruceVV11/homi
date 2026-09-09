import 'dart:convert';

class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.createdByName,
    this.createdByUid,
    this.notes,
    this.assigneeName,
    this.assigneeUid,
    this.dueAt,
    this.completedAt,
    this.completedByName,
    this.completedByUid,
    this.shared = false,
  });

  final String id;
  final String title;
  final String? notes;
  final String? assigneeName;
  final String? assigneeUid;
  final DateTime? dueAt;
  final DateTime createdAt;
  final String createdByName;
  final String? createdByUid;
  final DateTime? completedAt;
  final String? completedByName;
  final String? completedByUid;
  final bool shared;

  bool get completed => completedAt != null;

  HouseholdTask complete({
    required DateTime at,
    required String byName,
    String? byUid,
  }) {
    return copyWith(
      completedAt: at,
      completedByName: byName,
      completedByUid: byUid,
    );
  }

  HouseholdTask reopen() {
    return copyWith(
      clearCompletedAt: true,
      clearCompletedByName: true,
      clearCompletedByUid: true,
    );
  }

  HouseholdTask copyWith({
    String? title,
    String? notes,
    bool clearNotes = false,
    String? assigneeName,
    bool clearAssigneeName = false,
    String? assigneeUid,
    bool clearAssigneeUid = false,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? completedByName,
    bool clearCompletedByName = false,
    String? completedByUid,
    bool clearCompletedByUid = false,
  }) {
    return HouseholdTask(
      id: id,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      assigneeName:
          clearAssigneeName ? null : (assigneeName ?? this.assigneeName),
      assigneeUid: clearAssigneeUid ? null : (assigneeUid ?? this.assigneeUid),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      createdAt: createdAt,
      createdByName: createdByName,
      createdByUid: createdByUid,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      completedByName: clearCompletedByName
          ? null
          : (completedByName ?? this.completedByName),
      completedByUid: clearCompletedByUid
          ? null
          : (completedByUid ?? this.completedByUid),
      shared: shared,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'notes': notes,
        'assigneeName': assigneeName,
        'assigneeUid': assigneeUid,
        'dueAt': dueAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'createdByName': createdByName,
        'createdByUid': createdByUid,
        'completedAt': completedAt?.toIso8601String(),
        'completedByName': completedByName,
        'completedByUid': completedByUid,
        'shared': shared,
      };

  factory HouseholdTask.fromJson(Map<String, dynamic> json) {
    return HouseholdTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Task',
      notes: json['notes'] as String?,
      assigneeName: json['assigneeName'] as String?,
      assigneeUid: json['assigneeUid'] as String?,
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      createdByName: json['createdByName'] as String? ?? 'You',
      createdByUid: json['createdByUid'] as String?,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      completedByName: json['completedByName'] as String?,
      completedByUid: json['completedByUid'] as String?,
      shared: json['shared'] == true,
    );
  }

  String encode() => jsonEncode(toJson());

  factory HouseholdTask.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Household task must be a JSON object.');
    }
    return HouseholdTask.fromJson(Map<String, dynamic>.from(decoded));
  }
}

class HouseholdTaskInput {
  const HouseholdTaskInput({
    required this.title,
    this.notes,
    this.assigneeName,
    this.assigneeUid,
    this.dueAt,
  });

  final String title;
  final String? notes;
  final String? assigneeName;
  final String? assigneeUid;
  final DateTime? dueAt;
}
