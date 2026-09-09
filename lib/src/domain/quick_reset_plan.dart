import 'routine_item.dart';

enum QuickResetTaskSource {
  routine,
  suggestion,
}

class QuickResetTask {
  const QuickResetTask({
    required this.title,
    required this.minutes,
    required this.source,
    this.routineId,
  });

  final String title;
  final int minutes;
  final QuickResetTaskSource source;
  final String? routineId;

  bool get isSavedRoutine => source == QuickResetTaskSource.routine;
}

abstract final class QuickResetPlanner {
  static const List<QuickResetTask> _starterSuggestions = <QuickResetTask>[
    QuickResetTask(
      title: 'Refill pet water',
      minutes: 3,
      source: QuickResetTaskSource.suggestion,
    ),
    QuickResetTask(
      title: 'Wipe kitchen counters',
      minutes: 5,
      source: QuickResetTaskSource.suggestion,
    ),
    QuickResetTask(
      title: 'Put away loose items',
      minutes: 5,
      source: QuickResetTaskSource.suggestion,
    ),
    QuickResetTask(
      title: 'Empty recycling',
      minutes: 5,
      source: QuickResetTaskSource.suggestion,
    ),
    QuickResetTask(
      title: 'Quick bathroom wipe',
      minutes: 8,
      source: QuickResetTaskSource.suggestion,
    ),
    QuickResetTask(
      title: 'Sweep a high-traffic area',
      minutes: 10,
      source: QuickResetTaskSource.suggestion,
    ),
  ];

  static List<QuickResetTask> build({
    required int budgetMinutes,
    required List<RoutineItem> routines,
  }) {
    if (budgetMinutes <= 0) return const <QuickResetTask>[];

    final candidates = routines.where((item) => !item.completed).toList()
      ..sort((a, b) {
        final duration = a.estimatedMinutes.compareTo(b.estimatedMinutes);
        if (duration != 0) return duration;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final tasks = <QuickResetTask>[];
    final usedTitles = <String>{};
    var remaining = budgetMinutes;
    final maxTasks = budgetMinutes <= 10 ? 3 : 4;

    for (final routine in candidates) {
      if (tasks.length >= maxTasks) break;
      if (routine.estimatedMinutes > remaining) continue;
      tasks.add(
        QuickResetTask(
          title: routine.title,
          minutes: routine.estimatedMinutes,
          source: QuickResetTaskSource.routine,
          routineId: routine.id,
        ),
      );
      usedTitles.add(routine.title.trim().toLowerCase());
      remaining -= routine.estimatedMinutes;
    }

    for (final suggestion in _starterSuggestions) {
      if (tasks.length >= maxTasks || remaining <= 0) break;
      if (suggestion.minutes > remaining) continue;
      if (usedTitles.contains(suggestion.title.toLowerCase())) continue;
      tasks.add(suggestion);
      usedTitles.add(suggestion.title.toLowerCase());
      remaining -= suggestion.minutes;
    }

    return List<QuickResetTask>.unmodifiable(tasks);
  }

  static int plannedMinutes(Iterable<QuickResetTask> tasks) {
    return tasks.fold<int>(0, (total, task) => total + task.minutes);
  }
}
