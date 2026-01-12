import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';

class PlanOccurrence {
  final PrescriptionPlan plan;
  final PlanMedication medication;
  final Profile profile;
  final DateTime scheduledAt;

  const PlanOccurrence({
    required this.plan,
    required this.medication,
    required this.profile,
    required this.scheduledAt,
  });

  String get id =>
      '${plan.id}|${medication.id}|${scheduledAt.toIso8601String()}';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isPlanInRange(PrescriptionPlan plan, DateTime day) {
  final dayOnly = dateOnly(day);
  final start = dateOnly(plan.startDate);
  final end = plan.endDate == null ? null : dateOnly(plan.endDate!);
  if (dayOnly.isBefore(start)) {
    return false;
  }
  if (end != null && dayOnly.isAfter(end)) {
    return false;
  }
  return true;
}

bool isPlanActiveNow(PrescriptionPlan plan, DateTime now) {
  if (!plan.isActive) {
    return false;
  }
  return isPlanInRange(plan, now);
}

List<PlanOccurrence> buildOccurrencesForDay({
  required DateTime day,
  required List<PrescriptionPlan> plans,
  required List<Profile> profiles,
}) {
  final profileById = {
    for (final profile in profiles) profile.id: profile,
  };

  final occurrences = <PlanOccurrence>[];
  for (final plan in plans) {
    if (!isPlanActiveNow(plan, day)) {
      continue;
    }
    final profile = profileById[plan.profileId];
    if (profile == null) {
      continue;
    }

    for (final medication in plan.medications) {
      for (final time in medication.times) {
        final parsed = _parseTime(time);
        if (parsed == null) {
          continue;
        }
        final scheduledAt = DateTime(
          day.year,
          day.month,
          day.day,
          parsed.hour,
          parsed.minute,
        );
        occurrences.add(
          PlanOccurrence(
            plan: plan,
            medication: medication,
            profile: profile,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }
  }

  occurrences.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return occurrences;
}

List<PlanOccurrence> buildDueOccurrences({
  required DateTime now,
  required List<PrescriptionPlan> plans,
  required List<Profile> profiles,
  required Set<String> dismissedIds,
}) {
  final occurrences = buildOccurrencesForDay(
    day: now,
    plans: plans,
    profiles: profiles,
  );

  return occurrences.where((occurrence) {
    if (occurrence.scheduledAt.isAfter(now)) {
      return false;
    }
    return !dismissedIds.contains(occurrence.id);
  }).toList();
}

_TimeOfDay? _parseTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return _TimeOfDay(hour: hour, minute: minute);
}

class _TimeOfDay {
  final int hour;
  final int minute;

  const _TimeOfDay({required this.hour, required this.minute});
}
