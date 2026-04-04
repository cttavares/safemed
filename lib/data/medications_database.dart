import 'package:safemed/models/medication.dart';

/// Base de dados de medicamentos para Portugal
/// Contém exemplos de medicamentos comuns com todos os atributos necessários
/// para análise de riscos, interações e contra-indicações

/// IDs de patologias/contra-indicações
class PathologyIds {
  // Cardiovascular
  static const String hipertensao = 'hipertensao';
  static const String arritmia = 'arritmia';
  static const String insuficienciaCardiaca = 'insuficiencia_cardiaca';
  static const String trombose = 'trombose';

  // Renal e Hepática
  static const String insuficienciaRenal = 'insuficiencia_renal';
  static const String insuficienciaHepatica = 'insuficiencia_hepatica';

  // Gastrointestinal
  static const String ulceraGastrica = 'ulcera_gastrica';
  static const String doencaCrohn = 'doenca_crohn';

  // Respiratória
  static const String asma = 'asma';
  static const String dopc = 'dopc'; // Doença Obstrutiva Pulmonar Crónica

  // Alergia
  static const String alergia = 'alergia_nsaid';

  // Endócrina
  static const String diabetes = 'diabetes';

  // Hematológica
  static const String anemia = 'anemia';
}

/// IDs de substâncias ativas (para cruzamento de interações)
class SubstanceIds {
  static const String paracetamol = 'paracetamol';
  static const String ibuprofeno = 'ibuprofeno';
  static const String acido_acetilsalicilico = 'acido_acetilsalicilico';
  static const String diclofenaco = 'diclofenaco';
  static const String metformina = 'metformina';
  static const String lisinopril = 'lisinopril';
  static const String amoxicilina = 'amoxicilina';
  static const String omeprazol = 'omeprazol';
  static const String isotretinoina = 'isotretinoina';
  static const String talidomida = 'talidomida';
  static const String sulfametoxazol = 'sulfametoxazol';
  static const String prednisolona = 'prednisolona';
  static const String pseudoefedrina = 'pseudoefedrina';
  static const String atorvastatina = 'atorvastatina';
  static const String varfarina = 'varfarina';
  static const String sertralina = 'sertralina';
  static const String diazepam = 'diazepam';
  static const String levotiroxina = 'levotiroxina';
  static const String furosemida = 'furosemida';
  static const String amlodipina = 'amlodipina';
  static const String azitromicina = 'azitromicina';
}

