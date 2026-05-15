import 'package:safemed/models/medication.dart';

class AllergySubstanceRule {
  final String allergyKeyword;
  final List<String> substanceKeywords;

  const AllergySubstanceRule({
    required this.allergyKeyword,
    required this.substanceKeywords,
  });
}

class SubstancePregnancyRule {
  final String substanceKeyword;
  final PregnancyRiskCategory risk;

  const SubstancePregnancyRule({
    required this.substanceKeyword,
    required this.risk,
  });
}

/// A Beers Criteria-style rule: substance classes that carry elevated risk for
/// elderly patients (≥65 years), regardless of other conditions.
class ElderlyRiskRule {
  final String substanceKeyword;
  final String message;

  const ElderlyRiskRule({
    required this.substanceKeyword,
    required this.message,
  });
}

const List<String> medicalRestrictionOptions = [
  'Disfagia (dificuldade de deglutição)',
  'Necessidade de forma farmacêutica líquida',
  'Intolerância à lactose',
  'Evitar sedação (risco de quedas)',
  'Necessidade de administração com alimento',
  'Evitar anti-inflamatórios não esteroides',
];

const List<AllergySubstanceRule> allergySubstanceRules = [
  // ── Penicilinas e cefalosporinas (reatividade cruzada ~10 %) ──────────────
  AllergySubstanceRule(
    allergyKeyword: 'Penicilina',
    substanceKeywords: [
      'Amoxicilina',
      'Ampicilina',
      'Penicilina',
      // Cefalosporinas — reatividade cruzada
      'Cefalexina',
      'Cefuroxima',
      'Ceftriaxona',
      'Cefazolina',
      'Cefadroxilo',
      'Cefixima',
      'Cefepima',
      'Ceftazidima',
    ],
  ),
  // ── Anti-inflamatórios não esteroides (NSAIDs) ────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Anti-inflamatorio nao esteroide',
    substanceKeywords: [
      'Ibuprofeno',
      'Diclofenaco',
      'Naproxeno',
      'Acido Acetilsalicilico',
      'Aspirina',
      'Cetoprofeno',
      'Meloxicam',
      'Celecoxibe',
      'Etoricoxibe',
    ],
  ),
  // ── Aspirina (separada dos NSAIDs — reatividade mais específica) ──────────
  AllergySubstanceRule(
    allergyKeyword: 'Aspirina',
    substanceKeywords: ['Acido Acetilsalicilico', 'Aspirina'],
  ),
  // ── Sulfonamidas ──────────────────────────────────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Sulfonamidas',
    substanceKeywords: [
      'Sulfametoxazol',
      'Sulfadiazina',
      'Sulfassalazina',
    ],
  ),
  // ── Paracetamol ───────────────────────────────────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Paracetamol',
    substanceKeywords: ['Paracetamol', 'Acetaminofeno'],
  ),
  // ── Macrolídeos ───────────────────────────────────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Macrolideo',
    substanceKeywords: [
      'Azitromicina',
      'Claritromicina',
      'Eritromicina',
      'Roxitromicina',
      'Spiramicina',
    ],
  ),
  // ── Fluoroquinolonas ──────────────────────────────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Fluoroquinolona',
    substanceKeywords: [
      'Ciprofloxacino',
      'Levofloxacino',
      'Moxifloxacino',
      'Norfloxacino',
      'Ofloxacino',
    ],
  ),
  // ── Estatinas (miopatia por hipersensibilidade) ───────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Estatina',
    substanceKeywords: [
      'Atorvastatina',
      'Sinvastatina',
      'Rosuvastatina',
      'Pravastatina',
      'Pitavastatina',
      'Fluvastatina',
    ],
  ),
  // ── Benzodiazepinas ───────────────────────────────────────────────────────
  AllergySubstanceRule(
    allergyKeyword: 'Benzodiazepina',
    substanceKeywords: [
      'Diazepam',
      'Clonazepam',
      'Alprazolam',
      'Lorazepam',
      'Bromazepam',
      'Midazolam',
    ],
  ),
];

