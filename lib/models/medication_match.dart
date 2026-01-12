class MedicationMatch {
  final String name;
  final List<String> aliases;
  final String reason;
  final String source;

  const MedicationMatch({
    required this.name,
    required this.aliases,
    required this.reason,
    required this.source,
  });
}
