class RiskResult {
  final String drug;
  final String level;
  final String message;

  RiskResult(this.drug, this.level, this.message);
}

List<RiskResult> analyzePrescription(
    String text,
    int age,
    bool renal,
    bool hepatic,
    ) {
  final results = <RiskResult>[];

  for (final line in text.split('\n')) {
    final name = line.toLowerCase();

    if (name.contains('ibuprofen') && renal) {
      results.add(RiskResult(
        line,
        'RED',
        'NSAIDs may worsen renal function.',
      ));
    } else if (age >= 65) {
      results.add(RiskResult(
        line,
        'YELLOW',
        'Elderly patients require dose review.',
      ));
    } else {
      results.add(RiskResult(
        line,
        'GREEN',
        'No obvious risks detected.',
      ));
    }
  }

  return results;
}