const List<SubstancePregnancyRule> pregnancySubstanceRules = [
  SubstancePregnancyRule(
    substanceKeyword: 'Paracetamol',
    risk: PregnancyRiskCategory.B,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Ibuprofeno',
    risk: PregnancyRiskCategory.C,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Diclofenaco',
    risk: PregnancyRiskCategory.D,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Acido Acetilsalicilico',
    risk: PregnancyRiskCategory.D,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Lisinopril',
    risk: PregnancyRiskCategory.D,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Sulfametoxazol',
    risk: PregnancyRiskCategory.D,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Varfarina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Atorvastatina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Sinvastatina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Rosuvastatina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Isotretinoina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Talidomida',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Metformina',
    risk: PregnancyRiskCategory.B,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Sertralina',
    risk: PregnancyRiskCategory.C,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Diazepam',
    risk: PregnancyRiskCategory.D,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Omeprazol',
    risk: PregnancyRiskCategory.C,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Azitromicina',
    risk: PregnancyRiskCategory.B,
  ),
];

/// Beers Criteria-inspired rules for elderly patients (≥ 65 years).
/// Each entry maps a substance keyword to a Portuguese clinical warning message.
const List<ElderlyRiskRule> elderlyRiskRules = [
  // Benzodiazepinas
  ElderlyRiskRule(
    substanceKeyword: 'Diazepam',
    message:
        'Benzodiazepínico de longa ação — risco de sedação excessiva, quedas e confusão em idosos (Critérios de Beers).',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Clonazepam',
    message:
        'Benzodiazepínico — risco acrescido de quedas, fraturas e deterioração cognitiva em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Alprazolam',
    message:
        'Benzodiazepínico — associado a sedação e risco de quedas em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Lorazepam',
    message:
        'Benzodiazepínico — risco de sedação prolongada e desequilíbrio em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Bromazepam',
    message:
        'Benzodiazepínico — pode causar sedação e instabilidade postural em idosos.',
  ),
  // Anti-histamínicos de 1ª geração
  ElderlyRiskRule(
    substanceKeyword: 'Clemastina',
    message:
        'Anti-histamínico de 1ª geração — efeito anticolinérgico; pode causar confusão mental e retenção urinária em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Hidroxizina',
    message:
        'Antihistamínico sedativo — risco de hipotensão ortostática, confusão e quedas em idosos.',
  ),
  // NSAIDs em idosos
  ElderlyRiskRule(
    substanceKeyword: 'Ibuprofeno',
    message:
        'AINE — risco acrescido de hemorragia gastrointestinal e insuficiência renal em idosos. Preferir paracetamol se possível.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Diclofenaco',
    message:
        'AINE — risco acrescido de eventos cardiovasculares e hemorragia GI em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Naproxeno',
    message:
        'AINE — risco de hemorragia gastrointestinal aumentado em idosos; usar com precaução.',
  ),
  // Antidepressivos tricíclicos
  ElderlyRiskRule(
    substanceKeyword: 'Amitriptilina',
    message:
        'Antidepressivo tricíclico — efeitos anticolinérgicos severos; risco de quedas, hipotensão ortostática e confusão em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Imipramina',
    message:
        'Antidepressivo tricíclico — risco de hipotensão ortostática e arritmias em idosos.',
  ),
  ElderlyRiskRule(
    substanceKeyword: 'Nortriptilina',
    message:
        'Antidepressivo tricíclico — efeitos anticolinérgicos; preferir alternativas mais seguras em idosos.',
  ),
  // Zolpidem
  ElderlyRiskRule(
    substanceKeyword: 'Zolpidem',
    message:
        'Hipnótico não-benzodiazepínico — risco de quedas noturnas, confusão e dependência em idosos.',
  ),
  // Antipsicóticos
  ElderlyRiskRule(
    substanceKeyword: 'Haloperidol',
    message:
        'Antipsicótico — risco de sintomas extrapiramidais, sedação excessiva e eventos cardiovasculares em idosos.',
  ),
  // Digoxina em altas doses
  ElderlyRiskRule(
    substanceKeyword: 'Digoxina',
    message:
        'Glicosídeo cardíaco — margem terapêutica estreita; risco de toxicidade aumentado por redução do clearance renal em idosos.',
  ),
];

