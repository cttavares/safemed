import '../models/medication_entry.dart';
import '../data/medications_pt_pt.dart';

class PrescriptionParser {
  // Common Æ’?ounitsÆ’?? youÆ’?Tll see in prescriptions
  static const _units = ['mg', 'g', 'mcg', 'AÃ¦g', 'ug', 'ml', 'mL'];

  // Words that often indicate dosing instructions (helps identify med lines)
  static const _doseHints = [
    'comp', 'comprim', 'caps', 'cAÂ­ps', 'cp', 'tab', 'saqueta', 'sach',
    'x/dia', 'vez', 'vezes', 'dia', 'diario', 'diaria',
    '8/8', '12/12', '24/24',
    'manhAÅ“', 'noite', 'tarde',
    'take', 'daily', 'hours', 'every',
    'sos', 's.o.s', 'necessario',
  ];

  // Normalize OCR text a bit
  String _normalize(String s) {
    var t = s.trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    // Common OCR confusions
    t = t.replaceAll('O', '0'); // careful: can be wrong, but often helps with "1O00 mg"
    t = t.replaceAll('l', '1'); // similarly risky; remove if too aggressive

    // Normalize microgram symbols
    t = t.replaceAll('AÃ¦g', 'mcg');
    t = t.replaceAll('ug', 'mcg');

    return t;
  }

