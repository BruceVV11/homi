import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/home_event.dart';
import 'package:homi/src/domain/home_thing.dart';
import 'package:homi/src/domain/quick_reset_plan.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';
import 'package:homi/src/domain/utility_reading.dart';

void main() {
  test('routine schedule and completion attribution survive persistence', () {
    final source = RoutineItem(
      id: 'routine-1',
      title: 'Feed Milo',
      category: 'Pets',
      repeat: RoutineRepeat.daily,
      estimatedMinutes: 5,
      dueHour: 7,
      dueMinute: 0,
      createdAt: DateTime(2026, 9, 9, 6),
      nextDueAt: DateTime(2026, 9, 9, 7),
    ).recordCompletion(
      at: DateTime(2026, 9, 9, 7, 30),
      byName: 'Bruce',
      byUid: 'uid-bruce',
    );

    final restored = RoutineItem.decode(source.encode());

    expect(restored.id, source.id);
    expect(restored.title, source.title);
    expect(restored.repeat, RoutineRepeat.daily);
    expect(restored.estimatedMinutes, 5);
    expect(restored.lastCompletion?.byName, 'Bruce');
    expect(restored.lastCompletion?.byUid, 'uid-bruce');
    expect(restored.lastCompletion?.at, DateTime(2026, 9, 9, 7, 30));
    expect(restored.nextDueAt, DateTime(2026, 9, 10, 7));
    expect(restored.isDue(DateTime(2026, 9, 9, 20)), isFalse);
    expect(restored.isDue(DateTime(2026, 9, 10, 7)), isTrue);
  });

  test('weekly routines move to the next selected day after completion', () {
    final routine = RoutineItem(
      id: 'bins',
      title: 'Take the bins out',
      category: 'Chores',
      repeat: RoutineRepeat.weekly,
      repeatDays: const <int>[1, 4],
      dueHour: 18,
      dueMinute: 0,
      createdAt: DateTime(2026, 9, 7, 8),
      nextDueAt: DateTime(2026, 9, 7, 18),
    ).recordCompletion(
      at: DateTime(2026, 9, 7, 18, 5),
      byName: 'Bruce',
    );

    expect(routine.nextDueAt, DateTime(2026, 9, 10, 18));
  });

  test('legacy routines migrate to recurrence and safe duration defaults', () {
    final restored = RoutineItem.decode(
      '{"id":"legacy","title":"Bins","category":"Chores","frequency":"Weekly","completed":false}',
    );

    expect(restored.estimatedMinutes, 10);
    expect(restored.repeat, RoutineRepeat.weekly);
    expect(restored.repeats, isTrue);
  });

  test('supply items preserve status and derive expiry attention', () {
    final source = SupplyItem(
      id: 'supply-1',
      name: 'Milk',
      category: 'Fridge',
      status: SupplyStatus.okay,
      expiryDate: DateTime(2026, 9, 11),
    );

    final restored = SupplyItem.decode(source.encode());
    final now = DateTime(2026, 9, 9);

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.category, source.category);
    expect(restored.status, SupplyStatus.okay);
    expect(restored.expiryDate, source.expiryDate);
    expect(restored.effectiveStatus(now), SupplyStatus.eatSoon);
    expect(restored.displayStatusLabel(now), 'Use soon');
    expect(SupplyStatus.needToBuy.label, 'Need to buy');
    expect(SupplyStatus.okay.label, 'In stock');
  });

  test('expired supplies get an explicit display label', () {
    final item = SupplyItem(
      id: 'expired',
      name: 'Yoghurt',
      category: 'Fridge',
      status: SupplyStatus.okay,
      expiryDate: DateTime(2026, 9, 8),
    );

    expect(item.effectiveStatus(DateTime(2026, 9, 9)), SupplyStatus.eatSoon);
    expect(item.displayStatusLabel(DateTime(2026, 9, 9)), 'Expired');
  });

  test('Quick Reset prioritises due routines and stays within time budget', () {
    final now = DateTime(2026, 9, 9, 8);
    final routines = <RoutineItem>[
      RoutineItem(
        id: 'quick',
        title: 'Feed Milo',
        category: 'Pets',
        repeat: RoutineRepeat.daily,
        estimatedMinutes: 5,
        dueHour: 7,
        createdAt: DateTime(2026, 9, 9, 6),
        nextDueAt: DateTime(2026, 9, 9, 7),
      ),
      RoutineItem(
        id: 'long',
        title: 'Clean bathroom',
        category: 'Chores',
        repeat: RoutineRepeat.weekly,
        repeatDays: const <int>[3],
        estimatedMinutes: 20,
        dueHour: 7,
        createdAt: DateTime(2026, 9, 9, 6),
        nextDueAt: DateTime(2026, 9, 9, 7),
      ),
    ];

    final plan = QuickResetPlanner.build(
      budgetMinutes: 10,
      routines: routines,
      now: now,
      suggestionSeed: 7,
    );

    expect(plan.any((task) => task.routineId == 'quick'), isTrue);
    expect(plan.any((task) => task.routineId == 'long'), isFalse);
    expect(QuickResetPlanner.plannedMinutes(plan), lessThanOrEqualTo(10));
  });

  test('Home things preserve service details', () {
    final source = HomeThing(
      id: 'geyser-1',
      name: 'Geyser',
      category: 'Plumbing',
      location: 'Garage',
      brandModel: 'Example 200L',
      createdAt: DateTime(2026, 9, 9),
      nextServiceDate: DateTime(2026, 10, 1),
      notes: 'Keep installer details with the invoice.',
    );

    final restored = HomeThing.decode(source.encode());
    expect(restored.name, 'Geyser');
    expect(restored.brandModel, 'Example 200L');
    expect(restored.nextServiceDate, DateTime(2026, 10, 1));
  });

  test('Home history preserves who completed the work', () {
    final source = HomeEvent(
      id: 'repair-1',
      type: HomeEventType.repair,
      title: 'Replaced pool pump seal',
      date: DateTime(2026, 9, 9),
      completedByName: 'Bruce',
      thingId: 'pool-pump',
    );

    final restored = HomeEvent.decode(source.encode());
    expect(restored.type, HomeEventType.repair);
    expect(restored.completedByName, 'Bruce');
    expect(restored.thingId, 'pool-pump');
  });

  test('Utility readings survive local JSON persistence', () {
    final source = UtilityReading(
      id: 'reading-1',
      type: UtilityType.electricity,
      value: 1234.5,
      unit: 'kWh',
      recordedAt: DateTime(2026, 9, 9, 17, 30),
      recordedByName: 'Bruce',
    );

    final restored = UtilityReading.decode(source.encode());
    expect(restored.type, UtilityType.electricity);
    expect(restored.value, 1234.5);
    expect(restored.recordedByName, 'Bruce');
  });
}
