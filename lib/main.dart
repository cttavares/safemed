import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/services/alert_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ProfileStore.instance.load(),
    PlanStore.instance.load(),
    AlertStore.instance.load(),
  ]);
  if (kDebugMode) {
    await _seedDemoData();
  }
  runApp(const SafeMedApp());
}

class SafeMedApp extends StatelessWidget {
  const SafeMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeMed',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomeScreen(),
    );
  }
}

Future<void> _seedDemoData() async {
  final profileStore = ProfileStore.instance;
  final planStore = PlanStore.instance;
  if (profileStore.profiles.isEmpty) {
    await profileStore.seedDemoData();
  }
  if (planStore.plans.isEmpty) {
    final ids = profileStore.profiles.map((p) => p.id).toList();
    await planStore.seedDemoData(ids);
  }
}
