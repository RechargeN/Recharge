import '../../../../shared/primitives/time/local_date.dart';

enum VisitEvidence { selfReported, attendanceConfirmed }

class VisitedPlaceEntity {
  const VisitedPlaceEntity({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.visitedOn,
    required this.timezoneId,
    required this.evidence,
    required this.recordedAtUtc,
    this.coverImageUrl = '',
  }) : assert(id != ''),
       assert(userId != ''),
       assert(placeId != ''),
       assert(timezoneId != '');

  final String id;
  final String userId;
  final String placeId;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final DateTime visitedOn;
  final String timezoneId;
  final VisitEvidence evidence;
  final DateTime recordedAtUtc;
  final String coverImageUrl;

  LocalDate get localDate =>
      LocalDate(visitedOn.year, visitedOn.month, visitedOn.day);
  String get localDayKey => localDate.toString();
}
