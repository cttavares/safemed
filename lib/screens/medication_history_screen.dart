import 'package:flutter/material.dart';
import 'package:safemed/models/medication_history.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/services/medication_history_store.dart';
import 'package:safemed/services/plan_store.dart';

class MedicationHistoryScreen extends StatefulWidget {
  final String profileId;
  final String profileName;

  const MedicationHistoryScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  String? _selectedPlanId;
  DateTime? _selectedDay;
  DateTimeRange? _selectedDateRange;
  String _selectedStatus = 'all';
  String _searchQuery = '';

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final initialDate = _selectedDay ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;
        _selectedDateRange = null;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDateRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedDay = null;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedPlanId = null;
      _selectedDay = null;
      _selectedDateRange = null;
      _selectedStatus = 'all';
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyStore = MedicationHistoryStore.instance;
    final planStore = PlanStore.instance;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.profileName} - Medication History')),
      body: AnimatedBuilder(
        animation: Listenable.merge([historyStore, planStore]),
        builder: (context, _) {
          final plans = planStore.plans
              .where((plan) => plan.profileId == widget.profileId)
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          final selectedPlanId = plans.any((plan) => plan.id == _selectedPlanId)
              ? _selectedPlanId
              : null;
          final historyForProfile = historyStore.getForProfileFiltered(
            widget.profileId,
            planId: selectedPlanId,
            day: _selectedDay,
          );

          final filteredHistory = historyForProfile.where((history) {
            if (_selectedDateRange != null) {
              final entryStart = DateTime(
                history.startDate.year,
                history.startDate.month,
                history.startDate.day,
              );
              final entryEnd = history.endDate == null
                  ? entryStart
                  : DateTime(
                      history.endDate!.year,
                      history.endDate!.month,
                      history.endDate!.day,
                    );
              final rangeStart = DateTime(
                _selectedDateRange!.start.year,
                _selectedDateRange!.start.month,
                _selectedDateRange!.start.day,
              );
              final rangeEnd = DateTime(
                _selectedDateRange!.end.year,
                _selectedDateRange!.end.month,
                _selectedDateRange!.end.day,
              );

              final overlapsRange = !entryEnd.isBefore(rangeStart) &&
                  !entryStart.isAfter(rangeEnd);
              if (!overlapsRange) {
                return false;
              }
            }
            if (_selectedStatus == 'active' && !history.isActive) {
              return false;
            }
            if (_selectedStatus == 'past' && history.isActive) {
              return false;
            }
            if (_searchQuery.trim().isEmpty) {
              return true;
            }

            final query = _searchQuery.trim().toLowerCase();
            return history.medicationName.toLowerCase().contains(query) ||
                history.dose.toLowerCase().contains(query) ||
                history.reasonForTaking.toLowerCase().contains(query) ||
                (history.planName?.toLowerCase().contains(query) ?? false);
          }).toList();

          final activeHistory = filteredHistory.where((h) => h.isActive).toList();
          final pastHistory = filteredHistory.where((h) => !h.isActive).toList();
          final summaries = _buildUsageSummaries(filteredHistory);
          final totalEntries = filteredHistory.length;
          final distinctMedicines = summaries.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OverviewCard(
                totalEntries: totalEntries,
                distinctMedicines: distinctMedicines,
                activeEntries: activeHistory.length,
              ),
              const SizedBox(height: 16),
              _FiltersCard(
                plans: plans,
                selectedPlanId: selectedPlanId,
                selectedDay: _selectedDay,
                selectedDateRange: _selectedDateRange,
                selectedStatus: _selectedStatus,
                searchQuery: _searchQuery,
                onPlanChanged: (value) => setState(() => _selectedPlanId = value),
                onPickDay: _pickDay,
                onPickDateRange: _pickDateRange,
                onStatusChanged: (value) => setState(() => _selectedStatus = value),
                onSearchChanged: (value) => setState(() => _searchQuery = value),
                onClearDay: _selectedDay == null
                    ? null
                    : () => setState(() => _selectedDay = null),
                onClearRange: _selectedDateRange == null
                  ? null
                  : () => setState(() => _selectedDateRange = null),
                onClearAll: (selectedPlanId != null || _selectedDay != null || _selectedDateRange != null)
                    || _selectedStatus != 'all'
                    || _searchQuery.isNotEmpty
                    ? _clearFilters
                    : null,
              ),
              const SizedBox(height: 16),
              if (summaries.isNotEmpty) ...[
                const Text(
                  'Medication overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: summaries
                        .map((summary) => _SummaryTile(summary: summary))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (filteredHistory.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No medication history for the selected filters.'),
                  ),
                )
              else ...[
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
            ],
          );
        },
      ),
    );
  }

  List<_UsageSummary> _buildUsageSummaries(List<MedicationHistory> history) {
    final grouped = <String, _UsageSummary>{};

    for (final entry in history) {
      final key = entry.medicationName.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }

      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = _UsageSummary(
          medicationName: entry.medicationName,
          dose: entry.dose,
          count: 1,
          latestStartDate: entry.startDate,
          activeCount: entry.isActive ? 1 : 0,
        );
        continue;
      }

      grouped[key] = existing.copyWith(
        count: existing.count + 1,
        latestStartDate: entry.startDate.isAfter(existing.latestStartDate)
            ? entry.startDate
            : existing.latestStartDate,
        activeCount: existing.activeCount + (entry.isActive ? 1 : 0),
        dose: existing.dose.isEmpty ? entry.dose : existing.dose,
      );
    }

    final summaries = grouped.values.toList();
    summaries.sort((a, b) => b.count.compareTo(a.count));
    return summaries;
  }
}

