import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/publisher_ref.dart';

class ActivityDraftMapper {
  const ActivityDraftMapper._();

  static const Set<String> _knownKeys = <String>{
    'schema_version',
    'revision',
    'publisher_ref',
    'location',
    'typical_duration_minutes',
    'suggested_group_size',
    'optional_contribution',
    'best_time',
  };

  static ActivityDraftData fromJson(
    Object? raw, {
    required ActivityDraftData defaults,
  }) {
    if (raw is! Map) return defaults;
    final Map<String, Object?> json = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int version = _int(json['schema_version']) ?? 1;
    if (version > ActivityDraftData.currentSchemaVersion) {
      throw const FormatException(
        'Unsupported Recharge Activity draft schema version',
      );
    }
    final Map<String, Object?> unknownFields = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    return ActivityDraftData(
      schemaVersion: ActivityDraftData.currentSchemaVersion,
      revision: _int(json['revision']) ?? defaults.revision,
      publisherRef:
          _publisherRef(json['publisher_ref']) ?? defaults.publisherRef,
      location: _location(json['location'], defaults.location),
      typicalDurationMinutes:
          _intRange(json['typical_duration_minutes']) ??
          defaults.typicalDurationMinutes,
      suggestedGroupSize: _intRange(json['suggested_group_size']),
      optionalContribution: _optionalContribution(
        json['optional_contribution'],
      ),
      bestTime: _bestTime(json['best_time']),
      unknownFields: unknownFields,
    );
  }

  static Map<String, Object?> toJson(ActivityDraftData value) {
    final ActivityAccessCautionDraft? caution = value.location.accessCaution;
    final ActivityIntRangeDraft? groupSize = value.suggestedGroupSize;
    final ActivityOptionalContributionDraft? contribution =
        value.optionalContribution;
    final ActivityContributionAmountDraft? amountHint =
        contribution?.amountHint;
    final ActivityBestTimeDraft? bestTime = value.bestTime;
    return <String, Object?>{
      ...value.unknownFields,
      'schema_version': ActivityDraftData.currentSchemaVersion,
      'revision': value.revision,
      'publisher_ref': <String, Object?>{
        'type': value.publisherRef.type.name,
        'id': value.publisherRef.id,
      },
      'location': <String, Object?>{
        'latitude': value.location.latitude,
        'longitude': value.location.longitude,
        'pin_confirmed': value.location.pinConfirmed,
        'address_line': value.location.addressLine,
        'access_notes': value.location.accessNotes,
        'access_caution': caution == null
            ? null
            : <String, Object?>{
                'is_informal': caution.isInformal,
                'note': caution.note,
              },
        'linked_place_id': value.location.linkedPlaceId,
      },
      'typical_duration_minutes': <String, Object?>{
        'min': value.typicalDurationMinutes.min,
        'max': value.typicalDurationMinutes.max,
      },
      'suggested_group_size': groupSize == null
          ? null
          : <String, Object?>{'min': groupSize.min, 'max': groupSize.max},
      'optional_contribution': contribution == null
          ? null
          : <String, Object?>{
              'kind': contribution.kind?.name,
              'note': contribution.note,
              'amount_hint': amountHint == null
                  ? null
                  : <String, Object?>{
                      'amount_minor': amountHint.amountMinor,
                      'currency_code': amountHint.currencyCode,
                    },
            },
      'best_time': bestTime == null
          ? null
          : <String, Object?>{
              'time_of_day': bestTime.timeOfDay?.name,
              'season': bestTime.season?.name,
            },
    };
  }

  static PublisherRef? _publisherRef(Object? raw) {
    if (raw is! Map) return null;
    final String? id = _text(raw['id']);
    if (id == null) return null;
    final PublisherType type =
        _enumValue<PublisherType>(raw['type'] as String?, PublisherType.values) ??
        PublisherType.user;
    return PublisherRef(type: type, id: id);
  }

  static ActivityLocationDraft _location(
    Object? raw,
    ActivityLocationDraft defaults,
  ) {
    if (raw is! Map) return defaults;
    return ActivityLocationDraft(
      latitude: _double(raw['latitude']),
      longitude: _double(raw['longitude']),
      pinConfirmed: raw['pin_confirmed'] as bool? ?? false,
      addressLine: _text(raw['address_line']),
      accessNotes: _text(raw['access_notes']) ?? '',
      accessCaution: _accessCaution(raw['access_caution']),
      linkedPlaceId: _text(raw['linked_place_id']),
    );
  }

  static ActivityAccessCautionDraft? _accessCaution(Object? raw) {
    if (raw is! Map) return null;
    return ActivityAccessCautionDraft(
      isInformal: raw['is_informal'] as bool? ?? false,
      note: _text(raw['note']),
    );
  }

  static ActivityIntRangeDraft? _intRange(Object? raw) {
    if (raw is! Map) return null;
    final int? min = _int(raw['min']);
    final int? max = _int(raw['max']);
    if (min == null || max == null) return null;
    return ActivityIntRangeDraft(min: min, max: max);
  }

  static ActivityOptionalContributionDraft? _optionalContribution(
    Object? raw,
  ) {
    if (raw is! Map) return null;
    final ActivityContributionKind? kind = _enumValue<ActivityContributionKind>(
      raw['kind'] as String?,
      ActivityContributionKind.values,
    );
    final String? note = _text(raw['note']);
    final Object? amountRaw = raw['amount_hint'];
    ActivityContributionAmountDraft? amountHint;
    if (amountRaw is Map) {
      final int? amountMinor = _int(amountRaw['amount_minor']);
      final String? currencyCode = _text(amountRaw['currency_code']);
      if (amountMinor != null && currencyCode != null) {
        amountHint = ActivityContributionAmountDraft(
          amountMinor: amountMinor,
          currencyCode: currencyCode,
        );
      }
    }
    if (kind == null && note == null && amountHint == null) return null;
    return ActivityOptionalContributionDraft(
      kind: kind,
      note: note,
      amountHint: amountHint,
    );
  }

  static ActivityBestTimeDraft? _bestTime(Object? raw) {
    if (raw is! Map) return null;
    final ActivityTimeOfDay? timeOfDay = _enumValue<ActivityTimeOfDay>(
      raw['time_of_day'] as String?,
      ActivityTimeOfDay.values,
    );
    final ActivitySeason? season = _enumValue<ActivitySeason>(
      raw['season'] as String?,
      ActivitySeason.values,
    );
    if (timeOfDay == null && season == null) return null;
    return ActivityBestTimeDraft(timeOfDay: timeOfDay, season: season);
  }

  static T? _enumValue<T extends Enum>(String? name, List<T> values) {
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static double? _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }
}
