import 'package:flutter/material.dart';
import 'package:safemed/screens/scanner/barcode_scan_screen.dart';
import 'package:safemed/screens/scanner/ocr_screen.dart' show OcrScreen;
import 'package:safemed/services/profile_store.dart';

import '../models/medication_entry.dart';
import '../services/prescription_parser.dart';
import 'confirm_medications_screen.dart';
import 'plan_form_screen.dart';

class PrescriptionScreen extends StatefulWidget {
  final String profileId;

  const PrescriptionScreen({super.key, required this.profileId});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _appendLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    final current = controller.text.trimRight();
    controller.text = current.isEmpty ? trimmed : "$current\n$trimmed";
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    setState(() {});
  }

  void _replaceText(String text) {
    controller.text = text.trim();
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    setState(() {});
  }

  Future<void> _scanBarcode() async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );

    if (barcode == null || barcode.trim().isEmpty) return;

    _appendLine("BARCODE: ${barcode.trim()}");
  }

  Future<void> _runOcr() async {
    final String? recognizedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );

    if (recognizedText == null || recognizedText.trim().isEmpty) return;

    final parser = PrescriptionParser();
    final meds = parser.parse(recognizedText);
    if (meds.isEmpty) {
      _replaceText(recognizedText);
      return;
    }

    final List<MedicationEntry>? confirmed =
        await Navigator.push<List<MedicationEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmMedicationsScreen(
          initial: meds,
        ),
      ),
    );

    if (confirmed == null) {
      return;
    }

    final text = confirmed.map((m) {
      final boxInfo = _formatBoxInfo(m);
      final freq = (m.timesPerDay != null) ? ' ${m.timesPerDay}x/day' : '';
      final interval = (m.interval != null && m.interval!.trim().isNotEmpty)
          ? ' ${m.interval}'
          : '';
      final intake = (m.intakeNotes != null && m.intakeNotes!.trim().isNotEmpty)
          ? ' Toma: ${m.intakeNotes}'
          : '';
      final daily = _formatDailyDose(m);
      return '${boxInfo}${m.displayName}$freq$interval$daily$intake'.trim();
    }).join('\n');

    _replaceText(text);
  }

  String _formatNumber(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String _formatBoxInfo(MedicationEntry m) {
    final v = m.strengthValue;
    final u = m.strengthUnit;
    final pack = m.packQuantity;

    final strengthText =
        (v != null && u != null && u.trim().isNotEmpty) ? '${_formatNumber(v)} $u' : '';
    final packText = (pack != null) ? ' x $pack' : '';

    final combined = '$strengthText$packText'.trim();
    if (combined.isEmpty) return '';
    return '$combined - ';
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
    final dailyText = _formatNumber(daily);
    return ' Dose diaria: $dailyText $unit/dia';
  }

  List<String> _extractMedicationNames(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final canNext = controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('New prescription plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ProfileBanner(profileId: widget.profileId),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan barcode'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _runOcr,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('OCR prescription'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: 'Enter medications (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canNext
                  ? () {
                      final meds = _extractMedicationNames(controller.text);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlanFormScreen(
                            initialMedications: meds,
                            profileId: widget.profileId,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Create plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  final String profileId;

  const _ProfileBanner({required this.profileId});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileStore.instance.getById(profileId);
    final name = profile?.name ?? 'Unknown patient';
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Patient',
        border: OutlineInputBorder(),
      ),
      child: Text(name),
    );
  }
}
