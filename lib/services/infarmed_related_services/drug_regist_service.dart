import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:safemed/models/drug_regist.dart';

class DrugRegistService {
  static const _sqliteAssetPath = 'assets/meds_infarmed.sqlite';

  final List<DrugRegist> _entries = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get count => _entries.length;
  List<DrugRegist> get all => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _loadFromSqliteAsset();
    } catch (_) {
      _entries.clear();
    }

    _initialized = true;
  }

  List<DrugRegist> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    return _entries.where((entry) {
      final searchableText = _normalize(
        [
          entry.medName,
          entry.dci,
          entry.form,
          entry.dosage,
          entry.boxsize,
          entry.commercialized,
          entry.infoUrl,
        ].join(' '),
      );

      return searchableText.contains(normalizedQuery);
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

  Future<void> _loadFromSqliteAsset() async {
    final dbFile = await _materializeAssetDatabase();
    final database = sqlite3.open(dbFile.path);

    try {
      final medicationRows = database.select(
        'SELECT * FROM medications ORDER BY dci, nome_medicamento, id',
      );

      _entries.clear();

      for (final row in medicationRows) {
        _entries.add(_drugRegistFromMedicationRow(row));
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

extension DrugRegistSqliteX on DrugRegist {
  String get nomeComercial => medName;
  String get substanciaAtiva => dci;
  String get formaFarmaceutica => form;
  String get dosagem => dosage;
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

bool _boolValue(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'sim';
}

final drugRegistService = DrugRegistService();