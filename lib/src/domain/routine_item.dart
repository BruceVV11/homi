import 'dart:convert';

enum RoutineRepeat {
  once,
  daily,
  weekdays,
  weekly,
  biweekly,
  monthly,
}

extension RoutineRepeatLabel on RoutineRepeat {
  String get label {
    switch (this) {
      case RoutineRepeat.once:
        return 'One-off';
      case RoutineRepeat.daily:
        return 'Daily';
      case RoutineRepeat.weekdays:
        return 'Weekdays';
      case RoutineRepeat.weekly:
        return 'Weekly';
      case RoutineRepeat.biweekly:
        return 'Bi-weekly';
      case RoutineRepeat.monthly:
        return 'Monthly';
    }
  }
}

class RoutineCompletion {
  const RoutineCompletion({
    required this.at,
    required this.byName,
    this.byUid,
    this.occurrenceDueAt,
  });

  final DateTime at;
  final String byName;
  final String? byUid;

  /// The scheduled occurrence that was marked complete. Keeping this makes an
  /// accidental uncheck reversible: Homi can reopen the same occurrence rather
  /// than jumping to an unrelated future date.
  final DateTime? occurrenceDueAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': at.toIso8601String(),
        'byName': byName,
        'byUid': byUid,
        'occurrenceDueAt': occurrenceDueAt?.toIso8601String(),
      };

  factory RoutineCompletion.fromJson(Map<String, dynamic> json) {
    final parsedAt = DateTime.tryParse(json['at'] as String? ?? '');
    if (parsedAt == null) {
      throw const FormatException('Routine completion is missing a valid time.');
    }
    return RoutineCompletion(
      at: parsedAt,
      byName: (json['byName'] as String?)?.trim().isNotEmpty == true
          ? (json['byName'] as String).trim()
          : 'You',
      byUid: json['byUid'] as String?,
      occurrenceDueAt:
          DateTime.tryParse(json['occurrenceDueAt'] as String? ?? ''),
    );
  }
}

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.category,
    required this.repeat,
    required this.createdAt,
    this.estimatedMinutes = 10,
    this.repeatDays = const <int>[],
    this.dayOfMonth,
    this.dueHour = 9,
    this.dueMinute = 0,
    this.nextDueAt,
    this.completions = const <RoutineCompletion>[],
  });

  final String id;
  final String title;
  final String category;
  final RoutineRepeat repeat;
  final int estimatedMinutes;
  final List<int> repeatDays;
  final int? dayOfMonth;
  final int dueHour;
  final int dueMinute;
  final DateTime createdAt;
  final DateTime? nextDueAt;
  final List<RoutineCompletion> completions;

  bool get repeats => repeat != RoutineRepeat.once;

  RoutineCompletion? get lastCompletion =>
      completions.isEmpty ? null : completions.last;

  String get frequency => repeat.label;

  String get durationLabel =>
      estimatedMinutes >= 60 ? '60+ min' : '$estimatedMinutes min';

  bool isDue(DateTime now) {
    if (repeat == RoutineRepeat.once) return completions.isEmpty;
    final due = nextDueAt ?? initialDueAt();
    return !due.isAfter(now);
  }

  DateTime initialDueAt() {
    if (repeat == RoutineRepeat.biweekly) {
      return _nextBiweekly(createdAt);
    }

    final base = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
      dueHour,
      dueMinute,
    );
    if (repeat == RoutineRepeat.once) return base;
    if (base.isAfter(createdAt)) return _nextMatchingAtOrAfter(base);
    return nextOccurrenceAfter(createdAt);
  }

  DateTime nextOccurrenceAfter(DateTime after) {
    final start = after.add(const Duration(minutes: 1));
    switch (repeat) {
      case RoutineRepeat.once:
        return DateTime(
          start.year,
          start.month,
          start.day,
          dueHour,
          dueMinute,
        );
      case RoutineRepeat.daily:
        return _nextDaily(start);
      case RoutineRepeat.weekdays:
        return _nextForWeekdays(start, const <int>[1, 2, 3, 4, 5]);
      case RoutineRepeat.weekly:
        final days = repeatDays.isEmpty ? <int>[createdAt.weekday] : repeatDays;
        return _nextForWeekdays(start, days);
      case RoutineRepeat.biweekly:
        return _nextBiweekly(start);
      case RoutineRepeat.monthly:
        return _nextMonthly(start);
    }
  }

  DateTime _nextDaily(DateTime start) {
    final today = DateTime(start.year, start.month, start.day, dueHour, dueMinute);
    if (!today.isBefore(start)) return today;
    final tomorrow = start.add(const Duration(days: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      dueHour,
      dueMinute,
    );
  }

  DateTime _nextForWeekdays(DateTime start, List<int> weekdays) {
    final wanted = weekdays.toSet();
    for (var offset = 0; offset < 14; offset++) {
      final day = start.add(Duration(days: offset));
      if (!wanted.contains(day.weekday)) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        dueHour,
        dueMinute,
      );
      if (!candidate.isBefore(start)) return candidate;
    }
    final fallback = start.add(const Duration(days: 7));
    return DateTime(
      fallback.year,
      fallback.month,
      fallback.day,
      dueHour,
      dueMinute,
    );
  }

  DateTime _biweeklyAnchor() {
    final wantedDay = repeatDays.isEmpty ? createdAt.weekday : repeatDays.first;
    for (var offset = 0; offset < 8; offset++) {
      final day = createdAt.add(Duration(days: offset));
      if (day.weekday != wantedDay) continue;
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        dueHour,
        dueMinute,
      );
      if (!candidate.isBefore(createdAt)) return candidate;
    }
    final fallback = createdAt.add(const Duration(days: 7));
    return DateTime(
      fallback.year,
      fallback.month,
      fallback.day,
      dueHour,
      dueMinute,
    );
  }

  DateTime _nextBiweekly(DateTime start) {
    final anchor = _biweeklyAnchor();
    if (!anchor.isBefore(start)) return anchor;

    const period = Duration(days: 14);
    final elapsedMinutes = start.difference(anchor).inMinutes;
    final periodMinutes = period.inMinutes;
    final periods = (elapsedMinutes / periodMinutes).floor();
    var candidate = anchor.add(Duration(days: periods * 14));
    while (candidate.isBefore(start)) {
      candidate = candidate.add(period);
    }
    return candidate;
  }

  DateTime _nextMonthly(DateTime start) {
    final targetDay = (dayOfMonth ?? createdAt.day).clamp(1, 31).toInt();
    for (var addMonths = 0; addMonths < 14; addMonths++) {
      final monthIndex = (start.month - 1) + addMonths;
      final year = start.year + (monthIndex ~/ 12);
      final month = (monthIndex % 12) + 1;
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = targetDay > lastDay ? lastDay : targetDay;
      final candidate = DateTime(year, month, day, dueHour, dueMinute);
      if (!candidate.isBefore(start)) return candidate;
    }
    return DateTime(start.year + 1, start.month, 1, dueHour, dueMinute);
  }

  DateTime _nextMatchingAtOrAfter(DateTime candidate) {
    switch (repeat) {
      case RoutineRepeat.once:
      case RoutineRepeat.daily:
        return candidate;
      case RoutineRepeat.weekdays:
        return _nextForWeekdays(candidate, const <int>[1, 2, 3, 4, 5]);
      case RoutineRepeat.weekly:
        final days = repeatDays.isEmpty ? <int>[createdAt.weekday] : repeatDays;
        return _nextForWeekdays(candidate, days);
      case RoutineRepeat.biweekly:
        return _nextBiweekly(candidate);
      case RoutineRepeat.monthly:
        return _nextMonthly(candidate);
    }
  }

  RoutineItem recordCompletion({
    required DateTime at,
    required String byName,
    String? byUid,
  }) {
    final occurrenceDueAt = repeat == RoutineRepeat.once
        ? null
        : (nextDueAt ?? initialDueAt());
    final history = <RoutineCompletion>[
      ...completions,
      RoutineCompletion(
        at: at,
        byName: byName,
        byUid: byUid,
        occurrenceDueAt: occurrenceDueAt,
      ),
    ];
    final trimmedHistory = history.length <= 20
        ? history
        : history.sublist(history.length - 20);
    return copyWith(
      completions: trimmedHistory,
      nextDueAt: repeats ? nextOccurrenceAfter(occurrenceDueAt ?? at) : null,
      clearNextDueAt: !repeats,
    );
  }

  RoutineItem undoLastCompletion() {
    if (completions.isEmpty) return this;
    final removed = completions.last;
    final remaining = List<RoutineCompletion>.of(completions)..removeLast();
    DateTime? next;
    if (repeats) {
      next = removed.occurrenceDueAt ?? removed.at;
    }
    return copyWith(
      completions: remaining,
      nextDueAt: next,
      clearNextDueAt: !repeats,
    );
  }

  RoutineItem copyWith({
    int? estimatedMinutes,
    DateTime? nextDueAt,
    bool clearNextDueAt = false,
    List<RoutineCompletion>? completions,
  }) {
    return RoutineItem(
      id: id,
      title: title,
      category: category,
      repeat: repeat,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      repeatDays: repeatDays,
      dayOfMonth: dayOfMonth,
      dueHour: dueHour,
      dueMinute: dueMinute,
      createdAt: createdAt,
      nextDueAt: clearNextDueAt ? null : (nextDueAt ?? this.nextDueAt),
      completions: completions ?? this.completions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'repeat': repeat.name,
        'frequency': frequency,
        'estimatedMinutes': estimatedMinutes,
        'repeatDays': repeatDays,
        'dayOfMonth': dayOfMonth,
        'dueHour': dueHour,
        'dueMinute': dueMinute,
        'createdAt': createdAt.toIso8601String(),
        'nextDueAt': nextDueAt?.toIso8601String(),
        'completions': completions.map((item) => item.toJson()).toList(),
        'completed': repeat == RoutineRepeat.once && completions.isNotEmpty,
        'lastCompletedAt': lastCompletion?.at.toIso8601String(),
      };

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now;
    final rawMinutes = json['estimatedMinutes'];
    final minutes = rawMinutes is num ? rawMinutes.toInt() : 10;
    final legacyFrequency = json['frequency'] as String? ?? 'As needed';
    final repeatName = json['repeat'] as String?;
    final repeat = RoutineRepeat.values.firstWhere(
      (value) => value.name == repeatName,
      orElse: () => _repeatFromLegacy(legacyFrequency),
    );

    final rawDays = json['repeatDays'];
    final days = rawDays is List
        ? rawDays
            .whereType<num>()
            .map((value) => value.toInt())
            .where((day) => day >= 1 && day <= 7)
            .toList()
        : <int>[];
    final dueHourRaw = json['dueHour'];
    final dueMinuteRaw = json['dueMinute'];
    final dueHour = dueHourRaw is num
        ? dueHourRaw.toInt().clamp(0, 23).toInt()
        : 9;
    final dueMinute = dueMinuteRaw is num
        ? dueMinuteRaw.toInt().clamp(0, 59).toInt()
        : 0;
    final dayOfMonthRaw = json['dayOfMonth'];
    final dayOfMonth = dayOfMonthRaw is num
        ? dayOfMonthRaw.toInt().clamp(1, 31).toInt()
        : null;

    final rawCompletions = json['completions'];
    final completions = <RoutineCompletion>[];
    if (rawCompletions is List) {
      for (final value in rawCompletions) {
        if (value is! Map) continue;
        try {
          completions.add(
            RoutineCompletion.fromJson(Map<String, dynamic>.from(value)),
          );
        } catch (_) {
          // Skip corrupt historical entries without blocking the app.
        }
      }
    }

    final legacyCompletedAt = DateTime.tryParse(
      json['lastCompletedAt'] as String? ?? '',
    );
    if (completions.isEmpty && legacyCompletedAt != null) {
      completions.add(
        RoutineCompletion(at: legacyCompletedAt, byName: 'You'),
      );
    }

    final item = RoutineItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Routine',
      category: json['category'] as String? ?? 'Home',
      repeat: repeat,
      estimatedMinutes: minutes <= 0 ? 10 : minutes,
      repeatDays: days,
      dayOfMonth: dayOfMonth,
      dueHour: dueHour,
      dueMinute: dueMinute,
      createdAt: createdAt,
      nextDueAt: DateTime.tryParse(json['nextDueAt'] as String? ?? ''),
      completions: completions,
    );

    if (item.nextDueAt != null || !item.repeats) return item;
    if (item.lastCompletion != null) {
      return item.copyWith(
        nextDueAt: item.nextOccurrenceAfter(item.lastCompletion!.at),
      );
    }
    return item.copyWith(nextDueAt: item.initialDueAt());
  }

  static RoutineRepeat _repeatFromLegacy(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return RoutineRepeat.daily;
      case 'weekdays':
        return RoutineRepeat.weekdays;
      case 'weekly':
        return RoutineRepeat.weekly;
      case 'bi-weekly':
      case 'biweekly':
      case 'fortnightly':
        return RoutineRepeat.biweekly;
      case 'monthly':
        return RoutineRepeat.monthly;
      default:
        return RoutineRepeat.once;
    }
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
