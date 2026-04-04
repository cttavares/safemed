/// Escala FDA de risco na gravidez
enum PregnancyRiskCategory {
  A, // Sem risco
  B, // Risco remota em estudos animais
  C, // Risco em estudos animais, sem dados em humanos
  D, // Evidência de risco fetal, mas benefício pode justificar
  X, // Totalmente contraindicado na gravidez
}

extension PregnancyRiskCategoryExt on PregnancyRiskCategory {
  String get label {
    switch (this) {
      case PregnancyRiskCategory.A:
        return 'A - Sem risco';
      case PregnancyRiskCategory.B:
        return 'B - Risco remoto';
      case PregnancyRiskCategory.C:
        return 'C - Risco em animais';
      case PregnancyRiskCategory.D:
        return 'D - Evidência de risco';
      case PregnancyRiskCategory.X:
        return 'X - Contraindicado';
    }
  }

  int get severity {
    switch (this) {
      case PregnancyRiskCategory.A:
        return 1;
      case PregnancyRiskCategory.B:
        return 2;
      case PregnancyRiskCategory.C:
        return 3;
      case PregnancyRiskCategory.D:
        return 4;
      case PregnancyRiskCategory.X:
        return 5;
    }
  }
}

class Medication {
  // 1. IDENTIFICAÇÃO BASE
  final String id;
  final String cnp; // Código Nacional do Produto (código de barras)
  final String nomeComercial; // Nome da caixa
  final String
  formaFarmaceutica; // Comprimido, xarope, cápsula, pomada, injeção, etc.

  // 2. COMPOSIÇÃO CLÍNICA
  final String substanciaAtiva; // Molécula que faz o efeito
  final String dosagem; // Quantidade (ex: "500 mg", "1 g")

  // 3. DADOS DE SEGURANÇA E RISCO
  final PregnancyRiskCategory riscoGravidez; // Escala FDA
  final int? idadeMinima; // Idade mínima recomendada (null se sem limite)
  final bool sujeitoReceitaMedica; // Venda livre vs prescrição obrigatória

  // 4. LIGAÇÕES RELACIONAIS (Listas de Risco)
  final List<String>
  contraindicacoes; // IDs de patologias (ex: ["hipertensao", "insuficiencia_renal"])
  final List<String> efeitosSecundariosComuns; // Informação para o utilizador

  // OPCIONAL: Interações com outras substâncias ativas
  final List<String> interacoesComSubstancias; // IDs de substâncias ativas

  const Medication({
    required this.id,
    required this.cnp,
    required this.nomeComercial,
    required this.formaFarmaceutica,
    required this.substanciaAtiva,
    required this.dosagem,
    required this.riscoGravidez,
    this.idadeMinima,
    required this.sujeitoReceitaMedica,
    this.contraindicacoes = const [],
    this.efeitosSecundariosComuns = const [],
    this.interacoesComSubstancias = const [],
  });

  String get displayName => '$nomeComercial ($substanciaAtiva $dosagem)';

  // Verifica se é seguro para uma criança
  bool isSafeForAge(int idade) => idadeMinima == null || idade >= idadeMinima!;

  // Verifica se há risco na gravidez
  bool get isRiskyDuringPregnancy => riscoGravidez.severity >= 3; // C, D ou X

  // Verifica se é totalmente contraindicado na gravidez
  bool get isContraindicatedInPregnancy =>
      riscoGravidez == PregnancyRiskCategory.X;

  // Converte para JSON (útil para persistência)
  Map<String, dynamic> toJson() => {
    'id': id,
    'cnp': cnp,
    'nomeComercial': nomeComercial,
    'formaFarmaceutica': formaFarmaceutica,
    'substanciaAtiva': substanciaAtiva,
    'dosagem': dosagem,
    'riscoGravidez': riscoGravidez.name,
    'idadeMinima': idadeMinima,
    'sujeitoReceitaMedica': sujeitoReceitaMedica,
    'contraindicacoes': contraindicacoes,
    'efeitosSecundariosComuns': efeitosSecundariosComuns,
    'interacoesComSubstancias': interacoesComSubstancias,
  };

  // Cria partir de JSON
  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as String,
    cnp: json['cnp'] as String,
    nomeComercial: json['nomeComercial'] as String,
    formaFarmaceutica: json['formaFarmaceutica'] as String,
    substanciaAtiva: json['substanciaAtiva'] as String,
    dosagem: json['dosagem'] as String,
    riscoGravidez: PregnancyRiskCategory.values.byName(
      json['riscoGravidez'] as String,
    ),
    idadeMinima: json['idadeMinima'] as int?,
    sujeitoReceitaMedica: json['sujeitoReceitaMedica'] as bool,
    contraindicacoes: List<String>.from(
      json['contraindicacoes'] as List? ?? [],
    ),
    efeitosSecundariosComuns: List<String>.from(
      json['efeitosSecundariosComuns'] as List? ?? [],
    ),
    interacoesComSubstancias: List<String>.from(
      json['interacoesComSubstancias'] as List? ?? [],
    ),
  );

  @override
  String toString() =>
      'Medication{id: $id, nome: $nomeComercial, substancia: $substanciaAtiva}';
}
