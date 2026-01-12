import 'package:flutter/material.dart';
import 'package:safemed/screens/administration_screen.dart';
import 'package:safemed/screens/alerts_screen.dart';
import 'package:safemed/screens/medication_explorer_screen.dart';
import 'package:safemed/screens/profile_list_screen.dart';
import 'package:safemed/screens/profile_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SafeMed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            title: 'New prescription plan',
            subtitle: 'Create a plan from a prescription',
            icon: Icons.medical_services,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSelectScreen()),
              );
            },
          ),
          _Card(
            title: 'Medication explorer',
            subtitle: 'Scan labels or describe symptoms',
            icon: Icons.camera_alt,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationExplorerScreen()),
              );
            },
          ),
          _Card(
            title: 'Profiles',
            subtitle: 'Create and manage patients',
            icon: Icons.manage_accounts,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileListScreen()),
              );
            },
          ),
          _Card(
            title: 'Administration',
            subtitle: 'Today schedule',
            icon: Icons.schedule,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdministrationScreen(),
                ),
              );
            },
          ),
          _Card(
            title: 'Alerts',
            subtitle: 'Due medications to administer',
            icon: Icons.notifications_active,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
