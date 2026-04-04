import 'package:flutter/material.dart';
import 'package:safemed/data/medications_database.dart';
import 'package:safemed/data/substance_risk_tables.dart';
import 'package:safemed/models/medication.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/services/profile_store.dart';

class MedicationPickerDialog extends StatefulWidget {
  final PlanMedication? initialMedication;
  final String? profileId;
  final List<PlanMedication> existingPlanMedications;

  const MedicationPickerDialog({
    super.key,
    this.initialMedication,
    this.profileId,
    this.existingPlanMedications = const [],
  });

  @override
  State<MedicationPickerDialog> createState() => _MedicationPickerDialogState();
}

class _MedicationPickerDialogState extends State<MedicationPickerDialog> {
  final _searchController = TextEditingController();
  List<Medication> _filteredMedications = List.from(medicamentosBaseDados);

  Profile? get _profile {
    final id = widget.profileId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return ProfileStore.instance.getById(id);
  }

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
    final profile = _profile;
    final interactions = _buildInteractionAlertsForCandidate(
      candidate: medication,
      existingPlanMedications: widget.existingPlanMedications,
    );
    showDialog(
      context: context,
      builder: (context) => _DosageAndTimesDialog(
        medication: medication,
        initialMedication: initial,
        profile: profile,
        interactionAlerts: interactions,
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
                          final profile = _profile;
                          final allergyMatches = profile == null
                              ? const <String>[]
                              : findMatchedAllergyRulesForSubstance(
                                  patientAllergies: profile.allergies,
                                  substance: med.substanciaAtiva,
                                );
                          final hasAllergyRisk = allergyMatches.isNotEmpty;
                            final conditionMatches = profile == null
                              ? const <String>[]
                              : _buildConditionMatches(profile, med);
                            final hasConditionRisk = conditionMatches.isNotEmpty;
                            final restrictionMatches = profile == null
                              ? const <String>[]
                              : _buildRestrictionMatches(profile, med);
                            final hasRestrictionWarning = restrictionMatches.isNotEmpty;
                          final pregRisk = pregnancyRiskBySubstance(
                                med.substanciaAtiva,
                              ) ??
                              med.riscoGravidez;
                          final showPregnancyRisk = profile != null &&
                              profile.sex == BiologicalSex.female &&
                              profile.isPregnant;
                          final interactionAlerts = _buildInteractionAlertsForCandidate(
                            candidate: med,
                            existingPlanMedications: widget.existingPlanMedications,
                          );
                          final hasHighInteraction = interactionAlerts.any(
                            (a) => a.level == _RiskLevel.high,
                          );
                          final hasMediumInteraction = interactionAlerts.any(
                            (a) => a.level == _RiskLevel.medium,
                          );
                            final hasLowOnly = interactionAlerts.isNotEmpty &&
                              interactionAlerts.every((a) => a.level == _RiskLevel.low);
                            final lowRiskContext =
                              !hasAllergyRisk && !showPregnancyRisk && !hasHighInteraction && !hasMediumInteraction;

                          return ListTile(
                            leading: hasAllergyRisk || hasConditionRisk
                                ? const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red,
                                  )
                                : hasHighInteraction
                                    ? const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red,
                                      )
                                    : hasMediumInteraction
                                        ? const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.amber,
                                          )
                                : showPregnancyRisk
                                    ? Icon(
                                        Icons.pregnant_woman,
                                        color: _fdaColor(pregRisk),
                                      )
                                    : hasRestrictionWarning || hasLowOnly
                                        ? const Icon(
                                            Icons.info_outline,
                                            color: Colors.amber,
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.green,
                                          ),
                            title: Text(med.nomeComercial),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${med.substanciaAtiva} · ${med.dosagem}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (hasAllergyRisk)
                                      _RiskChip(
                                        label: 'Alergia (alto)',
                                        bg: Colors.red.shade50,
                                        fg: Colors.red.shade900,
                                      ),
                                    if (hasConditionRisk)
                                      _RiskChip(
                                        label: 'Condição (alto)',
                                        bg: Colors.red.shade50,
                                        fg: Colors.red.shade900,
                                      ),
                                    if (hasHighInteraction)
                                      _RiskChip(
                                        label: 'Interacao (alto)',
                                        bg: Colors.red.shade50,
                                        fg: Colors.red.shade900,
                                      ),
                                    if (hasMediumInteraction)
                                      _RiskChip(
                                        label: 'Interacao (medio)',
                                        bg: Colors.amber.shade50,
                                        fg: Colors.amber.shade900,
                                      ),
                                    if (hasRestrictionWarning)
                                      _RiskChip(
                                        label: 'Restricao (aviso)',
                                        bg: Colors.amber.shade50,
                                        fg: Colors.amber.shade900,
                                      ),
                                    if (showPregnancyRisk)
                                      _RiskChip(
                                        label: 'FDA ${pregRisk.name}',
                                        bg: _fdaColor(pregRisk).withValues(alpha: 0.12),
                                        fg: _fdaColor(pregRisk),
                                      ),
                                    if (lowRiskContext || hasLowOnly)
                                      _RiskChip(
                                        label: 'Risco baixo',
                                        bg: Colors.green.shade50,
                                        fg: Colors.green.shade900,
                                      ),
                                  ],
                                ),
                              ],
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
  final Profile? profile;
  final List<_InteractionAlert> interactionAlerts;

  const _DosageAndTimesDialog({
    Key? key,
    required this.medication,
    this.initialMedication,
    this.profile,
    this.interactionAlerts = const [],
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
    final profile = widget.profile;
    final allergyMatches = profile == null
        ? const <String>[]
        : findMatchedAllergyRulesForSubstance(
            patientAllergies: profile.allergies,
            substance: widget.medication.substanciaAtiva,
          );
    final hasAllergyRisk = allergyMatches.isNotEmpty;
      final conditionMatches = profile == null
        ? const <String>[]
        : _buildConditionMatches(profile, widget.medication);
      final hasConditionRisk = conditionMatches.isNotEmpty;
      final restrictionMatches = profile == null
        ? const <String>[]
        : _buildRestrictionMatches(profile, widget.medication);
      final hasRestrictionWarning = restrictionMatches.isNotEmpty;

    final riskFromTable = pregnancyRiskBySubstance(widget.medication.substanciaAtiva);
    final pregnancyRisk = riskFromTable ?? widget.medication.riscoGravidez;
    final isPregnantProfile = profile != null &&
        profile.sex == BiologicalSex.female &&
        profile.isPregnant;
    final hasAnyInteraction = widget.interactionAlerts.isNotEmpty;
    final hasHighInteraction = widget.interactionAlerts.any((a) => a.level == _RiskLevel.high);
    final hasMediumInteraction = widget.interactionAlerts.any((a) => a.level == _RiskLevel.medium);
    final hasAnyRisk = hasAllergyRisk || hasConditionRisk || isPregnantProfile || hasAnyInteraction || hasRestrictionWarning;

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
              if (hasAllergyRisk)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ALERTA VERMELHO: o utilizador nao pode tomar este medicamento devido a alergia ${allergyMatches.join(', ')}.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (hasConditionRisk)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ALERTA VERMELHO: este medicamento nao e recomendado para a condicao ${conditionMatches.join(', ')}.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (hasRestrictionWarning)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AVISO AMARELO: restricao pratica do perfil - ${restrictionMatches.join(', ')}.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (hasAnyInteraction)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (hasHighInteraction ? Colors.red : Colors.amber).shade50,
                    border: Border.all(
                      color: hasHighInteraction ? Colors.red.shade700 : Colors.amber.shade800,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasHighInteraction
                            ? 'Interacao de risco alto detetada (VERMELHO).'
                            : hasMediumInteraction
                                ? 'Interacao de risco medio detetada (AMARELO).'
                                : 'Interacao de baixo risco detetada (VERDE).',
                        style: TextStyle(
                          color: hasHighInteraction ? Colors.red.shade900 : Colors.amber.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...widget.interactionAlerts.map(
                        (alert) => Text('• ${alert.message}'),
                      ),
                    ],
                  ),
                ),
              if (isPregnantProfile)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _fdaColor(pregnancyRisk).withValues(alpha: 0.12),
                    border: Border.all(color: _fdaColor(pregnancyRisk)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Risco na gravidez FDA ${pregnancyRisk.name}: ${_fdaMessage(pregnancyRisk)}',
                    style: TextStyle(
                      color: _fdaColor(pregnancyRisk),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!hasAnyRisk)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sem alertas de risco relevantes para este contexto (VERDE).',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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

Color _fdaColor(PregnancyRiskCategory category) {
  switch (category) {
    case PregnancyRiskCategory.A:
      return Colors.green.shade700;
    case PregnancyRiskCategory.B:
      return Colors.lightGreen.shade700;
    case PregnancyRiskCategory.C:
      return Colors.amber.shade800;
    case PregnancyRiskCategory.D:
      return Colors.orange.shade900;
    case PregnancyRiskCategory.X:
      return Colors.red.shade800;
  }
}

String _fdaMessage(PregnancyRiskCategory category) {
  switch (category) {
    case PregnancyRiskCategory.A:
      return 'sem risco conhecido em humanos.';
    case PregnancyRiskCategory.B:
      return 'baixo risco, usar com avaliacao clinica.';
    case PregnancyRiskCategory.C:
      return 'risco potencial; avaliar risco/beneficio.';
    case PregnancyRiskCategory.D:
      return 'evidencia de risco fetal.';
    case PregnancyRiskCategory.X:
      return 'contraindicado na gravidez.';
  }
}

enum _RiskLevel { high, medium, low }

class _InteractionAlert {
  final _RiskLevel level;
  final String message;

  const _InteractionAlert({required this.level, required this.message});
}

class _RiskChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _RiskChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

List<_InteractionAlert> _buildInteractionAlertsForCandidate({
  required Medication candidate,
  required List<PlanMedication> existingPlanMedications,
}) {
  final alerts = <_InteractionAlert>[];
  final candidateSubstance = _normalizeKey(candidate.substanciaAtiva);

  for (final planMed in existingPlanMedications) {
    final existing = _findMedicationByCommercialName(planMed.name);
    if (existing == null) {
      continue;
    }

    final existingSubstance = _normalizeKey(existing.substanciaAtiva);
    final existingLabel = existing.nomeComercial;

    if (existingSubstance == candidateSubstance) {
      alerts.add(
        _InteractionAlert(
          level: _RiskLevel.high,
          message: 'Duplicacao de substancia ativa com $existingLabel.',
        ),
      );
      continue;
    }

    final candidateInteractsWithExisting = candidate.interacoesComSubstancias.any(
      (s) => _normalizeKey(s) == existingSubstance,
    );
    final existingInteractsWithCandidate = existing.interacoesComSubstancias.any(
      (s) => _normalizeKey(s) == candidateSubstance,
    );

    if (candidateInteractsWithExisting || existingInteractsWithCandidate) {
      alerts.add(
        _InteractionAlert(
          level: _RiskLevel.medium,
          message:
              'Possivel interacao entre ${candidate.nomeComercial} e $existingLabel.',
        ),
      );
    }
  }

  if (alerts.isEmpty && existingPlanMedications.isNotEmpty) {
    alerts.add(
      const _InteractionAlert(
        level: _RiskLevel.low,
        message: 'Nao foram encontradas interacoes relevantes com a medicacao atual.',
      ),
    );
  }

  return alerts;
}

Medication? _findMedicationByCommercialName(String name) {
  final n = _normalizeKey(name);

  for (final med in medicamentosBaseDados) {
    final medName = _normalizeKey(med.nomeComercial);
    if (medName == n || medName.contains(n) || n.contains(medName)) {
      return med;
    }
  }

  return null;
}

String _normalizeKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

List<String> _buildConditionMatches(Profile profile, Medication medication) {
  final matches = <String>[];
  final contraindications = medication.contraindicacoes.toSet();

  if (profile.renalDisease && contraindications.contains(PathologyIds.insuficienciaRenal)) {
    matches.add('Insuficiência renal');
  }
  if (profile.hepaticDisease && contraindications.contains(PathologyIds.insuficienciaHepatica)) {
    matches.add('Insuficiência hepática');
  }
  if (profile.diabetes && contraindications.contains(PathologyIds.diabetes)) {
    matches.add('Diabetes');
  }
  if (profile.hypertension && contraindications.contains(PathologyIds.hipertensao)) {
    matches.add('Hipertensão');
  }

  return matches;
}

List<String> _buildRestrictionMatches(Profile profile, Medication medication) {
  final matches = <String>[];
  final textRestrictions = profile.medicalRestrictions.map(_normalizeKey).toList();
  final form = _normalizeKey(medication.formaFarmaceutica);
  final substance = _normalizeKey(medication.substanciaAtiva);

  final solidOralForms = <String>{'comprimido', 'capsula', 'capsulas', 'pastilha', 'comprimidos'};
  final liquidForms = <String>{'xarope', 'solucao', 'suspensao', 'gotas'};
  final nsaidSubstances = <String>{
    'ibuprofeno',
    'diclofenaco',
    'naproxeno',
    'acido_acetilsalicilico',
    'aspirina',
  };

  final isSolidOralMedication = solidOralForms.any(form.contains);
  final isLiquidMedication = liquidForms.any(form.contains);

  for (final restriction in textRestrictions) {
    if (restriction.isEmpty) {
      continue;
    }

    if ((restriction.contains('disfagia') ||
            restriction.contains('deglut') ||
            restriction.contains('engol') ||
            restriction.contains('comprim') ||
            restriction.contains('capsul')) &&
        isSolidOralMedication) {
      matches.add('Disfagia (dificuldade de deglutição)');
      continue;
    }

    if ((restriction.contains('liquida') || restriction.contains('farmaceutica_liquida')) &&
        !isLiquidMedication) {
      matches.add('Necessidade de forma farmacêutica líquida');
      continue;
    }

    if (restriction.contains('lactose') &&
        (_normalizeKey(medication.nomeComercial).contains('lactose') ||
            _normalizeKey(medication.substanciaAtiva).contains('lactose'))) {
      matches.add('Intolerância à lactose');
      continue;
    }

    if ((restriction.contains('sedacao') || restriction.contains('sedativ')) &&
        (substance.contains('clemastina') || substance.contains('talidomida'))) {
      matches.add('Evitar sedação (risco de quedas)');
      continue;
    }

    if ((restriction.contains('alimento') || restriction.contains('com_alimento')) &&
        (substance.contains('ibuprofeno') ||
            substance.contains('diclofenaco') ||
            substance.contains('acido_acetilsalicilico') ||
            substance.contains('aspirina'))) {
      matches.add('Necessidade de administração com alimento');
      continue;
    }

    if ((restriction.contains('antiinflamatorio') ||
            restriction.contains('anti_inflamatorio') ||
            restriction.contains('nao_esteroides')) &&
        nsaidSubstances.any(substance.contains)) {
      matches.add('Evitar anti-inflamatórios não esteroides');
      continue;
    }
  }

  return matches.toSet().toList();
}