/// Medicamentos comuns em Portugal
const List<Medication> medicamentosBaseDados = [
  // ==================== ANALGÉSICOS / ANTI-INFLAMATÓRIOS ====================
  Medication(
    id: 'med_001',
    cnp: '5601151', // Ben-u-ron comprimidos
    nomeComercial: 'Ben-u-ron',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Paracetamol',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 3,
    sujeitoReceitaMedica: false,
    contraindicacoes: [PathologyIds.insuficienciaHepatica],
    efeitosSecundariosComuns: ['Raramente hepatotoxicidade em sobredose'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_002',
    cnp: '5601151',
    nomeComercial: 'Panadol',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Paracetamol',
    dosagem: '1000 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 6,
    sujeitoReceitaMedica: false,
    contraindicacoes: [PathologyIds.insuficienciaHepatica],
    efeitosSecundariosComuns: [
      'Dor de cabeça',
      'Hepatotoxicidade em sobredose',
    ],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_003',
    cnp: '5600971',
    nomeComercial: 'Brufen',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Ibuprofeno',
    dosagem: '400 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 12,
    sujeitoReceitaMedica: false,
    contraindicacoes: [
      PathologyIds.ulceraGastrica,
      PathologyIds.insuficienciaRenal,
      PathologyIds.asma,
    ],
    efeitosSecundariosComuns: ['Gastrite', 'Dor abdominal', 'Tonturas'],
    interacoesComSubstancias: [SubstanceIds.acido_acetilsalicilico],
  ),

  Medication(
    id: 'med_004',
    cnp: '5600970',
    nomeComercial: 'Nurofen',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Ibuprofeno',
    dosagem: '600 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 12,
    sujeitoReceitaMedica: false,
    contraindicacoes: [
      PathologyIds.ulceraGastrica,
      PathologyIds.insuficienciaRenal,
      PathologyIds.asma,
    ],
    efeitosSecundariosComuns: [
      'Gastrite',
      'Dor abdominal',
      'Tonturas',
      'Reações alérgicas',
    ],
    interacoesComSubstancias: [SubstanceIds.acido_acetilsalicilico],
  ),

  Medication(
    id: 'med_005',
    cnp: '5600868',
    nomeComercial: 'Aspirina',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Ácido Acetilsalicílico',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.D, // Especialmente no 3º trimestre
    idadeMinima: 12,
    sujeitoReceitaMedica: false,
    contraindicacoes: [
      PathologyIds.ulceraGastrica,
      PathologyIds.asma,
      PathologyIds.alergia,
    ],
    efeitosSecundariosComuns: [
      'Hemorragia gastrointestinal',
      'Problemas de coagulação',
    ],
    interacoesComSubstancias: [SubstanceIds.ibuprofeno],
  ),

  Medication(
    id: 'med_006',
    cnp: '5440702',
    nomeComercial: 'Voltaren',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Diclofenaco',
    dosagem: '50 mg',
    riscoGravidez: PregnancyRiskCategory.D,
    idadeMinima: 14,
    sujeitoReceitaMedica: true,
    contraindicacoes: [
      PathologyIds.ulceraGastrica,
      PathologyIds.insuficienciaRenal,
      PathologyIds.insuficienciaCardiaca,
    ],
    efeitosSecundariosComuns: [
      'Gastrite',
      'Retenção de líquidos',
      'Reações cutâneas',
    ],
    interacoesComSubstancias: [SubstanceIds.ibuprofeno],
  ),

  // ==================== ANTIBIÓTICOS ====================
  Medication(
    id: 'med_007',
    cnp: '5601049',
    nomeComercial: 'Amoxicilina',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Amoxicilina',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: null,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.alergia], // Alergia a penicilinas
    efeitosSecundariosComuns: [
      'Diarreia',
      'Náuseas',
      'Reações alérgicas',
      'Aftas',
    ],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_008',
    cnp: '5601050',
    nomeComercial: 'Amoxicilina Clavulânico',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Amoxicilina + Ácido Clavulânico',
    dosagem: '500 mg + 125 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [
      PathologyIds.alergia,
      PathologyIds.insuficienciaHepatica,
    ],
    efeitosSecundariosComuns: ['Diarreia', 'Náuseas', 'Reações alérgicas'],
    interacoesComSubstancias: [],
  ),

  // ==================== DIABETES ====================
  Medication(
    id: 'med_009',
    cnp: '5440123',
    nomeComercial: 'Metformina',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Metformina',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 10,
    sujeitoReceitaMedica: true,
    contraindicacoes: [
      PathologyIds.insuficienciaRenal,
      PathologyIds.insuficienciaHepatica,
    ],
    efeitosSecundariosComuns: [
      'Dor abdominal',
      'Diarreia',
      'Sabor metálico',
      'Acidose láctica (raro)',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== ANTI-HIPERTENSIVOS ====================
  Medication(
    id: 'med_010',
    cnp: '5440456',
    nomeComercial: 'Zestril',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Lisinopril',
    dosagem: '10 mg',
    riscoGravidez:
        PregnancyRiskCategory.D, // Risco fetal, especialmente 2º e 3º trimestre
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.insuficienciaRenal, PathologyIds.arritmia],
    efeitosSecundariosComuns: [
      'Tosse seca',
      'Tonturas',
      'Fraqueza',
      'Hipercaliemia',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== ANTI-ÁCIDOS / GASTROINTESTINAIS ====================
  Medication(
    id: 'med_011',
    cnp: '5600750',
    nomeComercial: 'Omeprazol',
    formaFarmaceutica: 'Cápsula',
    substanciaAtiva: 'Omeprazol',
    dosagem: '20 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 18,
    sujeitoReceitaMedica: false,
    contraindicacoes: [PathologyIds.insuficienciaHepatica],
    efeitosSecundariosComuns: [
      'Dor de cabeça',
      'Diarreia',
      'Interferência na absorção de B12',
      'Osteoporose (uso prolongado)',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== ANTIHISTAMÍNICOS ====================
  Medication(
    id: 'med_012',
    cnp: '5600834',
    nomeComercial: 'Tavegil',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Clemastina',
    dosagem: '1 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 12,
    sujeitoReceitaMedica: false,
    contraindicacoes: [],
    efeitosSecundariosComuns: [
      'Sonolência',
      'Boca seca',
      'Tonturas',
      'Tremores (raro)',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== XAROPES / TOSSE E GRIPE ====================
  Medication(
    id: 'med_013',
    cnp: '5600921',
    nomeComercial: 'Strepsils',
    formaFarmaceutica: 'Pastilha',
    substanciaAtiva: 'Amilmetacresol + Diclorobenzil álcool',
    dosagem: 'Variável',
    riscoGravidez: PregnancyRiskCategory.A,
    idadeMinima: 6,
    sujeitoReceitaMedica: false,
    contraindicacoes: [],
    efeitosSecundariosComuns: ['Irritação local', 'Reações alérgicas (raras)'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_014',
    cnp: '5601151',
    nomeComercial: 'Bisolvon',
    formaFarmaceutica: 'Xarope',
    substanciaAtiva: 'Bromexina',
    dosagem: '4 mg/5ml',
    riscoGravidez: PregnancyRiskCategory.A,
    idadeMinima: 4,
    sujeitoReceitaMedica: false,
    contraindicacoes: [],
    efeitosSecundariosComuns: ['Náuseas', 'Dor abdominal (raro)'],
    interacoesComSubstancias: [],
  ),

  // ==================== VITAMINAS E SUPLEMENTOS ====================
  Medication(
    id: 'med_015',
    cnp: '5600515',
    nomeComercial: 'Centrum',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Multivitamínico (A, B, C, D, E, Minerais)',
    dosagem: 'Variável',
    riscoGravidez: PregnancyRiskCategory.A,
    idadeMinima: null,
    sujeitoReceitaMedica: false,
    contraindicacoes: [],
    efeitosSecundariosComuns: [],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_016',
    cnp: '5600516',
    nomeComercial: 'Vitaplus',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Vitamina D3',
    dosagem: '1000 UI',
    riscoGravidez: PregnancyRiskCategory.A,
    idadeMinima: null,
    sujeitoReceitaMedica: false,
    contraindicacoes: [],
    efeitosSecundariosComuns: ['Hipercalcemia (sobredose crónica)'],
    interacoesComSubstancias: [],
  ),

  // ==================== RISCO ELEVADO NA GRAVIDEZ (FDA X) ====================
  Medication(
    id: 'med_017',
    cnp: '5600901',
    nomeComercial: 'Roacutan',
    formaFarmaceutica: 'Cápsula',
    substanciaAtiva: 'Isotretinoína',
    dosagem: '20 mg',
    riscoGravidez: PregnancyRiskCategory.X,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [],
    efeitosSecundariosComuns: [
      'Teratogenicidade',
      'Secura cutânea',
      'Alteração hepática',
    ],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_018',
    cnp: '5600902',
    nomeComercial: 'Talidomida Generis',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Talidomida',
    dosagem: '100 mg',
    riscoGravidez: PregnancyRiskCategory.X,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [],
    efeitosSecundariosComuns: [
      'Teratogenicidade',
      'Neuropatia periférica',
      'Sonolência',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== CASOS PARA TESTE DE ALERGIAS ====================
  Medication(
    id: 'med_019',
    cnp: '5601201',
    nomeComercial: 'Ampicilina Labesfal',
    formaFarmaceutica: 'Cápsula',
    substanciaAtiva: 'Ampicilina',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.alergia],
    efeitosSecundariosComuns: ['Náuseas', 'Diarreia', 'Reação alérgica'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_020',
    cnp: '5601202',
    nomeComercial: 'Bactrim Forte',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Sulfametoxazol + Trimetoprim',
    dosagem: '800 mg + 160 mg',
    riscoGravidez: PregnancyRiskCategory.D,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.alergia],
    efeitosSecundariosComuns: [
      'Erupção cutânea',
      'Náuseas',
      'Fotossensibilidade',
    ],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_021',
    cnp: '5601301',
    nomeComercial: 'Prednisona Teva',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Prednisolona',
    dosagem: '20 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [
      PathologyIds.diabetes,
      PathologyIds.hipertensao,
      PathologyIds.insuficienciaHepatica,
    ],
    efeitosSecundariosComuns: ['Aumento da glicemia', 'Hipertensão', 'Insónia'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_022',
    cnp: '5601302',
    nomeComercial: 'Actifed',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Pseudoefedrina',
    dosagem: '60 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 12,
    sujeitoReceitaMedica: false,
    contraindicacoes: [PathologyIds.hipertensao, PathologyIds.arritmia],
    efeitosSecundariosComuns: [
      'Taquicardia',
      'Insónia',
      'Aumento da pressão arterial',
    ],
    interacoesComSubstancias: [],
  ),

  // ==================== CARDIO / METABÓLICO ====================
  Medication(
    id: 'med_023',
    cnp: '5601401',
    nomeComercial: 'Atoris',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Atorvastatina',
    dosagem: '20 mg',
    riscoGravidez: PregnancyRiskCategory.X,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.insuficienciaHepatica],
    efeitosSecundariosComuns: ['Mialgias', 'Elevação de enzimas hepáticas'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_024',
    cnp: '5601402',
    nomeComercial: 'Varfine',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Varfarina',
    dosagem: '5 mg',
    riscoGravidez: PregnancyRiskCategory.X,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.anemia],
    efeitosSecundariosComuns: ['Risco hemorrágico', 'Hematomas'],
    interacoesComSubstancias: [
      SubstanceIds.acido_acetilsalicilico,
      SubstanceIds.ibuprofeno,
    ],
  ),

  Medication(
    id: 'med_025',
    cnp: '5601403',
    nomeComercial: 'Amlodipina Generis',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Amlodipina',
    dosagem: '5 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.insuficienciaCardiaca],
    efeitosSecundariosComuns: ['Edema periférico', 'Cefaleias', 'Rubor'],
    interacoesComSubstancias: [],
  ),

  Medication(
    id: 'med_026',
    cnp: '5601404',
    nomeComercial: 'Lasix',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Furosemida',
    dosagem: '40 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.insuficienciaRenal],
    efeitosSecundariosComuns: ['Desidratação', 'Hipocaliemia', 'Tonturas'],
    interacoesComSubstancias: [SubstanceIds.lisinopril],
  ),

  // ==================== SNC / PSIQUIATRIA ====================
  Medication(
    id: 'med_027',
    cnp: '5601405',
    nomeComercial: 'Zoloft',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Sertralina',
    dosagem: '50 mg',
    riscoGravidez: PregnancyRiskCategory.C,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [],
    efeitosSecundariosComuns: ['Náuseas', 'Insónia', 'Ansiedade inicial'],
    interacoesComSubstancias: [SubstanceIds.acido_acetilsalicilico],
  ),

  Medication(
    id: 'med_028',
    cnp: '5601406',
    nomeComercial: 'Valium',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Diazepam',
    dosagem: '5 mg',
    riscoGravidez: PregnancyRiskCategory.D,
    idadeMinima: 18,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.dopc],
    efeitosSecundariosComuns: ['Sonolência', 'Confusão', 'Fraqueza muscular'],
    interacoesComSubstancias: [SubstanceIds.talidomida],
  ),

  // ==================== ENDOCRINO ====================
  Medication(
    id: 'med_029',
    cnp: '5601407',
    nomeComercial: 'Eutirox',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Levotiroxina',
    dosagem: '100 mcg',
    riscoGravidez: PregnancyRiskCategory.A,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.arritmia],
    efeitosSecundariosComuns: ['Taquicardia em sobredosagem', 'Nervosismo'],
    interacoesComSubstancias: [],
  ),

  // ==================== ANTIBIÓTICOS EXTRA ====================
  Medication(
    id: 'med_030',
    cnp: '5601408',
    nomeComercial: 'Zitromax',
    formaFarmaceutica: 'Comprimido',
    substanciaAtiva: 'Azitromicina',
    dosagem: '500 mg',
    riscoGravidez: PregnancyRiskCategory.B,
    idadeMinima: 12,
    sujeitoReceitaMedica: true,
    contraindicacoes: [PathologyIds.arritmia],
    efeitosSecundariosComuns: [
      'Náuseas',
      'Diarreia',
      'Prolongamento QT (raro)',
    ],
    interacoesComSubstancias: [SubstanceIds.pseudoefedrina],
  ),
];

/// Função auxiliar para obter um medicamento pelo ID
Medication? getMedicationById(String id) {
  try {
    return medicamentosBaseDados.firstWhere((med) => med.id == id);
  } catch (e) {
    return null;
  }
}

/// Função auxiliar para obter medicamentos pelo nome comercial (parcial)
List<Medication> searchMedicationByName(String query) {
  final lowerQuery = query.toLowerCase();
  return medicamentosBaseDados
      .where(
        (med) =>
            med.nomeComercial.toLowerCase().contains(lowerQuery) ||
            med.substanciaAtiva.toLowerCase().contains(lowerQuery),
      )
      .cast<Medication>()
      .toList();
}

/// Função para obter medicamentos seguros para uma idade específica
List<Medication> getMedicationsSafeForAge(int idade) {
  return medicamentosBaseDados
      .where((med) => med.isSafeForAge(idade))
      .cast<Medication>()
      .toList();
}

/// Função para obter medicamentos com risco na gravidez
List<Medication> getMedicationsRiskyDuringPregnancy() {
  return medicamentosBaseDados
      .where((med) => med.isRiskyDuringPregnancy)
      .cast<Medication>()
      .toList();
}

/// Função para obter medicamentos contraindiacados na gravidez
List<Medication> getMedicationsContraindicatedInPregnancy() {
  return medicamentosBaseDados
      .where((med) => med.isContraindicatedInPregnancy)
      .cast<Medication>()
      .toList();
}

/// Função para verificar interações entre medicamentos
List<String> checkInteractions(List<String> medicationIds) {
  final interactions = <String>{};

  for (int i = 0; i < medicationIds.length; i++) {
    final med1 = getMedicationById(medicationIds[i]);
    if (med1 == null) continue;

    for (int j = i + 1; j < medicationIds.length; j++) {
      final med2 = getMedicationById(medicationIds[j]);
      if (med2 == null) continue;

      // Verifica se têm substâncias que interagem
      if (med1.interacoesComSubstancias.contains(med2.substanciaAtiva) ||
          med2.interacoesComSubstancias.contains(med1.substanciaAtiva)) {
        interactions.add('${med1.nomeComercial} + ${med2.nomeComercial}');
      }
    }
  }

  return interactions.toList();
}
