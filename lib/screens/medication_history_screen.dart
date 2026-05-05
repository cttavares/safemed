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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedDay = null;
      });
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedPlanId = null;
      _selectedDay = null;
      _selectedDateRange = null;
      _selectedStatus = 'all';
      _searchQuery = '';
    });
  }

  bool get _hasActiveFilters =>
      _selectedPlanId != null ||
      _selectedDay != null ||
      _selectedDateRange != null ||
      _selectedStatus != 'all' ||
      _searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final historyStore = MedicationHistoryStore.instance;
    final planStore = PlanStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.profileName} — History'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              tooltip: 'Clear all filters',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([historyStore, planStore]),
        builder: (context, _) {
          final plans = planStore.plans
              .where((p) => p.profileId == widget.profileId)
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          final selectedPlanId =
              plans.any((p) => p.id == _selectedPlanId) ? _selectedPlanId : null;

          final base = historyStore.getForProfileFiltered(
            widget.profileId,
            planId: selectedPlanId,
            day: _selectedDay,
          );

          final filtered = base.where((h) {
            // date-range filter
            if (_selectedDateRange != null) {
              final s = _dateOnly(h.startDate);
              final e = h.endDate != null ? _dateOnly(h.endDate!) : s;
              final rs = _dateOnly(_selectedDateRange!.start);
              final re = _dateOnly(_selectedDateRange!.end);
              if (e.isBefore(rs) || s.isAfter(re)) return false;
            }
            // status filter
            if (_selectedStatus == 'active' && !h.isActive) return false;
            if (_selectedStatus == 'past' && h.isActive) return false;
            // search filter
            final q = _searchQuery.trim().toLowerCase();
            if (q.isNotEmpty) {
              final hit = h.medicationName.toLowerCase().contains(q) ||
                  h.dose.toLowerCase().contains(q) ||
                  h.reasonForTaking.toLowerCase().contains(q) ||
                  (h.planName?.toLowerCase().contains(q) ?? false) ||
                  h.notes.toLowerCase().contains(q);
              if (!hit) return false;
            }
            return true;
          }).toList();

          final active = filtered.where((h) => h.isActive).toList();
          final past = filtered.where((h) => !h.isActive).toList();
          final summaries = _buildSummaries(filtered);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Stats ────────────────────────────────────────────────────
              _OverviewCard(
                total: filtered.length,
                distinct: summaries.length,
                active: active.length,
              ),
              const SizedBox(height: 16),

              // ── Filters ──────────────────────────────────────────────────
              _FiltersCard(
                plans: plans,
                selectedPlanId: selectedPlanId,
                selectedDay: _selectedDay,
                selectedDateRange: _selectedDateRange,
                selectedStatus: _selectedStatus,
                searchController: _searchController,
                onPlanChanged: (v) => setState(() => _selectedPlanId = v),
                onPickDay: _pickDay,
                onPickDateRange: _pickDateRange,
                onStatusChanged: (v) => setState(() => _selectedStatus = v),
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onClearDay: _selectedDay == null
                    ? null
                    : () => setState(() => _selectedDay = null),
                onClearRange: _selectedDateRange == null
                    ? null
                    : () => setState(() => _selectedDateRange = null),
              ),
              const SizedBox(height: 16),

              // ── Medication overview ──────────────────────────────────────
              if (summaries.isNotEmpty) ...[
                _SectionHeader('Medication overview'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: summaries
                        .map((s) => _SummaryTile(summary: s))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Timeline ─────────────────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(hasFilters: _hasActiveFilters)
              else ...[
                if (active.isNotEmpty) ...[
                  _SectionHeader('Currently Taking'),
                  const SizedBox(height: 8),
                  ..._groupByMonth(active).entries.expand((e) => [
                        _MonthDivider(label: e.key),
                        ...e.value.map((h) => _HistoryCard(entry: h)),
                      ]),
                  const SizedBox(height: 24),
                ],
                if (past.isNotEmpty) ...[
                  _SectionHeader('Past Medications'),
                  const SizedBox(height: 8),
                  ..._groupByMonth(past).entries.expand((e) => [
                        _MonthDivider(label: e.key),
                        ...e.value.map((h) => _HistoryCard(entry: h)),
                      ]),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Groups entries by "Month Year" label, newest first.
  Map<String, List<MedicationHistory>> _groupByMonth(
      List<MedicationHistory> entries) {
    final result = <String, List<MedicationHistory>>{};
    for (final h in entries) {
      final key = _monthLabel(h.startDate);
      result.putIfAbsent(key, () => []).add(h);
    }
    return result;
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  List<_UsageSummary> _buildSummaries(List<MedicationHistory> history) {
    final grouped = <String, _UsageSummary>{};
    for (final h in history) {
      final key = h.medicationName.trim().toLowerCase();
      if (key.isEmpty) continue;
      final ex = grouped[key];
      if (ex == null) {
        grouped[key] = _UsageSummary(
          medicationName: h.medicationName,
          dose: h.dose,
          count: 1,
          latestStartDate: h.startDate,
          activeCount: h.isActive ? 1 : 0,
        );
      } else {
        grouped[key] = ex.copyWith(
          count: ex.count + 1,
          latestStartDate: h.startDate.isAfter(ex.latestStartDate)
              ? h.startDate
              : ex.latestStartDate,
          activeCount: ex.activeCount + (h.isActive ? 1 : 0),
          dose: ex.dose.isEmpty ? h.dose : ex.dose,
        );
      }
    }
    final list = grouped.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _MonthDivider extends StatelessWidget {
  final String label;
  const _MonthDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: color,
              margin: const EdgeInsets.only(right: 8)),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No records match the current filters.'
                : 'No medication history yet.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final int total;
  final int distinct;
  final int active;

  const _OverviewCard({
    required this.total,
    required this.distinct,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History overview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        label: 'Records',
                        value: '$total',
                        icon: Icons.description_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        label: 'Medications',
                        value: '$distinct',
                        icon: Icons.medication_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatTile(
                        label: 'Active',
                        value: '$active',
                        icon: Icons.play_circle_outline)),
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
  const _StatTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final List<PrescriptionPlan> plans;
  final String? selectedPlanId;
  final DateTime? selectedDay;
  final DateTimeRange? selectedDateRange;
  final String selectedStatus;
  final TextEditingController searchController;
  final ValueChanged<String?> onPlanChanged;
  final VoidCallback onPickDay;
  final VoidCallback onPickDateRange;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearDay;
  final VoidCallback? onClearRange;

  const _FiltersCard({
    required this.plans,
    required this.selectedPlanId,
    required this.selectedDay,
    required this.selectedDateRange,
    required this.selectedStatus,
    required this.searchController,
    required this.onPlanChanged,
    required this.onPickDay,
    required this.onPickDateRange,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onClearDay,
    required this.onClearRange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Plan dropdown
            DropdownButtonFormField<String?>(
              value: selectedPlanId,
              decoration: const InputDecoration(
                  labelText: 'Prescription plan',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All plans')),
                ...plans.map((p) =>
                    DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
              ],
              onChanged: onPlanChanged,
            ),
            const SizedBox(height: 12),

            // Search
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Name, dose, plan or reason…',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Status
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active only')),
                DropdownMenuItem(value: 'past', child: Text('Past only')),
              ],
              onChanged: (v) => onStatusChanged(v ?? 'all'),
            ),
            const SizedBox(height: 12),

            // Date pickers row
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDay,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(selectedDay == null
                      ? 'Pick a day'
                      : _fmt(selectedDay!)),
                ),
              ),
              if (onClearDay != null) ...[
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClearDay,
                    tooltip: 'Clear date'),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(selectedDateRange == null
                      ? 'Pick a date range'
                      : '${_fmt(selectedDateRange!.start)} – ${_fmt(selectedDateRange!.end)}'),
                ),
              ),
              if (onClearRange != null) ...[
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClearRange,
                    tooltip: 'Clear range'),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _HistoryCard extends StatelessWidget {
  final MedicationHistory entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = _durationLabel(entry);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.medicationName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    if (entry.dose.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(entry.dose,
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                      ),
                  ]),
            ),
            const SizedBox(width: 8),
            // Active / duration badge
            if (entry.isActive)
              _Badge(label: 'Active', color: Colors.green.shade600)
            else if (duration != null)
              _Badge(label: duration, color: cs.primary),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Details ───────────────────────────────────────────────────
          _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Started',
              value: _fmtFull(entry.startDate)),
          if (entry.endDate != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.event_available_outlined,
                label: 'Ended',
                value: _fmtFull(entry.endDate!)),
          ],
          if (entry.planName != null && entry.planName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.assignment_outlined,
                label: 'Plan',
                value: entry.planName!),
          ],
          // Show reason only if it differs from planName
          if (entry.reasonForTaking.isNotEmpty &&
              entry.reasonForTaking != entry.planName) ...[
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.medical_information_outlined,
                label: 'Reason',
                value: entry.reasonForTaking),
          ],
          if (entry.reasonForStopping != null &&
              entry.reasonForStopping!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.stop_circle_outlined,
                label: 'Stopped',
                value: entry.reasonForStopping!),
          ],
          if (entry.effectivenessRating != null) ...[
            const SizedBox(height: 6),
            _StarRating(rating: entry.effectivenessRating!),
          ],
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: entry.notes),
          ],
        ]),
      ),
    );
  }

  String? _durationLabel(MedicationHistory h) {
    if (h.endDate == null) return null;
    final days = h.endDate!.difference(h.startDate).inDays;
    if (days == 0) return '1 day';
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    final weeks = (days / 7).round();
    if (days < 31) return '$weeks wk${weeks > 1 ? 's' : ''}';
    final months = (days / 30.5).round();
    return '$months mo${months > 1 ? 's' : ''}';
  }

  static String _fmtFull(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.star_outline,
          size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 6),
      Text('Effectiveness: ',
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ...List.generate(
          5,
          (i) => Icon(i < rating ? Icons.star : Icons.star_border,
              size: 15, color: Colors.amber)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 13, color: color),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _SummaryTile extends StatelessWidget {
  final _UsageSummary summary;
  const _SummaryTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (summary.dose.isNotEmpty) parts.add(summary.dose);
    parts.add('${summary.count} record${summary.count != 1 ? 's' : ''}');
    if (summary.activeCount > 0) {
      parts.add('${summary.activeCount} active');
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          summary.medicationName.isNotEmpty
              ? summary.medicationName[0].toUpperCase()
              : '?',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(summary.medicationName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(parts.join(' · '),
          style: const TextStyle(fontSize: 12)),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

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
