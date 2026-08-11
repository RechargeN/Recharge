import '../../domain/entities/visited_place_entity.dart';

class VisitedPlaceModel {
  const VisitedPlaceModel({
    required this.schemaVersion,
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
    required this.recordedAtUtcIso,
    required this.coverImageUrl,
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String id;
  final String userId;
  final String placeId;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final String visitedOn;
  final String timezoneId;
  final String evidence;
  final String recordedAtUtcIso;
  final String coverImageUrl;

  factory VisitedPlaceModel.fromJson(Map<String, dynamic> json) {
    return VisitedPlaceModel(
      schemaVersion: json['schemaVersion'] as int,
      id: json['id'] as String,
      userId: json['userId'] as String,
      placeId: json['placeId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      city: json['city'] as String,
      category: json['category'] as String,
      visitedOn: json['visitedOn'] as String,
      timezoneId: json['timezoneId'] as String,
      evidence: json['evidence'] as String,
      recordedAtUtcIso: json['recordedAtUtcIso'] as String,
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
    );
  }

  factory VisitedPlaceModel.fromEntity(VisitedPlaceEntity entity) {
    return VisitedPlaceModel(
      schemaVersion: currentSchemaVersion,
      id: entity.id,
      userId: entity.userId,
      placeId: entity.placeId,
      title: entity.title,
      subtitle: entity.subtitle,
      city: entity.city,
      category: entity.category,
      visitedOn: entity.localDayKey,
      timezoneId: entity.timezoneId,
      evidence: entity.evidence.name,
      recordedAtUtcIso: entity.recordedAtUtc.toUtc().toIso8601String(),
      coverImageUrl: entity.coverImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'userId': userId,
      'placeId': placeId,
      'title': title,
      'subtitle': subtitle,
      'city': city,
      'category': category,
      'visitedOn': visitedOn,
      'timezoneId': timezoneId,
      'evidence': evidence,
      'recordedAtUtcIso': recordedAtUtcIso,
      'coverImageUrl': coverImageUrl,
    };
  }

  VisitedPlaceEntity toEntity() {
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported visit schema');
    }
    final DateTime parsedDay = DateTime.parse(visitedOn);
    if (_formatLocalDay(parsedDay) != visitedOn) {
      throw const FormatException('Invalid visit calendar day');
    }
    return VisitedPlaceEntity(
      id: id,
      userId: userId,
      placeId: placeId,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      visitedOn: DateTime(parsedDay.year, parsedDay.month, parsedDay.day),
      timezoneId: timezoneId,
      evidence: VisitEvidence.values.byName(evidence),
      recordedAtUtc: DateTime.parse(recordedAtUtcIso).toUtc(),
      coverImageUrl: coverImageUrl,
    );
  }
}

String _formatLocalDay(DateTime value) {
  final String year = value.year.toString().padLeft(4, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
