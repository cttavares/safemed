import 'package:flutter/material.dart';
import 'package:safemed/screens/prescription_screen.dart';
import 'package:safemed/screens/profile_form_screen.dart';
import 'package:safemed/services/profile_store.dart';

class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProfileStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Select patient')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final profiles = store.profiles;
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Create a profile to start a plan.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileFormScreen(),
                        ),
                      );
                    },
                    child: const Text('Add profile'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                child: ListTile(
                  title: Text(profile.name),
                  subtitle: Text('Age ${profile.age}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrescriptionScreen(
                          profileId: profile.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
