import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:safemed/models/drug_regist.dart';
import 'package:safemed/models/informative_bill.dart';

/// Service that loads the bundled Infarmed database and exposes the same
/// medication data that the UI already expects.
class InfarmedMedicationService {
  static const _sqliteAssetPath = 'assets/meds_infarmed.sqlite';

  final List<DrugRegist> _entries = [];
  final List<InformativeBill> _informativeBills = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get count => _entries.length;
  List<DrugRegist> get all => List.unmodifiable(_entries);
  List<InformativeBill> get informativeBills => List.unmodifiable(_informativeBills);

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _loadFromSqliteAsset();
    } catch (_) {
      _entries.clear();
      _informativeBills.clear();
    }

    _initialized = true;
  }

  List<DrugRegist> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    return _entries.where((entry) {
      return _normalize(entry.medName).contains(normalizedQuery) ||
          _normalize(entry.dci).contains(normalizedQuery) ||
          _normalize(entry.form).contains(normalizedQuery) ||
          _normalize(entry.dosage).contains(normalizedQuery);
    }).toList();
  }

  DrugRegist? findByCnpem(String cnpem) {
    final clean = _digitsOnly(cnpem);
    if (clean.isEmpty) return null;

    try {
      return _entries.firstWhere((entry) => entry.cnpem.toString() == clean);
    } catch (_) {
      return null;
    }
  }

  DrugRegist? findById(String id) => getEntryById(id);

  DrugRegist? getEntryById(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return null;

    try {
      return _entries.firstWhere((entry) {
        return entry.id.toString() == clean || entry.nRegisto.toString() == clean;
      });
    } catch (_) {
      return null;
    }
  }

  InformativeBill? getInformativeBillById(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return null;

    try {
      return _informativeBills.firstWhere((bill) => bill.id.toString() == clean);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFromSqliteAsset() async {
    final dbFile = await _materializeAssetDatabase();
    final database = sqlite3.open(dbFile.path);

    try {
      final medicationRows = database.select(
        'SELECT * FROM medications ORDER BY dci, nome_medicamento, id',
      );
      final billRows = database.select(
        'SELECT * FROM informative_bills ORDER BY dci, medicamento, id',
      );

      final billsByKey = <String, Map<String, Object?>>{};
      for (final row in billRows) {
        final sourceKey = _stringValue(row['source_key']);
        final dci = _stringValue(row['dci']);
        final medicamento = _stringValue(row['medicamento']);
        final key = _normalizeKey(
          sourceKey.isNotEmpty ? sourceKey : '$dci|$medicamento',
        );
        billsByKey[key] = row;
      }

      _entries.clear();
      _informativeBills.clear();

      for (final row in medicationRows) {
        final entry = _drugRegistFromMedicationRow(row);
        final billRow = billsByKey[_normalizeKey('${entry.dci}|${entry.medName}')];
        final bill = _informativeBillFromRows(entry, billRow, medicationRow: row);
        _entries.add(_InfarmedDrugRegist(entry, bill));
        _informativeBills.add(bill);
      }
    } finally {
      database.dispose();
    }
  }

  Future<File> _materializeAssetDatabase() async {
    final bytes = await rootBundle.load(_sqliteAssetPath);
    final directory = await getApplicationSupportDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}meds_infarmed.sqlite',
    );
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return file;
  }

  DrugRegist _drugRegistFromMedicationRow(Map<String, Object?> row) {
    return DrugRegist(
      id: _intValue(row['id']) ?? 0,
      nRegisto: _intValue(row['n_registo']) ?? 0,
      dci: _stringValue(row['dci']),
      medName: _stringValue(row['nome_medicamento']),
      form: _stringValue(row['forma_farmaceutica']),
      dosage: _stringValue(row['dosagem']),
      boxsize: _stringValue(row['tamanho_embalagem']),
      cnpem: _intValue(row['cnpem']) ?? 0,
      pricePVP: _stringValue(row['price_pvp']).isNotEmpty
          ? _stringValue(row['price_pvp'])
          : null,
      pricePVPnotified: _stringValue(row['price_pvp_notified']).isNotEmpty
          ? _stringValue(row['price_pvp_notified'])
          : null,
      priceUtente: _stringValue(row['price_utente']).isNotEmpty
          ? _stringValue(row['price_utente'])
          : null,
      pricePensionista: _stringValue(row['price_pensionist']).isNotEmpty
          ? _stringValue(row['price_pensionist'])
          : null,
      commercialized: _stringValue(row['commercialized']),
      isGeneric: _boolValue(row['is_generic']),
      infoUrl: _stringValue(row['info_url']),
    );
  }

  DrugRegist _drugRegistFromJsonRow(
    Map<String, Object?> row, {
    required int fallbackIndex,
  }) {
    return DrugRegist(
      id: _intValue(row['id']) ?? fallbackIndex + 1,
      nRegisto: _intValue(row['nRegisto']) ?? 0,
      dci: _stringValue(row['dci']),
      medName: _stringValue(row['nome_medicamento']),
      form: _stringValue(row['forma_farmaceutica']),
      dosage: _stringValue(row['dosagem']),
      boxsize: _stringValue(row['tamanho_embalagem']),
      cnpem: _intValue(row['cnpem']) ?? 0,
      pricePVP: _stringValue(row['pricePVP']).isNotEmpty
          ? _stringValue(row['pricePVP'])
          : null,
      pricePVPnotified: _stringValue(row['pricePVPnotified']).isNotEmpty
          ? _stringValue(row['pricePVPnotified'])
          : null,
      priceUtente: _stringValue(row['priceUtente']).isNotEmpty
          ? _stringValue(row['priceUtente'])
          : null,
      pricePensionista: _stringValue(row['pricePensionist']).isNotEmpty
          ? _stringValue(row['pricePensionist'])
          : null,
      commercialized: _stringValue(row['commercialized']),
      isGeneric: _boolValue(row['isGeneric']),
      infoUrl: _stringValue(row['infoUrl']),
    );
  }

  InformativeBill _informativeBillFromRows(
    DrugRegist entry,
    Map<String, Object?>? billRow, {
    required Map<String, Object?> medicationRow,
  }) {
    if (billRow == null) {
      return _fallbackInformativeBill(entry, medicationRow);
    }

    return _informativeBillFromRow(
      billRow,
      fallbackId: entry.id,
      fallbackDci: entry.dci,
      fallbackMedName: entry.medName,
      fallbackUrl: entry.infoUrl,
    );
  }

      minimumAge: _intValue(row['idade_minima']),
      pregnancyRisk: _stringValue(row['gravidez_seguro']).isNotEmpty
          ? _stringValue(row['gravidez_seguro'])
          : null,
      pregnancyNote: _stringValue(row['gravidez_nota']).isNotEmpty
          ? _stringValue(row['gravidez_nota'])
          : null,
      breastfeedingRisk: _stringValue(row['amamentacao_seguro']).isNotEmpty
          ? _stringValue(row['amamentacao_seguro'])
          : null,
      breastfeedingNote: _stringValue(row['amamentacao_nota']).isNotEmpty
          ? _stringValue(row['amamentacao_nota'])
          : null,
    );
  }

  InformativeBill _fallbackInformativeBill(
    DrugRegist entry,
    Map<String, Object?> medicationRow,
  ) {
    return InformativeBill(
      id: entry.id,
      dci: entry.dci,
      medName: entry.medName,
      pdfUrl: entry.infoUrl,
      therapeuticIndications: const [],
      adverseReactions: const [],
      howToStore: null,
      criticalAdvices: null,
      minimumAge: null,
      pregnancyRisk: null,
      pregnancyNote: null,
      breastfeedingRisk: null,
      breastfeedingNote: null,
    );
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãä]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _InfarmedDrugRegist extends DrugRegist {
  final InformativeBill informativeBill;

  _InfarmedDrugRegist(DrugRegist base, this.informativeBill)
      : super(
          id: base.id,
          nRegisto: base.nRegisto,
          dci: base.dci,
          medName: base.medName,
          dosage: base.dosage,
          form: base.form,
          boxsize: base.boxsize,
          cnpem: base.cnpem,
          pricePVP: base.pricePVP,
          pricePVPnotified: base.pricePVPnotified,
          priceUtente: base.priceUtente,
          pricePensionista: base.pricePensionista,
          commercialized: base.commercialized,
          isGeneric: base.isGeneric,
          infoUrl: base.infoUrl,
        );
}

