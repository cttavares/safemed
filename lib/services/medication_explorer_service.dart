import '../data/medications_pt_br.dart' as br;
import '../data/medications_pt_pt.dart' as pt;
import '../models/medication_match.dart';

class MedicationExplorerService {
  final List<_MedicationRecord> _records;
  final List<_SymptomRule> _symptomRules;

  MedicationExplorerService()
      : _records = _buildRecords(),
        _symptomRules = _buildSymptomRules();

  List<MedicationMatch> searchText(String text, {required String source}) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return const [];

    final matches = <String, MedicationMatch>{};

    for (final record in _records) {
      if (record.matches(normalized)) {
        matches[record.name] = MedicationMatch(
          name: record.name,
          aliases: record.aliases,
          reason: 'Matched by text recognition.',
          source: source,
        );
      }
    }

    for (final rule in _symptomRules) {
      if (!normalized.contains(rule.keyword)) continue;
      for (final medName in rule.medications) {
        final record = _records.firstWhere(
          (r) => r.name == medName,
          orElse: () => _MedicationRecord(medName, const []),
        );
        matches.putIfAbsent(
          record.name,
          () => MedicationMatch(
            name: record.name,
            aliases: record.aliases,
            reason: 'Suggested for symptom: ${rule.displayName}.',
            source: 'symptom',
          ),
        );
      }
    }

    final list = matches.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<MedicationMatch> searchBarcode(String barcode) {
    final normalized = _normalize(barcode);
    if (normalized.isEmpty) return const [];

    final matches = <MedicationMatch>[];

    final mapped = _barcodeMap[normalized];
    if (mapped != null) {
      for (final medName in mapped) {
        final record = _records.firstWhere(
          (r) => r.name == medName,
          orElse: () => _MedicationRecord(medName, const []),
        );
        matches.add(
          MedicationMatch(
            name: record.name,
            aliases: record.aliases,
            reason: 'Matched by barcode.',
            source: 'barcode',
          ),
        );
      }
    }

    return matches;
  }
}

class _MedicationRecord {
  final String name;
  final List<String> aliases;
  final String _normalizedName;
  final List<String> _normalizedAliases;

  _MedicationRecord(this.name, this.aliases)
      : _normalizedName = _normalize(name),
        _normalizedAliases = aliases.map(_normalize).toList();

  bool matches(String normalizedText) {
    if (_normalizedName.isNotEmpty && normalizedText.contains(_normalizedName)) {
      return true;
    }
    for (final alias in _normalizedAliases) {
      if (alias.isNotEmpty && normalizedText.contains(alias)) return true;
    }
    return false;
  }
}

class _SymptomRule {
  final String keyword;
  final String displayName;
  final List<String> medications;

  _SymptomRule(this.keyword, this.displayName, this.medications);
}

List<_MedicationRecord> _buildRecords() {
  final seen = <String>{};
  final records = <_MedicationRecord>[];

  void addAll(List<dynamic> entries) {
    for (final entry in entries) {
      if (entry is br.MedicationDictionaryEntry) {
        if (seen.add(entry.name)) {
          records.add(_MedicationRecord(entry.name, entry.aliases));
        }
      } else if (entry is pt.MedicationDictionaryEntry) {
        if (seen.add(entry.name)) {
          records.add(_MedicationRecord(entry.name, entry.aliases));
        }
      }
    }
  }

  addAll(br.medicationsPtBr);
  addAll(pt.medicationsPtPt);

  return records;
}

List<_SymptomRule> _buildSymptomRules() {
  return [
    _SymptomRule('dor de cabeca', 'dor de cabeca', [
      'paracetamol',
      'ibuprofeno',
      'dipirona',
    ]),
    _SymptomRule('febre', 'febre', [
      'paracetamol',
      'ibuprofeno',
      'dipirona',
    ]),
    _SymptomRule('dor muscular', 'dor muscular', [
      'ibuprofeno',
      'diclofenaco',
    ]),
    _SymptomRule('azia', 'azia', [
      'omeprazol',
      'pantoprazol',
    ]),
    _SymptomRule('nausea', 'nausea', [
      'ondansetrona',
      'metoclopramida',
    ]),
    _SymptomRule('diarreia', 'diarreia', [
      'loperamida',
    ]),
    _SymptomRule('alergia', 'alergia', [
      'loratadina',
      'cetirizina',
      'desloratadina',
    ]),
    _SymptomRule('tosse', 'tosse', [
      'ambroxol',
      'acetilcisteina',
    ]),
  ];
}

String _normalize(String input) {
  var text = input.toLowerCase();
  text = text
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, List<String>> _barcodeMap = {};
