import 'package:flutter/material.dart';
import 'package:safemed/screens/administration_screen.dart';
import 'package:safemed/screens/alerts_screen.dart';
import 'package:safemed/screens/medication_explorer/medication_explorer_screen.dart';
import 'package:safemed/screens/profile_list_screen.dart';
import 'package:safemed/screens/profile_select_screen.dart';
import 'package:safemed/screens/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color _cameraAccent = Color(0xFFC9FCCA);
    const Color _searchAccent = Color(0xFFC2BDF0);
    const Color _cameraAccentDark = Color(0xFF2E6B4A);
    const Color _searchAccentDark = Color(0xFF594A9E);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cameraAccent, _searchAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _cameraAccentDark.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // logo slightly to the right
                Transform.translate(
                  offset: const Offset(5, 0),
                  child: Image.asset(
                    'assets/images/app_icon/app_icon_small_no-bg.png',
                    height: 92,
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      height: 92,
                      width: 92,
                      child: Icon(Icons.medical_services, color: _cameraAccentDark, size: 56),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // text nudged to the left relative to the container center
                Transform.translate(
                  offset: const Offset(-14, 0),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        'SAFEMED',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.4
                            ..color = _searchAccentDark,
                        ),
                      ),
                      const Text(
                        'SAFEMED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                MaterialPageRoute(
                  builder: (_) => const MedicationExplorerScreen(),
                ),
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
                MaterialPageRoute(builder: (_) => const AdministrationScreen()),
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
          _Card(
            title: 'Settings',
            subtitle: 'Notifications, alarm sound and factory reset',
            icon: Icons.settings,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
      color: const Color(0xFFC9FCCA).withOpacity(0.14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF594A9E).withOpacity(0.22),
          width: 1.8,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Color(0xFF2E6B4A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
