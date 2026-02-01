import 'package:flutter/foundation.dart';

enum DistanceUnit { mi, km }

/// In-memory settings; add SharedPreferences if you want persistence.
class SettingsProvider with ChangeNotifier {
  DistanceUnit _distanceUnit = DistanceUnit.mi;
  String _currency = 'USD';

  DistanceUnit get distanceUnit => _distanceUnit;
  String get currency => _currency;
  bool get useKm => _distanceUnit == DistanceUnit.km;

  void setDistanceUnit(DistanceUnit unit) {
    if (_distanceUnit == unit) return;
    _distanceUnit = unit;
    notifyListeners();
  }

  void setCurrency(String currency) {
    if (_currency == currency) return;
    _currency = currency;
    notifyListeners();
  }
}
