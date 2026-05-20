import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:safemed/models/drug_regist.dart';
import 'package:safemed/models/informative_bill.dart';

class InformativeBillService {
  static const _sqliteAssetPath = 'assets/meds_infarmed.sqlite';

  final List<InformativeBill> _bills = [];
  final Map<String, InformativeBill> _billsById = {};
  final Map<String, InformativeBill> _billsByDci = {};
  final Map<String, InformativeBill> _billsBySourceKey = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get count => _bills.length;
  List<InformativeBill> get all => List.unmodifiable(_bills);

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _loadFromSqliteAsset();
    } catch (_) {
      _bills.clear();
      _billsById.clear();
      _billsByDci.clear();
      _billsBySourceKey.clear();
    }

    _initialized = true;
  }

  InformativeBill? getById(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    return _billsById[clean];
  }

  InformativeBill? getByDrugRegist(DrugRegist entry) {
    final dciKey = _normalizeKey(entry.dci);
    final byDci = _billsByDci[dciKey];
    if (byDci != null) return byDci;

    final sourceKey = _normalizeKey('${entry.dci}|${entry.medName}');
    final bySourceKey = _billsBySourceKey[sourceKey];
    if (bySourceKey != null) return bySourceKey;

    final byId = _billsById[entry.id.toString()];
    if (byId != null) return byId;

    try {
      return _bills.firstWhere(
        (bill) => _normalizeKey(bill.dci) == dciKey,
      );
    } catch (_) {
      return null;
    }
  }

  InformativeBill resolveFor(DrugRegist entry) {
    return getByDrugRegist(entry) ?? _fallbackInformativeBill(entry);
  }

  List<InformativeBill> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    return _bills.where((bill) {
      final searchableText = _normalize(
        [
          bill.dci,
          bill.medName,
          bill.pdfUrl,
          bill.therapeuticIndications.join(' '),
          bill.criticalAdvices ?? '',
          bill.howToStore ?? '',
          bill.pregnancyRisk ?? '',
          bill.pregnancyNote ?? '',
          bill.breastfeedingRisk ?? '',
          bill.breastfeedingNote ?? '',
        ].join(' '),
      );
      return searchableText.contains(normalizedQuery);
    }).toList();
  }

  Future<void> _loadFromSqliteAsset() async {
    final dbFile = await _materializeAssetDatabase();
    final database = sqlite3.open(dbFile.path);

    try {
      final billRows = database.select(
        'SELECT * FROM informative_bills ORDER BY dci, medicamento, id',
      );

      _bills.clear();
      _billsById.clear();
      _billsByDci.clear();
      _billsBySourceKey.clear();

      for (final row in billRows) {
        final bill = _informativeBillFromRow(row);
        final dciKey = _normalizeKey(bill.dci);
        final sourceKeyText = _stringValue(row['source_key']);
        final sourceKey = _normalizeKey(
          sourceKeyText.isNotEmpty
              ? sourceKeyText
              : '${bill.dci}|${bill.medName}',
        );

        _bills.add(bill);
        _billsById[bill.id.toString()] = bill;
        _billsByDci.putIfAbsent(dciKey, () => bill);
        _billsBySourceKey[sourceKey] = bill;
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

  InformativeBill _informativeBillFromRow(Map<String, Object?> row) {
    final indicacoes = _listFromJson(row['indicacoes_json']);
    final efeitosJson = _mapFromJson(row['efeitos_json']);
    final frequentes = _listFromJson(efeitosJson['frequentes']);
    final outros = _listFromJson(efeitosJson['outros']);

    return InformativeBill(
      id: _intValue(row['id']) ?? 0,
      dci: _stringValue(row['dci']),
      medName: _stringValue(row['medicamento']),
      pdfUrl: _stringValue(row['pdf_url']),
      therapeuticIndications: indicacoes,
      adverseReactions: [
        AdverseReactions(frequent: frequentes, other: outros),
      ],
      howToStore: _stringValue(row['conservacao']).isNotEmpty
          ? _stringValue(row['conservacao'])
          : null,
      criticalAdvices: _stringValue(row['aviso_critico']).isNotEmpty
          ? _stringValue(row['aviso_critico'])
          : null,
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

  InformativeBill _fallbackInformativeBill(DrugRegist entry) {
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

String _normalizeKey(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
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

final informativeBillService = InformativeBillService();