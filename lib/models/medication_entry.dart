class MedicationEntry {
  final String rawLine;          // original line from OCR
  final String name;             // best guess drug name
  final String? brandName;       // commercial/popular name (optional)
  final double? strengthValue;   // e.g. 500
  final String? strengthUnit;    // mg, g, mcg, ml
  final int? packQuantity;       // e.g. 56 in "x 56"
  final double? dosePerIntake;   // optional (if detected)
  final String? doseUnit;        // tab, comp, ml, etc. (optional)
  final int? timesPerDay;        // e.g. 3 for "3x/day"
  final String? interval;        // e.g. "8/8h"
  final String? intakeNotes;     // e.g. "1 comprimido ao pequeno almoco"
  final String? notes;           // any extra parsing notes

  MedicationEntry({
    required this.rawLine,
    required this.name,
    this.brandName,
    this.strengthValue,
    this.strengthUnit,
    this.packQuantity,
    this.dosePerIntake,
    this.doseUnit,
    this.timesPerDay,
    this.interval,
    this.intakeNotes,
    this.notes,
  });

  String get displayName {
    final brand = brandName?.trim();
    if (brand == null || brand.isEmpty) return name;
    return '$brand [$name]';
  }
}
