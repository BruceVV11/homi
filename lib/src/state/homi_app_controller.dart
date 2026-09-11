import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/home_event.dart';
import '../domain/home_thing.dart';
import '../domain/household_data_mutation.dart';
import '../domain/household_task.dart';
import '../domain/routine_item.dart';
import '../domain/supply_item.dart';
import '../domain/utility_reading.dart';

class HomiAppController extends ChangeNotifier {
  static const _onboardingKey = 'homi.onboarding.complete';
  static const _homeNameKey = 'homi.home.name';
  static const _homeTypeKey = 'homi.home.type';
  static const _localOnlyKey = 'homi.account.localOnly';
  static const _quickItemsKey = 'homi.today.quickItems';
  static const _tasksKey = 'homi.tasks.items';
  static const _routinesKey = 'homi.routines.items';
  static const _suppliesKey = 'homi.supplies.items';
  static const _homeThingsKey = 'homi.home.things';
  static const _homeEventsKey = 'homi.home.events';
  static const _utilityReadingsKey = 'homi.home.utilityReadings';

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;
  HouseholdDataMutationSink? _householdDataSink;

  bool isReady = false;
  bool onboardingComplete = false;
  bool localOnly = true;
  String homeName = 'My home';
  String homeType = 'House';
  List<String> quickItems = <String>[];
  List<HouseholdTask> tasks = <HouseholdTask>[];
  List<RoutineItem> routines = <RoutineItem>[];
  List<SupplyItem> supplies = <SupplyItem>[];
  List<HomeThing> homeThings = <HomeThing>[];
  List<HomeEvent> homeEvents = <HomeEvent>[];
  List<UtilityReading> utilityReadings = <UtilityReading>[];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    onboardingComplete = _prefs?.getBool(_onboardingKey) ?? false;
    homeName = _prefs?.getString(_homeNameKey) ?? 'My home';
    homeType = _prefs?.getString(_homeTypeKey) ?? 'House';
    localOnly = _prefs?.getBool(_localOnlyKey) ?? true;
    quickItems = _prefs?.getStringList(_quickItemsKey) ?? <String>[];

    final loadedTasks = _decode<HouseholdTask>(
      _prefs?.getStringList(_tasksKey) ?? <String>[],
      HouseholdTask.decode,
    );
    final now = DateTime.now();
    tasks = loadedTasks
        .where((task) => !task.shouldPurge(now))
        .toList(growable: false);
    if (tasks.length != loadedTasks.length) {
      await _persistTasks();
    }