class _OverviewCard extends StatelessWidget {
  final int totalEntries;
  final int distinctMedicines;
  final int activeEntries;

  const _OverviewCard({
    required this.totalEntries,
    required this.distinctMedicines,
    required this.activeEntries,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Records',
                    value: totalEntries.toString(),
                    icon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Different meds',
                    value: distinctMedicines.toString(),
                    icon: Icons.medication_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Active',
                    value: activeEntries.toString(),
                    icon: Icons.play_circle_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final List<PrescriptionPlan> plans;
  final String? selectedPlanId;
  final DateTime? selectedDay;
  final DateTimeRange? selectedDateRange;
  final String selectedStatus;
  final String searchQuery;
  final ValueChanged<String?> onPlanChanged;
  final VoidCallback onPickDay;
  final VoidCallback onPickDateRange;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearDay;
  final VoidCallback? onClearRange;
  final VoidCallback? onClearAll;

  const _FiltersCard({
    required this.plans,
    required this.selectedPlanId,
    required this.selectedDay,
    required this.selectedDateRange,
    required this.selectedStatus,
    required this.searchQuery,
    required this.onPlanChanged,
    required this.onPickDay,
    required this.onPickDateRange,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onClearDay,
    required this.onClearRange,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: selectedPlanId,
              decoration: const InputDecoration(
                labelText: 'Prescription plan',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All plans'),
                ),
                ...plans.map(
                  (plan) => DropdownMenuItem<String?>(
                    value: plan.id,
                    child: Text(plan.name),
                  ),
                ),
              ],
              onChanged: onPlanChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search medication',
                hintText: 'Name, dose, plan or reason',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => onSearchChanged(''),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active only')),
                DropdownMenuItem(value: 'past', child: Text('Past only')),
              ],
              onChanged: (value) => onStatusChanged(value ?? 'all'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDay,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDay == null
                          ? 'Pick a day'
                          : _formatDate(selectedDay!),
                    ),
                  ),
                ),
                if (selectedDay != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onClearDay,
                    child: const Text('Clear date'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      selectedDateRange == null
                          ? 'Pick a date range'
                          : _formatRange(selectedDateRange!),
                    ),
                  ),
                ),
                if (selectedDateRange != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onClearRange,
                    child: const Text('Clear range'),
                  ),
                ],
              ],
            ),
            if (onClearAll != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear all filters'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatRange(DateTimeRange range) {
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
            if (entry.planName != null && entry.planName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.assignment_outlined,
                label: 'Plan',
                value: entry.planName!,
              ),
            ],
            if (entry.reasonForTaking.isNotEmpty &&
                entry.reasonForTaking != entry.planName) ...[
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

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SummaryTile extends StatelessWidget {
  final _UsageSummary summary;

  const _SummaryTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.medication_outlined),
      title: Text(summary.medicationName),
      subtitle: Text(
        [
          if (summary.dose.isNotEmpty) summary.dose,
          '${summary.count} record(s)',
          if (summary.activeCount > 0) '${summary.activeCount} active',
        ].join(' • '),
      ),
      trailing: Text(
        summary.count.toString(),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _UsageSummary {
  final String medicationName;
  final String dose;
  final int count;
  final DateTime latestStartDate;
  final int activeCount;

  const _UsageSummary({
    required this.medicationName,
    required this.dose,
    required this.count,
    required this.latestStartDate,
    required this.activeCount,
  });

  _UsageSummary copyWith({
    String? medicationName,
    String? dose,
    int? count,
    DateTime? latestStartDate,
    int? activeCount,
  }) {
    return _UsageSummary(
      medicationName: medicationName ?? this.medicationName,
      dose: dose ?? this.dose,
      count: count ?? this.count,
      latestStartDate: latestStartDate ?? this.latestStartDate,
      activeCount: activeCount ?? this.activeCount,
    );
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
