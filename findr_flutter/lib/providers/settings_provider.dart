import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit { mi, km }
enum ThemeModeSetting { system, light, dark }

const _kDistanceUnitKey = 'distance_unit';
const _kCurrencyKey = 'currency';
const _kThemeModeKey = 'theme_mode';

/// Settings with SharedPreferences persistence.
class SettingsProvider with ChangeNotifier {
  DistanceUnit _distanceUnit = DistanceUnit.mi;
  String _currency = 'USD';
  ThemeModeSetting _themeMode = ThemeModeSetting.light;

  DistanceUnit get distanceUnit => _distanceUnit;
  String get currency => _currency;
  bool get useKm => _distanceUnit == DistanceUnit.km;
  ThemeModeSetting get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeModeSetting.dark;

  /// Call once at startup to load persisted values.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unitStr = prefs.getString(_kDistanceUnitKey);
      if (unitStr == 'km') _distanceUnit = DistanceUnit.km;
      final curr = prefs.getString(_kCurrencyKey);
      if (curr != null && curr.isNotEmpty) _currency = curr;
      final theme = prefs.getString(_kThemeModeKey);
      if (theme == 'dark') {
        _themeMode = ThemeModeSetting.dark;
      } else if (theme == 'system') {
        _themeMode = ThemeModeSetting.system;
      }
      notifyListeners();
    } catch (e) {
      print('[Wayvio] SettingsProvider.load failed: $e');
    }
  }

  void setDistanceUnit(DistanceUnit unit) {
    if (_distanceUnit == unit) return;
    _distanceUnit = unit;
    notifyListeners();
    _persist();
  }

  void setCurrency(String currency) {
    if (_currency == currency) return;
    _currency = currency;
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeModeSetting mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kDistanceUnitKey, _distanceUnit == DistanceUnit.km ? 'km' : 'mi');
      await prefs.setString(_kCurrencyKey, _currency);
      await prefs.setString(_kThemeModeKey,
          _themeMode == ThemeModeSetting.dark ? 'dark' :
          _themeMode == ThemeModeSetting.system ? 'system' : 'light');
    } catch (e) {
      print('[Wayvio] SettingsProvider._persist failed: $e');
    }
  }
}
