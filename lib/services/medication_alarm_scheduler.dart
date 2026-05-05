import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:safemed/services/app_settings_store.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

class MedicationAlarmScheduler {
  MedicationAlarmScheduler._();

  static final MedicationAlarmScheduler instance = MedicationAlarmScheduler._();

  static const _channelIdPrefix = 'medication_alarm_channel';
  static const _channelName = 'Medication Alarms';
  static const _channelDescription =
      'Medication reminders with alarm sound and vibration';

  static const int _androidMaxPending = 500;
  static const int _iosMaxPending = 60;
  static const int _lookaheadDays = 30;

  static const _alarmChannel = MethodChannel('safemed/alarm_manager');

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Tracks IDs of AlarmManager alarms so we can cancel them in [cancelAll].
  final Set<int> _scheduledAlarmIds = <int>{};

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissions();
    await _configureTimezone();

    _initialized = true;
  }

  Future<void> syncWithPlans({
    required List<PrescriptionPlan> plans,
    required List<Profile> profiles,
  }) async {
    await initialize();
    final settings = AppSettingsStore.instance.settings;

    // Cancel flutter_local_notifications alarms
    await _notifications.cancelAll();
    // Cancel direct AlarmManager alarms
    await _cancelAllAlarmManagerAlarms();

    if (!settings.notificationsEnabled) {
      return;
    }

    final upcoming = _buildUpcomingAlarms(
      plans: plans,
      profiles: profiles,
      now: DateTime.now(),
    );

    for (final alarm in upcoming) {
      final id = _notificationIdFor(alarm.uniqueKey);
      await _notifications.zonedSchedule(
        id,
        alarm.title,
        alarm.body,
        tz.TZDateTime.from(alarm.scheduledAt, tz.local),
        _detailsForAlarm(settings: settings, profile: alarm.profile),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: alarm.uniqueKey,
      );
      // Also schedule a direct AlarmManager alarm so AlarmActivity fires
      // even when the app is in the foreground.
      await _scheduleAlarmManagerAlarm(
        id: id,
        title: alarm.title,
        body: alarm.body,
        triggerAtMillis: alarm.scheduledAt.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    await _notifications.cancelAll();
    await _cancelAllAlarmManagerAlarms();
  }

  // ── AlarmManager helpers (Android only) ──────────────────────────────────

  Future<void> _scheduleAlarmManagerAlarm({
    required int id,
    required String title,
    required String body,
    required int triggerAtMillis,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmChannel.invokeMethod<void>('scheduleAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'triggerAtMillis': triggerAtMillis,
      });
      _scheduledAlarmIds.add(id);
    } catch (_) {
      // AlarmManager scheduling is best-effort; notification is the fallback.
    }
  }

  Future<void> _cancelAllAlarmManagerAlarms() async {
    if (!Platform.isAndroid) return;
    for (final id in _scheduledAlarmIds) {
      try {
        await _alarmChannel.invokeMethod<void>('cancelAlarm', {'id': id});
      } catch (_) {}
    }
    _scheduledAlarmIds.clear();
  }

  NotificationDetails _detailsForAlarm({
    required AppSettings settings,
    required Profile profile,
  }) {
    final resolvedTone = profile.alarmTone == 'default'
        ? settings.alarmTone
        : profile.alarmTone;
    final resolvedCustomUri =
        profile.customAlarmUri ?? settings.customAlarmUri;

    final soundEnabled = settings.alarmsEnabled;
    final vibrationEnabled = settings.alarmsEnabled && settings.vibrationEnabled;

    final useImported = soundEnabled &&
        resolvedTone == 'custom' &&
        resolvedCustomUri != null &&
        resolvedCustomUri.trim().isNotEmpty;

    final useBundledAlarm = soundEnabled && !useImported && resolvedTone != 'notification';

    final channelId = '${_channelIdPrefix}_${profile.id}_${_channelHash(
      settings: settings,
      resolvedTone: resolvedTone,
      resolvedCustomUri: resolvedCustomUri,
    )}';
    final iosSound = switch (resolvedTone) {
      'ios_pulse' => 'med_alarm_1.wav',
      'ios_beacon' => 'med_alarm_2.wav',
      _ => null,
    };

    // Strong repeating vibration: wait 0 ms, buzz 900 ms, pause 400 ms (repeat)
    final vibrationPattern =
        vibrationEnabled ? Int64List.fromList([0, 900, 400]) : null;

    // Whether to show the full-screen alarm overlay on the lock screen
    final showFullScreen = resolvedTone != 'notification' && soundEnabled;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
        vibrationPattern: vibrationPattern,
        autoCancel: false,
        ongoing: true,
        additionalFlags: Int32List.fromList(const <int>[4]),
        sound: useImported
            ? UriAndroidNotificationSound(resolvedCustomUri.trim())
            : (useBundledAlarm
                  ? const RawResourceAndroidNotificationSound('med_alarm_android')
                  : null),
        audioAttributesUsage: resolvedTone == 'notification'
            ? AudioAttributesUsage.notification
            : AudioAttributesUsage.alarm,
        fullScreenIntent: showFullScreen,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  int _channelHash({
    required AppSettings settings,
    required String resolvedTone,
    required String? resolvedCustomUri,
  }) {
    return Object.hash(
      settings.notificationsEnabled,
      settings.alarmsEnabled,
      settings.vibrationEnabled,
      resolvedTone,
      resolvedCustomUri,
    ).abs();
  }

  List<_ScheduledAlarm> _buildUpcomingAlarms({
    required List<PrescriptionPlan> plans,
    required List<Profile> profiles,
    required DateTime now,
  }) {
    final profileById = {for (final profile in profiles) profile.id: profile};
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: _lookaheadDays));

    final alarms = <_ScheduledAlarm>[];

    for (final plan in plans) {
      if (!plan.isActive || plan.medications.isEmpty) {
        continue;
      }

      final planStart = DateTime(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day,
      );
      final planEnd = plan.endDate == null
          ? dayEnd
          : DateTime(plan.endDate!.year, plan.endDate!.month, plan.endDate!.day);

      if (planEnd.isBefore(dayStart)) {
        continue;
      }

      final effectiveStart = planStart.isAfter(dayStart) ? planStart : dayStart;
      final effectiveEnd = planEnd.isBefore(dayEnd) ? planEnd : dayEnd;
      if (effectiveEnd.isBefore(effectiveStart)) {
        continue;
      }

      for (
        DateTime day = effectiveStart;
        !day.isAfter(effectiveEnd);
        day = day.add(const Duration(days: 1))
      ) {
        for (final medication in plan.medications) {
          for (final time in medication.times) {
            final parsed = _parseTime(time);
            if (parsed == null) {
              continue;
            }

            final scheduledAt = DateTime(
              day.year,
              day.month,
              day.day,
              parsed.$1,
              parsed.$2,
            );

            if (!scheduledAt.isAfter(now)) {
              continue;
            }

            final profile = profileById[plan.profileId];
            if (profile == null) {
              continue;
            }
            final doseText = medication.dose.trim().isEmpty
                ? ''
                : ' (${medication.dose.trim()})';
            final timeText = '${parsed.$1.toString().padLeft(2, '0')}:${parsed.$2.toString().padLeft(2, '0')}';

            alarms.add(
              _ScheduledAlarm(
                uniqueKey:
                    '${plan.id}|${medication.id}|${scheduledAt.toIso8601String()}',
                profile: profile,
                scheduledAt: scheduledAt,
                title: profile.name,
                body:
                    'Plan: ${plan.name}\nMedication: ${medication.name}$doseText\nTake at: $timeText',
              ),
            );
          }
        }
      }
    }

    alarms.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final maxPending = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosMaxPending,
      _ => _androidMaxPending,
    };

    if (alarms.length <= maxPending) {
      return alarms;
    }
    return alarms.take(maxPending).toList();
  }

  (int, int)? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return (hour, minute);
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    // Some plugin versions expose exact alarm permission only at runtime.
    final dynamic dynamicAndroid = androidImpl;
    try {
      await dynamicAndroid?.requestExactAlarmsPermission();
    } catch (_) {}

    // Android 14+ requires explicit permission to show full-screen intents
    // (USE_FULL_SCREEN_INTENT). The plugin exposes this via
    // requestFullScreenIntentPermission if available.
    try {
      await dynamicAndroid?.requestFullScreenIntentPermission();
    } catch (_) {}

    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    final macImpl = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _configureTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  int _notificationIdFor(String key) => key.hashCode & 0x7fffffff;
}

class _ScheduledAlarm {
  final String uniqueKey;
  final Profile profile;
  final DateTime scheduledAt;
  final String title;
  final String body;

  const _ScheduledAlarm({
    required this.uniqueKey,
    required this.profile,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });
}
