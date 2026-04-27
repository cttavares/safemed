class MedicationHistory {
  final String id;
  final String profileId;
  final String? planId;
  final String? planName;
  final String medicationName;
  final String dose;
  final DateTime startDate;
  final DateTime? endDate;
  final String reasonForTaking;
  final String? reasonForStopping;
  final int? effectivenessRating; // 1-5 scale
  final String notes;

  const MedicationHistory({
    required this.id,
    required this.profileId,
    this.planId,
    this.planName,
    required this.medicationName,
    required this.dose,
    required this.startDate,
    this.endDate,
    required this.reasonForTaking,
    this.reasonForStopping,
    this.effectivenessRating,
    this.notes = '',
  });

  bool get isActive => endDate == null;

  MedicationHistory copyWith({
    String? planId,
    String? planName,
    String? medicationName,
    String? dose,
    DateTime? startDate,
    DateTime? endDate,
    String? reasonForTaking,
    String? reasonForStopping,
    int? effectivenessRating,
    String? notes,
  }) {
    return MedicationHistory(
      id: id,
      profileId: profileId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      medicationName: medicationName ?? this.medicationName,
      dose: dose ?? this.dose,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reasonForTaking: reasonForTaking ?? this.reasonForTaking,
      reasonForStopping: reasonForStopping ?? this.reasonForStopping,
      effectivenessRating: effectivenessRating ?? this.effectivenessRating,
      notes: notes ?? this.notes,
    );
  }

  factory MedicationHistory.fromJson(Map<String, dynamic> json) {
    return MedicationHistory(
      id: json['id']?.toString() ?? '',
      profileId: json['profileId']?.toString() ?? '',
      planId: json['planId']?.toString(),
      planName: json['planName']?.toString(),
      medicationName: json['medicationName']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      reasonForTaking: json['reasonForTaking']?.toString() ?? '',
      reasonForStopping: json['reasonForStopping']?.toString(),
      effectivenessRating: json['effectivenessRating'] as int?,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'planId': planId,
      'planName': planName,
      'medicationName': medicationName,
      'dose': dose,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'reasonForTaking': reasonForTaking,
      'reasonForStopping': reasonForStopping,
      'effectivenessRating': effectivenessRating,
      'notes': notes,
    };
  }
}
