import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:safemed/screens/home_screen.dart';
import 'package:safemed/services/alert_store.dart';
import 'package:safemed/services/app_settings_store.dart';
import 'package:safemed/services/medication_alarm_scheduler.dart';
import 'package:safemed/services/medication_history_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _rescheduleAlarms() async {
    await MedicationAlarmScheduler.instance.syncWithPlans(
      plans: PlanStore.instance.plans,
      profiles: ProfileStore.instance.profiles,
    );
  }

  Future<void> _pickCustomSound(AppSettingsStore settingsStore) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
    );

    final path = result?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }

    final uri = Uri.file(path).toString();
    await settingsStore.setCustomAlarmUri(uri);
    await settingsStore.setAlarmTone('custom');
    await _rescheduleAlarms();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported sound: ${p.basename(path)}')),
    );
  }

  Future<void> _confirmFactoryReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory reset'),
        content: const Text(
          'This will erase all profiles, plans, medication history, alerts and settings. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase all'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    await MedicationAlarmScheduler.instance.cancelAll();
    await PlanStore.instance.clearAll();
    await ProfileStore.instance.clearAll();
    await MedicationHistoryStore.instance.clearAll();
    await AlertStore.instance.clearAll();
    await AppSettingsStore.instance.resetToDefaults();

    if (!mounted) {
      return;
    }

    setState(() => _busy = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsStore = AppSettingsStore.instance;
    final platformIsAndroid = settingsStore.isAndroid;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: settingsStore,
        builder: (context, _) {
          final settings = settingsStore.settings;
          final customName = settings.customAlarmUri == null
              ? 'No custom sound selected'
              : p.basename(Uri.parse(settings.customAlarmUri!).path);

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alerts and alarms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Alarms are scheduled in the OS and should ring even when the app is closed.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.notificationsEnabled,
                          title: const Text('Enable notifications'),
                          subtitle: const Text('Show medication reminders'),
                          onChanged: (value) async {
                            await settingsStore.setNotificationsEnabled(value);
                            await _rescheduleAlarms();
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.alarmsEnabled,
                          title: const Text('Enable alarm sound'),
                          subtitle: const Text('Play ringtone when reminder fires'),
                          onChanged: settings.notificationsEnabled
                              ? (value) async {
                                  await settingsStore.setAlarmsEnabled(value);
                                  await _rescheduleAlarms();
                                }
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.vibrationEnabled,
                          title: const Text('Enable vibration'),
                          onChanged:
                              settings.notificationsEnabled && settings.alarmsEnabled
                              ? (value) async {
                                  await settingsStore.setVibrationEnabled(value);
                                  await _rescheduleAlarms();
                                }
                              : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: settings.alarmTone,
                          decoration: const InputDecoration(
                            labelText: 'Alarm tone',
                            border: OutlineInputBorder(),
                          ),
                              items: platformIsAndroid
                                  ? const [
                                      DropdownMenuItem(
                                        value: 'alarm',
                                        child: Text('System alarm style'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'notification',
                                        child: Text('System notification style'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'custom',
                                        child: Text('Imported sound (Android)'),
                                      ),
                                    ]
                                  : const [
                                      DropdownMenuItem(
                                        value: 'ios_pulse',
                                        child: Text('iOS Pulse'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ios_beacon',
                                        child: Text('iOS Beacon'),
                                      ),
                                    ],
                          onChanged:
                              settings.notificationsEnabled && settings.alarmsEnabled
                              ? (value) async {
                                      final tone = value ?? (platformIsAndroid ? 'alarm' : 'ios_pulse');
                                  await settingsStore.setAlarmTone(tone);
                                  await _rescheduleAlarms();
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                            if (platformIsAndroid) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.music_note),
                                title: Text(customName),
                                subtitle: const Text(
                                  'Import a local audio file from your phone',
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          settings.notificationsEnabled && settings.alarmsEnabled
                                          ? () => _pickCustomSound(settingsStore)
                                          : null,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Import sound'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: settings.customAlarmUri == null
                                        ? null
                                        : () async {
                                            await settingsStore.clearCustomAlarmUri();
                                            await settingsStore.setAlarmTone('alarm');
                                            await _rescheduleAlarms();
                                          },
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Imported sounds are available for Android background alarms.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ] else ...[
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.library_music),
                                title: Text('Internal iOS sounds'),
                                subtitle: Text(
                                  'Choose one of the bundled tones. iOS does not allow importing arbitrary phone files for notification sounds.',
                                ),
                              ),
                            ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Factory reset',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Erase all app data and return to a clean state.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _busy ? null : _confirmFactoryReset,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Reset to factory settings'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
