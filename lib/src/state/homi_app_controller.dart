import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomiAppController extends ChangeNotifier {
  static const _onboardingKey = 'homi.onboarding.complete';
  static const _homeNameKey = 'homi.home.name';
  static const _homeTypeKey = 'homi.home.type';
  static const _localOnlyKey = 'homi.account.localOnly';
  static const _quickItemsKey = 'homi.today.quickItems';

  SharedPreferences? _prefs;

  bool isReady = false;
  bool onboardingComplete = false;
  bool localOnly = true;
  String homeName = 'My home';
  String homeType = 'House';
  List<String> quickItems = <String>[];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    onboardingComplete = _prefs?.getBool(_onboardingKey) ?? false;
    homeName = _prefs?.getString(_homeNameKey) ?? 'My home';
    homeType = _prefs?.getString(_homeTypeKey) ?? 'House';
    localOnly = _prefs?.getBool(_localOnlyKey) ?? true;
    quickItems = _prefs?.getStringList(_quickItemsKey) ?? <String>[];
    isReady = true;
    notifyListeners();
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

  Future<void> setLocalOnly(bool value) async {
    localOnly = value;
    await _prefs?.setBool(_localOnlyKey, value);
    notifyListeners();
  }
}
