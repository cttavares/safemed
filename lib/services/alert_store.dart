import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertStore extends ChangeNotifier {
  AlertStore._();

  static final AlertStore instance = AlertStore._();

  static const _storageKey = 'dismissed_alerts';
  static const _dateKey = 'dismissed_alerts_date';

  final Set<String> _dismissed = {};

  Set<String> get dismissedIds => Set.unmodifiable(_dismissed);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKeyFor(DateTime.now());
    final storedDate = prefs.getString(_dateKey);
    if (storedDate != today) {
      _dismissed.clear();
      await prefs.setString(_dateKey, today);
      await prefs.setStringList(_storageKey, <String>[]);
      notifyListeners();
      return;
    }

    final stored = prefs.getStringList(_storageKey) ?? <String>[];
    _dismissed
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  Future<void> dismiss(String id) async {
    if (_dismissed.contains(id)) {
      return;
    }
    _dismissed.add(id);
    await _persist();
    notifyListeners();
  }

  bool isDismissed(String id) => _dismissed.contains(id);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _dismissed.toList());
  }

  String _dateKeyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

}
