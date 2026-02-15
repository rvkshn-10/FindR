import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit { mi, km }

const _kDistanceUnitKey = 'distance_unit';
const _kCurrencyKey = 'currency';

/// Settings with SharedPreferences persistence.
class SettingsProvider with ChangeNotifier {
  DistanceUnit _distanceUnit = DistanceUnit.mi;
  String _currency = 'USD';

  DistanceUnit get distanceUnit => _distanceUnit;
  String get currency => _currency;
  bool get useKm => _distanceUnit == DistanceUnit.km;

  /// Call once at startup to load persisted values.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final unitStr = prefs.getString(_kDistanceUnitKey);
    if (unitStr == 'km') _distanceUnit = DistanceUnit.km;
    final curr = prefs.getString(_kCurrencyKey);
    if (curr != null && curr.isNotEmpty) _currency = curr;
    notifyListeners();
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kDistanceUnitKey, _distanceUnit == DistanceUnit.km ? 'km' : 'mi');
    await prefs.setString(_kCurrencyKey, _currency);
  }
}
