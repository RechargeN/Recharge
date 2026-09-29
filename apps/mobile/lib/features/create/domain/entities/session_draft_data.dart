import 'legacy_session_schedule.dart';
import 'session_availability_exception.dart';
import 'session_price_disclosure.dart';
import 'session_schedule.dart';

/// Type-specific payload for `CreateObjectType.session` inside the common
/// Create draft envelope (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §14).
///
/// Resource identity/location/media/title live on the shared
/// `CreateDraftEntity` fields, same pattern as `routeData`/`eventData` — this
/// class holds only what is genuinely specific to a bookable time slot.
class SessionDraftData {
  const SessionDraftData({
    this.schemaVersion = 1,
    required this.resourceName,
    required this.timezoneId,
    this.timezoneConfirmed = false,
    this.amenityIds = const <String>{},
    required this.maxPartySize,
    required this.schedule,
    this.exceptions = const <SessionAvailabilityException>[],
    required this.price,
    required this.externalBookingUrl,
    this.externalTermsUrl,
    this.legacySchedule,
    this.revision = 0,
    this.unknownFields = const <String, Object?>{},
  });

  final int schemaVersion;
  final String resourceName;
  final String timezoneId;
  final bool timezoneConfirmed;
  final Set<String> amenityIds;

  /// v1 bounds: 1..20 (§13.1 `session_party_size_out_of_range`). Pre-filled
  /// with a default at draft creation (§12 Блок 3, SES-D15) — this field is
  /// still validated but should never be left unset in practice.
  final int maxPartySize;

  final SessionSchedule schedule;
  final List<SessionAvailabilityException> exceptions;
  final SessionPriceDisclosure price;

  /// Required, HTTPS. Session v1 has no `contact_host` booking mode (§8.2) —
  /// this is the single MVP path to a real booking.
  final String externalBookingUrl;
  final String? externalTermsUrl;

  final LegacySessionSchedule? legacySchedule;

  final int revision;

  /// Fields the current app version does not understand yet, preserved
  /// verbatim through mapper round-trips (§14.1 invariant).
  final Map<String, Object?> unknownFields;

  static const int currentSchemaVersion = 1;

  static const int minMaxPartySize = 1;
  static const int maxMaxPartySize = 20;

  bool get maxPartySizeInRange =>
      maxPartySize >= minMaxPartySize && maxPartySize <= maxMaxPartySize;

  SessionDraftData copyWith({
    int? schemaVersion,
    String? resourceName,
    String? timezoneId,
    bool? timezoneConfirmed,
    Set<String>? amenityIds,
    int? maxPartySize,
    SessionSchedule? schedule,
    List<SessionAvailabilityException>? exceptions,
    SessionPriceDisclosure? price,
    String? externalBookingUrl,
    String? externalTermsUrl,
    bool clearExternalTermsUrl = false,
    LegacySessionSchedule? legacySchedule,
    bool clearLegacySchedule = false,
    int? revision,
    Map<String, Object?>? unknownFields,
  }) => SessionDraftData(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    resourceName: resourceName ?? this.resourceName,
    timezoneId: timezoneId ?? this.timezoneId,
    timezoneConfirmed: timezoneConfirmed ?? this.timezoneConfirmed,
    amenityIds: amenityIds ?? this.amenityIds,
    maxPartySize: maxPartySize ?? this.maxPartySize,
    schedule: schedule ?? this.schedule,
    exceptions: exceptions ?? this.exceptions,
    price: price ?? this.price,
    externalBookingUrl: externalBookingUrl ?? this.externalBookingUrl,
    externalTermsUrl: clearExternalTermsUrl
        ? null
        : (externalTermsUrl ?? this.externalTermsUrl),
    legacySchedule: clearLegacySchedule
        ? null
        : (legacySchedule ?? this.legacySchedule),
    revision: revision ?? this.revision,
    unknownFields: unknownFields ?? this.unknownFields,
  );

  /// Replaces any remaining `loc_*` weekly-rule/exception ids with permanent
  /// ones at publish time (`CreateRepositoryImpl.publishDraft`), same
  /// contract as `PlaceDraftData.replaceLocalIds`/
  /// `FindPeopleDraftData.replaceLocalIds` (rule 2 AGENTS.md).
  SessionDraftData replaceLocalIds(String Function() generateId) {
    String replace(String id) => id.startsWith('loc_') ? generateId() : id;
    return copyWith(
      schedule: schedule.copyWith(
        weeklyRules: schedule.weeklyRules
            .map((rule) => rule.copyWith(id: replace(rule.id)))
            .toList(growable: false),
      ),
      exceptions: exceptions
          .map((exception) => exception.copyWith(id: replace(exception.id)))
          .toList(growable: false),
    );
  }

  static SessionDraftData defaults({
    required String resourceName,
    required String timezoneId,
    int defaultMaxPartySize = 4,
    int defaultSlotDurationMinutes = 60,
    int defaultProjectionWindowDays = 30,
  }) => SessionDraftData(
    resourceName: resourceName,
    timezoneId: timezoneId,
    maxPartySize: defaultMaxPartySize,
    schedule: SessionSchedule(
      scheduleRevision: 0,
      slotDurationMinutes: defaultSlotDurationMinutes,
      projectionWindowDays: defaultProjectionWindowDays,
    ),
    price: SessionPriceDisclosure.free,
    externalBookingUrl: '',
  );
}
