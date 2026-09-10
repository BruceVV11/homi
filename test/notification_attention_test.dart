import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/notification_preferences.dart';
import 'package:homi/src/domain/supply_attention.dart';
import 'package:homi/src/domain/supply_item.dart';

void main() {
  group('Homi notification preferences', () {
    test('fresh installs default useful operational notifications on', () {
      const preferences = HomiNotificationPreferences();

      expect(preferences.enabled, isTrue);
      expect(preferences.householdAttention, isTrue);
      expect(preferences.tasksAndRoutines, isTrue);
      expect(preferences.people, isTrue);
      expect(preferences.homiUpdates, isFalse);
      expect(preferences.serviceNotices, isTrue);
      expect(preferences.allowsCategory('supply'), isTrue);
      expect(preferences.allowsCategory('update'), isFalse);
    });

    test('category switches gate notification types after opt-in', () {
      const preferences = HomiNotificationPreferences(
        enabled: true,
        householdAttention: false,
        tasksAndRoutines: true,
        people: false,
        homiUpdates: true,
        serviceNotices: false,
      );

      expect(preferences.allowsCategory('supply'), isFalse);
      expect(preferences.allowsCategory('maintenance'), isFalse);
      expect(preferences.allowsCategory('task'), isTrue);
      expect(preferences.allowsCategory('routine'), isTrue);
      expect(preferences.allowsCategory('heart'), isFalse);
      expect(preferences.allowsCategory('update'), isTrue);
      expect(preferences.allowsCategory('security'), isFalse);
    });

    test('preferences survive local persistence round trip', () {
      const source = HomiNotificationPreferences(
        enabled: true,
        householdAttention: true,
        tasksAndRoutines: false,
        people: true,
        homiUpdates: false,
        serviceNotices: true,
      );

      final restored = HomiNotificationPreferences.decode(source.encode());
      expect(restored.enabled, source.enabled);
      expect(restored.householdAttention, source.householdAttention);
      expect(restored.tasksAndRoutines, source.tasksAndRoutines);
      expect(restored.people, source.people);
      expect(restored.homiUpdates, source.homiUpdates);
      expect(restored.serviceNotices, source.serviceNotices);
    });

    test('legacy preferences without Homi updates keep that category off', () {
      final restored = HomiNotificationPreferences.fromJson(
        const <String, dynamic>{
          'enabled': true,
          'householdAttention': true,
          'tasksAndRoutines': true,
          'people': true,
          'serviceNotices': true,
        },
      );

      expect(restored.homiUpdates, isFalse);
      expect(restored.allowsCategory('update'), isFalse);
    });
  });

  group('Supply attention priority', () {
    final now = DateTime(2026, 9, 10, 12);

    test('sorts need-to-buy before expired, use-soon and running-low', () {
      final items = <SupplyItem>[
        const SupplyItem(
          id: 'low',
          name: 'Coffee',
          category: 'Pantry',
          status: SupplyStatus.runningLow,
        ),
        SupplyItem(
          id: 'soon',
          name: 'Milk',
          category: 'Fridge',
          status: SupplyStatus.okay,
          expiryDate: DateTime(2026, 9, 12),
        ),
        SupplyItem(
          id: 'expired',
          name: 'Yoghurt',
          category: 'Fridge',
          status: SupplyStatus.okay,
          expiryDate: DateTime(2026, 9, 9),
        ),
        const SupplyItem(
          id: 'buy',
          name: 'Bread',
          category: 'Pantry',
          status: SupplyStatus.needToBuy,
        ),
      ];

      final sorted = SupplyAttention.sorted(items, now);
      expect(
        sorted.map((item) => item.id).toList(),
        <String>['buy', 'expired', 'soon', 'low'],
      );
      expect(SupplyAttention.conciseStatus(sorted[0], now), 'Need to buy');
      expect(SupplyAttention.conciseStatus(sorted[1], now), 'Expired');
      expect(SupplyAttention.conciseStatus(sorted[2], now), 'Use soon');
      expect(SupplyAttention.conciseStatus(sorted[3], now), 'Running low');
    });

    test('ignores supplies that need no attention', () {
      final sorted = SupplyAttention.sorted(
        const <SupplyItem>[
          SupplyItem(
            id: 'fine',
            name: 'Rice',
            category: 'Pantry',
            status: SupplyStatus.okay,
          ),
        ],
        now,
      );
      expect(sorted, isEmpty);
    });
  });
}
