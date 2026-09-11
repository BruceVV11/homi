import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/emergency_region.dart';

/// App-wide, offline emergency-region preference.
///
/// No location permission is used to choose a default. Homi only suggests the
/// device locale's region when that region exists in the verified bundled
/// catalog, and the user can override it at any time.
class EmergencyRegionService extends ChangeNotifier {
  EmergencyRegionService._();

  static final EmergencyRegionService instance = EmergencyRegionService._();
  static const _selectedRegionKey = 'homi.safety.emergencyRegionIso';

  EmergencyRegion? _current;
  bool _initialized = false;

  EmergencyRegion? get current => _current;
  bool get initialized => _initialized;

  EmergencyRegion? get localeSuggestion {
    final countryCode = PlatformDispatcher.instance.locale.countryCode;
    return EmergencyRegionCatalog.byIsoCode(countryCode);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = EmergencyRegionCatalog.byIsoCode(
        preferences.getString(_selectedRegionKey),
      );
      // Use the device locale as a suggestion for existing installs, but do
      // not persist it until the user explicitly confirms/selects a region.
      _current = stored ?? localeSuggestion;
    } catch (_) {
      _current = localeSuggestion;
    }
    _initialized = true;
  }

  Future<void> select(EmergencyRegion region) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedRegionKey, region.isoCode);
    if (_current?.isoCode == region.isoCode) return;
    _current = region;
    notifyListeners();
  }
}