  String _normalizeForMatch(String s) {
    var t = s.trim().toLowerCase();
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  String _fixOcrConfusions(String s) {
    // Swap common OCR confusions for matching only.
    return s
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
  }

  String _stripDiacritics(String s) {
    return s
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('Á', 'a')
        .replaceAll('À', 'a')
        .replaceAll('Â', 'a')
        .replaceAll('Ã', 'a')
        .replaceAll('É', 'e')
        .replaceAll('Ê', 'e')
        .replaceAll('Í', 'i')
        .replaceAll('Ó', 'o')
        .replaceAll('Ô', 'o')
        .replaceAll('Õ', 'o')
        .replaceAll('Ú', 'u')
        .replaceAll('Ç', 'c');
  }

  String _normalizeLoose(String s) {
    var t = _stripDiacritics(s.toLowerCase());
    t = _fixOcrConfusions(t);
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  int _levenshtein(String a, String b, {int? maxDistance}) {
    final alen = a.length;
    final blen = b.length;
    if (alen == 0) return blen;
    if (blen == 0) return alen;
    if (maxDistance != null && (alen - blen).abs() > maxDistance) {
      return maxDistance + 1;
    }

    final prev = List<int>.generate(blen + 1, (i) => i);
    final curr = List<int>.filled(blen + 1, 0);

    for (var i = 1; i <= alen; i++) {
      curr[0] = i;
      var rowMin = curr[0];
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= blen; j++) {
        final cb = b.codeUnitAt(j - 1);
        final cost = (ca == cb) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        final v = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
        curr[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (maxDistance != null && rowMin > maxDistance) {
        return maxDistance + 1;
      }
      for (var j = 0; j <= blen; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[blen];
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1.0;
    if (a.contains(b) || b.contains(a)) {
      final minLen = a.length < b.length ? a.length : b.length;
      if (minLen >= 4) return 0.95;
    }
    final maxLen = a.length > b.length ? a.length : b.length;
    final maxDistance = (maxLen / 3).floor();
    final dist = _levenshtein(a, b, maxDistance: maxDistance);
    if (dist > maxDistance) return 0;
    return 1.0 - (dist / maxLen);
  }

  ({String name, String? brandName}) _resolveMedicationName(String rawName, String fullLine) {
    final base = _normalizeForMatch(rawName);
    if (base.isEmpty) return (name: rawName, brandName: null);

    final variants = <String>{
      base,
      _normalizeForMatch(_fixOcrConfusions(base)),
    };

    var bestScore = 0.0;
    MedicationDictionaryEntry? bestEntry;
    String? bestCandidate;
    var bestCandidateIsAlias = false;

    for (final entry in medicationsPtPt) {
      final candidates = <String>[entry.name, ...entry.aliases];
      for (final candidate in candidates) {
        final normalizedCandidate = _normalizeForMatch(candidate);
        for (final variant in variants) {
          final score = _similarity(variant, normalizedCandidate);
          if (score > bestScore) {
            bestScore = score;
            bestEntry = entry;
            bestCandidate = candidate;
            bestCandidateIsAlias = candidate != entry.name;
          }
        }
      }
    }

    if (bestScore < 0.78 || bestEntry == null) {
      return (name: rawName, brandName: null);
    }

    final brandName = _extractBrandFromLine(
      bestEntry,
      fullLine,
      fallback: bestCandidateIsAlias ? bestCandidate : null,
    );

    return (name: bestEntry.name, brandName: brandName);
  }

  String? _extractBrandFromLine(
    MedicationDictionaryEntry entry,
    String line, {
    String? fallback,
  }) {
    if (entry.aliases.isEmpty) return fallback;

    final entryNameNorm = _normalizeForMatch(entry.name);
    final lower = line.toLowerCase();
    String? bestAlias;

    for (final alias in entry.aliases) {
      final aliasNorm = _normalizeForMatch(alias);
      if (aliasNorm.isEmpty || aliasNorm == entryNameNorm) continue;
      if (!lower.contains(alias.toLowerCase())) continue;
      if (bestAlias == null || alias.length > bestAlias.length) {
        bestAlias = alias;
      }
    }

    if (bestAlias == null) return fallback;

    final match = RegExp(RegExp.escape(bestAlias), caseSensitive: false).firstMatch(line);
    if (match != null) return match.group(0);
    return bestAlias;
  }

  // Heuristic: decide if a line likely contains a medication
  bool _looksLikeMedicationLine(String line) {
    final lower = line.toLowerCase();

    // has a number + unit (e.g. 500 mg, 1 g, 5 ml)
    final hasStrength = RegExp(r'(\d+([.,]\d+)?)\s*(mg|g|mcg|ml)\b', caseSensitive: false)
        .hasMatch(lower);

    // or has dosing hints
    final hasDoseHint = _doseHints.any((h) => lower.contains(h));

    // ignore very short lines
    if (lower.length < 4) return false;

    // ignore obvious headers
    if (lower.contains('prescri') || lower.contains('receita') || lower.contains('utente')) {
      return false;
    }

    return hasStrength || hasDoseHint;
  }

  // Extract strength: "500 mg" / "1 g" / "0.5 mg"
  (double?, String?) _extractStrength(String line) {
    final m = RegExp(r'(\d+([.,]\d+)?)\s*(mg|g|mcg|ml)\b', caseSensitive: false).firstMatch(line);
    if (m == null) return (null, null);

    final rawNum = m.group(1)!.replaceAll(',', '.');
    final unit = m.group(3)!.toLowerCase();

    final value = double.tryParse(rawNum);
    if (value == null) return (null, null);

    // Normalize grams to mg to simplify later, if you want:
    // Here we keep unit as-is; you can normalize later.
    return (value, unit);
  }

  // Extract frequency: "3x/dia", "2x dia", "de 8/8h", "8/8"
  (int?, String?) _extractFrequency(String line) {
    final lower = line.toLowerCase();
    final normalized = _normalizeLoose(line);

    // 3x/dia or 3 x dia
    final m1 = RegExp(r'(\d+)\s*x\s*/?\s*(dia|day)\b').firstMatch(lower);
    if (m1 != null) {
      return (int.tryParse(m1.group(1)!), null);
    }

    // "8/8h", "12/12h", "8/8"
    final m2 = RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})\s*h?').firstMatch(lower);
    if (m2 != null) {
      final a = m2.group(1)!;
      final b = m2.group(2)!;
      // Often written 8/8 meaning every 8 hours
      if (a == b) return (null, '$a/$b h');
      return (null, '$a/$b h');
    }

    // "every 8 hours"
    final m3 = RegExp(r'every\s+(\d{1,2})\s+hours').firstMatch(lower);
    if (m3 != null) {
      return (null, '${m3.group(1)}h');
    }

    // "diario", "diaria", "daily", "cada dia"
    if (RegExp(r'\b(diario|diaria|diariamente|daily|cada dia)\b').hasMatch(normalized)) {
      return (1, null);
    }

    return (null, null);
  }

  // Extract dose per intake: "1 comprimido", "2 comp", "1 cp", "1 tab"
  (double?, String?) _extractDose(String line) {
    final m = RegExp(
      r'(\d+([.,]\d+)?)\s*(comprimidos?|comprimido|comprim|comp|cp|tab|tabs|caps?|capsula|capsulas|saquetas?|sache|sachet|sach)\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (m == null) return (null, null);

    final rawNum = m.group(1)!.replaceAll(',', '.');
    final value = double.tryParse(rawNum);
    if (value == null) return (null, null);

    var unit = m.group(3)!.toLowerCase();
    if (unit == 'cp' || unit.startsWith('comp') || unit.startsWith('comprim')) {
      unit = 'comprimido';
    } else if (unit.startsWith('tab')) {
      unit = 'tab';
    } else if (unit.startsWith('cap')) {
      unit = 'capsula';
    } else if (unit.startsWith('saq') || unit.startsWith('sach')) {
      unit = 'saqueta';
    }

    return (value, unit);
  }

  String _formatDose(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  int? _extractPackQuantity(String line) {
    final m = RegExp(r'\b[x×]\s*s?\s*(\d{1,4})\b', caseSensitive: false)
        .firstMatch(line);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  String? _detectTiming(String line) {
    final tokens = _normalizeLoose(line).split(' ');
    if (tokens.isEmpty) return null;

    bool matchesToken(String token, String target) {
      if (token == target) return true;
      return _similarity(token, target) >= 0.82;
    }

    int? indexOfToken(String target) {
      for (var i = 0; i < tokens.length; i++) {
        if (matchesToken(tokens[i], target)) return i;
      }
      return null;
    }

    final almocoIndex = indexOfToken('almoco');
    if (almocoIndex != null) {
      final hasPequeno = almocoIndex > 0 && matchesToken(tokens[almocoIndex - 1], 'pequeno');
      return hasPequeno ? 'ao pequeno almoco' : 'ao almoco';
    }

    if (indexOfToken('jantar') != null) return 'ao jantar';
    if (indexOfToken('lanche') != null) return 'ao lanche';

    return null;
  }

  String? _extractIntakeNotes(
    String line, {
    double? doseValue,
    String? doseUnit,
  }) {
    final timingText = _detectTiming(line);
    if (timingText == null) return null;

    if (doseValue != null && doseUnit != null) {
      return '${_formatDose(doseValue)} $doseUnit $timingText';
    }

    return timingText;
  }

  String? _extractDurationNote(String line) {
    final match = RegExp(
      r'\b(durante|por)\s+\d{1,3}\s*(dias?|semanas?|meses?|anos?)\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    return match.group(0);
  }

  String? _extractUsageNote(String line) {
    final normalized = _normalizeLoose(line);
    if (RegExp(r'\b(sos|s o s)\b').hasMatch(normalized)) return 'SOS';
    if (RegExp(r'\b(se necessario|necessario)\b').hasMatch(normalized)) {
      return 'se necessario';
    }
    return null;
  }

  String? _combineNotes(List<String?> notes) {
    final cleaned = notes
        .where((n) => n != null && n!.trim().isNotEmpty)
        .map((n) => n!.trim())
        .toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join(' | ');
  }

  bool _isDosingOnlyLine(String line, {required bool hasStrength, required bool hasDose}) {
    if (hasStrength || !hasDose) return false;
    return RegExp(
      r'^\s*(tomar|toma|ingerir|via)?\s*\d+([.,]\d+)?\s*(comprimidos?|comprimido|comprim|comp|cp|tab|tabs|caps?|capsula|capsulas|saquetas?|sache|sachet|sach)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  // Guess name: take text before strength, or first 2-4 tokens
  String _guessName(String line) {
    final m = RegExp(r'(\d+([.,]\d+)?)\s*(mg|g|mcg|ml)\b', caseSensitive: false).firstMatch(line);
    if (m != null) {
      final before = line.substring(0, m.start).trim();
      if (before.isNotEmpty) return before;
    }

    final parts = line.split(' ');
    if (parts.length <= 4) return line;
    return parts.take(4).join(' ');
  }

  List<MedicationEntry> parse(String ocrText) {
    final lines = ocrText
        .split(RegExp(r'[\n\r]+'))
        .map(_normalize)
        .where((l) => l.isNotEmpty)
        .toList();

    final meds = <MedicationEntry>[];

    for (final line in lines) {
      final (strengthValue, strengthUnit) = _extractStrength(line);
      final (dosePerIntake, doseUnit) = _extractDose(line);
      final (timesPerDay, interval) = _extractFrequency(line);
      final packQuantity = _extractPackQuantity(line);
      final intakeNotes = _extractIntakeNotes(
        line,
        doseValue: dosePerIntake,
        doseUnit: doseUnit,
      );
      final durationNote = _extractDurationNote(line);
      final usageNote = _extractUsageNote(line);
      final combinedIntakeNotes = _combineNotes([
        intakeNotes,
        usageNote,
        durationNote,
      ]);

      if (_isDosingOnlyLine(
            line,
            hasStrength: strengthValue != null,
            hasDose: dosePerIntake != null,
          ) &&
          meds.isNotEmpty) {
        final last = meds.removeLast();
        meds.add(
          MedicationEntry(
            rawLine: '${last.rawLine} | $line',
            name: last.name,
            brandName: last.brandName,
            strengthValue: last.strengthValue,
            strengthUnit: last.strengthUnit,
            packQuantity: packQuantity ?? last.packQuantity,
            dosePerIntake: dosePerIntake ?? last.dosePerIntake,
            doseUnit: doseUnit ?? last.doseUnit,
            timesPerDay: timesPerDay ?? last.timesPerDay,
            interval: interval ?? last.interval,
            intakeNotes: combinedIntakeNotes ?? last.intakeNotes,
            notes: last.notes,
          ),
        );
        continue;
      }

      if (!_looksLikeMedicationLine(line)) continue;
      final guessedName = _guessName(line);
      final resolved = _resolveMedicationName(guessedName, line);

      meds.add(
        MedicationEntry(
          rawLine: line,
          name: resolved.name,
          brandName: resolved.brandName,
          strengthValue: strengthValue,
          strengthUnit: strengthUnit,
          packQuantity: packQuantity,
          dosePerIntake: dosePerIntake,
          doseUnit: doseUnit,
          timesPerDay: timesPerDay,
          interval: interval,
          intakeNotes: combinedIntakeNotes,
        ),
      );
    }

    return meds;
  }
}
