import 'package:flutter/material.dart';
import 'package:safemed/models/medication_history.dart';
import 'package:safemed/services/medication_history_store.dart';

class MedicationHistoryScreen extends StatelessWidget {
  final String profileId;
  final String profileName;

  const MedicationHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  Widget build(BuildContext context) {
    final historyStore = MedicationHistoryStore.instance;

    return Scaffold(
      appBar: AppBar(title: Text('$profileName - Medication History')),
      body: AnimatedBuilder(
        animation: historyStore,
        builder: (context, _) {
          final history = historyStore.getForProfile(profileId);

          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No medication history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'History is automatically created from active plans',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final activeHistory = history.where((h) => h.isActive).toList();
          final pastHistory = history.where((h) => !h.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeHistory.isNotEmpty) ...[
                const Text(
                  'Currently Taking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...activeHistory.map((entry) => _HistoryCard(entry: entry)),
                const SizedBox(height: 24),
              ],
              if (pastHistory.isNotEmpty) ...[
                const Text(
                  'Past Medications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...pastHistory.map((entry) => _HistoryCard(entry: entry)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final MedicationHistory entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.medicationName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (entry.dose.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.dose,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (entry.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Started',
              value: _formatDate(entry.startDate),
            ),
            if (entry.endDate != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.event_available,
                label: 'Ended',
                value: _formatDate(entry.endDate!),
              ),
            ],
            if (entry.reasonForTaking.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.medical_information,
                label: 'Reason',
                value: entry.reasonForTaking,
              ),
            ],
            if (entry.reasonForStopping != null &&
                entry.reasonForStopping!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.stop_circle_outlined,
                label: 'Stopped',
                value: entry.reasonForStopping!,
              ),
            ],
            if (entry.effectivenessRating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Effectiveness: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < entry.effectivenessRating!
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
            if (entry.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.notes, label: 'Notes', value: entry.notes),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
