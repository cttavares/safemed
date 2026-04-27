enum ProfileType {
  adult,
  child,
  elderly;

  String get displayName {
    switch (this) {
      case ProfileType.adult:
        return 'Adult';
      case ProfileType.child:
        return 'Child';
      case ProfileType.elderly:
        return 'Elderly';
    }
  }

  static ProfileType fromAge(int age) {
    if (age < 18) return ProfileType.child;
    if (age >= 65) return ProfileType.elderly;
    return ProfileType.adult;
  }

  static ProfileType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'child':
        return ProfileType.child;
      case 'elderly':
        return ProfileType.elderly;
      default:
        return ProfileType.adult;
    }
  }
}

enum BiologicalSex {
  female,
  male;

  String get displayName {
    switch (this) {
      case BiologicalSex.female:
        return 'Feminino';
      case BiologicalSex.male:
        return 'Masculino';
    }
  }

  static BiologicalSex fromString(String value) {
    switch (value.toLowerCase()) {
      case 'female':
        return BiologicalSex.female;
      default:
        return BiologicalSex.male;
    }
  }
}

class Profile {
  final String id;
  final String name;
  final int age;
  final BiologicalSex sex;
  final bool isPregnant;
  final String? photoPath;
  final bool renalDisease;
  final bool hepaticDisease;
  final bool diabetes;
  final bool hypertension;
  final String healthIssues;
  final List<String> allergies;
  final List<String> medicalRestrictions;
  final ProfileType category;
  final String alarmTone;
  final String? customAlarmUri;

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    this.sex = BiologicalSex.male,
    this.isPregnant = false,
    this.photoPath,
    this.renalDisease = false,
    this.hepaticDisease = false,
    this.diabetes = false,
    this.hypertension = false,
    required this.healthIssues,
    this.allergies = const [],
    this.medicalRestrictions = const [],
    ProfileType? category,
    this.alarmTone = 'default',
    this.customAlarmUri,
  }) : category = category ?? ProfileType.adult;

  Profile copyWith({
    String? name,
    int? age,
    BiologicalSex? sex,
    bool? isPregnant,
    String? photoPath,
    bool? renalDisease,
    bool? hepaticDisease,
    bool? diabetes,
    bool? hypertension,
    String? healthIssues,
    List<String>? allergies,
    List<String>? medicalRestrictions,
    ProfileType? category,
    String? alarmTone,
    String? customAlarmUri,
    bool clearCustomAlarmUri = false,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      isPregnant: isPregnant ?? this.isPregnant,
      photoPath: photoPath ?? this.photoPath,
      renalDisease: renalDisease ?? this.renalDisease,
      hepaticDisease: hepaticDisease ?? this.hepaticDisease,
      diabetes: diabetes ?? this.diabetes,
      hypertension: hypertension ?? this.hypertension,
      healthIssues: healthIssues ?? this.healthIssues,
      allergies: allergies ?? this.allergies,
      medicalRestrictions: medicalRestrictions ?? this.medicalRestrictions,
      category: category ?? this.category,
      alarmTone: alarmTone ?? this.alarmTone,
      customAlarmUri: clearCustomAlarmUri
          ? null
          : (customAlarmUri ?? this.customAlarmUri),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    final parsedSex = json['sex'] != null
        ? BiologicalSex.fromString(json['sex'].toString())
        : BiologicalSex.male;

    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      sex: parsedSex,
      isPregnant: parsedSex == BiologicalSex.female
          ? (json['isPregnant'] as bool? ?? false)
          : false,
      photoPath: json['photoPath'] as String?,
      renalDisease: json['renalDisease'] as bool? ?? false,
      hepaticDisease: json['hepaticDisease'] as bool? ?? false,
      diabetes: json['diabetes'] as bool? ?? false,
      hypertension: json['hypertension'] as bool? ?? false,
      healthIssues: json['healthIssues']?.toString() ?? '',
      allergies:
          (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      medicalRestrictions:
          (json['medicalRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] != null
          ? ProfileType.fromString(json['category'].toString())
          : ProfileType.fromAge((json['age'] as num?)?.toInt() ?? 0),
      alarmTone: json['alarmTone']?.toString() ?? 'default',
      customAlarmUri: json['customAlarmUri']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'sex': sex.name,
      'isPregnant': sex == BiologicalSex.female ? isPregnant : false,
      'photoPath': photoPath,
      'renalDisease': renalDisease,
      'hepaticDisease': hepaticDisease,
      'diabetes': diabetes,
      'hypertension': hypertension,
      'healthIssues': healthIssues,
      'allergies': allergies,
      'medicalRestrictions': medicalRestrictions,
      'category': category.name,
      'alarmTone': alarmTone,
      'customAlarmUri': customAlarmUri,
    };
  }
}
