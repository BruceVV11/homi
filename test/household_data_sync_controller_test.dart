import 'package:flutter_test/flutter_test.dart';
import 'package:homi/src/domain/household_data_mutation.dart';
import 'package:homi/src/domain/routine_item.dart';
import 'package:homi/src/domain/supply_item.dart';
import 'package:homi/src/state/homi_app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('routine changes save locally and emit a Household upsert', () async {
    final controller = HomiAppController();
    await controller.load();
    final mutations = <HouseholdDataMutation>[];
    controller.bindHouseholdDataSink((mutation) async {
      mutations.add(mutation);
    });

    await controller.addRoutine(
      title: 'Take bins out',
      category: 'Chores',
      repeat: RoutineRepeat.weekly,
      estimatedMinutes: 10,
      dueHour: 18,
      dueMinute: 0,
      repeatDays: const <int>[1],
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.routines, hasLength(1));
    expect(mutations, hasLength(1));
    expect(mutations.single.domain, HouseholdDataDomain.routine);
    expect(mutations.single.delete, isFalse);
    expect(mutations.single.itemId, controller.routines.single.id);
    expect(mutations.single.payload?['title'], 'Take bins out');

    final persisted = await SharedPreferences.getInstance();
    expect(persisted.getStringList('homi.routines.items'), hasLength(1));
  });

  test('cloud replacement preserves only explicitly private legacy routines', () async {
    final controller = HomiAppController();
    await controller.load();
    await controller.addRoutine(
      title: 'Private old routine',
      category: 'Home',
      repeat: RoutineRepeat.daily,
      estimatedMinutes: 5,
      dueHour: 8,
      dueMinute: 0,
    );
    final privateId = controller.routines.single.id;
    final cloud = RoutineItem(
      id: 'cloud-routine',
      title: 'Shared routine',
      category: 'Home',
      repeat: RoutineRepeat.daily,
      createdAt: DateTime(2026, 9, 11, 8),
      nextDueAt: DateTime(2026, 9, 12, 8),
    );

    await controller.applyHouseholdRoutines(
      <RoutineItem>[cloud],
      preserveLocalIds: <String>{privateId},
    );
    expect(
      controller.routines.map((item) => item.id).toSet(),
      <String>{privateId, 'cloud-routine'},
    );

    await controller.applyHouseholdRoutines(<RoutineItem>[cloud]);
    expect(controller.routines.map((item) => item.id).toList(),
        <String>['cloud-routine']);
  });

  test('shared supply deletion emits a Household delete without cloud echo', () async {
    final controller = HomiAppController();
    await controller.load();
    final mutations = <HouseholdDataMutation>[];
    controller.bindHouseholdDataSink((mutation) async {
      mutations.add(mutation);
    });

    await controller.addSupply(
      'Milk',
      'Kitchen',
      SupplyStatus.okay,
      null,
      quantity: 1,
      unit: SupplyUnit.carton,
    );
    await Future<void>.delayed(Duration.zero);
    final id = controller.supplies.single.id;
    mutations.clear();

    await controller.removeSupply(id);
    await Future<void>.delayed(Duration.zero);
    expect(controller.supplies, isEmpty);
    expect(mutations, hasLength(1));
    expect(mutations.single.domain, HouseholdDataDomain.supply);
    expect(mutations.single.itemId, id);
    expect(mutations.single.delete, isTrue);

    mutations.clear();
    final cloud = SupplyItem(
      id: 'cloud-supply',
      name: 'Rice',
      category: 'Pantry',
      status: SupplyStatus.okay,
    );
    await controller.applyHouseholdSupplies(<SupplyItem>[cloud]);
    await Future<void>.delayed(Duration.zero);
    expect(mutations, isEmpty,
        reason: 'Applying a cloud snapshot must not write it back again.');
  });
}
