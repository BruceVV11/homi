import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/routine_item.dart';
import '../domain/supply_item.dart';

class HomiAppController extends ChangeNotifier {
  static const _onboardingKey = 'homi.onboarding.complete';
  static const _homeNameKey = 'homi.home.name';
  static const _homeTypeKey = 'homi.home.type';
  static const _localOnlyKey = 'homi.account.localOnly';
  static const _quickItemsKey = 'homi.today.quickItems';
  static const _routinesKey = 'homi.routines.items';
  static const _suppliesKey = 'homi.supplies.items';

  final Uuid _uuid = Uuid();
  SharedPreferences? _prefs;

  bool isReady = false;
  bool onboardingComplete = false;
  bool localOnly = true;
  String homeName = 'My home';
  String homeType = 'House';
  List<String> quickItems = <String>[];
  List<RoutineItem> routines = <RoutineItem>[];
  List<SupplyItem> supplies = <SupplyItem>[];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    onboardingComplete = _prefs?.getBool(_onboardingKey) ?? false;
    homeName = _prefs?.getString(_homeNameKey) ?? 'My home';
    homeType = _prefs?.getString(_homeTypeKey) ?? 'House';
    localOnly = _prefs?.getBool(_localOnlyKey) ?? true;
    quickItems = _prefs?.getStringList(_quickItemsKey) ?? <String>[];
    routines = _decodeRoutines(_prefs?.getStringList(_routinesKey) ?? <String>[]);
    supplies = _decodeSupplies(_prefs?.getStringList(_suppliesKey) ?? <String>[]);
    isReady = true;
    notifyListeners();
  }

  List<RoutineItem> _decodeRoutines(List<String> values) {
    return values
        .map<RoutineItem?>((value) {
          try {
            return RoutineItem.decode(value);
          } catch (_) {
            return null;
          }
        })
        .whereType<RoutineItem>()
        .toList(growable: false);
  }

  List<SupplyItem> _decodeSupplies(List<String> values) {
    return values
        .map<SupplyItem?>((value) {
          try {
            return SupplyItem.decode(value);
          } catch (_) {
            return null;
          }
        })
        .whereType<SupplyItem>()
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

  Future<void> addRoutine(String title, String category, String frequency) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    routines = <RoutineItem>[
      ...routines,
      RoutineItem(
        id: _uuid.v4(),
        title: trimmed,
        category: category,
        frequency: frequency,
      ),
    ];
    await _persistRoutines();
    notifyListeners();
  }

  Future<void> toggleRoutine(String id) async {
    routines = routines.map((item) {
      if (item.id != id) return item;
      final completed = !item.completed;
      return item.copyWith(
        completed: completed,
        lastCompletedAt: completed ? DateTime.now() : null,
        clearLastCompletedAt: !completed,
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
    DateTime? expiryDate,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    supplies = <SupplyItem>[
      ...supplies,
      SupplyItem(
        id: _uuid.v4(),
        name: trimmed,
        category: category,
        status: status,
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

  Future<void> setLocalOnly(bool value) async {
    localOnly = value;
    await _prefs?.setBool(_localOnlyKey, value);
    notifyListeners();
  }
}
