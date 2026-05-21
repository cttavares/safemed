import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/screens/plan_form_screen.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';
import 'package:safemed/services/risk_engine.dart';
import 'package:safemed/services/llm_review_service.dart';
import 'package:safemed/screens/api_key_dialog.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
              _DetailTile(label: 'Status', value: _statusText(currentPlan)),
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
                  await planStore.update(currentPlan.copyWith(isActive: value));
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
              // ── Risk alerts ────────────────────────────────────────
              if (profile != null) ...[
                const SizedBox(height: 16),
                _RiskAlertsSection(plan: currentPlan, profile: profile),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () =>
                        _reviewPlanWithAI(context, currentPlan, profile),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      'Revisão Inteligente do Plano',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
    if (medication.intervalHours != null && medication.firstDoseAt != null) {
      final fda = medication.firstDoseAt!;
      final y = fda.year.toString().padLeft(4, '0');
      final mo = fda.month.toString().padLeft(2, '0');
      final d = fda.day.toString().padLeft(2, '0');
      final h = fda.hour.toString().padLeft(2, '0');
      final mi = fda.minute.toString().padLeft(2, '0');
      parts.add('Every ${medication.intervalHours}h from $y-$mo-$d $h:$mi');
    } else if (medication.times.isNotEmpty) {
      parts.add('Times: ${medication.times.join(', ')}');
    }
    if (medication.notes.trim().isNotEmpty) {
      parts.add(medication.notes.trim());
    }
    return parts.join(' | ');
  }

  Future<void> _reviewPlanWithAI(
    BuildContext context,
    PrescriptionPlan plan,
    Profile profile,
  ) async {
    // Check for API key
    String? apiKey = await LlmReviewService.getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!context.mounted) return;
      final saved = await ApiKeyDialog.show(context);
      if (!saved) return;
      apiKey = await LlmReviewService.getSavedApiKey();
    }
    if (apiKey == null || apiKey.isEmpty) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AIReviewSheet(
        plan: plan,
        profile: profile,
        apiKey: apiKey,
      ),
    );
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

// ── AI Review Bottom Sheet ───────────────────────────────────────────────────

class _AIReviewSheet extends StatefulWidget {
  final PrescriptionPlan plan;
  final Profile profile;
  final String apiKey;

  const _AIReviewSheet({
    required this.plan,
    required this.profile,
    required this.apiKey,
  });

  @override
  State<_AIReviewSheet> createState() => _AIReviewSheetState();
}

class _AIReviewSheetState extends State<_AIReviewSheet> {
  late Future<String> _reviewFuture;

  @override
  void initState() {
    super.initState();
    _reviewFuture = LlmReviewService.reviewPlan(
      widget.profile,
      widget.plan,
      widget.apiKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Revisão Inteligente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<String>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurple),
                        SizedBox(height: 16),
                        Text('A analisar o plano de medicação...'),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao analisar o plano:\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else if (snapshot.hasData) {
                  return Markdown(
                    data: snapshot.data!,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
          ),
        ],
      ),
    );
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

// ── Risk Alerts Section ───────────────────────────────────────────────────────

class _RiskAlertsSection extends StatelessWidget {
  final PrescriptionPlan plan;
  final Profile profile;

  const _RiskAlertsSection({required this.plan, required this.profile});

  @override
  Widget build(BuildContext context) {
    final alerts = analyzeplan(plan, profile);

    if (alerts.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: const Text('No safety alerts',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('No known interactions or contraindications detected.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: _severityColor(alerts.first.severity), size: 20),
          const SizedBox(width: 6),
          Text(
            'Safety alerts (${alerts.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 8),
        ...alerts.map((a) => _AlertCard(alert: a)),
      ],
    );
  }
}

class _AlertCard extends StatefulWidget {
  final RiskAlert alert;
  const _AlertCard({required this.alert});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final color = _severityColor(a.severity);
    final bg = color.withOpacity(0.07);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      color: bg,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _SeverityBadge(severity: a.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey,
                ),
              ]),
              if (a.involvedDrugs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: a.involvedDrugs
                      .map((d) => Chip(
                            label: Text(d,
                                style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  a.detail,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    a.category,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final RiskSeverity severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

Color _severityColor(RiskSeverity s) {
  switch (s) {
    case RiskSeverity.critical: return const Color(0xFFB71C1C);
    case RiskSeverity.high:     return const Color(0xFFE65100);
    case RiskSeverity.moderate: return const Color(0xFFF57F17);
    case RiskSeverity.info:     return const Color(0xFF1565C0);
  }
}
