import 'opening_hours_rule.dart';
import 'time_fit_evaluation.dart';
import 'time_slot.dart';

enum DurationConfidence { exact, estimated, unknown }

enum AvailabilityKind { eventSlots, openingHours, none }

class DiscoverItemEntity {
  const DiscoverItemEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    this.subcategory = '',
    required this.startsAtUtc,
    required this.latitude,
    required this.longitude,
    required this.priceAmount,
    required this.distanceKm,
    required this.isFree,
    this.relevanceScore = 0,
    this.coverImageUrl = '',
    this.organizerName = '',
    this.organizerHandle = '',
    this.venueName = '',
    this.addressLine = '',
    this.marketCityId = '',
    this.timezoneId = '',
    this.participantsCount,
    this.capacity,
    this.durationMinutes,
    this.durationConfidence = DurationConfidence.unknown,
    this.availabilityKind = AvailabilityKind.none,
    this.scheduleSlots = const <TimeSlot>[],
    this.openingHours = const <OpeningHoursRule>[],
    this.allowsPartialAttendance = false,
    this.minimumVisitDurationMinutes,
    this.bufferBeforeMinutes = 0,
    this.bufferAfterMinutes = 0,
    this.timeFitEvaluation,
    this.ctaLabel = '',
    this.highlights = const <String>[],
  }) : assert(durationMinutes == null || durationMinutes > 0),
       assert(capacity == null || capacity > 0),
       assert(participantsCount == null || participantsCount >= 0),
       assert(bufferBeforeMinutes >= 0),
       assert(bufferAfterMinutes >= 0),
       assert(
         !allowsPartialAttendance || (minimumVisitDurationMinutes ?? 0) > 0,
       );

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final String subcategory;
  final DateTime startsAtUtc;
  final double latitude;
  final double longitude;
  final double priceAmount;
  final double distanceKm;
  final bool isFree;
  final double relevanceScore;
  final String coverImageUrl;
  final String organizerName;
  final String organizerHandle;
  final String venueName;
  final String addressLine;
  final String marketCityId;
  final String timezoneId;
  final int? participantsCount;
  final int? capacity;
  final int? durationMinutes;
  final DurationConfidence durationConfidence;
  final AvailabilityKind availabilityKind;
  final List<TimeSlot> scheduleSlots;
  final List<OpeningHoursRule> openingHours;
  final bool allowsPartialAttendance;
  final int? minimumVisitDurationMinutes;
  final int bufferBeforeMinutes;
  final int bufferAfterMinutes;
  final TimeFitEvaluation? timeFitEvaluation;
  final String ctaLabel;
  final List<String> highlights;

  DiscoverItemEntity copyWith({
    double? distanceKm,
    double? relevanceScore,
    String? coverImageUrl,
    String? organizerName,
    String? organizerHandle,
    String? venueName,
    String? addressLine,
    String? marketCityId,
    String? timezoneId,
    int? participantsCount,
    bool clearParticipantsCount = false,
    int? capacity,
    bool clearCapacity = false,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    DurationConfidence? durationConfidence,
    AvailabilityKind? availabilityKind,
    List<TimeSlot>? scheduleSlots,
    List<OpeningHoursRule>? openingHours,
    bool? allowsPartialAttendance,
    int? minimumVisitDurationMinutes,
    bool clearMinimumVisitDurationMinutes = false,
    int? bufferBeforeMinutes,
    int? bufferAfterMinutes,
    TimeFitEvaluation? timeFitEvaluation,
    bool clearTimeFitEvaluation = false,
    String? ctaLabel,
    List<String>? highlights,
  }) {
    return DiscoverItemEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      subcategory: subcategory,
      startsAtUtc: startsAtUtc,
      latitude: latitude,
      longitude: longitude,
      priceAmount: priceAmount,
      distanceKm: distanceKm ?? this.distanceKm,
      isFree: isFree,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      organizerName: organizerName ?? this.organizerName,
      organizerHandle: organizerHandle ?? this.organizerHandle,
      venueName: venueName ?? this.venueName,
      addressLine: addressLine ?? this.addressLine,
      marketCityId: marketCityId ?? this.marketCityId,
      timezoneId: timezoneId ?? this.timezoneId,
      participantsCount: clearParticipantsCount
          ? null
          : (participantsCount ?? this.participantsCount),
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      durationConfidence: durationConfidence ?? this.durationConfidence,
      availabilityKind: availabilityKind ?? this.availabilityKind,
      scheduleSlots: scheduleSlots ?? this.scheduleSlots,
      openingHours: openingHours ?? this.openingHours,
      allowsPartialAttendance:
          allowsPartialAttendance ?? this.allowsPartialAttendance,
      minimumVisitDurationMinutes: clearMinimumVisitDurationMinutes
          ? null
          : (minimumVisitDurationMinutes ?? this.minimumVisitDurationMinutes),
      bufferBeforeMinutes: bufferBeforeMinutes ?? this.bufferBeforeMinutes,
      bufferAfterMinutes: bufferAfterMinutes ?? this.bufferAfterMinutes,
      timeFitEvaluation: clearTimeFitEvaluation
          ? null
          : (timeFitEvaluation ?? this.timeFitEvaluation),
      ctaLabel: ctaLabel ?? this.ctaLabel,
      highlights: highlights ?? this.highlights,
    );
  }
}
