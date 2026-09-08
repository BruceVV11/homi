import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomiAppController extends ChangeNotifier {
  static const _onboardingKey = 'homi.onboarding.complete';
  static const _homeNameKey = 'homi.home.name';
  static const _homeTypeKey = 'homi.home.type';
  static const _localOnlyKey = 'homi.account.localOnly';

  SharedPreferences? _prefs;

  bool isReady = false;
  bool onboardingComplete = false;
  bool localOnly = true;
  String homeName = 'My home';
  String homeType = 'House';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    onboardingComplete = _prefs?.getBool(_onboardingKey) ?? false;
    homeName = _prefs?.getString(_homeNameKey) ?? 'My home';
    homeType = _prefs?.getString(_homeTypeKey) ?? 'House';
    localOnly = _prefs?.getBool(_localOnlyKey) ?? true;
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

  Future<void> setLocalOnly(bool value) async {
    localOnly = value;
    await _prefs?.setBool(_localOnlyKey, value);
    notifyListeners();
  }
}
