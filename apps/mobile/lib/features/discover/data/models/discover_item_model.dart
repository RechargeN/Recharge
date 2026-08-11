import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/opening_hours_rule.dart';
import '../../domain/entities/time_slot.dart';

class DiscoverItemModel extends DiscoverItemEntity {
  const DiscoverItemModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.city,
    required super.category,
    super.subcategory,
    required super.startsAtUtc,
    required super.latitude,
    required super.longitude,
    required super.priceAmount,
    required super.distanceKm,
    required super.isFree,
    super.objectKind,
    required super.relevanceScore,
    super.coverImageUrl,
    super.organizerName,
    super.organizerHandle,
    super.venueName,
    super.addressLine,
    super.marketCityId,
    super.timezoneId,
    super.participantsCount,
    super.capacity,
    super.durationMinutes,
    super.durationConfidence,
    super.availabilityKind,
    super.scheduleSlots,
    super.openingHours,
    super.allowsPartialAttendance,
    super.minimumVisitDurationMinutes,
    super.bufferBeforeMinutes,
    super.bufferAfterMinutes,
    super.ctaLabel,
    super.highlights,
  });

  factory DiscoverItemModel.fromMap(Map<String, Object?> map) {
    return DiscoverItemModel(
      id: map['id']! as String,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      city: map['city']! as String,
      category: map['category']! as String,
      subcategory: map['subcategory'] as String? ?? '',
      startsAtUtc: DateTime.parse(map['starts_at_utc']! as String),
      latitude: (map['latitude']! as num).toDouble(),
      longitude: (map['longitude']! as num).toDouble(),
      priceAmount: (map['price_amount']! as num).toDouble(),
      distanceKm: (map['distance_km']! as num).toDouble(),
      isFree: map['is_free']! as bool,
      objectKind: DiscoverObjectKind.values.firstWhere(
        (DiscoverObjectKind value) => value.name == map['object_kind'],
        orElse: () => DiscoverObjectKind.activity,
      ),
      relevanceScore: (map['relevance_score'] as num?)?.toDouble() ?? 0,
      coverImageUrl: map['cover_image_url'] as String? ?? '',
      organizerName: map['organizer_name'] as String? ?? '',
      organizerHandle: map['organizer_handle'] as String? ?? '',
      venueName: map['venue_name'] as String? ?? '',
      addressLine: map['address_line'] as String? ?? '',
      marketCityId: map['market_city_id'] as String? ?? '',
      timezoneId: map['timezone_id'] as String? ?? '',
      participantsCount: _participantsOrNull(map['participants_count']),
      capacity: _positiveIntOrNull(map['capacity']),
      durationMinutes: _positiveIntOrNull(map['duration_minutes']),
      durationConfidence: DurationConfidence.values.firstWhere(
        (DurationConfidence value) => value.name == map['duration_confidence'],
        orElse: () => _positiveIntOrNull(map['duration_minutes']) == null
            ? DurationConfidence.unknown
            : DurationConfidence.estimated,
      ),
      availabilityKind: AvailabilityKind.values.firstWhere(
        (AvailabilityKind value) => value.name == map['availability_kind'],
        orElse: () => AvailabilityKind.none,
      ),
      scheduleSlots: _mapList(
        map['schedule_slots'],
      ).map(TimeSlot.fromMap).toList(growable: false),
      openingHours: _mapList(
        map['opening_hours'],
      ).map(OpeningHoursRule.fromMap).toList(growable: false),
      allowsPartialAttendance:
          (map['allows_partial_attendance'] as bool?) ?? false,
      minimumVisitDurationMinutes: _positiveIntOrNull(
        map['minimum_visit_duration_minutes'],
      ),
      bufferBeforeMinutes:
          ((map['buffer_before_minutes'] as num?)?.toInt() ?? 0).clamp(0, 1440),
      bufferAfterMinutes: ((map['buffer_after_minutes'] as num?)?.toInt() ?? 0)
          .clamp(0, 1440),
      ctaLabel: map['cta_label'] as String? ?? '',
      highlights: (map['highlights'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }
}

int? _positiveIntOrNull(Object? value) {
  final int? parsed = (value as num?)?.toInt();
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _participantsOrNull(Object? value) {
  final int? parsed = (value as num?)?.toInt();
  return parsed != null && parsed >= 0 ? parsed : null;
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List<dynamic>) return const <Map<String, Object?>>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((Map<dynamic, dynamic> map) {
        return map.map(
          (dynamic key, dynamic nested) =>
              MapEntry<String, Object?>(key as String, nested as Object?),
        );
      })
      .toList(growable: false);
}
