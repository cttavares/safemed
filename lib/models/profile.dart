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

class Profile {
  final String id;
  final String name;
  final int age;
  final String? photoPath;
  final bool renalDisease;
  final bool hepaticDisease;
  final bool diabetes;
  final bool hypertension;
  final String healthIssues;
  final List<String> allergies;
  final List<String> medicalRestrictions;
  final ProfileType category;

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    this.photoPath,
    this.renalDisease = false,
    this.hepaticDisease = false,
    this.diabetes = false,
    this.hypertension = false,
    required this.healthIssues,
    this.allergies = const [],
    this.medicalRestrictions = const [],
    ProfileType? category,
  }) : category = category ?? ProfileType.adult;

  Profile copyWith({
    String? name,
    int? age,
    String? photoPath,
    bool? renalDisease,
    bool? hepaticDisease,
    bool? diabetes,
    bool? hypertension,
    String? healthIssues,
    List<String>? allergies,
    List<String>? medicalRestrictions,
    ProfileType? category,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      photoPath: photoPath ?? this.photoPath,
      renalDisease: renalDisease ?? this.renalDisease,
      hepaticDisease: hepaticDisease ?? this.hepaticDisease,
      diabetes: diabetes ?? this.diabetes,
      hypertension: hypertension ?? this.hypertension,
      healthIssues: healthIssues ?? this.healthIssues,
      allergies: allergies ?? this.allergies,
      medicalRestrictions: medicalRestrictions ?? this.medicalRestrictions,
      category: category ?? this.category,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      photoPath: json['photoPath'] as String?,
      renalDisease: json['renalDisease'] as bool? ?? false,
      hepaticDisease: json['hepaticDisease'] as bool? ?? false,
      diabetes: json['diabetes'] as bool? ?? false,
      hypertension: json['hypertension'] as bool? ?? false,
      healthIssues: json['healthIssues']?.toString() ?? '',
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      medicalRestrictions: (json['medicalRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] != null
          ? ProfileType.fromString(json['category'].toString())
          : ProfileType.fromAge((json['age'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'photoPath': photoPath,
      'renalDisease': renalDisease,
      'hepaticDisease': hepaticDisease,
      'diabetes': diabetes,
      'hypertension': hypertension,
      'healthIssues': healthIssues,
      'allergies': allergies,
      'medicalRestrictions': medicalRestrictions,
      'category': category.name,
    };
  }
}
