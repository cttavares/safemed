import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/services/alert_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'package:safemed/utils/plan_schedule.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planStore = PlanStore.instance;
    final profileStore = ProfileStore.instance;
    final alertStore = AlertStore.instance;
    final listenable = Listenable.merge([planStore, profileStore, alertStore]);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
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

          if (occurrences.isEmpty) {
            return const Center(child: Text('No alerts right now.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: occurrences.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final occurrence = occurrences[index];
              final profile = occurrence.profile;
              final time = _formatTime(occurrence.scheduledAt);
              final subtitle =
                  '${profile.name} | ${occurrence.medication.name}';

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
