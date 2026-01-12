class MedicationDictionaryEntry {
  final String name;
  final List<String> aliases;

  const MedicationDictionaryEntry({
    required this.name,
    this.aliases = const [],
  });
}

const medicationsPtBr = [
  MedicationDictionaryEntry(
    name: 'acido acetilsalicilico',
    aliases: ['aspirina', 'aas', 'aspirina gr'],
  ),
  MedicationDictionaryEntry(
    name: 'paracetamol',
    aliases: ['acetaminofeno', 'tylenol', 'paracetamol'],
  ),
  MedicationDictionaryEntry(
    name: 'dipirona',
    aliases: ['metamizol', 'novalgina', 'dipirona sodica'],
  ),
  MedicationDictionaryEntry(
    name: 'ibuprofeno',
    aliases: ['advil', 'motrin'],
  ),
  MedicationDictionaryEntry(
    name: 'naproxeno',
    aliases: ['naprosyn'],
  ),
  MedicationDictionaryEntry(
    name: 'diclofenaco',
    aliases: ['voltaren', 'cataflam'],
  ),
  MedicationDictionaryEntry(
    name: 'cetoprofeno',
    aliases: ['profenid'],
  ),
  MedicationDictionaryEntry(
    name: 'nimesulida',
    aliases: ['nimesulida'],
  ),
  MedicationDictionaryEntry(
    name: 'meloxicam',
    aliases: ['movatec'],
  ),
  MedicationDictionaryEntry(
    name: 'piroxicam',
    aliases: ['feldene'],
  ),
  MedicationDictionaryEntry(
    name: 'indometacina',
    aliases: ['indocid'],
  ),
  MedicationDictionaryEntry(
    name: 'celecoxibe',
    aliases: ['celebra'],
  ),
  MedicationDictionaryEntry(
    name: 'etoricoxibe',
    aliases: ['arcoxia'],
  ),
  MedicationDictionaryEntry(
    name: 'tramadol',
    aliases: ['tramal'],
  ),
  MedicationDictionaryEntry(
    name: 'codeina',
    aliases: ['codeina'],
  ),
  MedicationDictionaryEntry(
    name: 'morfina',
    aliases: ['morfina'],
  ),
  MedicationDictionaryEntry(
    name: 'oxicodona',
    aliases: ['oxycontin'],
  ),
  MedicationDictionaryEntry(
    name: 'cetorolaco',
    aliases: ['toradol'],
  ),
  MedicationDictionaryEntry(
    name: 'baclofeno',
    aliases: ['lioresal'],
  ),
  MedicationDictionaryEntry(
    name: 'ciclobenzaprina',
    aliases: ['miosan'],
  ),
  MedicationDictionaryEntry(
    name: 'tiocolchicosido',
    aliases: ['coltrax'],
  ),
  MedicationDictionaryEntry(
    name: 'colchicina',
    aliases: ['colchicina'],
  ),
  MedicationDictionaryEntry(
    name: 'amoxicilina',
    aliases: ['amoxil'],
  ),
  MedicationDictionaryEntry(
    name: 'amoxicilina clavulanato',
    aliases: ['augmentin', 'amoxicilina/clavulanato'],
  ),
  MedicationDictionaryEntry(
    name: 'azitromicina',
    aliases: ['zitromax'],
  ),
  MedicationDictionaryEntry(
    name: 'claritromicina',
    aliases: ['klacid'],
  ),
  MedicationDictionaryEntry(
    name: 'eritromicina',
    aliases: ['eritromicina'],
  ),
  MedicationDictionaryEntry(
    name: 'cefalexina',
    aliases: ['keflex'],
  ),
  MedicationDictionaryEntry(
    name: 'cefadroxila',
    aliases: ['duricef'],
  ),
  MedicationDictionaryEntry(
    name: 'cefuroxima',
    aliases: ['zinat'],
  ),
  MedicationDictionaryEntry(
    name: 'ceftriaxona',
    aliases: ['rocefin'],
  ),
  MedicationDictionaryEntry(
    name: 'cefazolina',
    aliases: ['cefazolina'],
  ),
  MedicationDictionaryEntry(
    name: 'cefixima',
    aliases: ['suprax'],
  ),
  MedicationDictionaryEntry(
    name: 'ciprofloxacino',
    aliases: ['cipro'],
  ),
  MedicationDictionaryEntry(
    name: 'levofloxacino',
    aliases: ['tavanic'],
  ),
  MedicationDictionaryEntry(
    name: 'moxifloxacino',
    aliases: ['avalox'],
  ),
  MedicationDictionaryEntry(
    name: 'norfloxacino',
    aliases: ['norfloxacino'],
  ),
  MedicationDictionaryEntry(
    name: 'ofloxacino',
    aliases: ['oflox'],
  ),
  MedicationDictionaryEntry(
    name: 'metronidazol',
    aliases: ['flagyl'],
  ),
  MedicationDictionaryEntry(
    name: 'clindamicina',
    aliases: ['dalacin'],
  ),
  MedicationDictionaryEntry(
    name: 'doxiciclina',
    aliases: ['vibramicina'],
  ),
  MedicationDictionaryEntry(
    name: 'tetraciclina',
    aliases: ['tetraciclina'],
  ),
  MedicationDictionaryEntry(
    name: 'sulfametoxazol trimetoprim',
    aliases: ['bactrim', 'sulfametoxazol/trimetoprim'],
  ),
  MedicationDictionaryEntry(
    name: 'nitrofurantoina',
    aliases: ['macrodantina'],
  ),
  MedicationDictionaryEntry(
    name: 'penicilina benzatina',
    aliases: ['benzetacil'],
  ),
  MedicationDictionaryEntry(
    name: 'ampicilina',
    aliases: ['ampicilina'],
  ),
  MedicationDictionaryEntry(
    name: 'gentamicina',
    aliases: ['gentamicina'],
  ),
  MedicationDictionaryEntry(
    name: 'vancomicina',
    aliases: ['vancomicina'],
  ),
  MedicationDictionaryEntry(
    name: 'linezolida',
    aliases: ['zyvox'],
  ),
  MedicationDictionaryEntry(
    name: 'rifampicina',
    aliases: ['rifampicina'],
  ),
  MedicationDictionaryEntry(
    name: 'isoniazida',
    aliases: ['isoniazida'],
  ),
  MedicationDictionaryEntry(
    name: 'pirazinamida',
    aliases: ['pirazinamida'],
  ),
  MedicationDictionaryEntry(
    name: 'etambutol',
    aliases: ['etambutol'],
  ),
  MedicationDictionaryEntry(
    name: 'losartana',
    aliases: ['cozaar'],
  ),
  MedicationDictionaryEntry(
    name: 'enalapril',
    aliases: ['renitec'],
  ),
  MedicationDictionaryEntry(
    name: 'captopril',
    aliases: ['capoten'],
  ),
  MedicationDictionaryEntry(
    name: 'lisinopril',
    aliases: ['zestril'],
  ),
  MedicationDictionaryEntry(
    name: 'valsartana',
    aliases: ['diovan'],
  ),
  MedicationDictionaryEntry(
    name: 'telmisartana',
    aliases: ['micardis'],
  ),
  MedicationDictionaryEntry(
    name: 'irbesartana',
    aliases: ['aprosar'],
  ),
  MedicationDictionaryEntry(
    name: 'candesartana',
    aliases: ['atacand'],
  ),
  MedicationDictionaryEntry(
    name: 'amlodipina',
    aliases: ['norvasc', 'anlodipino'],
  ),
  MedicationDictionaryEntry(
    name: 'nifedipina',
    aliases: ['adalat'],
  ),
  MedicationDictionaryEntry(
    name: 'verapamil',
    aliases: ['isoptin'],
  ),
  MedicationDictionaryEntry(
    name: 'diltiazem',
    aliases: ['cardizem'],
  ),
  MedicationDictionaryEntry(
    name: 'hidroclorotiazida',
    aliases: ['hydrodiuril'],
  ),
  MedicationDictionaryEntry(
    name: 'furosemida',
    aliases: ['lasix'],
  ),
  MedicationDictionaryEntry(
    name: 'espironolactona',
    aliases: ['aldactone'],
  ),
  MedicationDictionaryEntry(
    name: 'atenolol',
    aliases: ['atenol'],
  ),
  MedicationDictionaryEntry(
    name: 'metoprolol',
    aliases: ['seloken'],
  ),
  MedicationDictionaryEntry(
    name: 'propranolol',
    aliases: ['inderal'],
  ),
  MedicationDictionaryEntry(
    name: 'carvedilol',
    aliases: ['dilatrend'],
  ),
  MedicationDictionaryEntry(
    name: 'bisoprolol',
    aliases: ['concor'],
  ),
  MedicationDictionaryEntry(
    name: 'digoxina',
    aliases: ['lanoxin'],
  ),
  MedicationDictionaryEntry(
    name: 'amiodarona',
    aliases: ['anacoron'],
  ),
  MedicationDictionaryEntry(
    name: 'sinvastatina',
    aliases: ['zocor'],
  ),
  MedicationDictionaryEntry(
    name: 'atorvastatina',
    aliases: ['lipitor'],
  ),
  MedicationDictionaryEntry(
    name: 'rosuvastatina',
    aliases: ['crestor'],
  ),
  MedicationDictionaryEntry(
    name: 'pravastatina',
    aliases: ['pravastatina'],
  ),
  MedicationDictionaryEntry(
    name: 'ezetimiba',
    aliases: ['ezetrol'],
  ),
  MedicationDictionaryEntry(
    name: 'clopidogrel',
    aliases: ['plavix'],
  ),
  MedicationDictionaryEntry(
    name: 'varfarina',
    aliases: ['marevan'],
  ),
  MedicationDictionaryEntry(
    name: 'rivaroxabana',
    aliases: ['xarelto'],
  ),
  MedicationDictionaryEntry(
    name: 'apixabana',
    aliases: ['eliquis'],
  ),
  MedicationDictionaryEntry(
    name: 'dabigatrana',
    aliases: ['pradaxa'],
  ),
  MedicationDictionaryEntry(
    name: 'metformina',
    aliases: ['glifage'],
  ),
  MedicationDictionaryEntry(
    name: 'glibenclamida',
    aliases: ['daonil'],
  ),
  MedicationDictionaryEntry(
    name: 'gliclazida',
    aliases: ['diamicron'],
  ),
  MedicationDictionaryEntry(
    name: 'glimepirida',
    aliases: ['amaril'],
  ),
  MedicationDictionaryEntry(
    name: 'sitagliptina',
    aliases: ['januvia'],
  ),
  MedicationDictionaryEntry(
    name: 'vildagliptina',
    aliases: ['galvus'],
  ),
  MedicationDictionaryEntry(
    name: 'saxagliptina',
    aliases: ['onglyza'],
  ),
  MedicationDictionaryEntry(
    name: 'linagliptina',
    aliases: ['trajenta'],
  ),
  MedicationDictionaryEntry(
    name: 'empagliflozina',
    aliases: ['jardiance'],
  ),
  MedicationDictionaryEntry(
    name: 'dapagliflozina',
    aliases: ['forxiga'],
  ),
  MedicationDictionaryEntry(
    name: 'canagliflozina',
    aliases: ['invokana'],
  ),
  MedicationDictionaryEntry(
    name: 'liraglutida',
    aliases: ['victoza'],
  ),
  MedicationDictionaryEntry(
    name: 'semaglutida',
    aliases: ['ozempic', 'rybelsus'],
  ),
  MedicationDictionaryEntry(
    name: 'insulina nph',
    aliases: ['insulina isofana', 'nph'],
  ),
  MedicationDictionaryEntry(
    name: 'insulina regular',
    aliases: ['regular'],
  ),
  MedicationDictionaryEntry(
    name: 'insulina glargina',
    aliases: ['lantus'],
  ),
  MedicationDictionaryEntry(
    name: 'insulina detemir',
    aliases: ['levemir'],
  ),
  MedicationDictionaryEntry(
    name: 'levotiroxina',
    aliases: ['puran t4', 'euthyrox'],
  ),
  MedicationDictionaryEntry(
    name: 'metimazol',
    aliases: ['tapazol'],
  ),
  MedicationDictionaryEntry(
    name: 'propiltiouracil',
    aliases: ['ptu'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol',
    aliases: ['losec'],
  ),
  MedicationDictionaryEntry(
    name: 'pantoprazol',
    aliases: ['pantozol'],
  ),
  MedicationDictionaryEntry(
    name: 'esomeprazol',
    aliases: ['nexium'],
  ),
  MedicationDictionaryEntry(
    name: 'lansoprazol',
    aliases: ['lanzoprazol'],
  ),
  MedicationDictionaryEntry(
    name: 'rabeprazol',
    aliases: ['pariet'],
  ),
  MedicationDictionaryEntry(
    name: 'ranitidina',
    aliases: ['ranitidina'],
  ),
  MedicationDictionaryEntry(
    name: 'famotidina',
    aliases: ['pepcid'],
  ),
  MedicationDictionaryEntry(
    name: 'cimetidina',
    aliases: ['tagamet'],
  ),
  MedicationDictionaryEntry(
    name: 'domperidona',
    aliases: ['motilium'],
  ),
  MedicationDictionaryEntry(
    name: 'metoclopramida',
    aliases: ['plasil'],
  ),
  MedicationDictionaryEntry(
    name: 'ondansetrona',
    aliases: ['zofran'],
  ),
  MedicationDictionaryEntry(
    name: 'bromoprida',
    aliases: ['digesan'],
  ),
  MedicationDictionaryEntry(
    name: 'simeticona',
    aliases: ['luftal'],
  ),
  MedicationDictionaryEntry(
    name: 'loperamida',
    aliases: ['imosec'],
  ),
  MedicationDictionaryEntry(
    name: 'lactulose',
    aliases: ['lactulona'],
  ),
  MedicationDictionaryEntry(
    name: 'bisacodil',
    aliases: ['dulcolax'],
  ),
  MedicationDictionaryEntry(
    name: 'senosideos',
    aliases: ['senna'],
  ),
  MedicationDictionaryEntry(
    name: 'macrogol',
    aliases: ['peg', 'movicol'],
  ),
  MedicationDictionaryEntry(
    name: 'mesalazina',
    aliases: ['asacol'],
  ),
  MedicationDictionaryEntry(
    name: 'salbutamol',
    aliases: ['aerolin', 'ventolin'],
  ),
  MedicationDictionaryEntry(
    name: 'formoterol',
    aliases: ['foradil'],
  ),
  MedicationDictionaryEntry(
    name: 'salmeterol',
    aliases: ['serevent'],
  ),
  MedicationDictionaryEntry(
    name: 'budesonida',
    aliases: ['pulmicort'],
  ),
  MedicationDictionaryEntry(
    name: 'beclometasona',
    aliases: ['beclosol'],
  ),
  MedicationDictionaryEntry(
    name: 'fluticasona',
    aliases: ['flixotide', 'flixonase'],
  ),
  MedicationDictionaryEntry(
    name: 'ipratropio',
    aliases: ['atrovent'],
  ),
  MedicationDictionaryEntry(
    name: 'tiotropio',
    aliases: ['spiriva'],
  ),
  MedicationDictionaryEntry(
    name: 'montelucaste',
    aliases: ['singulair'],
  ),
  MedicationDictionaryEntry(
    name: 'prednisona',
    aliases: ['prednisona'],
  ),
  MedicationDictionaryEntry(
    name: 'prednisolona',
    aliases: ['prednisolona'],
  ),
  MedicationDictionaryEntry(
    name: 'dexametasona',
    aliases: ['decadron'],
  ),
  MedicationDictionaryEntry(
    name: 'betametasona',
    aliases: ['betnovate'],
  ),
  MedicationDictionaryEntry(
    name: 'hidrocortisona',
    aliases: ['solucortef'],
  ),
  MedicationDictionaryEntry(
    name: 'sertralina',
    aliases: ['zoloft'],
  ),
  MedicationDictionaryEntry(
    name: 'fluoxetina',
    aliases: ['prozac'],
  ),
  MedicationDictionaryEntry(
    name: 'paroxetina',
    aliases: ['aropax'],
  ),
  MedicationDictionaryEntry(
    name: 'escitalopram',
    aliases: ['lexapro'],
  ),
  MedicationDictionaryEntry(
    name: 'citalopram',
    aliases: ['celexa'],
  ),
  MedicationDictionaryEntry(
    name: 'venlafaxina',
    aliases: ['efexor'],
  ),
  MedicationDictionaryEntry(
    name: 'duloxetina',
    aliases: ['cymbalta'],
  ),
  MedicationDictionaryEntry(
    name: 'amitriptilina',
    aliases: ['tryptanol'],
  ),
  MedicationDictionaryEntry(
    name: 'nortriptilina',
    aliases: ['pamelor'],
  ),
  MedicationDictionaryEntry(
    name: 'imipramina',
    aliases: ['tofranil'],
  ),
  MedicationDictionaryEntry(
    name: 'clomipramina',
    aliases: ['anafranil'],
  ),
  MedicationDictionaryEntry(
    name: 'risperidona',
    aliases: ['risperdal'],
  ),
  MedicationDictionaryEntry(
    name: 'olanzapina',
    aliases: ['zyprexa'],
  ),
  MedicationDictionaryEntry(
    name: 'quetiapina',
    aliases: ['seroquel'],
  ),
  MedicationDictionaryEntry(
    name: 'haloperidol',
    aliases: ['haldol'],
  ),
  MedicationDictionaryEntry(
    name: 'clorpromazina',
    aliases: ['largactil'],
  ),
  MedicationDictionaryEntry(
    name: 'diazepam',
    aliases: ['valium'],
  ),
  MedicationDictionaryEntry(
    name: 'clonazepam',
    aliases: ['rivotril'],
  ),
  MedicationDictionaryEntry(
    name: 'alprazolam',
    aliases: ['frontal'],
  ),
  MedicationDictionaryEntry(
    name: 'lorazepam',
    aliases: ['lorax'],
  ),
  MedicationDictionaryEntry(
    name: 'bromazepam',
    aliases: ['lexotan'],
  ),
  MedicationDictionaryEntry(
    name: 'zolpidem',
    aliases: ['stilnox'],
  ),
  MedicationDictionaryEntry(
    name: 'pregabalina',
    aliases: ['lyrica'],
  ),
  MedicationDictionaryEntry(
    name: 'gabapentina',
    aliases: ['neurontin'],
  ),
  MedicationDictionaryEntry(
    name: 'carbamazepina',
    aliases: ['tegretol'],
  ),
  MedicationDictionaryEntry(
    name: 'valproato',
    aliases: ['depakene', 'depakote'],
  ),
  MedicationDictionaryEntry(
    name: 'fenitoina',
    aliases: ['epamin'],
  ),
  MedicationDictionaryEntry(
    name: 'lamotrigina',
    aliases: ['lamictal'],
  ),
  MedicationDictionaryEntry(
    name: 'levetiracetam',
    aliases: ['keppra'],
  ),
  MedicationDictionaryEntry(
    name: 'topiramato',
    aliases: ['topamax'],
  ),
  MedicationDictionaryEntry(
    name: 'oxcarbazepina',
    aliases: ['trileptal'],
  ),
  MedicationDictionaryEntry(
    name: 'loratadina',
    aliases: ['claritin'],
  ),
  MedicationDictionaryEntry(
    name: 'desloratadina',
    aliases: ['desalex'],
  ),
  MedicationDictionaryEntry(
    name: 'cetirizina',
    aliases: ['zyrtec'],
  ),
  MedicationDictionaryEntry(
    name: 'levocetirizina',
    aliases: ['xuzal'],
  ),
  MedicationDictionaryEntry(
    name: 'fexofenadina',
    aliases: ['allegra'],
  ),
  MedicationDictionaryEntry(
    name: 'hidroxizina',
    aliases: ['hixizine'],
  ),
  MedicationDictionaryEntry(
    name: 'aciclovir',
    aliases: ['zovirax'],
  ),
  MedicationDictionaryEntry(
    name: 'valaciclovir',
    aliases: ['valtrex'],
  ),
  MedicationDictionaryEntry(
    name: 'nistatina',
    aliases: ['nistatina'],
  ),
  MedicationDictionaryEntry(
    name: 'cetoconazol',
    aliases: ['nizoral'],
  ),
  MedicationDictionaryEntry(
    name: 'fluconazol',
    aliases: ['diflucan'],
  ),
  MedicationDictionaryEntry(
    name: 'itraconazol',
    aliases: ['sporanox'],
  ),
  MedicationDictionaryEntry(
    name: 'terbinafina',
    aliases: ['lamisil'],
  ),
  MedicationDictionaryEntry(
    name: 'mupirocina',
    aliases: ['bactroban'],
  ),
  MedicationDictionaryEntry(
    name: 'sulfadiazina de prata',
    aliases: ['dermazine'],
  ),
  MedicationDictionaryEntry(
    name: 'tamsulosina',
    aliases: ['omnic'],
  ),
  MedicationDictionaryEntry(
    name: 'finasterida',
    aliases: ['proscar', 'propecia'],
  ),
  MedicationDictionaryEntry(
    name: 'dutasterida',
    aliases: ['avodart'],
  ),
  MedicationDictionaryEntry(
    name: 'sildenafila',
    aliases: ['viagra'],
  ),
  MedicationDictionaryEntry(
    name: 'tadalafila',
    aliases: ['cialis'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol magnesio',
    aliases: ['omeprazol'],
  ),
  MedicationDictionaryEntry(
    name: 'acetilcisteina',
    aliases: ['fluimucil'],
  ),
  MedicationDictionaryEntry(
    name: 'ambroxol',
    aliases: ['mucosolvan'],
  ),
  MedicationDictionaryEntry(
    name: 'bromexina',
    aliases: ['bisolvon'],
  ),
  MedicationDictionaryEntry(
    name: 'guaifenesina',
    aliases: ['robitussin'],
  ),
  MedicationDictionaryEntry(
    name: 'orfenadrina',
    aliases: ['dorflex'],
  ),
  MedicationDictionaryEntry(
    name: 'cinarizina',
    aliases: ['cinnatrat'],
  ),
  MedicationDictionaryEntry(
    name: 'betahistina',
    aliases: ['labirin'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol sodio',
    aliases: ['omeprazol'],
  ),
  MedicationDictionaryEntry(
    name: 'isossorbida mononitrato',
    aliases: ['monocordil'],
  ),
  MedicationDictionaryEntry(
    name: 'isossorbida dinitrato',
    aliases: ['isordil'],
  ),
  MedicationDictionaryEntry(
    name: 'nitroglicerina',
    aliases: ['tridil'],
  ),
  MedicationDictionaryEntry(
    name: 'clortalidona',
    aliases: ['hygroton'],
  ),
  MedicationDictionaryEntry(
    name: 'atenolol clortalidona',
    aliases: ['tenoretic'],
  ),
  MedicationDictionaryEntry(
    name: 'losartana hidroclorotiazida',
    aliases: ['cozaar h', 'losartana/hidroclorotiazida'],
  ),
  MedicationDictionaryEntry(
    name: 'valsartana hidroclorotiazida',
    aliases: ['diovan hct'],
  ),
  MedicationDictionaryEntry(
    name: 'enalapril hidroclorotiazida',
    aliases: ['enalapril/hidroclorotiazida'],
  ),
  MedicationDictionaryEntry(
    name: 'ramipril',
    aliases: ['tritace'],
  ),
  MedicationDictionaryEntry(
    name: 'perindopril',
    aliases: ['coversyl'],
  ),
  MedicationDictionaryEntry(
    name: 'nebivolol',
    aliases: ['nebilet'],
  ),
  MedicationDictionaryEntry(
    name: 'clonidina',
    aliases: ['catapres'],
  ),
  MedicationDictionaryEntry(
    name: 'metildopa',
    aliases: ['aldomet'],
  ),
  MedicationDictionaryEntry(
    name: 'clopidogrel aspirina',
    aliases: ['duoplavin'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol bicarbonato',
    aliases: ['omeprazol'],
  ),
  MedicationDictionaryEntry(
    name: 'clotrimazol',
    aliases: ['canesten'],
  ),
  MedicationDictionaryEntry(
    name: 'miconazol',
    aliases: ['daktarin'],
  ),
  MedicationDictionaryEntry(
    name: 'metronidazol vaginal',
    aliases: ['metronidazol'],
  ),
  MedicationDictionaryEntry(
    name: 'escopolamina',
    aliases: ['buscopan'],
  ),
  MedicationDictionaryEntry(
    name: 'dimenidrinato',
    aliases: ['dramin'],
  ),
  MedicationDictionaryEntry(
    name: 'piridoxina',
    aliases: ['vitamina b6'],
  ),
  MedicationDictionaryEntry(
    name: 'cianocobalamina',
    aliases: ['vitamina b12'],
  ),
  MedicationDictionaryEntry(
    name: 'colecalciferol',
    aliases: ['vitamina d', 'vitamina d3'],
  ),
  MedicationDictionaryEntry(
    name: 'acido folico',
    aliases: ['folico'],
  ),
  MedicationDictionaryEntry(
    name: 'sulfato ferroso',
    aliases: ['ferronil', 'ferro'],
  ),
  MedicationDictionaryEntry(
    name: 'polivitaminico',
    aliases: ['centrum', 'supradyn'],
  ),
  MedicationDictionaryEntry(
    name: 'alendronato',
    aliases: ['fosamax'],
  ),
  MedicationDictionaryEntry(
    name: 'risedronato',
    aliases: ['actonel'],
  ),
  MedicationDictionaryEntry(
    name: 'calcitonina',
    aliases: ['miacalcic'],
  ),
  MedicationDictionaryEntry(
    name: 'estradiol',
    aliases: ['oestrogel'],
  ),
  MedicationDictionaryEntry(
    name: 'progesterona',
    aliases: ['utrogestan'],
  ),
  MedicationDictionaryEntry(
    name: 'medroxiprogesterona',
    aliases: ['depo provera'],
  ),
  MedicationDictionaryEntry(
    name: 'etinilestradiol levonorgestrel',
    aliases: ['ciclo 21', 'ciclo21'],
  ),
  MedicationDictionaryEntry(
    name: 'etinilestradiol drospirenona',
    aliases: ['yasmin', 'yaz'],
  ),
  MedicationDictionaryEntry(
    name: 'levonorgestrel',
    aliases: ['diad', 'pds', 'pds dia seguinte'],
  ),
  MedicationDictionaryEntry(
    name: 'metronidazol',
    aliases: ['flagyl'],
  ),
  MedicationDictionaryEntry(
    name: 'clotrimazol betametasona',
    aliases: ['candicort'],
  ),
  MedicationDictionaryEntry(
    name: 'azul de metileno',
    aliases: ['azul de metileno'],
  ),
  MedicationDictionaryEntry(
    name: 'cloranfenicol',
    aliases: ['cloranfenicol'],
  ),
  MedicationDictionaryEntry(
    name: 'ciprofibrato',
    aliases: ['lipless'],
  ),
  MedicationDictionaryEntry(
    name: 'fenofibrato',
    aliases: ['lipanon'],
  ),
  MedicationDictionaryEntry(
    name: 'bezafibrato',
    aliases: ['bezafibrato'],
  ),
  MedicationDictionaryEntry(
    name: 'bacitracina',
    aliases: ['nebacetin'],
  ),
  MedicationDictionaryEntry(
    name: 'neomicina',
    aliases: ['nebacetin'],
  ),
  MedicationDictionaryEntry(
    name: 'clorexidina',
    aliases: ['perio aid'],
  ),
  MedicationDictionaryEntry(
    name: 'rifaximina',
    aliases: ['xifaxan'],
  ),
  MedicationDictionaryEntry(
    name: 'montelucaste sodico',
    aliases: ['singulair'],
  ),
  MedicationDictionaryEntry(
    name: 'azitromicina dihidrato',
    aliases: ['zitromax'],
  ),
  MedicationDictionaryEntry(
    name: 'amiodarona cloridrato',
    aliases: ['anacoron'],
  ),
  MedicationDictionaryEntry(
    name: 'escitalopram oxalato',
    aliases: ['lexapro'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol',
    aliases: ['omeprazol', 'losec'],
  ),
  MedicationDictionaryEntry(
    name: 'escopolamina dipirona',
    aliases: ['buscopan composto'],
  ),
  MedicationDictionaryEntry(
    name: 'diosmina hesperidina',
    aliases: ['daflon'],
  ),
  MedicationDictionaryEntry(
    name: 'pentoxifilina',
    aliases: ['trental'],
  ),
  MedicationDictionaryEntry(
    name: 'cilostazol',
    aliases: ['pletal'],
  ),
  MedicationDictionaryEntry(
    name: 'rosuvastatina calcio',
    aliases: ['crestor'],
  ),
  MedicationDictionaryEntry(
    name: 'atorvastatina calcio',
    aliases: ['lipitor'],
  ),
  MedicationDictionaryEntry(
    name: 'sulfato de magnesio',
    aliases: ['magnesio'],
  ),
  MedicationDictionaryEntry(
    name: 'sulfato de zinco',
    aliases: ['zinco'],
  ),
  MedicationDictionaryEntry(
    name: 'cetorolaco trometamol',
    aliases: ['toradol'],
  ),
  MedicationDictionaryEntry(
    name: 'etoricoxibe',
    aliases: ['arcoxia'],
  ),
  MedicationDictionaryEntry(
    name: 'omeprazol',
    aliases: ['omeprazol'],
  ),
];
