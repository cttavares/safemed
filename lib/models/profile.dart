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
  });

  Profile copyWith({
    String? name,
    int? age,
    String? photoPath,
    bool? renalDisease,
    bool? hepaticDisease,
    bool? diabetes,
    bool? hypertension,
    String? healthIssues,
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
    };
  }
}
