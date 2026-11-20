import '../../../../shared/primitives/time/local_date.dart';
import '../../../../shared/primitives/time/iana_time_zone.dart';
import '../../../../shared/primitives/time/utc_instant.dart';
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
      timezoneId: IanaTimeZone.parse(entity.timezoneId).value,
      evidence: entity.evidence.name,
      recordedAtUtcIso: UtcInstant(entity.recordedAtUtc).toString(),
      coverImageUrl: entity.coverImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    toEntity();
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
    final parsedDay = LocalDate.parse(visitedOn);
    return VisitedPlaceEntity(
      id: id,
      userId: userId,
      placeId: placeId,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      visitedOn: DateTime(parsedDay.year, parsedDay.month, parsedDay.day),
      timezoneId: IanaTimeZone.parse(timezoneId).value,
      evidence: VisitEvidence.values.byName(evidence),
      recordedAtUtc: UtcInstant.parse(recordedAtUtcIso).value,
      coverImageUrl: coverImageUrl,
    );
  }
}
