class DrugRegist {
  final int id;            // ID interno da bd sqlite
  final int nRegisto;      // Chave vinda do Infarmed
  final String dci;            // Ex: Ácido Acetilsalicílico
  final String medName;      // Ex: Tromalyt
  final String form;           // Ex: Cápsula de libertação modificada
  final String dosage;         // Ex: 150mg
  final String boxsize;       // Ex: 28 cápsulas
  final int cnpem;          // Código Nacional de Produtos Medicinais (CNPem)
  
  // Campo de preço
  String? pricePVP;
  String? pricePVPnotified;
  String? priceUtente;
  String? pricePensionista;

  String commercialized;
  bool isGeneric;

  String infoUrl;         // URL para a página de detalhes do medicamento no Infarmed (para referência)
  
  DrugRegist({
    required this.id,
    required this.nRegisto,
    required this.medName,
    required this.dci,
    required this.dosage,
    required this.form,
    required this.boxsize,
    required this.cnpem,
    this.pricePVP,
    this.pricePVPnotified,
    this.priceUtente,
    this.pricePensionista,
    required this.commercialized,
    required this.isGeneric,
    required this.infoUrl,
  });

  @override
  String toString() =>
      'Medication{id: $id, nome: $medName, substancia: $dci}';
}