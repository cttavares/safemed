class PrescriptionPlan {
  final String id;
  final String profileId;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<PlanMedication> medications;

  const PrescriptionPlan({
    required this.id,
    required this.profileId,
    required this.name,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.medications,
  });

  PrescriptionPlan copyWith({
    String? profileId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<PlanMedication>? medications,
  }) {
    return PrescriptionPlan(
      id: id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      medications: medications ?? this.medications,
    );
  }

  factory PrescriptionPlan.fromJson(Map<String, dynamic> json) {
    return PrescriptionPlan(
      id: json['id']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      isActive: json['isActive'] as bool? ?? true,
      medications: (json['medications'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PlanMedication.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'medications': medications.map((m) => m.toJson()).toList(),
    };
  }
}

class PlanMedication {
  final String id;
  final String name;
  final String dose;
  final List<String> times;
  final String notes;

  /// When set, the medication is scheduled by repeating every [intervalHours]
  /// hours starting from [firstDoseAt], instead of using the fixed [times] list.
  final int? intervalHours;
  final DateTime? firstDoseAt;

  const PlanMedication({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    required this.notes,
    this.intervalHours,
    this.firstDoseAt,
  });

  PlanMedication copyWith({
    String? name,
    String? dose,
    List<String>? times,
    String? notes,
    Object? intervalHours = _sentinel,
    Object? firstDoseAt = _sentinel,
  }) {
    return PlanMedication(
      id: id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      times: times ?? this.times,
      notes: notes ?? this.notes,
      intervalHours: intervalHours == _sentinel
          ? this.intervalHours
          : intervalHours as int?,
      firstDoseAt: firstDoseAt == _sentinel
          ? this.firstDoseAt
          : firstDoseAt as DateTime?,
    );
  }

  factory PlanMedication.fromJson(Map<String, dynamic> json) {
    return PlanMedication(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      times: (json['times'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes']?.toString() ?? '',
      intervalHours: json['intervalHours'] as int?,
      firstDoseAt: json['firstDoseAt'] == null
          ? null
          : DateTime.tryParse(json['firstDoseAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'times': times,
      'notes': notes,
      if (intervalHours != null) 'intervalHours': intervalHours,
      if (firstDoseAt != null) 'firstDoseAt': firstDoseAt!.toIso8601String(),
    };
  }
}

// Sentinel object used to distinguish "not provided" from explicit null in copyWith.
const Object _sentinel = Object();
