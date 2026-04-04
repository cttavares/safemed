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

const List<String> medicalRestrictionOptions = [
  'Disfagia (dificuldade de deglutição)',
  'Necessidade de forma farmacêutica líquida',
  'Intolerância à lactose',
  'Evitar sedação (risco de quedas)',
  'Necessidade de administração com alimento',
  'Evitar anti-inflamatórios não esteroides',
];

const List<AllergySubstanceRule> allergySubstanceRules = [
  AllergySubstanceRule(
    allergyKeyword: 'Penicilina',
    substanceKeywords: ['Amoxicilina', 'Ampicilina', 'Penicilina'],
  ),
  AllergySubstanceRule(
    allergyKeyword: 'Anti-inflamatorio nao esteroide',
    substanceKeywords: [
      'Ibuprofeno',
      'Diclofenaco',
      'Naproxeno',
      'Acido Acetilsalicilico',
      'Aspirina',
    ],
  ),
  AllergySubstanceRule(
    allergyKeyword: 'Aspirina',
    substanceKeywords: ['Acido Acetilsalicilico', 'Aspirina'],
  ),
  AllergySubstanceRule(
    allergyKeyword: 'Sulfonamidas',
    substanceKeywords: ['Sulfametoxazol', 'Sulfadiazina'],
  ),
  AllergySubstanceRule(
    allergyKeyword: 'Paracetamol',
    substanceKeywords: ['Paracetamol', 'Acetaminofeno'],
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
    substanceKeyword: 'Isotretinoina',
    risk: PregnancyRiskCategory.X,
  ),
  SubstancePregnancyRule(
    substanceKeyword: 'Talidomida',
    risk: PregnancyRiskCategory.X,
  ),
];

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

  if (n.contains('penicillin')) {
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
  return n;
}

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

PregnancyRiskCategory? pregnancyRiskBySubstance(String substance) {
  final normalized = _normalize(substance);

  for (final rule in pregnancySubstanceRules) {
    if (normalized.contains(_normalize(rule.substanceKeyword))) {
      return rule.risk;
    }
  }

  return null;
}
