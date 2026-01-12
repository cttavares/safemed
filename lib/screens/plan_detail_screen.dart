import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/screens/plan_form_screen.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'package:safemed/utils/plan_schedule.dart';

class PlanDetailScreen extends StatelessWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    final planStore = PlanStore.instance;
    final profileStore = ProfileStore.instance;
    final listenable = Listenable.merge([planStore, profileStore]);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan details')),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          PrescriptionPlan? plan;
          for (final candidate in planStore.plans) {
            if (candidate.id == planId) {
              plan = candidate;
              break;
            }
          }
          if (plan == null) {
            return const Center(child: Text('Plan not found.'));
          }
          final currentPlan = plan;
          final profile = profileStore.getById(currentPlan.profileId);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (profile != null) _ProfileHeader(profile: profile),
              const SizedBox(height: 12),
              _DetailTile(label: 'Plan', value: currentPlan.name),
              _DetailTile(
                label: 'Status',
                value: _statusText(currentPlan),
              ),
              _DetailTile(
                label: 'Start date',
                value: _formatDate(currentPlan.startDate),
              ),
              _DetailTile(
                label: 'End date',
                value: currentPlan.endDate == null
                    ? 'Not set'
                    : _formatDate(currentPlan.endDate!),
              ),
              SwitchListTile(
                title: const Text('Plan active'),
                value: currentPlan.isActive,
                onChanged: (value) async {
                  await planStore.update(
                    currentPlan.copyWith(isActive: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Medications',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final medication in currentPlan.medications)
                Card(
                  child: ListTile(
                    title: Text(medication.name),
                    subtitle: Text(_medicationText(medication)),
                  ),
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
                        builder: (_) => PlanFormScreen(plan: currentPlan),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit plan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _confirmDelete(context, planStore, currentPlan),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusText(PrescriptionPlan plan) {
    final now = DateTime.now();
    final active = plan.isActive && isPlanInRange(plan, now);
    return active ? 'Active' : 'Inactive';
  }

  String _medicationText(PlanMedication medication) {
    final parts = <String>[];
    if (medication.dose.trim().isNotEmpty) {
      parts.add('Dose: ${medication.dose}');
    }
    if (medication.times.isNotEmpty) {
      parts.add('Times: ${medication.times.join(', ')}');
    }
    if (medication.notes.trim().isNotEmpty) {
      parts.add(medication.notes.trim());
    }
    return parts.join(' | ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlanStore store,
    PrescriptionPlan plan,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('Remove ${plan.name}? This cannot be undone.'),
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
      await store.remove(plan.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
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

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
