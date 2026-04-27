import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:safemed/models/medication_history.dart';
import 'package:safemed/models/prescription_plan.dart';
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

  List<MedicationHistory> getForProfileFiltered(
    String profileId, {
    String? planId,
    DateTime? day,
  }) {
    final dayOnly = day == null ? null : DateTime(day.year, day.month, day.day);
    return _history.where((history) {
      if (history.profileId != profileId) {
        return false;
      }
      if (planId != null && history.planId != planId) {
        return false;
      }
      if (dayOnly != null) {
        final start = DateTime(
          history.startDate.year,
          history.startDate.month,
          history.startDate.day,
        );
        final end = history.endDate == null
            ? null
            : DateTime(
                history.endDate!.year,
                history.endDate!.month,
                history.endDate!.day,
              );
        if (dayOnly.isBefore(start)) {
          return false;
        }
        if (end != null && dayOnly.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList()
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
      _history.clear();
      notifyListeners();
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

  Future<void> syncFromPlans(List<PrescriptionPlan> plans) async {
    final derivedHistory = _buildHistoryFromPlans(plans);

    _history
      ..clear()
      ..addAll(derivedHistory);

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

  Future<void> clearAll() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _history.map((h) => h.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  List<MedicationHistory> _buildHistoryFromPlans(List<PrescriptionPlan> plans) {
    final derived = <MedicationHistory>[];

    for (final plan in plans) {
      for (final medication in plan.medications) {
        final notes = <String>[];
        if (medication.notes.trim().isNotEmpty) {
          notes.add(medication.notes.trim());
        }
        if (medication.times.isNotEmpty) {
          notes.add('Times: ${medication.times.join(', ')}');
        }

        derived.add(
          MedicationHistory(
            id: 'history-${plan.id}-${medication.id}',
            profileId: plan.profileId,
            planId: plan.id,
            planName: plan.name,
            medicationName: medication.name,
            dose: medication.dose,
            startDate: plan.startDate,
            endDate: plan.endDate,
            reasonForTaking: plan.name,
            reasonForStopping: plan.isActive ? null : 'Plan finished',
            notes: notes.join(' | '),
          ),
        );
      }
    }

    return derived;
  }
}
