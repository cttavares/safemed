import 'package:flutter/foundation.dart';

import '../../models/medication_match.dart';
import '../../services/medication_explorer_service.dart';

class MedicationExplorerMatchEngine extends ChangeNotifier {
  MedicationExplorerMatchEngine() : _service = MedicationExplorerService();

  final MedicationExplorerService _service;

  List<MedicationMatch> _visionMatches = const [];
  List<MedicationMatch> _ocrMatches = const [];
  List<MedicationMatch> _manualMatches = const [];
  List<MedicationMatch> _matches = const [];
  String _lastOcrSnippet = '';

  List<MedicationMatch> get visionMatches => _visionMatches;
  List<MedicationMatch> get ocrMatches => _ocrMatches;
  List<MedicationMatch> get manualMatches => _manualMatches;
  List<MedicationMatch> get matches => _matches;
  String get lastOcrSnippet => _lastOcrSnippet;

  void updateVisionTags(Iterable<String> tags) {
    final visionMatches = <MedicationMatch>[];
    for (final tag in tags) {
      visionMatches.addAll(_service.searchText(tag, source: 'vision'));
    }

    _visionMatches = visionMatches;
    _recomputeMatches();
  }

  void updateOcrText(String text) {
    final matches = _service.searchText(text, source: 'ocr');
    final snippet = text.replaceAll(RegExp(r'\s+'), ' ');

    _lastOcrSnippet = snippet.length > 120
        ? '${snippet.substring(0, 120)}...'
        : snippet;
    _ocrMatches = matches;
    _recomputeMatches();
  }

  void searchManual(String text) {
    final trimmed = text.trim();
    _manualMatches = trimmed.isEmpty
        ? const <MedicationMatch>[]
        : _service.searchText(trimmed, source: 'manual');
    _recomputeMatches();
  }

  void clearManualSearch() {
    _manualMatches = const [];
    _recomputeMatches();
  }

  void _recomputeMatches() {
    final map = <String, MedicationMatch>{};
    for (final match in _manualMatches) {
      map.putIfAbsent(match.name, () => match);
    }
    for (final match in _ocrMatches) {
      map.putIfAbsent(match.name, () => match);
    }
    for (final match in _visionMatches) {
      map.putIfAbsent(match.name, () => match);
    }

    _matches = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }
}
