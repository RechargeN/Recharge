import '../../domain/entities/create_availability.dart';
import '../../domain/entities/legacy_session_schedule.dart';
import '../../domain/entities/session_availability_exception.dart';
import '../../domain/entities/session_draft_data.dart';
import '../../domain/entities/session_price_disclosure.dart';
import '../../domain/entities/session_schedule.dart';

class UnsupportedSessionSchemaException implements Exception {
  const UnsupportedSessionSchemaException(this.version);

  final int version;

  @override
  String toString() => 'Unsupported Session schema version: $version';
}

/// Strict, lossless round-trip mapper for `SessionDraftData`
/// (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §14, §15.4). Rejects an unknown
/// future major schema instead of guessing, and never drops legacy
/// `eventSlots`-era payload — it is carried forward as
/// `LegacySessionSchedule` until the Creator explicitly builds a weekly
/// schedule (§15.4 migration steps).
abstract final class SessionDraftMapper {
  static Map<String, Object?> toJson(
    SessionDraftData data,
  ) => <String, Object?>{
    'schema_version': data.schemaVersion,
    'resource_name': data.resourceName,
    'timezone_id': data.timezoneId,
    'timezone_confirmed': data.timezoneConfirmed,
    'amenity_ids': data.amenityIds.toList(growable: false),
    'max_party_size': data.maxPartySize,
    'schedule': _scheduleToJson(data.schedule),
    'exceptions': data.exceptions.map(_exceptionToJson).toList(growable: false),
    'price': _priceToJson(data.price),
    'external_booking_url': data.externalBookingUrl,
    'external_terms_url': data.externalTermsUrl,
    'legacy_schedule': data.legacySchedule?.toMap(),
    'revision': data.revision,
    ...data.unknownFields,
  };

  static SessionDraftData fromJson(Map<String, Object?> json) {
    final int version = _intOr(json['schema_version'], 1);
    if (version > SessionDraftData.currentSchemaVersion) {
      throw UnsupportedSessionSchemaException(version);
    }
    const Set<String> known = <String>{
      'schema_version',
      'resource_name',
      'timezone_id',
      'timezone_confirmed',
      'amenity_ids',
      'max_party_size',
      'schedule',
      'exceptions',
      'price',
      'external_booking_url',
      'external_terms_url',
      'legacy_schedule',
      'revision',
    };
    final Map<String, Object?> unknownFields = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };

