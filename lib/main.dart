import 'package:flutter/material.dart';
import 'package:safemed/services/alert_store.dart';
import 'package:safemed/services/app_settings_store.dart';
import 'package:safemed/services/infarmed_medication_service.dart';
import 'package:safemed/services/medication_alarm_scheduler.dart';
import 'package:safemed/services/medication_history_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ProfileStore.instance.load(),
    PlanStore.instance.load(),
    AlertStore.instance.load(),
    MedicationHistoryStore.instance.load(),
    AppSettingsStore.instance.load(),
    // Load Infarmed medication database from bundled JSON asset.
    // Fails gracefully if the scraper hasn't run yet (empty asset).
    infarmedMedicationService.init(),
  ]);
  await MedicationHistoryStore.instance.syncFromPlans(PlanStore.instance.plans);
  await MedicationAlarmScheduler.instance.syncWithPlans(
    plans: PlanStore.instance.plans,
    profiles: ProfileStore.instance.profiles,
  );
  runApp(const SafeMedApp());
}

class SafeMedApp extends StatelessWidget {
  const SafeMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safemed',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomeScreen(),
    );
  }
}
