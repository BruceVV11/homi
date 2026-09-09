import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/home_event.dart';
import '../domain/home_thing.dart';
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
    tasks = _decode<HouseholdTask>(
      _prefs?.getStringList(_tasksKey) ?? <String>[],
      HouseholdTask.decode,
    );
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
    notifyListeners();
  }

  Future<void> removeRoutine(String id) async {
    routines = routines.where((item) => item.id != id).toList(growable: false);
    await _persistRoutines();
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
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    supplies = <SupplyItem>[
      ...supplies,
      SupplyItem(
        id: _uuid.v4(),
        name: trimmed,
        category: category,
        status: status,
        iconKey: iconKey,
        expiryDate: expiryDate,
      ),
    ];
    await _persistSupplies();
    notifyListeners();
  }

  Future<void> updateSupplyStatus(String id, SupplyStatus status) async {
    supplies = supplies
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList(growable: false);
    await _persistSupplies();
    notifyListeners();
  }

  Future<void> removeSupply(String id) async {
    supplies = supplies.where((item) => item.id != id).toList(growable: false);
    await _persistSupplies();
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
    homeThings = <HomeThing>[
      ...homeThings,
      HomeThing(
        id: _uuid.v4(),
        name: trimmed,
        category: category,
        location: location,
        brandModel: _cleanOptional(brandModel),
        createdAt: DateTime.now(),
        nextServiceDate: nextServiceDate,
        warrantyUntil: warrantyUntil,
        notes: _cleanOptional(notes),
      ),
    ];
    await _persistHomeThings();
    notifyListeners();
  }

  Future<void> removeHomeThing(String id) async {
    homeThings = homeThings.where((item) => item.id != id).toList(growable: false);
    homeEvents = homeEvents.where((item) => item.thingId != id).toList(growable: false);
    await Future.wait(<Future<void>>[
      _persistHomeThings(),
      _persistHomeEvents(),
    ]);
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
    homeEvents = <HomeEvent>[
      ...homeEvents,
      HomeEvent(
        id: _uuid.v4(),
        type: type,
        title: trimmed,
        date: date,
        completedByName: completedByName.trim().isEmpty
            ? 'You'
            : completedByName.trim(),
        thingId: thingId,
        notes: _cleanOptional(notes),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    await _persistHomeEvents();
    notifyListeners();
  }

  Future<void> removeHomeEvent(String id) async {
    homeEvents = homeEvents.where((item) => item.id != id).toList(growable: false);
    await _persistHomeEvents();
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
    utilityReadings = <UtilityReading>[
      ...utilityReadings,
      UtilityReading(
        id: _uuid.v4(),
        type: type,
        value: value,
        unit: _cleanOptional(unit) ?? type.defaultUnit,
        recordedAt: recordedAt,
        recordedByName: recordedByName.trim().isEmpty
            ? 'You'
            : recordedByName.trim(),
        notes: _cleanOptional(notes),
      ),
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _persistUtilityReadings();
    notifyListeners();
  }

  Future<void> removeUtilityReading(String id) async {
    utilityReadings = utilityReadings
        .where((item) => item.id != id)
        .toList(growable: false);
    await _persistUtilityReadings();
    notifyListeners();
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
