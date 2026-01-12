import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/screens/plan_detail_screen.dart';
import 'package:safemed/screens/plan_form_screen.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'package:safemed/utils/plan_schedule.dart';

class PlanListScreen extends StatelessWidget {
  final String? profileId;
  final String? title;

  const PlanListScreen({super.key, this.profileId, this.title});

  @override
  Widget build(BuildContext context) {
    final planStore = PlanStore.instance;
    final profileStore = ProfileStore.instance;
    final listenable = Listenable.merge([planStore, profileStore]);

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Plans')),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final plans = profileId == null
              ? planStore.plans
              : planStore.plans
                  .where((plan) => plan.profileId == profileId)
                  .toList();
          if (plans.isEmpty) {
            final message = profileId == null
                ? 'No plans yet. Tap + to add one.'
                : 'No plans for this patient yet. Tap + to add one.';
            return Center(child: Text(message));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final profile = profileStore.getById(plan.profileId);
              final status = _statusText(plan);
              return Card(
                child: ListTile(
                  title: Text(plan.name),
                  subtitle: Text(
                    '${profile?.name ?? 'Unknown patient'} | $status',
                  ),
                  trailing: Switch(
                    value: plan.isActive,
                    onChanged: (value) async {
                      await planStore.update(plan.copyWith(isActive: value));
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanDetailScreen(planId: plan.id),
                      ),
                    );
                  },
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
            MaterialPageRoute(
              builder: (_) => PlanFormScreen(profileId: profileId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _statusText(PrescriptionPlan plan) {
    final start = _formatDate(plan.startDate);
    final end = plan.endDate == null ? null : _formatDate(plan.endDate!);
    final now = DateTime.now();
    final inRange = isPlanInRange(plan, now);

    final active = plan.isActive && inRange;
    final label = active ? 'Active' : 'Inactive';

    if (end == null) {
      return '$label since $start';
    }
    return '$label ($start to $end)';
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
