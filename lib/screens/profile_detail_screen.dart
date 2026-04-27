import 'dart:io';

import 'package:flutter/material.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/screens/medication_history_screen.dart';
import 'package:safemed/screens/plan_list_screen.dart';
import 'package:safemed/screens/prescription_screen.dart';
import 'package:safemed/screens/profile_form_screen.dart';
import 'package:safemed/services/medication_history_store.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';

class ProfileDetailScreen extends StatelessWidget {
  final String profileId;

  const ProfileDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    final profileStore = ProfileStore.instance;
    final planStore = PlanStore.instance;
    final listenable = Listenable.merge([profileStore, planStore]);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final profile = profileStore.getById(profileId);
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: 16),
              _SectionTitle('Profile Category'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        profile.category == ProfileType.child
                            ? Icons.child_care
                            : profile.category == ProfileType.elderly
                            ? Icons.elderly
                            : Icons.person,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        profile.category.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle('Alarm Tone'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: Text(_toneLabel(profile)),
                  subtitle: Text(_toneSubtitle(profile)),
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle('Sexo e Gravidez'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        profile.sex == BiologicalSex.female
                            ? Icons.female
                            : Icons.male,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile.sex.displayName +
                              (profile.sex == BiologicalSex.female
                                  ? (profile.isPregnant
                                        ? ' • Gravida'
                                        : ' • Nao gravida')
                                  : ''),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle('Conditions'),
              const SizedBox(height: 8),
              _ConditionsList(profile: profile),
              if (profile.allergies.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle('Allergies'),
                const SizedBox(height: 8),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: profile.allergies
                          .map(
                            (allergy) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 20,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(allergy)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
              if (profile.medicalRestrictions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle('Medical Restrictions'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: profile.medicalRestrictions
                          .map(
                            (restriction) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(restriction)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PrescriptionScreen(profileId: profile.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_services),
                      label: const Text('New prescription plan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanListScreen(
                              profileId: profile.id,
                              title: '${profile.name} plans',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment),
                      label: const Text('Plans'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileFormScreen(profile: profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicationHistoryScreen(
                        profileId: profile.id,
                        profileName: profile.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Medication History'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmDelete(context, profileStore, planStore, profile),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete profile'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProfileStore profileStore,
    PlanStore planStore,
    Profile profile,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Remove ${profile.name} and all plans?'),
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
      await MedicationHistoryStore.instance.removeForProfile(profile.id);
      await profileStore.remove(profile.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

String _toneLabel(Profile profile) {
  switch (profile.alarmTone) {
    case 'alarm':
      return 'System alarm style';
    case 'notification':
      return 'System notification style';
    case 'custom':
      return 'Imported sound';
    case 'ios_pulse':
      return 'iOS Pulse';
    case 'ios_beacon':
      return 'iOS Beacon';
    case 'default':
    default:
      return 'App default';
  }
}

String _toneSubtitle(Profile profile) {
  if (profile.alarmTone == 'custom' && profile.customAlarmUri != null) {
    return 'Custom file: ${Uri.parse(profile.customAlarmUri!).pathSegments.isEmpty ? profile.customAlarmUri : Uri.parse(profile.customAlarmUri!).pathSegments.last}';
  }
  if (profile.alarmTone == 'default') {
    return 'Uses the global app alarm settings';
  }
  return 'Used when this profile receives a medication reminder';
}

class _ProfileHeader extends StatelessWidget {
  final Profile profile;

  const _ProfileHeader({required this.profile});

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

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: imageProvider,
          child: imageProvider == null ? Text(_initial(profile.name)) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Age ${profile.age}'),
            ],
          ),
        ),
      ],
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}

class _ConditionsList extends StatelessWidget {
  final Profile profile;

  const _ConditionsList({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = <String>[];
    if (profile.renalDisease) items.add('Renal disease');
    if (profile.hepaticDisease) items.add('Hepatic disease');
    if (profile.diabetes) items.add('Diabetes');
    if (profile.hypertension) items.add('Hypertension');
    if (profile.healthIssues.trim().isNotEmpty) {
      items.add(profile.healthIssues.trim());
    }

    if (items.isEmpty) {
      return const Text('No conditions listed.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('- $item'),
          ),
      ],
    );
  }
}
