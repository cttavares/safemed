class AdverseReactions {
  List<String> frequent;
  List<String> other;

  AdverseReactions({
    this.frequent = const [],
    this.other = const [],
  });
}

class InformativeBill {
  final int id;     
  final String dci; 
  final String medName;    
  final String pdfUrl;
  
  // Webscraping (Folheto PDF)
  final List<String> therapeuticIndications; 

  final List<AdverseReactions> adverseReactions;

  final String? howToStore;
  final String? criticalAdvices; 

  final int? minimumAge; // Idade mínima para uso do medicamento (0 se não houver restrição) 

  final String? pregnancyRisk;
  final String? pregnancyNote;
  final String? breastfeedingRisk;
  final String? breastfeedingNote;

  InformativeBill({
    required this.id,
    required this.dci,
    required this.medName,
    required this.pdfUrl,
    this.therapeuticIndications = const [],
    this.adverseReactions = const [],
    this.howToStore,
    this.criticalAdvices,
    this.minimumAge,
    this.pregnancyRisk,
    this.pregnancyNote,
    this.breastfeedingRisk,
    this.breastfeedingNote,
  });
}