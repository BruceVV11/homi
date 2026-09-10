import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/household_task.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';
import 'package:homi/src/domain/utility_reading.dart';

void main() {
  test('one-off task keeps assignee and completion attribution', () {
    final source = HouseholdTask(
      id: 'task-1',
      title: 'Take the mince out to defrost',
      assigneeName: 'Sam',
      assigneeUid: 'uid-sam',
      dueAt: DateTime(2026, 9, 10, 15),
      createdAt: DateTime(2026, 9, 9, 20),
      createdByName: 'Bruce',
      createdByUid: 'uid-bruce',
    ).complete(
      at: DateTime(2026, 9, 10, 14, 52),
      byName: 'Sam',
      byUid: 'uid-sam',
    );

    final restored = HouseholdTask.decode(source.encode());
    expect(restored.title, source.title);
    expect(restored.assigneeName, 'Sam');
    expect(restored.dueAt, DateTime(2026, 9, 10, 15));
    expect(restored.completed, isTrue);
    expect(restored.completedByName, 'Sam');
    expect(restored.completedByUid, 'uid-sam');
  });

  test('completed tasks remain visible for two days then expire', () {
    final task = HouseholdTask(
      id: 'done',
      title: 'Collect parcel',
      createdAt: DateTime(2026, 9, 8, 8),
      createdByName: 'Bruce',
    ).complete(
      at: DateTime(2026, 9, 10, 10),
      byName: 'Bruce',
    );

    expect(
      task.completedWithinRetention(DateTime(2026, 9, 12, 9, 59)),
      isTrue,
    );
    expect(task.shouldPurge(DateTime(2026, 9, 12, 10)), isTrue);
    expect(task.removeAfter, DateTime(2026, 9, 12, 10));
  });

  test('recurring routine can be completed, undone and completed again', () {
    final dueAt = DateTime(2026, 9, 10, 7);
    final base = RoutineItem(
      id: 'dogs',
      title: 'Feed the dogs',
      category: 'Pets',
      repeat: RoutineRepeat.daily,
      dueHour: 7,
      createdAt: DateTime(2026, 9, 9, 12),
      nextDueAt: dueAt,
    );

    final completed = base.recordCompletion(
      at: DateTime(2026, 9, 10, 7, 3),
      byName: 'Bruce',
    );
    expect(completed.nextDueAt, DateTime(2026, 9, 11, 7));
    expect(completed.lastCompletion?.occurrenceDueAt, dueAt);

    final reopened = completed.undoLastCompletion();
    expect(reopened.nextDueAt, dueAt);
    expect(reopened.completions, isEmpty);
    expect(reopened.isDue(DateTime(2026, 9, 10, 7, 5)), isTrue);

    final completedAgain = reopened.recordCompletion(
      at: DateTime(2026, 9, 10, 7, 6),
      byName: 'Bruce',
    );
    expect(completedAgain.lastCompletion?.byName, 'Bruce');
    expect(completedAgain.nextDueAt, DateTime(2026, 9, 11, 7));
  });

  test('bi-weekly routine returns exactly two weeks after completion', () {
    final dueAt = DateTime(2026, 9, 7, 9);
    final routine = RoutineItem(
      id: 'garden',
      title: 'Water indoor plants',
      category: 'Plants & garden',
      repeat: RoutineRepeat.biweekly,
      repeatDays: const <int>[DateTime.monday],
      dueHour: 9,
      createdAt: DateTime(2026, 9, 7, 8),
      nextDueAt: dueAt,
    ).recordCompletion(
      at: DateTime(2026, 9, 7, 9, 5),
      byName: 'Bruce',
    );

    expect(routine.nextDueAt, DateTime(2026, 9, 21, 9));
    expect(routine.frequency, 'Bi-weekly');
  });

  test('60 minute routine uses launch-ready 60+ label', () {
    final routine = RoutineItem(
      id: 'deep-clean',
      title: 'Deep clean kitchen',
      category: 'Cleaning',
      repeat: RoutineRepeat.monthly,
      estimatedMinutes: 60,
      createdAt: DateTime(2026, 9, 10),
    );
    expect(routine.durationLabel, '60+ min');
  });

  test('legacy supply without icon or quantity remains valid', () {
    final restored = SupplyItem.decode(
      '{"id":"milk","name":"Milk","category":"Fridge","status":"okay"}',
    );
    expect(restored.iconKey, 'inventory');
    expect(restored.tracksQuantity, isFalse);
    expect(restored.quantityLabel, isNull);
  });

  test('selected supply icon and amount survive persistence', () {
    const source = SupplyItem(
      id: 'bread',
      name: 'Bread',
      category: 'Pantry',
      status: SupplyStatus.okay,
      iconKey: 'bread',
      quantity: 2,
      unit: SupplyUnit.loaf,
    );
    final restored = SupplyItem.decode(source.encode());
    expect(restored.iconKey, 'bread');
    expect(restored.quantity, 2);
    expect(restored.unit, SupplyUnit.loaf);
    expect(restored.quantityLabel, '2 loaves');
  });

  test('zero tracked supply becomes need to buy', () {
    const source = SupplyItem(
      id: 'eggs',
      name: 'Eggs',
      category: 'Fridge',
      status: SupplyStatus.okay,
      quantity: 0,
      unit: SupplyUnit.egg,
    );
    expect(
      source.effectiveStatus(DateTime(2026, 9, 10)),
      SupplyStatus.needToBuy,
    );
    expect(
      source.displayStatusLabel(DateTime(2026, 9, 10)),
      'Need to buy',
    );
  });

  test('utility unit choices stay controlled by type', () {
    expect(UtilityType.electricity.unitOptions, contains('kWh'));
    expect(UtilityType.water.unitOptions, contains('m³'));
    expect(UtilityType.electricity.unitOptions, isNot(contains('m³')));
  });
}
