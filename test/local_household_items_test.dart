import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/quick_reset_plan.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';

void main() {
  test('routine items survive local JSON persistence', () {
    final source = RoutineItem(
      id: 'routine-1',
      title: 'Feed Milo',
      category: 'Pets',
      frequency: 'Daily',
      estimatedMinutes: 5,
      completed: true,
      lastCompletedAt: DateTime(2026, 9, 9, 7, 30),
    );

    final restored = RoutineItem.decode(source.encode());

    expect(restored.id, source.id);
    expect(restored.title, source.title);
    expect(restored.category, source.category);
    expect(restored.frequency, source.frequency);
    expect(restored.estimatedMinutes, 5);
    expect(restored.completed, isTrue);
    expect(restored.lastCompletedAt, source.lastCompletedAt);
  });

  test('legacy routines receive a safe default time estimate', () {
    final restored = RoutineItem.decode(
      '{"id":"legacy","title":"Bins","category":"Chores","frequency":"Weekly","completed":false}',
    );

    expect(restored.estimatedMinutes, 10);
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

  test('Quick Reset prioritises saved routines that fit the time budget', () {
    final routines = <RoutineItem>[
      const RoutineItem(
        id: 'quick',
        title: 'Feed Milo',
        category: 'Pets',
        frequency: 'Daily',
        estimatedMinutes: 5,
      ),
      const RoutineItem(
        id: 'long',
        title: 'Clean bathroom',
        category: 'Chores',
        frequency: 'Weekly',
        estimatedMinutes: 20,
      ),
    ];

    final plan = QuickResetPlanner.build(
      budgetMinutes: 10,
      routines: routines,
    );

    expect(plan.any((task) => task.routineId == 'quick'), isTrue);
    expect(plan.any((task) => task.routineId == 'long'), isFalse);
    expect(QuickResetPlanner.plannedMinutes(plan), lessThanOrEqualTo(10));
  });
}