    routines = _decode<RoutineItem>(
      _prefs?.getStringList(_routinesKey) ?? <String>[],
      RoutineItem.decode,
    );
    supplies = _decode<SupplyItem>(
      _prefs?.getStringList(_suppliesKey) ?? <String>[],
      SupplyItem.decode,
    );
    homeThings = _decode<HomeThing>(
      _prefs?.getStringList(_homeThingsKey) ?? <String>[],
      HomeThing.decode,
    );
    homeEvents = _decode<HomeEvent>(
      _prefs?.getStringList(_homeEventsKey) ?? <String>[],
      HomeEvent.decode,
    );
    utilityReadings = _decode<UtilityReading>(
      _prefs?.getStringList(_utilityReadingsKey) ?? <String>[],
      UtilityReading.decode,
    );
    isReady = true;
    notifyListeners();
  }

  List<T> _decode<T>(List<String> values, T Function(String value) decoder) {
    return values
        .map<T?>((value) {
          try {
            return decoder(value);
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList(growable: false);
  }

  void bindHouseholdDataSink(HouseholdDataMutationSink? sink) {
    _householdDataSink = sink;
  }

  void _queueHouseholdMutation(HouseholdDataMutation mutation) {
    final sink = _householdDataSink;
    if (sink == null) return;
    unawaited(sink(mutation).catchError((_) {}));
  }

  Future<void> completeOnboarding({
    required String name,
    required String type,
    required bool useLocalOnly,
  }) async {
    homeName = name.trim().isEmpty ? 'My home' : name.trim();
    homeType = type;
    localOnly = useLocalOnly;
    onboardingComplete = true;

    await _prefs?.setString(_homeNameKey, homeName);
    await _prefs?.setString(_homeTypeKey, homeType);
    await _prefs?.setBool(_localOnlyKey, localOnly);
    await _prefs?.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> addQuickItem(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    quickItems = <String>[...quickItems, trimmed];
    await _prefs?.setStringList(_quickItemsKey, quickItems);
    notifyListeners();
  }

  Future<void> removeQuickItem(String value) async {
    quickItems = <String>[...quickItems]..remove(value);
    await _prefs?.setStringList(_quickItemsKey, quickItems);
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    required String createdByName,
    String? createdByUid,
    String? notes,
    String? assigneeName,
    String? assigneeUid,
    DateTime? dueAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    tasks = <HouseholdTask>[
      ...tasks,
      HouseholdTask(
        id: _uuid.v4(),
        title: trimmed,
        notes: _cleanOptional(notes),
        assigneeName: _cleanOptional(assigneeName),
        assigneeUid: _cleanOptional(assigneeUid),
        dueAt: dueAt,
        createdAt: DateTime.now(),
        createdByName: createdByName.trim().isEmpty
            ? 'You'
            : createdByName.trim(),
        createdByUid: createdByUid,
      ),
    ];
    await _persistTasks();
    notifyListeners();
  }

  Future<void> toggleTask(
    String id, {
    required String actorName,
    String? actorUid,
  }) async {
    tasks = tasks.map((task) {
      if (task.id != id) return task;
      if (task.completed) return task.reopen();
      return task.complete(
        at: DateTime.now(),
        byName: actorName,
        byUid: actorUid,
      );
    }).toList(growable: false);
    await _persistTasks();
    notifyListeners();
  }

  Future<void> pruneExpiredTasks({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final filtered = tasks
        .where((task) => !task.shouldPurge(reference))
        .toList(growable: false);
    if (filtered.length == tasks.length) return;
    tasks = filtered;
    await _persistTasks();
    notifyListeners();
  }

  Future<void> removeTask(String id) async {
    tasks = tasks.where((item) => item.id != id).toList(growable: false);
    await _persistTasks();
    notifyListeners();
  }

  Future<void> _persistTasks() async {
    await _prefs?.setStringList(
      _tasksKey,
      tasks.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<void> addRoutine({
    required String title,
    required String category,
    required RoutineRepeat repeat,
    required int estimatedMinutes,
    required int dueHour,
    required int dueMinute,
    List<int> repeatDays = const <int>[],
    int? dayOfMonth,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final createdAt = DateTime.now();
    var item = RoutineItem(
      id: _uuid.v4(),
      title: trimmed,
      category: category,
      repeat: repeat,
      estimatedMinutes: estimatedMinutes,
      repeatDays: repeatDays,
      dayOfMonth: dayOfMonth,
      dueHour: dueHour,
      dueMinute: dueMinute,
      createdAt: createdAt,
    );
    if (item.repeats) {
      item = item.copyWith(nextDueAt: item.initialDueAt());
    }
    routines = <RoutineItem>[...routines, item];
    await _persistRoutines();
    _queueHouseholdMutation(
      HouseholdDataMutation.upsert(
        domain: HouseholdDataDomain.routine,
        itemId: item.id,
        payload: item.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> toggleRoutine(
    String id, {
    required String actorName,
    String? actorUid,
  }) async {
    final now = DateTime.now();
    routines = routines.map((item) {
      if (item.id != id) return item;
      final canUndo = !item.isDue(now) && item.lastCompletion != null;
      if (canUndo) return item.undoLastCompletion();
      return item.recordCompletion(
        at: now,
        byName: actorName,
        byUid: actorUid,
      );
    }).toList(growable: false);
    await _persistRoutines();
    final updated = routines.where((item) => item.id == id);
    if (updated.isNotEmpty) {
      _queueHouseholdMutation(
        HouseholdDataMutation.upsert(
          domain: HouseholdDataDomain.routine,
          itemId: id,
          payload: updated.first.toJson(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> removeRoutine(String id) async {
    routines = routines.where((item) => item.id != id).toList(growable: false);
    await _persistRoutines();
    _queueHouseholdMutation(
      HouseholdDataMutation.delete(
        domain: HouseholdDataDomain.routine,
        itemId: id,
      ),
    );
    notifyListeners();
  }

  Future<void> _persistRoutines() async {
    await _prefs?.setStringList(
      _routinesKey,
      routines.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<void> addSupply(
    String name,
    String category,
    SupplyStatus status,
    DateTime? expiryDate, {
    String iconKey = 'inventory',
    double? quantity,
    SupplyUnit? unit,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final item = SupplyItem(
      id: _uuid.v4(),
      name: trimmed,
      category: category,
      status: status,
      iconKey: iconKey,
      expiryDate: expiryDate,
      quantity: quantity,
      unit: unit,
    );
    supplies = <SupplyItem>[...supplies, item];
    await _persistSupplies();
    _queueHouseholdMutation(
      HouseholdDataMutation.upsert(
        domain: HouseholdDataDomain.supply,
        itemId: item.id,
        payload: item.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateSupplyStatus(String id, SupplyStatus status) async {
    supplies = supplies
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList(growable: false);
    await _persistSupplies();
    final updated = supplies.where((item) => item.id == id);
    if (updated.isNotEmpty) {
      _queueHouseholdMutation(
        HouseholdDataMutation.upsert(
          domain: HouseholdDataDomain.supply,
          itemId: id,
          payload: updated.first.toJson(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> updateSupplyQuantity(
    String id, {
    required double? quantity,
    required SupplyUnit? unit,
  }) async {
    final safeQuantity = quantity == null
        ? null
        : quantity.isNaN || quantity.isInfinite
            ? null
            : quantity.clamp(0, 999999).toDouble();
    supplies = supplies.map((item) {
      if (item.id != id) return item;
      if (safeQuantity == null || unit == null) {
        return item.copyWith(clearQuantity: true, clearUnit: true);
      }
      return item.copyWith(quantity: safeQuantity, unit: unit);
    }).toList(growable: false);
    await _persistSupplies();
    final updated = supplies.where((item) => item.id == id);
    if (updated.isNotEmpty) {
      _queueHouseholdMutation(
        HouseholdDataMutation.upsert(
          domain: HouseholdDataDomain.supply,
          itemId: id,
          payload: updated.first.toJson(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> removeSupply(String id) async {
    supplies = supplies.where((item) => item.id != id).toList(growable: false);
    await _persistSupplies();
    _queueHouseholdMutation(
      HouseholdDataMutation.delete(
        domain: HouseholdDataDomain.supply,
        itemId: id,
      ),
    );
    notifyListeners();
  }

  Future<void> _persistSupplies() async {
    await _prefs?.setStringList(
      _suppliesKey,
      supplies.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<void> addHomeThing({
    required String name,
    required String category,
    required String location,
    String? brandModel,
    DateTime? nextServiceDate,
    DateTime? warrantyUntil,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final item = HomeThing(
      id: _uuid.v4(),
      name: trimmed,
      category: category,
      location: location,
      brandModel: _cleanOptional(brandModel),
      createdAt: DateTime.now(),
      nextServiceDate: nextServiceDate,
      warrantyUntil: warrantyUntil,
      notes: _cleanOptional(notes),
    );
    homeThings = <HomeThing>[...homeThings, item];
    await _persistHomeThings();
    _queueHouseholdMutation(
      HouseholdDataMutation.upsert(
        domain: HouseholdDataDomain.homeThing,
        itemId: item.id,
        payload: item.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> removeHomeThing(String id) async {
    final removedEventIds = homeEvents
        .where((item) => item.thingId == id)
        .map((item) => item.id)
        .toList(growable: false);
    homeThings = homeThings.where((item) => item.id != id).toList(growable: false);
    homeEvents = homeEvents.where((item) => item.thingId != id).toList(growable: false);
    await Future.wait(<Future<void>>[
      _persistHomeThings(),
      _persistHomeEvents(),
    ]);
    _queueHouseholdMutation(
      HouseholdDataMutation.delete(
        domain: HouseholdDataDomain.homeThing,
        itemId: id,
      ),
    );
    for (final eventId in removedEventIds) {
      _queueHouseholdMutation(
        HouseholdDataMutation.delete(
          domain: HouseholdDataDomain.homeEvent,
          itemId: eventId,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> addHomeEvent({
    required HomeEventType type,
    required String title,
    required DateTime date,
    required String completedByName,
    String? thingId,
    String? notes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final item = HomeEvent(
      id: _uuid.v4(),
      type: type,
      title: trimmed,
      date: date,
      completedByName: completedByName.trim().isEmpty
          ? 'You'
          : completedByName.trim(),
      thingId: thingId,
      notes: _cleanOptional(notes),
    );
    homeEvents = <HomeEvent>[...homeEvents, item]
      ..sort((a, b) => b.date.compareTo(a.date));
    await _persistHomeEvents();
    _queueHouseholdMutation(
      HouseholdDataMutation.upsert(
        domain: HouseholdDataDomain.homeEvent,
        itemId: item.id,
        payload: item.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> removeHomeEvent(String id) async {
    homeEvents = homeEvents.where((item) => item.id != id).toList(growable: false);
    await _persistHomeEvents();
    _queueHouseholdMutation(
      HouseholdDataMutation.delete(
        domain: HouseholdDataDomain.homeEvent,
        itemId: id,
      ),
    );
    notifyListeners();
  }

  Future<void> addUtilityReading({
    required UtilityType type,
    required double value,
    required DateTime recordedAt,
    required String recordedByName,
    String? unit,
    String? notes,
  }) async {
    final item = UtilityReading(
      id: _uuid.v4(),
      type: type,
      value: value,
      unit: _cleanOptional(unit) ?? type.defaultUnit,
      recordedAt: recordedAt,
      recordedByName: recordedByName.trim().isEmpty
          ? 'You'
          : recordedByName.trim(),
      notes: _cleanOptional(notes),
    );
    utilityReadings = <UtilityReading>[...utilityReadings, item]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _persistUtilityReadings();
    _queueHouseholdMutation(
      HouseholdDataMutation.upsert(
        domain: HouseholdDataDomain.utilityReading,
        itemId: item.id,
        payload: item.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> removeUtilityReading(String id) async {
    utilityReadings = utilityReadings
        .where((item) => item.id != id)
        .toList(growable: false);
    await _persistUtilityReadings();
    _queueHouseholdMutation(
      HouseholdDataMutation.delete(
        domain: HouseholdDataDomain.utilityReading,
        itemId: id,
      ),
    );
    notifyListeners();
  }

  Future<void> applyHouseholdRoutines(
    List<RoutineItem> cloudItems, {
    Set<String> preserveLocalIds = const <String>{},
  }) async {
    routines = _replaceCloudSubset<RoutineItem>(
      current: routines,
      cloud: cloudItems,
      preserveLocalIds: preserveLocalIds,
      idOf: (item) => item.id,
    );
    await _persistRoutines();
    notifyListeners();
  }

  Future<void> applyHouseholdSupplies(
    List<SupplyItem> cloudItems, {
    Set<String> preserveLocalIds = const <String>{},
  }) async {
    supplies = _replaceCloudSubset<SupplyItem>(
      current: supplies,
      cloud: cloudItems,
      preserveLocalIds: preserveLocalIds,
      idOf: (item) => item.id,
    );
    await _persistSupplies();
    notifyListeners();
  }

  Future<void> applyHouseholdHomeThings(
    List<HomeThing> cloudItems, {
    Set<String> preserveLocalIds = const <String>{},
  }) async {
    homeThings = _replaceCloudSubset<HomeThing>(
      current: homeThings,
      cloud: cloudItems,
      preserveLocalIds: preserveLocalIds,
      idOf: (item) => item.id,
    );
    await _persistHomeThings();
    notifyListeners();
  }

  Future<void> applyHouseholdHomeEvents(
    List<HomeEvent> cloudItems, {
    Set<String> preserveLocalIds = const <String>{},
  }) async {
    homeEvents = _replaceCloudSubset<HomeEvent>(
      current: homeEvents,
      cloud: cloudItems,
      preserveLocalIds: preserveLocalIds,
      idOf: (item) => item.id,
    )..sort((a, b) => b.date.compareTo(a.date));
    await _persistHomeEvents();
    notifyListeners();
  }

  Future<void> applyHouseholdUtilityReadings(
    List<UtilityReading> cloudItems, {
    Set<String> preserveLocalIds = const <String>{},
  }) async {
    utilityReadings = _replaceCloudSubset<UtilityReading>(
      current: utilityReadings,
      cloud: cloudItems,
      preserveLocalIds: preserveLocalIds,
      idOf: (item) => item.id,
    )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _persistUtilityReadings();
    notifyListeners();
  }

  List<T> _replaceCloudSubset<T>({
    required List<T> current,
    required List<T> cloud,
    required Set<String> preserveLocalIds,
    required String Function(T item) idOf,
  }) {
    final result = <String, T>{};
    for (final item in current) {
      final id = idOf(item);
      if (preserveLocalIds.contains(id)) result[id] = item;
    }
    for (final item in cloud) {
      result[idOf(item)] = item;
    }
    return result.values.toList(growable: false);
  }

  Future<void> _persistHomeThings() async {
    await _prefs?.setStringList(
      _homeThingsKey,
      homeThings.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<void> _persistHomeEvents() async {
    await _prefs?.setStringList(
      _homeEventsKey,
      homeEvents.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<void> _persistUtilityReadings() async {
    await _prefs?.setStringList(
      _utilityReadingsKey,
      utilityReadings.map((item) => item.encode()).toList(growable: false),
    );
  }

  /// Clears household content stored only on this device. It deliberately
  /// keeps onboarding/home identity and account sign-in state separate so a
  /// user does not accidentally delete their cloud account by clearing local
  /// household data.
  Future<void> eraseLocalHouseholdData() async {
    quickItems = <String>[];
    tasks = <HouseholdTask>[];
    routines = <RoutineItem>[];
    supplies = <SupplyItem>[];
    homeThings = <HomeThing>[];
    homeEvents = <HomeEvent>[];
    utilityReadings = <UtilityReading>[];

    await Future.wait(<Future<bool>>[
      _prefs?.remove(_quickItemsKey) ?? Future<bool>.value(false),
      _prefs?.remove(_tasksKey) ?? Future<bool>.value(false),
      _prefs?.remove(_routinesKey) ?? Future<bool>.value(false),
      _prefs?.remove(_suppliesKey) ?? Future<bool>.value(false),
      _prefs?.remove(_homeThingsKey) ?? Future<bool>.value(false),
      _prefs?.remove(_homeEventsKey) ?? Future<bool>.value(false),
      _prefs?.remove(_utilityReadingsKey) ?? Future<bool>.value(false),
    ]);
    notifyListeners();
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> setLocalOnly(bool value) async {
    localOnly = value;
    await _prefs?.setBool(_localOnlyKey, value);
    notifyListeners();
  }
}
