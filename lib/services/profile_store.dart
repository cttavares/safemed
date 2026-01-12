import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:safemed/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  static const _storageKey = 'profiles';

  final List<Profile> _profiles = [];

  List<Profile> get profiles => List.unmodifiable(_profiles);

  Profile? getById(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _profiles
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(Profile.fromJson),
        );
      notifyListeners();
    } catch (_) {
      _profiles.clear();
      await prefs.remove(_storageKey);
      notifyListeners();
    }
  }

  Future<void> add(Profile profile) async {
    _profiles.add(profile);
    await _persist();
    notifyListeners();
  }

  Future<void> update(Profile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) {
      return;
    }
    _profiles[index] = profile;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> seedDemoData() async {
    if (_profiles.isNotEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final demo = [
      Profile(
        id: 'p-$now-1',
        name: 'Laura Silva',
        age: 72,
        photoPath: null,
        renalDisease: true,
        hepaticDisease: false,
        diabetes: true,
        hypertension: false,
        healthIssues: 'Arthritis',
      ),
      Profile(
        id: 'p-$now-2',
        name: 'Carlos Teixeira',
        age: 58,
        photoPath: null,
        renalDisease: false,
        hepaticDisease: true,
        diabetes: false,
        hypertension: true,
        healthIssues: '',
      ),
    ];
    _profiles.addAll(demo);
    await _persist();
    notifyListeners();
  }
}
