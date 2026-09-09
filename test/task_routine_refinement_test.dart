import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/household_task.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';

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

  test('legacy supply without icon uses the general supply icon key', () {
    final restored = SupplyItem.decode(
      '{"id":"milk","name":"Milk","category":"Fridge","status":"okay"}',
    );
    expect(restored.iconKey, 'inventory');
  });

  test('selected supply icon survives persistence', () {
    const source = SupplyItem(
      id: 'bread',
      name: 'Bread',
      category: 'Pantry',
      status: SupplyStatus.okay,
      iconKey: 'bread',
    );
    expect(SupplyItem.decode(source.encode()).iconKey, 'bread');
  });
}
