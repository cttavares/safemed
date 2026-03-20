import 'package:flutter/material.dart';
import 'package:safemed/data/medications_database.dart';
import 'package:safemed/models/medication.dart';
import 'package:safemed/models/prescription_plan.dart';

class MedicationPickerDialog extends StatefulWidget {
  final PlanMedication? initialMedication;

  const MedicationPickerDialog({
    super.key,
    this.initialMedication,
  });

  @override
  State<MedicationPickerDialog> createState() => _MedicationPickerDialogState();
}

class _MedicationPickerDialogState extends State<MedicationPickerDialog> {
  final _searchController = TextEditingController();
  List<Medication> _filteredMedications = List.from(medicamentosBaseDados);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMedications);
  }

  void _filterMedications() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMedications = List.from(medicamentosBaseDados);
      } else {
        _filteredMedications = medicamentosBaseDados
            .where((med) =>
                med.nomeComercial.toLowerCase().contains(query) ||
                med.substanciaAtiva.toLowerCase().contains(query) ||
                med.cnp.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onMedicationSelected(Medication medication) {
    _showDosageAndTimesDialog(medication);
  }

  void _showDosageAndTimesDialog(Medication medication) {
    final initial = widget.initialMedication;
    showDialog(
      context: context,
      builder: (context) => _DosageAndTimesDialog(
        medication: medication,
        initialMedication: initial,
      ),
    ).then((planMedication) {
      if (!mounted || planMedication == null) {
        return;
      }
      Navigator.of(context).pop(planMedication);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 560,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Pesquisar Medicamento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Digite o nome, substância ou CNP...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredMedications.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum medicamento encontrado',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMedications.length,
                        itemBuilder: (context, index) {
                          final med = _filteredMedications[index];
                          return ListTile(
                            title: Text(med.nomeComercial),
                            subtitle: Text(
                              '${med.substanciaAtiva} · ${med.dosagem}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Chip(
                              label: Text(med.formaFarmaceutica),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                            onTap: () => _onMedicationSelected(med),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DosageAndTimesDialog extends StatefulWidget {
  final Medication medication;
  final PlanMedication? initialMedication;

  const _DosageAndTimesDialog({
    Key? key,
    required this.medication,
    this.initialMedication,
  }) : super(key: key);

  @override
  State<_DosageAndTimesDialog> createState() => _DosageAndTimesDialogState();
}

class _DosageAndTimesDialogState extends State<_DosageAndTimesDialog> {
  late TextEditingController _dosageController;
  late TextEditingController _notesController;
  late List<String> _times;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMedication;
    _dosageController =
        TextEditingController(text: initial?.dose ?? widget.medication.dosagem);
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _times = List<String>.from(initial?.times ?? const <String>[]);
    _selectedTime = TimeOfDay.now();
  }

  void _addTime(TimeOfDay time) {
    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {
      _times.add(formattedTime);
      _times.sort();
    });
  }

  void _removeTime(String time) {
    setState(() => _times.remove(time));
  }

  void _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      _addTime(picked);
    }
  }

  void _onConfirm() {
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Adicione pelo menos um horário de administração'),
      ));
      return;
    }

    final stableId = widget.initialMedication?.id ??
        '${widget.medication.id}_${DateTime.now().millisecondsSinceEpoch}';

    final planMedication = PlanMedication(
      id: stableId,
      name: widget.medication.nomeComercial,
      dose: _dosageController.text.isNotEmpty
          ? _dosageController.text
          : widget.medication.dosagem,
      times: _times,
      notes: _notesController.text,
    );

    Navigator.of(context).pop(planMedication);
  }

  @override
  void dispose() {
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalhes da Prescrição',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              // Medicamento selecionado (read-only)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.medication.nomeComercial,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${widget.medication.substanciaAtiva} · ${widget.medication.formaFarmaceutica}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (widget.medication.sujeitoReceitaMedica)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            label: const Text('Requer Receita Médica'),
                            backgroundColor: Colors.orange[100],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Dosagem
              Text(
                'Dosagem',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dosageController,
                decoration: InputDecoration(
                  hintText: 'Ex: 500 mg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Horários de administração
              Text(
                'Horários de Administração',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_times.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _times
                      .map(
                        (time) => InputChip(
                          label: Text(time),
                          onDeleted: () => _removeTime(time),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _selectTime,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Adicionar Horário'),
              ),
              const SizedBox(height: 16),
              // Notas
              Text(
                'Notas (Opcional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Ex: Com comida, ao deitar...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
