class DrugReference {
  final int nRegisto;      // Chave vinda do Infarmed
  final String dci;            // Ex: Ácido Acetilsalicílico
  final String brandName;      // Ex: Tromalyt
  final String form;           // Ex: Cápsula de libertação modificada
  final String dosage;         // Ex: 150mg
  final String boxsize;       // Ex: 28 cápsulas
  final int cnpem;          // Código Nacional de Produtos Medicinais (CNPem)
  
  // Campo de preço
  double? pricePVP;
  double? priceUtente;
  double? pricePensionista;

  // Estes campos virão do segundo passo Webscraping (Folheto PDF)
  String? therapeuticIndications; 
  String? toKnowBeforeTaking;
  String? adverseReactions;
  String? howToStore;
  
  DrugReference({
    required this.nRegisto,
    required this.brandName,
    required this.dci,
    required this.dosage,
    required this.form,
    required this.boxsize,
    required this.cnpem,
  });

}