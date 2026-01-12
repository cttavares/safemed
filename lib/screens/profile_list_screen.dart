import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/screens/profile_detail_screen.dart';
import 'package:safemed/screens/profile_form_screen.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';

class ProfileListScreen extends StatelessWidget {
  const ProfileListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProfileStore.instance;
    final planStore = PlanStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: AnimatedBuilder(
        animation: Listenable.merge([store, planStore]),
        builder: (context, _) {
          final profiles = store.profiles;
          if (profiles.isEmpty) {
            return const Center(
              child: Text('No profiles yet. Tap + to add one.'),
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
                  leading: _ProfileAvatar(profile: profile),
                  title: Text(profile.name),
                  subtitle: Text(_subtitleText(profile)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileDetailScreen(profileId: profile.id),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileFormScreen(profile: profile),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmDelete(context, store, planStore, profile),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  static String _subtitleText(Profile profile) {
    final tags = <String>[];
    if (profile.renalDisease) {
      tags.add('Renal');
    }
    if (profile.hepaticDisease) {
      tags.add('Hepatic');
    }
    if (profile.diabetes) {
      tags.add('Diabetes');
    }
    if (profile.hypertension) {
      tags.add('Hypertension');
    }
    final issues = profile.healthIssues.trim();
    if (issues.isNotEmpty) {
      tags.add(issues);
    }

    if (tags.isEmpty) {
      return 'Age ${profile.age}';
    }
    return 'Age ${profile.age} - ${tags.join(', ')}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProfileStore store,
    PlanStore planStore,
    Profile profile,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Remove ${profile.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final plans = planStore.plans
          .where((plan) => plan.profileId == profile.id)
          .toList();
      for (final plan in plans) {
        await planStore.remove(plan.id);
      }
      await store.remove(profile.id);
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  final Profile profile;

  const _ProfileAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photoPath = profile.photoPath;
    if (photoPath == null || photoPath.isEmpty) {
      return CircleAvatar(
        child: Text(_initial(profile.name)),
      );
    }
    final file = File(photoPath);
    if (!file.existsSync()) {
      return CircleAvatar(
        child: Text(_initial(profile.name)),
      );
    }
    return CircleAvatar(
      backgroundImage: FileImage(file),
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
