import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanStore extends ChangeNotifier {
  PlanStore._();

  static final PlanStore instance = PlanStore._();

  static const _storageKey = 'plans';

  final List<PrescriptionPlan> _plans = [];

  List<PrescriptionPlan> get plans => List.unmodifiable(_plans);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _plans
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(PrescriptionPlan.fromJson),
        );
      notifyListeners();
    } catch (_) {
      _plans.clear();
      await prefs.remove(_storageKey);
      notifyListeners();
    }
  }

  Future<void> add(PrescriptionPlan plan) async {
    _plans.add(plan);
    await _persist();
    notifyListeners();
  }

  Future<void> update(PrescriptionPlan plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index == -1) {
      return;
    }
    _plans[index] = plan;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _plans.map((p) => p.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> seedDemoData(List<String> profileIds) async {
    if (_plans.isNotEmpty || profileIds.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final firstProfile = profileIds.first;
    final secondProfile = profileIds.length > 1 ? profileIds[1] : firstProfile;
    final demo = [
      PrescriptionPlan(
        id: 'plan-${now.millisecondsSinceEpoch}-1',
        profileId: firstProfile,
        name: 'Morning + Evening routine',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: null,
        isActive: true,
        medications: [
          PlanMedication(
            id: 'med-${now.millisecondsSinceEpoch}-1',
            name: 'Metformin',
            dose: '500 mg',
            times: const ['08:00', '20:00'],
            notes: 'With food',
          ),
          PlanMedication(
            id: 'med-${now.millisecondsSinceEpoch}-2',
            name: 'Vitamin D',
            dose: '1000 IU',
            times: const ['09:00'],
            notes: '',
          ),
        ],
      ),
      PrescriptionPlan(
        id: 'plan-${now.millisecondsSinceEpoch}-2',
        profileId: secondProfile,
        name: 'Post-op antibiotics',
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 1)),
        isActive: true,
        medications: [
          PlanMedication(
            id: 'med-${now.millisecondsSinceEpoch}-3',
            name: 'Amoxicillin',
            dose: '500 mg',
            times: const ['07:00', '15:00', '23:00'],
            notes: 'Complete full course',
          ),
        ],
      ),
    ];
    _plans.addAll(demo);
    await _persist();
    notifyListeners();
  }
}
