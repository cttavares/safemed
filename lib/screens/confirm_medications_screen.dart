import 'package:flutter/material.dart';
import '../../models/medication_entry.dart';

class ConfirmMedicationsScreen extends StatefulWidget {
  final List<MedicationEntry> initial;
  const ConfirmMedicationsScreen({
    super.key,
    required this.initial,
  });

  @override
  State<ConfirmMedicationsScreen> createState() =>
      _ConfirmMedicationsScreenState();
}

class _ConfirmMedicationsScreenState extends State<ConfirmMedicationsScreen> {
  late List<MedicationEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initial);
  }

  Future<void> _editItem(int index) async {
    final edited = await showDialog<MedicationEntry>(
      context: context,
      builder: (_) => _EditMedicationDialog(item: _items[index]),
    );

    if (edited != null) {
      setState(() {
        _items[index] = edited;
      });
    }
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _confirm() {
    // Basic validation: keep only items with a non-empty name
    final cleaned = _items
        .map((e) => e)
        .where((e) => e.name.trim().isNotEmpty)
        .toList();

    Navigator.pop(context, cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm medications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'We extracted these medications from the prescription. '
                  'Please confirm and edit any mistakes.',
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _items.isEmpty
                  ? const Center(
                child: Text('No medications detected.'),
              )
                  : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = _items[i];
                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildNameText(context, m),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _editItem(i),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _deleteItem(i),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_formatStrength(m).isNotEmpty)
                                _Chip(
                                  label: _formatStrength(m),
                                  icon: Icons.local_pharmacy_outlined,
                                ),
                              if (m.timesPerDay != null)
                                _Chip(
                                  label: '${m.timesPerDay}x/day',
                                  icon: Icons.schedule,
                                ),
                              if (m.interval != null &&
                                  m.interval!.trim().isNotEmpty)
                                _Chip(
                                  label: m.interval!,
                                  icon: Icons.timelapse,
                                ),
                              if (_formatDailyDose(m).isNotEmpty)
                                _Chip(
                                  label: _formatDailyDose(m),
                                  icon: Icons.medication_outlined,
                                ),
                              if (m.intakeNotes != null &&
                                  m.intakeNotes!.trim().isNotEmpty)
                                _Chip(
                                  label: 'Toma: ${m.intakeNotes}',
                                  icon: Icons.restaurant,
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _items.isEmpty ? null : _confirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStrength(MedicationEntry m) {
    final v = m.strengthValue;
    final u = m.strengthUnit;
    if (v == null || u == null || u.trim().isEmpty) return '';
    // Show integers without decimal .0
    final txt = (v == v.roundToDouble()) ? v.toInt().toString() : v.toString();
    return '$txt $u';
  }

  String _formatBoxInfo(MedicationEntry m) {
    final v = m.strengthValue;
    final u = m.strengthUnit;
    final pack = m.packQuantity;

    final strengthText =
        (v != null && u != null && u.trim().isNotEmpty)
            ? '${(v == v.roundToDouble()) ? v.toInt().toString() : v.toString()} $u'
            : '';
    final packText = (pack != null) ? ' x $pack' : '';

    final combined = '$strengthText$packText'.trim();
    if (combined.isEmpty) return '';
    return '$combined - ';
  }

  Widget _buildNameText(BuildContext context, MedicationEntry m) {
    final name = m.displayName.trim().isEmpty ? '(Unnamed)' : m.displayName;
    final boxInfo = _formatBoxInfo(m);

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
        children: [
          if (boxInfo.isNotEmpty)
            TextSpan(
              text: boxInfo,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          TextSpan(text: name),
        ],
      ),
    );
  }

  int? _estimateTimesPerDay(MedicationEntry m) {
    if (m.timesPerDay != null) return m.timesPerDay;
    final interval = m.interval;
    if (interval == null || interval.trim().isEmpty) return null;

    final match = RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})').firstMatch(interval);
    if (match == null) return null;
    final a = int.tryParse(match.group(1)!);
    final b = int.tryParse(match.group(2)!);
    if (a == null || b == null || a != b) return null;
    if (24 % a != 0) return null;
    return 24 ~/ a;
  }

  String _formatDailyDose(MedicationEntry m) {
    if (m.dosePerIntake == null) return '';
    final times = _estimateTimesPerDay(m);
    if (times == null) return '';

    final daily = m.dosePerIntake! * times;
    final unit = (m.doseUnit != null && m.doseUnit!.trim().isNotEmpty)
        ? m.doseUnit!.trim()
        : 'unid';
    final dailyText =
        (daily == daily.roundToDouble()) ? daily.toInt().toString() : daily.toString();
    return 'Dose diaria: $dailyText $unit/dia';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _EditMedicationDialog extends StatefulWidget {
  final MedicationEntry item;

  const _EditMedicationDialog({required this.item});

  @override
  State<_EditMedicationDialog> createState() => _EditMedicationDialogState();
}

class _EditMedicationDialogState extends State<_EditMedicationDialog> {
  late final TextEditingController _name;
  late final TextEditingController _brandName;
  late final TextEditingController _intakeNotes;
  late final TextEditingController _strengthValue;
  late String _strengthUnit;
  late final TextEditingController _timesPerDay;
  late final TextEditingController _interval;

  static const _units = <String>['mg', 'g', 'mcg', 'ml'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _brandName = TextEditingController(text: widget.item.brandName ?? '');
    _intakeNotes = TextEditingController(text: widget.item.intakeNotes ?? '');

    _strengthValue = TextEditingController(
      text: widget.item.strengthValue?.toString() ?? '',
    );

    _strengthUnit = (widget.item.strengthUnit ?? '').trim().isEmpty
        ? 'mg'
        : widget.item.strengthUnit!.trim().toLowerCase();

    if (!_units.contains(_strengthUnit)) {
      _strengthUnit = 'mg';
    }

    _timesPerDay = TextEditingController(
      text: widget.item.timesPerDay?.toString() ?? '',
    );

    _interval = TextEditingController(text: widget.item.interval ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _brandName.dispose();
    _intakeNotes.dispose();
    _strengthValue.dispose();
    _timesPerDay.dispose();
    _interval.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final brandName = _brandName.text.trim().isEmpty ? null : _brandName.text.trim();
    final intakeNotes =
        _intakeNotes.text.trim().isEmpty ? null : _intakeNotes.text.trim();

    final strengthValue = _parseDouble(_strengthValue.text);
    final strengthUnit = _strengthUnit;

    final timesPerDay = _parseInt(_timesPerDay.text);
    final interval = _interval.text.trim().isEmpty ? null : _interval.text.trim();

    final updated = MedicationEntry(
      rawLine: widget.item.rawLine,
      name: name,
      brandName: brandName,
      strengthValue: strengthValue,
      strengthUnit: (strengthValue == null) ? null : strengthUnit,
      timesPerDay: timesPerDay,
      interval: interval,
      dosePerIntake: widget.item.dosePerIntake,
      doseUnit: widget.item.doseUnit,
      intakeNotes: intakeNotes,
      notes: widget.item.notes,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit medication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Substance name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandName,
              decoration: const InputDecoration(
                labelText: 'Brand name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _intakeNotes,
              decoration: const InputDecoration(
                labelText: 'Toma (optional)',
                hintText: 'e.g. 1 comprimido ao pequeno almoco',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _strengthValue,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Strength',
                      hintText: 'e.g. 500',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _strengthUnit,
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _strengthUnit = v ?? 'mg'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _timesPerDay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Times per day (optional)',
                hintText: 'e.g. 3',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _interval,
              decoration: const InputDecoration(
                labelText: 'Interval (optional)',
                hintText: 'e.g. 8/8 h',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  double? _parseDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
}
