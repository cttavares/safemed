import 'package:flutter/material.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/services/plan_store.dart';
import 'package:safemed/services/profile_store.dart';

class PlanFormScreen extends StatefulWidget {
  final PrescriptionPlan? plan;
  final List<String>? initialMedications;
  final String? profileId;

  const PlanFormScreen({
    super.key,
    this.plan,
    this.initialMedications,
    this.profileId,
  });

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _nameController = TextEditingController();
  final _planStore = PlanStore.instance;
  final _profileStore = ProfileStore.instance;

  String? _profileId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  List<PlanMedication> _medications = [];

  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _nameController.text = plan.name;
      _profileId = plan.profileId;
      _startDate = plan.startDate;
      _endDate = plan.endDate;
      _isActive = plan.isActive;
      _medications = List.of(plan.medications);
    } else {
      if (widget.profileId != null) {
        _profileId = widget.profileId;
      }
      if (widget.initialMedications != null) {
        _medications = widget.initialMedications!
            .map((name) => PlanMedication(
                  id: _newId(),
                  name: name,
                  dose: '',
                  times: const [],
                  notes: '',
                ))
            .toList();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _newId() {
    _idCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit plan' : 'New plan')),
      body: AnimatedBuilder(
        animation: _profileStore,
        builder: (context, _) {
          final profiles = _profileStore.profiles;
          final selectedProfileId = profiles.any((p) => p.id == _profileId)
              ? _profileId
              : null;
          final fixedProfileId = widget.profileId;
          Profile? fixedProfile;
          if (fixedProfileId != null) {
            for (final profile in profiles) {
              if (profile.id == fixedProfileId) {
                fixedProfile = profile;
                break;
              }
            }
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (profiles.isEmpty)
                _EmptyProfilesNotice(
                  onCreate: () {
                    Navigator.pop(context);
                  },
                ),
              if (fixedProfileId != null && fixedProfile != null)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Patient',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(fixedProfile.name),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedProfileId,
                  decoration: const InputDecoration(
                    labelText: 'Patient',
                    border: OutlineInputBorder(),
                  ),
                  items: profiles
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: profiles.isEmpty
                      ? null
                      : (value) => setState(() => _profileId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Start date',
                value: _startDate,
                onChanged: (date) {
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'End date (optional)',
                value: _endDate,
                onChanged: (date) => setState(() => _endDate = date),
                allowClear: true,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Plan active'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Medications',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_medications.isEmpty)
                const Text('No medications added yet.'),
              for (final medication in _medications)
                Card(
                  child: ListTile(
                    title: Text(medication.name.isEmpty
                        ? '(Unnamed medication)'
                        : medication.name),
                    subtitle: Text(_medicationSubtitle(medication)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editMedication(medication),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeMedication(medication.id),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: profiles.isEmpty ? null : _savePlan,
                child: Text(isEditing ? 'Save changes' : 'Create plan'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _medicationSubtitle(PlanMedication medication) {
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
    if (parts.isEmpty) {
      return 'No schedule set';
    }
    return parts.join(' | ');
  }

  Future<void> _addMedication() async {
    final result = await showDialog<PlanMedication>(
      context: context,
      builder: (_) => _EditPlanMedicationDialog(
        medication: PlanMedication(
          id: _newId(),
          name: '',
          dose: '',
          times: const [],
          notes: '',
        ),
      ),
    );

    if (result != null) {
      setState(() => _medications = [..._medications, result]);
    }
  }

  Future<void> _editMedication(PlanMedication medication) async {
    final result = await showDialog<PlanMedication>(
      context: context,
      builder: (_) => _EditPlanMedicationDialog(medication: medication),
    );

    if (result != null) {
      setState(() {
        _medications = _medications
            .map((m) => m.id == result.id ? result : m)
            .toList();
      });
    }
  }

  void _removeMedication(String id) {
    setState(() {
      _medications = _medications.where((m) => m.id != id).toList();
    });
  }

  Future<void> _savePlan() async {
    final name = _nameController.text.trim();

    if (_profileId == null || _profileId!.isEmpty) {
      _showSnack('Select a patient.');
      return;
    }
    if (name.isEmpty) {
      _showSnack('Enter a plan name.');
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      _showSnack('End date cannot be before start date.');
      return;
    }
    if (_medications.isEmpty) {
      _showSnack('Add at least one medication.');
      return;
    }

    for (final medication in _medications) {
      if (medication.name.trim().isEmpty) {
        _showSnack('Medication names cannot be empty.');
        return;
      }
      if (medication.times.isEmpty) {
        _showSnack('Each medication needs at least one time.');
        return;
      }
    }

    final plan = PrescriptionPlan(
      id: widget.plan?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: _profileId!,
      name: name,
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      medications: _medications,
    );

    if (widget.plan == null) {
      await _planStore.add(plan);
    } else {
      await _planStore.update(plan);
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : _formatDate(value!);
    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: allowClear && value != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged.call(null),
              )
            : const Icon(Icons.calendar_today),
      ),
      controller: TextEditingController(text: text),
      onTap: () async {
        final now = DateTime.now();
        final initial = value ?? now;
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
          initialDate: initial,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}

class _EmptyProfilesNotice extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyProfilesNotice({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create a profile before adding a plan.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Go back and add profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPlanMedicationDialog extends StatefulWidget {
  final PlanMedication medication;

  const _EditPlanMedicationDialog({required this.medication});

  @override
  State<_EditPlanMedicationDialog> createState() =>
      _EditPlanMedicationDialogState();
}

class _EditPlanMedicationDialogState extends State<_EditPlanMedicationDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _notesController;
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.name);
    _doseController = TextEditingController(text: widget.medication.dose);
    _notesController = TextEditingController(text: widget.medication.notes);
    _times = List.of(widget.medication.times);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Medication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doseController,
              decoration: const InputDecoration(
                labelText: 'Dose',
                hintText: 'e.g. 500 mg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    Chip(
                      label: Text(time),
                      onDeleted: () => setState(
                        () => _times = _times.where((t) => t != time).toList(),
                      ),
                    ),
                  ActionChip(
                    label: const Text('Add time'),
                    onPressed: () => _addTime(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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

  Future<void> _addTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }
    final label = _formatTime(picked);
    if (_times.contains(label)) {
      return;
    }
    setState(() {
      _times = [..._times, label]..sort();
    });
  }

  void _save() {
    final updated = widget.medication.copyWith(
      name: _nameController.text.trim(),
      dose: _doseController.text.trim(),
      times: _times,
      notes: _notesController.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
