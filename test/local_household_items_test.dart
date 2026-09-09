import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';

void main() {
  test('routine items survive local JSON persistence', () {
    final source = RoutineItem(
      id: 'routine-1',
      title: 'Feed Milo',
      category: 'Pets',
      frequency: 'Daily',
      completed: true,
      lastCompletedAt: DateTime(2026, 9, 9, 7, 30),
    );

    final restored = RoutineItem.decode(source.encode());

    expect(restored.id, source.id);
    expect(restored.title, source.title);
    expect(restored.category, source.category);
    expect(restored.frequency, source.frequency);
    expect(restored.completed, isTrue);
    expect(restored.lastCompletedAt, source.lastCompletedAt);
  });

  test('supply items preserve status and expiry date', () {
    final source = SupplyItem(
      id: 'supply-1',
      name: 'Milk',
      category: 'Fridge',
      status: SupplyStatus.eatSoon,
      expiryDate: DateTime(2026, 9, 12),
    );

    final restored = SupplyItem.decode(source.encode());

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.category, source.category);
    expect(restored.status, SupplyStatus.eatSoon);
    expect(restored.expiryDate, source.expiryDate);
    expect(SupplyStatus.needToBuy.label, 'Need to buy');
  });
}
