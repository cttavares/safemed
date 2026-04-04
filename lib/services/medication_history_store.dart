import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:safemed/models/medication_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationHistoryStore extends ChangeNotifier {
  MedicationHistoryStore._();

  static final MedicationHistoryStore instance = MedicationHistoryStore._();

  static const _storageKey = 'medication_history';

  final List<MedicationHistory> _history = [];

  List<MedicationHistory> get allHistory => List.unmodifiable(_history);

  List<MedicationHistory> getForProfile(String profileId) {
    return _history.where((h) => h.profileId == profileId).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<MedicationHistory> getActiveForProfile(String profileId) {
    return _history
        .where((h) => h.profileId == profileId && h.isActive)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _history
        ..clear()
        ..addAll(
          decoded.whereType<Map<String, dynamic>>().map(
            MedicationHistory.fromJson,
          ),
        );
      notifyListeners();
    } catch (_) {
      _history.clear();
      await prefs.remove(_storageKey);
      notifyListeners();
    }
  }

  Future<void> add(MedicationHistory entry) async {
    _history.add(entry);
    await _persist();
    notifyListeners();
  }

  Future<void> update(MedicationHistory entry) async {
    final index = _history.indexWhere((h) => h.id == entry.id);
    if (index == -1) {
      return;
    }
    _history[index] = entry;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _history.removeWhere((h) => h.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> removeForProfile(String profileId) async {
    _history.removeWhere((h) => h.profileId == profileId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _history.map((h) => h.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}
