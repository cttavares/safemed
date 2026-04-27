import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/services/alert_store.dart';
import 'package:safemed/services/app_settings_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'package:safemed/utils/plan_schedule.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _ringtone = FlutterRingtonePlayer();

  Set<String> _currentDueIds = <String>{};
  Set<String> _silencedDueIds = <String>{};
  bool _isAlarmPlaying = false;

  @override
  void dispose() {
    _stopAlarm();
    super.dispose();
  }

  void _updateAlarmState(Set<String> dueIds) {
    if (setEquals(dueIds, _currentDueIds)) {
      return;
    }

    _currentDueIds = dueIds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final settings = AppSettingsStore.instance.settings;
      if (!settings.notificationsEnabled || !settings.alarmsEnabled) {
        _stopAlarm();
        return;
      }

      if (dueIds.isEmpty) {
        _silencedDueIds = <String>{};
        _stopAlarm();
        return;
      }

      if (setEquals(dueIds, _silencedDueIds)) {
        _stopAlarm();
        return;
      }

      _startAlarm();
    });
  }

  void _startAlarm() {
    if (_isAlarmPlaying) {
      return;
    }

    final settings = AppSettingsStore.instance.settings;
    if (settings.alarmTone == 'notification') {
      _ringtone.playNotification(looping: true, asAlarm: false, volume: 1.0);
    } else {
      _ringtone.playAlarm(looping: true, asAlarm: true, volume: 1.0);
    }

    if (mounted) {
      setState(() => _isAlarmPlaying = true);
    }
  }

  void _stopAlarm() {
    if (!_isAlarmPlaying) {
      return;
    }

    _ringtone.stop();

    if (mounted) {
      setState(() => _isAlarmPlaying = false);
    }
  }

  void _silenceCurrentAlerts() {
    if (_currentDueIds.isEmpty) {
      return;
    }

    _silencedDueIds = Set<String>.from(_currentDueIds);
    _stopAlarm();
  }

  @override
  Widget build(BuildContext context) {
    final planStore = PlanStore.instance;
    final profileStore = ProfileStore.instance;
    final alertStore = AlertStore.instance;
    final settingsStore = AppSettingsStore.instance;
    final listenable = Listenable.merge([
      planStore,
      profileStore,
      alertStore,
      settingsStore,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (_currentDueIds.isNotEmpty)
            TextButton.icon(
              onPressed: _silenceCurrentAlerts,
              icon: Icon(
                _isAlarmPlaying ? Icons.volume_off : Icons.notifications_off,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                _isAlarmPlaying ? 'Silence' : 'Silenced',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final now = DateTime.now();
          final occurrences = buildDueOccurrences(
            now: now,
            plans: planStore.plans,
            profiles: profileStore.profiles,
            dismissedIds: alertStore.dismissedIds,
          );

          _updateAlarmState(occurrences.map((o) => o.id).toSet());

          if (occurrences.isEmpty) {
            return const Center(child: Text('No alerts right now.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: occurrences.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final occurrence = occurrences[index];
              final profile = occurrence.profile;
              final time = _formatTime(occurrence.scheduledAt);
              final subtitle =
                  '${profile.name} | ${occurrence.plan.name} | ${occurrence.medication.name}';

              return Card(
                child: ListTile(
                  leading: _Avatar(profile: profile),
                  title: Text('Due at $time'),
                  subtitle: Text(subtitle),
                  trailing: TextButton(
                    onPressed: () async {
                      await alertStore.dismiss(occurrence.id);
                    },
                    child: const Text('Dismiss'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Avatar extends StatelessWidget {
  final Profile profile;

  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photoPath = profile.photoPath;
    ImageProvider? imageProvider;
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
      }
    }

    return CircleAvatar(
      backgroundImage: imageProvider,
      child: imageProvider == null ? Text(_initial(profile.name)) : null,
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed[0].toUpperCase();
  }
}