    final Object? legacyRaw = json['legacy_schedule'];
    return SessionDraftData(
      schemaVersion: SessionDraftData.currentSchemaVersion,
      resourceName: (json['resource_name'] as String?) ?? '',
      timezoneId: (json['timezone_id'] as String?) ?? '',
      timezoneConfirmed: (json['timezone_confirmed'] as bool?) ?? false,
      amenityIds: ((json['amenity_ids'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toSet(),
      maxPartySize: _intOr(json['max_party_size'], 1),
      schedule: _scheduleFromJson(json['schedule']),
      exceptions: ((json['exceptions'] as List<Object?>?) ?? const <Object?>[])
          .map(
            (Object? value) =>
                _exceptionFromJson(value! as Map<String, Object?>),
          )
          .toList(growable: false),
      price: _priceFromJson(json['price']),
      externalBookingUrl: (json['external_booking_url'] as String?) ?? '',
      externalTermsUrl: json['external_terms_url'] as String?,
      legacySchedule: legacyRaw == null
          ? null
          : LegacySessionSchedule.fromMap(legacyRaw as Map<String, Object?>),
      revision: _intOr(json['revision'], 0),
      unknownFields: unknownFields,
    );
  }

  /// Reads a legacy generic Session draft that predates `SessionSchedule`
  /// (§15.4 step 1): the explicit `eventSlots`-style list, kept read-only.
  static LegacySessionSchedule migrateLegacyEventSlots(
    List<CreateTimeSlotDraft> legacyOneTimeSlots, {
    int sourceSchemaVersion = 0,
  }) => LegacySessionSchedule(
    sourceSchemaVersion: sourceSchemaVersion,
    legacyOneTimeSlots: legacyOneTimeSlots,
    state: LegacySessionScheduleState.unreviewed,
  );

  static Map<String, Object?> _scheduleToJson(SessionSchedule s) =>
      <String, Object?>{
        'schedule_revision': s.scheduleRevision,
        'dst_policy_version': s.dstPolicyVersion,
        'slot_duration_minutes': s.slotDurationMinutes,
        'buffer_after_slot_minutes': s.bufferAfterSlotMinutes,
        'min_notice_minutes': s.minNoticeMinutes,
        'projection_window_days': s.projectionWindowDays,
        'weekly_rules': s.weeklyRules
            .map(
              (rule) => <String, Object?>{
                'id': rule.id,
                'iso_weekday': rule.isoWeekday,
                'start_minute_local': rule.startMinuteLocal,
                'end_minute_local_exclusive': rule.endMinuteLocalExclusive,
              },
            )
            .toList(growable: false),
      };

  static SessionSchedule _scheduleFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return SessionSchedule.empty;
    final List<Object?> rawRules =
        (raw['weekly_rules'] as List<Object?>?) ?? const <Object?>[];
    return SessionSchedule(
      scheduleRevision: _intOr(raw['schedule_revision'], 0),
      dstPolicyVersion: _intOr(raw['dst_policy_version'], 1),
      slotDurationMinutes: _intOr(raw['slot_duration_minutes'], 60),
      bufferAfterSlotMinutes: _intOr(raw['buffer_after_slot_minutes'], 0),
      minNoticeMinutes: _intOr(raw['min_notice_minutes'], 0),
      projectionWindowDays: _intOr(raw['projection_window_days'], 30),
      weeklyRules: rawRules
          .map((value) {
            final Map<String, Object?> map = value! as Map<String, Object?>;
            return SessionWeeklyRule(
              id: (map['id'] as String?) ?? '',
              isoWeekday: _intOr(map['iso_weekday'], 1),
              startMinuteLocal: _intOr(map['start_minute_local'], 0),
              endMinuteLocalExclusive: _intOr(
                map['end_minute_local_exclusive'],
                0,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _exceptionToJson(
    SessionAvailabilityException e,
  ) => <String, Object?>{
    'id': e.id,
    'start_date_local': e.startDateLocal,
    'end_date_local': e.endDateLocal,
    'all_day': e.allDay,
    'start_minute_local': e.startMinuteLocal,
    'end_minute_local_exclusive': e.endMinuteLocalExclusive,
    'private_note': e.privateNote,
    'created_by_user_id': e.createdByUserId,
    'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
  };

  static SessionAvailabilityException _exceptionFromJson(
    Map<String, Object?> map,
  ) => SessionAvailabilityException(
    id: (map['id'] as String?) ?? '',
    startDateLocal: (map['start_date_local'] as String?) ?? '',
    endDateLocal: (map['end_date_local'] as String?) ?? '',
    allDay: (map['all_day'] as bool?) ?? true,
    startMinuteLocal: (map['start_minute_local'] as num?)?.toInt(),
    endMinuteLocalExclusive: (map['end_minute_local_exclusive'] as num?)
        ?.toInt(),
    privateNote: map['private_note'] as String?,
    createdByUserId: (map['created_by_user_id'] as String?) ?? '',
    createdAtUtc:
        DateTime.tryParse((map['created_at_utc'] as String?) ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  static Map<String, Object?> _priceToJson(SessionPriceDisclosure p) =>
      <String, Object?>{
        'mode': p.mode.name,
        'amount_minor': p.amount?.amountMinor,
        'currency_code': p.amount?.currencyCode,
      };

  static SessionPriceDisclosure _priceFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return SessionPriceDisclosure.free;
    final SessionPricingMode mode = SessionPricingMode.values.firstWhere(
      (SessionPricingMode value) => value.name == raw['mode'],
      orElse: () => SessionPricingMode.free,
    );
    final int? amountMinor = (raw['amount_minor'] as num?)?.toInt();
    final String? currencyCode = raw['currency_code'] as String?;
    return SessionPriceDisclosure(
      mode: mode,
      amount: amountMinor == null || currencyCode == null
          ? null
          : SessionMoneyDraft(
              amountMinor: amountMinor,
              currencyCode: currencyCode,
            ),
    );
  }

  static int _intOr(Object? value, int fallback) {
    if (value is num) return value.toInt();
    return fallback;
  }
}
