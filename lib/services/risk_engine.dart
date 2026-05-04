import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';

// ── Severity ──────────────────────────────────────────────────────────────────

enum RiskSeverity { critical, high, moderate, info }

extension RiskSeverityExt on RiskSeverity {
  String get label {
    switch (this) {
      case RiskSeverity.critical: return 'Critical';
      case RiskSeverity.high:     return 'High';
      case RiskSeverity.moderate: return 'Moderate';
      case RiskSeverity.info:     return 'Info';
    }
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class RiskAlert {
  final RiskSeverity severity;
  final String category;   // "Interaction", "Condition", "Allergy", "Pregnancy", "Age"
  final String title;
  final String detail;
  final List<String> involvedDrugs;

  const RiskAlert({
    required this.severity,
    required this.category,
    required this.title,
    required this.detail,
    this.involvedDrugs = const [],
  });
}

// ── Legacy surface (used by result_screen.dart) ───────────────────────────────

class RiskResult {
  final String drug;
  final String level;   // 'RED' | 'YELLOW' | 'GREEN'
  final String message;
  RiskResult(this.drug, this.level, this.message);
}

List<RiskResult> analyzePrescription(
  String text, int age, bool renal, bool hepatic,
) {
  // Kept for backward-compat; simple line-by-line scan
  final results = <RiskResult>[];
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;
    final n = line.toLowerCase();
    if (n.contains('ibuprofen') && renal) {
      results.add(RiskResult(line, 'RED', 'NSAIDs may worsen renal function.'));
    } else if (age >= 65) {
      results.add(RiskResult(line, 'YELLOW', 'Elderly patients require dose review.'));
    } else {
      results.add(RiskResult(line, 'GREEN', 'No obvious risks detected.'));
    }
  }
  return results;
}

// ── Main engine ───────────────────────────────────────────────────────────────

/// Analyses a [plan] against the patient [profile] and returns a list of
/// [RiskAlert]s ordered by severity (critical first).
List<RiskAlert> analyzeplan(PrescriptionPlan plan, Profile profile) {
  final alerts = <RiskAlert>[];
  final meds = plan.medications;
  final names = meds.map((m) => m.name.toLowerCase().trim()).toList();

  // ── 1. Profile-condition checks ──────────────────────────────────────────
  for (final med in meds) {
    final n = med.name.toLowerCase();

    // Renal disease
    if (profile.renalDisease) {
      if (_matchesAny(n, ['ibuprofen', 'naproxen', 'diclofenac', 'meloxicam',
                           'celecoxib', 'indomethacin', 'ketoprofen'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.critical,
          category: 'Condition',
          title: 'NSAID contraindicated — Renal disease',
          detail: '${med.name} can worsen renal function and cause acute kidney injury in patients with existing renal disease.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['metformin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Metformin — Renal caution',
          detail: 'Metformin is contraindicated in significant renal impairment (eGFR <30) due to lactic acidosis risk. Review renal function.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['lithium'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Lithium — Renal caution',
          detail: 'Lithium is renally cleared; impaired renal function greatly increases toxicity risk. Monitor levels closely.',
          involvedDrugs: [med.name],
        ));
      }
    }

    // Hepatic disease
    if (profile.hepaticDisease) {
      if (_matchesAny(n, ['paracetamol', 'acetaminophen'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Paracetamol — Hepatic caution',
          detail: 'Paracetamol is hepatotoxic at high doses. Reduce maximum daily dose in hepatic impairment (max 2 g/day).',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['statins', 'atorvastatin', 'simvastatin',
                           'rosuvastatin', 'lovastatin', 'pravastatin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Statin — Hepatic caution',
          detail: '${med.name} may worsen hepatic dysfunction. Statins are generally contraindicated in active liver disease.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['warfarin', 'acenocoumarol'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Anticoagulant — Hepatic caution',
          detail: 'Hepatic disease reduces clotting factor production, amplifying anticoagulant effect. Monitor INR closely.',
          involvedDrugs: [med.name],
        ));
      }
    }

    // Diabetes
    if (profile.diabetes) {
      if (_matchesAny(n, ['prednisolone', 'prednisone', 'dexamethasone',
                           'betamethasone', 'methylprednisolone', 'cortisone',
                           'hydrocortisone'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Corticosteroid — Hyperglycaemia risk',
          detail: '${med.name} raises blood glucose. Diabetic patients require closer glucose monitoring and possible insulin adjustment.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['thiazide', 'hydrochlorothiazide', 'bendroflumethiazide'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.moderate,
          category: 'Condition',
          title: 'Thiazide diuretic — Glucose elevation',
          detail: 'Thiazides can impair insulin secretion and increase blood glucose. Monitor glycaemic control.',
          involvedDrugs: [med.name],
        ));
      }
    }

    // Hypertension
    if (profile.hypertension) {
      if (_matchesAny(n, ['ibuprofen', 'naproxen', 'diclofenac', 'meloxicam',
                           'celecoxib', 'indomethacin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'NSAID — Blood pressure warning',
          detail: 'NSAIDs cause sodium retention and can raise blood pressure, reducing the effect of antihypertensive therapy.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['pseudoephedrine', 'phenylephrine', 'oxymetazoline'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Condition',
          title: 'Decongestant — Hypertension risk',
          detail: '${med.name} is a sympathomimetic that raises blood pressure. Avoid in uncontrolled hypertension.',
          involvedDrugs: [med.name],
        ));
      }
    }
  }

  // ── 2. Pregnancy checks ──────────────────────────────────────────────────
  if (profile.sex == BiologicalSex.female && profile.isPregnant) {
    for (final med in meds) {
      final n = med.name.toLowerCase();
      if (_matchesAny(n, ['warfarin', 'acenocoumarol'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.critical,
          category: 'Pregnancy',
          title: 'Warfarin — Contraindicated in pregnancy',
          detail: 'Warfarin crosses the placenta and causes embryopathy. Use LMWH instead.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['isotretinoin', 'acitretin', 'thalidomide',
                           'methotrexate', 'misoprostol', 'finasteride'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.critical,
          category: 'Pregnancy',
          title: '${med.name} — Absolutely contraindicated in pregnancy',
          detail: 'This medication is teratogenic / fetotoxic. Discontinue immediately and consult a specialist.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['ibuprofen', 'naproxen', 'diclofenac', 'aspirin',
                           'indomethacin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Pregnancy',
          title: 'NSAID — Avoid in 3rd trimester',
          detail: '${med.name} can cause premature closure of the ductus arteriosus and oligohydramnios after 28 weeks.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['tetracycline', 'doxycycline', 'minocycline'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Pregnancy',
          title: 'Tetracycline — Avoid in pregnancy',
          detail: 'Tetracyclines deposit in fetal bone and teeth causing discolouration and growth inhibition.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['ssri', 'fluoxetine', 'sertraline', 'paroxetine',
                           'citalopram', 'escitalopram'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.moderate,
          category: 'Pregnancy',
          title: 'SSRI — Monitor in pregnancy',
          detail: 'SSRIs in late pregnancy may cause neonatal adaptation syndrome. Balance risk of untreated depression.',
          involvedDrugs: [med.name],
        ));
      }
    }
  }

  // ── 3. Age checks ────────────────────────────────────────────────────────
  if (profile.age < 18) {
    for (final med in meds) {
      final n = med.name.toLowerCase();
      if (_matchesAny(n, ['aspirin', 'acetylsalicylic'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.critical,
          category: 'Age',
          title: 'Aspirin — Contraindicated under 16',
          detail: 'Aspirin in children with viral illness is associated with Reye\'s syndrome (severe liver and brain damage).',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['fluoroquinolone', 'ciprofloxacin', 'levofloxacin',
                           'moxifloxacin', 'ofloxacin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Age',
          title: 'Fluoroquinolone — Avoid in children',
          detail: '${med.name} can damage developing cartilage. Use alternative antibiotics in paediatric patients.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['tetracycline', 'doxycycline', 'minocycline'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Age',
          title: 'Tetracycline — Avoid under 8',
          detail: 'Tetracyclines cause permanent tooth discolouration and bone growth inhibition in children under 8.',
          involvedDrugs: [med.name],
        ));
      }
    }
  }

  if (profile.age >= 65) {
    for (final med in meds) {
      final n = med.name.toLowerCase();
      if (_matchesAny(n, ['benzodiazepine', 'diazepam', 'lorazepam',
                           'alprazolam', 'clonazepam', 'temazepam',
                           'nitrazepam', 'zolpidem', 'zopiclone'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Age',
          title: 'Sedative — Fall and confusion risk (elderly)',
          detail: '${med.name} significantly increases fall, fracture, and cognitive impairment risk in patients ≥65. Use lowest dose for shortest duration.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['amitriptyline', 'nortriptyline', 'imipramine',
                           'clomipramine', 'doxepin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Age',
          title: 'TCA — Beers criteria warning (elderly)',
          detail: '${med.name} has strong anticholinergic effects. Associated with confusion, urinary retention, and orthostatic hypotension in elderly.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(n, ['digoxin'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.moderate,
          category: 'Age',
          title: 'Digoxin — Narrow therapeutic window in elderly',
          detail: 'Reduced renal clearance in elderly raises digoxin levels. Target serum level 0.5–0.9 ng/mL; monitor closely.',
          involvedDrugs: [med.name],
        ));
      }
    }
  }

  // ── 4. Allergy checks ────────────────────────────────────────────────────
  for (final allergy in profile.allergies) {
    final a = allergy.toLowerCase().trim();
    for (final med in meds) {
      final n = med.name.toLowerCase();
      // Direct name match
      if (n.contains(a) || a.contains(n)) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.critical,
          category: 'Allergy',
          title: 'Allergy — ${med.name}',
          detail: 'Patient has a recorded allergy to "$allergy". This medication may trigger an allergic reaction.',
          involvedDrugs: [med.name],
        ));
        continue;
      }
      // Cross-reactivity groups
      if (_matchesAny(a, ['penicillin', 'amoxicillin', 'ampicillin']) &&
          _matchesAny(n, ['penicillin', 'amoxicillin', 'ampicillin',
                           'flucloxacillin', 'piperacillin', 'cephalexin',
                           'cefuroxime', 'ceftriaxone'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Allergy',
          title: 'Possible cross-reactivity — Penicillin allergy',
          detail: '${med.name} is a beta-lactam. ~2% cross-reactivity in penicillin-allergic patients. Confirm allergy history before use.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(a, ['sulfa', 'sulfonamide', 'sulfamethoxazole']) &&
          _matchesAny(n, ['trimethoprim', 'sulfamethoxazole', 'co-trimoxazole',
                           'furosemide', 'hydrochlorothiazide', 'celecoxib'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.moderate,
          category: 'Allergy',
          title: 'Possible cross-reactivity — Sulfa allergy',
          detail: '${med.name} contains a sulfonamide moiety. May cross-react in sulfa-allergic patients.',
          involvedDrugs: [med.name],
        ));
      }
      if (_matchesAny(a, ['nsaid', 'ibuprofen', 'aspirin', 'naproxen',
                           'diclofenac']) &&
          _matchesAny(n, ['ibuprofen', 'naproxen', 'diclofenac', 'meloxicam',
                           'celecoxib', 'aspirin', 'indomethacin', 'ketoprofen'])) {
        alerts.add(RiskAlert(
          severity: RiskSeverity.high,
          category: 'Allergy',
          title: 'NSAID allergy — Cross-reactivity',
          detail: 'Patient has NSAID allergy. ${med.name} may trigger the same reaction (aspirin-exacerbated respiratory disease or urticaria).',
          involvedDrugs: [med.name],
        ));
      }
    }
  }

  // ── 5. Drug-drug interactions ────────────────────────────────────────────
  final interactions = <_Interaction>[
    _Interaction(
      a: ['warfarin', 'acenocoumarol'],
      b: ['aspirin', 'ibuprofen', 'naproxen', 'diclofenac', 'meloxicam'],
      severity: RiskSeverity.critical,
      title: 'Anticoagulant + NSAID — Bleeding risk',
      detail: 'Combining anticoagulants with NSAIDs dramatically increases the risk of serious bleeding (GI, intracranial).',
    ),
    _Interaction(
      a: ['warfarin', 'acenocoumarol'],
      b: ['aspirin'],
      severity: RiskSeverity.critical,
      title: 'Warfarin + Aspirin — Severe bleeding risk',
      detail: 'Aspirin inhibits platelet function and potentiates warfarin anticoagulation. Avoid unless specifically indicated (e.g. mechanical heart valve).',
    ),
    _Interaction(
      a: ['ssri', 'fluoxetine', 'sertraline', 'paroxetine', 'citalopram',
          'escitalopram', 'venlafaxine', 'duloxetine'],
      b: ['tramadol'],
      severity: RiskSeverity.critical,
      title: 'Serotonin syndrome risk',
      detail: 'SSRI/SNRI + Tramadol combination markedly increases serotonin syndrome risk (agitation, hyperthermia, clonus, autonomic instability).',
    ),
    _Interaction(
      a: ['maoi', 'phenelzine', 'tranylcypromine', 'selegiline', 'moclobemide'],
      b: ['ssri', 'snri', 'fluoxetine', 'sertraline', 'paroxetine', 'citalopram',
          'venlafaxine', 'duloxetine', 'tramadol', 'pethidine', 'meperidine'],
      severity: RiskSeverity.critical,
      title: 'MAOI + Serotonergic drug — Potentially fatal',
      detail: 'This combination can cause fatal serotonin syndrome. Wait ≥14 days after stopping an MAOI before starting serotonergic drugs.',
    ),
    _Interaction(
      a: ['metformin'],
      b: ['alcohol', 'ethanol'],
      severity: RiskSeverity.high,
      title: 'Metformin + Alcohol — Lactic acidosis',
      detail: 'Heavy alcohol use with metformin increases lactic acidosis risk. Advise minimal alcohol intake.',
    ),
    _Interaction(
      a: ['ace inhibitor', 'enalapril', 'lisinopril', 'ramipril', 'perindopril',
          'captopril'],
      b: ['potassium', 'spironolactone', 'eplerenone', 'amiloride',
          'trimethoprim'],
      severity: RiskSeverity.high,
      title: 'ACE inhibitor + Potassium-sparing — Hyperkalaemia',
      detail: 'This combination risks dangerous hyperkalaemia. Monitor serum potassium regularly.',
    ),
    _Interaction(
      a: ['methotrexate'],
      b: ['nsaid', 'ibuprofen', 'naproxen', 'diclofenac', 'aspirin'],
      severity: RiskSeverity.critical,
      title: 'Methotrexate + NSAID — Toxicity',
      detail: 'NSAIDs reduce renal clearance of methotrexate, increasing risk of methotrexate toxicity (bone marrow suppression, mucositis).',
    ),
    _Interaction(
      a: ['statin', 'atorvastatin', 'simvastatin', 'lovastatin'],
      b: ['clarithromycin', 'erythromycin', 'fluconazole', 'itraconazole',
          'ketoconazole'],
      severity: RiskSeverity.high,
      title: 'Statin + CYP3A4 inhibitor — Myopathy risk',
      detail: 'CYP3A4 inhibitors markedly increase statin plasma levels, raising the risk of myopathy and rhabdomyolysis. Use lowest statin dose or switch to pravastatin.',
    ),
    _Interaction(
      a: ['digoxin'],
      b: ['amiodarone', 'verapamil', 'diltiazem', 'clarithromycin',
          'erythromycin', 'quinine'],
      severity: RiskSeverity.high,
      title: 'Digoxin level raised — Toxicity risk',
      detail: 'These drugs reduce digoxin clearance, increasing plasma levels. Monitor digoxin levels and signs of toxicity (nausea, visual disturbance, arrhythmias).',
    ),
    _Interaction(
      a: ['lithium'],
      b: ['ibuprofen', 'naproxen', 'diclofenac', 'celecoxib',
          'hydrochlorothiazide', 'furosemide', 'enalapril', 'lisinopril',
          'ramipril'],
      severity: RiskSeverity.high,
      title: 'Lithium level raised — Toxicity risk',
      detail: 'NSAIDs, diuretics, and ACE inhibitors reduce lithium excretion. Monitor lithium levels closely — toxicity is life-threatening.',
    ),
    _Interaction(
      a: ['sildenafil', 'tadalafil', 'vardenafil'],
      b: ['nitrate', 'isosorbide', 'glyceryl trinitrate', 'nitroglycerin',
          'nicorandil'],
      severity: RiskSeverity.critical,
      title: 'PDE5 inhibitor + Nitrate — Severe hypotension',
      detail: 'This combination causes potentially fatal hypotension. Absolutely contraindicated.',
    ),
    _Interaction(
      a: ['clopidogrel', 'ticagrelor', 'prasugrel'],
      b: ['omeprazole', 'esomeprazole'],
      severity: RiskSeverity.moderate,
      title: 'Clopidogrel + PPI — Reduced antiplatelet effect',
      detail: 'Omeprazole inhibits CYP2C19, reducing clopidogrel activation. Consider pantoprazole as an alternative PPI.',
    ),
    _Interaction(
      a: ['ssri', 'fluoxetine', 'sertraline', 'paroxetine', 'citalopram',
          'escitalopram'],
      b: ['aspirin', 'warfarin', 'clopidogrel'],
      severity: RiskSeverity.moderate,
      title: 'SSRI + Antiplatelet/Anticoagulant — Bleeding risk',
      detail: 'SSRIs inhibit platelet serotonin uptake. Combined with antiplatelet or anticoagulant drugs, bleeding risk (especially GI) is increased.',
    ),
  ];

  for (final rule in interactions) {
    String? drugA;
    String? drugB;
    for (final name in names) {
      if (_matchesAny(name, rule.a)) { drugA ??= meds[names.indexOf(name)].name; }
      if (_matchesAny(name, rule.b)) { drugB ??= meds[names.indexOf(name)].name; }
    }
    if (drugA != null && drugB != null && drugA != drugB) {
      alerts.add(RiskAlert(
        severity: rule.severity,
        category: 'Interaction',
        title: rule.title,
        detail: rule.detail,
        involvedDrugs: [drugA, drugB],
      ));
    }
  }

  // ── Sort: critical → high → moderate → info ──────────────────────────────
  alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));

  // Deduplicate by title
  final seen = <String>{};
  return alerts.where((a) => seen.add(a.title)).toList();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _matchesAny(String name, List<String> keywords) =>
    keywords.any((k) => name.contains(k.toLowerCase()));

class _Interaction {
  final List<String> a;
  final List<String> b;
  final RiskSeverity severity;
  final String title;
  final String detail;

  const _Interaction({
    required this.a,
    required this.b,
    required this.severity,
    required this.title,
    required this.detail,
  });
}
