import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AlarmTonePreset {
  systemAlarm,
  systemNotification,
  imported,
  iosPulse,
  iosBeacon;

  String get value => switch (this) {
    AlarmTonePreset.systemAlarm => 'alarm',
    AlarmTonePreset.systemNotification => 'notification',
    AlarmTonePreset.imported => 'custom',
    AlarmTonePreset.iosPulse => 'ios_pulse',
    AlarmTonePreset.iosBeacon => 'ios_beacon',
  };
}

class AppSettings {
  final bool notificationsEnabled;
  final bool alarmsEnabled;
  final bool vibrationEnabled;
  final String alarmTone;
  final String? customAlarmUri;

  const AppSettings({
    required this.notificationsEnabled,
    required this.alarmsEnabled,
    required this.vibrationEnabled,
    required this.alarmTone,
    this.customAlarmUri,
  });

  static const AppSettings defaults = AppSettings(
    notificationsEnabled: true,
    alarmsEnabled: true,
    vibrationEnabled: true,
    alarmTone: 'alarm',
    customAlarmUri: null,
  );

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? alarmsEnabled,
    bool? vibrationEnabled,
    String? alarmTone,
    String? customAlarmUri,
    bool clearCustomAlarmUri = false,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      alarmsEnabled: alarmsEnabled ?? this.alarmsEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      alarmTone: alarmTone ?? this.alarmTone,
      customAlarmUri: clearCustomAlarmUri
          ? null
          : (customAlarmUri ?? this.customAlarmUri),
    );
  }
}

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();

  static final AppSettingsStore instance = AppSettingsStore._();

  static const _notificationsEnabledKey = 'settings_notifications_enabled';
  static const _alarmsEnabledKey = 'settings_alarms_enabled';
  static const _vibrationEnabledKey = 'settings_vibration_enabled';
  static const _alarmToneKey = 'settings_alarm_tone';
  static const _customAlarmUriKey = 'settings_custom_alarm_uri';

  AppSettings _settings = AppSettings.defaults;

  AppSettings get settings => _settings;

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  List<AlarmTonePreset> get availableTonePresets => isAndroid
      ? const [
          AlarmTonePreset.systemAlarm,
          AlarmTonePreset.systemNotification,
          AlarmTonePreset.imported,
        ]
      : const [
          AlarmTonePreset.systemAlarm,
          AlarmTonePreset.iosPulse,
          AlarmTonePreset.iosBeacon,
        ];

  String get toneLabel => switch (_settings.alarmTone) {
    'alarm' => 'System alarm style',
    'notification' => 'System notification style',
    'custom' => 'Imported sound (Android)',
    'ios_pulse' => 'iOS Pulse',
    'ios_beacon' => 'iOS Beacon',
    _ => 'System alarm style',
  };

  String? get iosNotificationSoundName => switch (_settings.alarmTone) {
    'ios_pulse' => 'med_alarm_1.wav',
    'ios_beacon' => 'med_alarm_2.wav',
    _ => null,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      alarmsEnabled: prefs.getBool(_alarmsEnabledKey) ?? true,
      vibrationEnabled: prefs.getBool(_vibrationEnabledKey) ?? true,
      alarmTone: prefs.getString(_alarmToneKey) ?? 'alarm',
      customAlarmUri: prefs.getString(_customAlarmUriKey),
    );
    if (isIOS && _settings.alarmTone == 'custom') {
      _settings = _settings.copyWith(alarmTone: 'ios_pulse', clearCustomAlarmUri: true);
    }
    if (isAndroid && (_settings.alarmTone == 'ios_pulse' || _settings.alarmTone == 'ios_beacon')) {
      _settings = _settings.copyWith(alarmTone: 'alarm');
    }
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _settings = _settings.copyWith(notificationsEnabled: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setAlarmsEnabled(bool value) async {
    _settings = _settings.copyWith(alarmsEnabled: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _settings = _settings.copyWith(vibrationEnabled: value);
    await _persist();
    notifyListeners();
  }

  Future<void> setAlarmTone(String value) async {
    _settings = _settings.copyWith(
      alarmTone: value,
      clearCustomAlarmUri: value == 'custom' &&
          (_settings.customAlarmUri == null || _settings.customAlarmUri!.isEmpty),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> setCustomAlarmUri(String uri) async {
    _settings = _settings.copyWith(customAlarmUri: uri);
    await _persist();
    notifyListeners();
  }

  Future<void> clearCustomAlarmUri() async {
    _settings = _settings.copyWith(clearCustomAlarmUri: true);
    await _persist();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, _settings.notificationsEnabled);
    await prefs.setBool(_alarmsEnabledKey, _settings.alarmsEnabled);
    await prefs.setBool(_vibrationEnabledKey, _settings.vibrationEnabled);
    await prefs.setString(_alarmToneKey, _settings.alarmTone);
    if (_settings.customAlarmUri == null || _settings.customAlarmUri!.isEmpty) {
      await prefs.remove(_customAlarmUriKey);
    } else {
      await prefs.setString(_customAlarmUriKey, _settings.customAlarmUri!);
    }
  }
}
