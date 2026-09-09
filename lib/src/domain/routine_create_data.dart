import 'routine_item.dart';

class RoutineCreateData {
  const RoutineCreateData({
    required this.title,
    required this.category,
    required this.repeat,
    required this.estimatedMinutes,
    required this.dueHour,
    required this.dueMinute,
    this.repeatDays = const <int>[],
    this.dayOfMonth,
  });

  final String title;
  final String category;
  final RoutineRepeat repeat;
  final int estimatedMinutes;
  final int dueHour;
  final int dueMinute;
  final List<int> repeatDays;
  final int? dayOfMonth;
}