/// Maps normalized keywords found in the `healthIssues` free-text field to
/// pathology IDs used in `medication.contraindicacoes`.
const Map<String, String> _healthIssuesKeywordMap = {
  'asma': 'asma',
  'broncoespasmo': 'asma',
  'bronquite asmatica': 'asma',
  'dpoc': 'dopc',
  'doenca pulmonar obstrutiva': 'dopc',
  'enfisema': 'dopc',
  'bronquite cronica': 'dopc',
  'ulcera': 'ulcera_gastrica',
  'ulcera gastrica': 'ulcera_gastrica',
  'ulcera peptica': 'ulcera_gastrica',
  'gastrite': 'ulcera_gastrica',
  'insuficiencia renal': 'insuficiencia_renal',
  'doenca renal': 'insuficiencia_renal',
  'rim': 'insuficiencia_renal',
  'nefropatia': 'insuficiencia_renal',
  'insuficiencia hepatica': 'insuficiencia_hepatica',
  'doenca hepatica': 'insuficiencia_hepatica',
  'cirrose': 'insuficiencia_hepatica',
  'hepatite': 'insuficiencia_hepatica',
  'figado': 'insuficiencia_hepatica',
  'arritmia': 'arritmia',
  'fibrilacao auricular': 'arritmia',
  'taquicardia': 'arritmia',
  'insuficiencia cardiaca': 'insuficiencia_cardiaca',
  'insuficiencia cardiaca congestiva': 'insuficiencia_cardiaca',
  'hipertensao': 'hipertensao',
  'pressao alta': 'hipertensao',
  'diabetes': 'diabetes',
  'diabetico': 'diabetes',
  'anemia': 'anemia',
};

// ─── Internal helpers ─────────────────────────────────────────────────────────

String _normalize(String value) {
  final lower = value.toLowerCase().trim();
  return lower
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
      .replaceAll('ç', 'c');
}

String _normalizeAllergyInput(String value) {
  final n = _normalize(value);

  if (n.contains('penicillin') || n.contains('penicilina')) {
    return 'penicilina';
  }
  if (n.contains('sulfa')) {
    return 'sulfonamidas';
  }
  if (n.contains('nsaid') ||
      n.contains('antiinflamatorio') ||
      n.contains('anti-inflamatorio')) {
    return 'anti-inflamatorio nao esteroide';
  }
  if (n.contains('macrolideo') || n.contains('macrolide')) {
    return 'macrolideo';
  }
  if (n.contains('quinolona') ||
      n.contains('fluoroquinolona') ||
      n.contains('quinolone')) {
    return 'fluoroquinolona';
  }
  if (n.contains('estatina') || n.contains('statin')) {
    return 'estatina';
  }
  if (n.contains('benzodiazepina') || n.contains('benzodiazepine')) {
    return 'benzodiazepina';
  }
  return n;
}

// ─── Public API ───────────────────────────────────────────────────────────────

/// Returns allergy keywords that match [substance] given the patient's allergy
/// list. Used to surface the "Alergia (alto)" red warning.
List<String> findMatchedAllergyRulesForSubstance({
  required List<String> patientAllergies,
  required String substance,
}) {
  final normalizedSubstance = _normalize(substance);
  final normalizedPatientAllergies = patientAllergies
      .map(_normalizeAllergyInput)
      .where((v) => v.isNotEmpty)
      .toList();

  final matches = <String>{};

  for (final rule in allergySubstanceRules) {
    final allergyKey = _normalize(rule.allergyKeyword);
    final hasAllergy = normalizedPatientAllergies.any(
      (a) => a.contains(allergyKey) || allergyKey.contains(a),
    );
    if (!hasAllergy) {
      continue;
    }

    final substanceMatch = rule.substanceKeywords.any(
      (s) => normalizedSubstance.contains(_normalize(s)),
    );

    if (substanceMatch) {
      matches.add(rule.allergyKeyword);
    }
  }

  return matches.toList()..sort();
}

/// Returns the FDA pregnancy risk category for [substance] from the override
/// table, or null if no override exists (caller falls back to model field).
PregnancyRiskCategory? pregnancyRiskBySubstance(String substance) {
  final normalized = _normalize(substance);

  for (final rule in pregnancySubstanceRules) {
    if (normalized.contains(_normalize(rule.substanceKeyword))) {
      return rule.risk;
    }
  }

  return null;
}

/// Returns a list of Beers Criteria warning messages for [substance] when the
/// patient profile is elderly (≥ 65 years).
List<String> findElderlyRisks(String substance) {
  final normalized = _normalize(substance);
  return elderlyRiskRules
      .where((rule) => normalized.contains(_normalize(rule.substanceKeyword)))
      .map((rule) => rule.message)
      .toList();
}

/// Parses the free-text [healthIssues] field and returns a list of pathology
/// IDs that can be cross-checked against [medication.contraindicacoes].
List<String> parseHealthIssuesConditions(String healthIssues) {
  final normalized = _normalize(healthIssues);
  final found = <String>{};
  for (final entry in _healthIssuesKeywordMap.entries) {
    if (normalized.contains(_normalize(entry.key))) {
      found.add(entry.value);
    }
  }
  return found.toList();
}