extension InfarmedDrugRegistX on DrugRegist {
  _InfarmedDrugRegist? get _infarmed => this is _InfarmedDrugRegist
      ? this as _InfarmedDrugRegist
      : null;

  String get nomeComercial => medName;
  String get substanciaAtiva => dci;
  String get formaFarmaceutica => form;
  String get dosagem => dosage;

  String get fiUrl {
    final billUrl = _infarmed?.informativeBill.pdfUrl;
    if (billUrl != null && billUrl.isNotEmpty) return billUrl;
    return infoUrl;
  }

  int? get idadeMinima => _infarmed?.informativeBill.minimumAge;

  String get pregnancyRiskText => _infarmed?.informativeBill.pregnancyRisk ?? '';

  String get pregnancyWarning {
    final bill = _infarmed?.informativeBill;
    if (bill == null) return '';
    return bill.pregnancyNote ?? bill.criticalAdvices ?? '';
  }

  String get breastfeedingRisk =>
      _infarmed?.informativeBill.breastfeedingRisk ?? '';

  String get breastfeedingNote =>
      _infarmed?.informativeBill.breastfeedingNote ?? '';

  InformativeBill toInformativeBill() {
    final bill = _infarmed?.informativeBill;
    if (bill != null) return bill;

    return InformativeBill(
      id: id,
      dci: dci,
      medName: medName,
      pdfUrl: infoUrl,
      therapeuticIndications: const [],
      adverseReactions: const [],
      howToStore: null,
      criticalAdvices: null,
      minimumAge: null,
      pregnancyRisk: null,
      pregnancyNote: null,
      breastfeedingRisk: null,
      breastfeedingNote: null,
    );
  }
}

String _normalizeKey(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  final text = value.toString().replaceAll(',', '.');
  return double.tryParse(text);
}

bool _boolValue(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'sim';
}

List<String> _listFromJson(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      return _listFromJson(decoded);
    } catch (_) {
      return text.isEmpty ? const [] : [text];
    }
  }
  return [value.toString().trim()].where((item) => item.isNotEmpty).toList();
}

Map<String, dynamic> _mapFromJson(dynamic value) {
  if (value == null) return const {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      return _mapFromJson(decoded);
    } catch (_) {
      return const {};
    }
  }
  return const {};
}

/// Global singleton instance — initialize once in main.dart.
final infarmedMedicationService = InfarmedMedicationService();
