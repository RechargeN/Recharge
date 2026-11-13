import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/activity_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';

void main() {
  final ActivityDraftData defaults = ActivityDraftData.defaults(
    userId: 'user-1',
    currencyCode: 'EUR',
  );

  test('fromJson(null) returns defaults', () {
    expect(ActivityDraftMapper.fromJson(null, defaults: defaults), same(defaults));
  });

  test('round-trips a fully populated draft', () {
    final ActivityDraftData original = defaults.copyWith(
      revision: 3,
      location: const ActivityLocationDraft(
        latitude: 56.951,
        longitude: 24.113,
        pinConfirmed: true,
        addressLine: 'Kalnciema iela 35',
        accessNotes: 'Gravel path from the parking lot, 5 min walk.',
        accessCaution: ActivityAccessCautionDraft(
          isInformal: true,
          note: 'Part of the slope is fenced private land, do not cross.',
        ),
        linkedPlaceId: 'place-123',
      ),
      typicalDurationMinutes: const ActivityIntRangeDraft(min: 45, max: 90),
      suggestedGroupSize: const ActivityIntRangeDraft(min: 2, max: 4),
      optionalContribution: const ActivityOptionalContributionDraft(
        kind: ActivityContributionKind.donation,
        note: 'Donate to the park cleanup box.',
        amountHint: ActivityContributionAmountDraft(
          amountMinor: 300,
          currencyCode: 'EUR',
        ),
      ),
      bestTime: const ActivityBestTimeDraft(
        timeOfDay: ActivityTimeOfDay.evening,
        season: ActivitySeason.autumn,
      ),
    );

    final Map<String, Object?> json = ActivityDraftMapper.toJson(original);
    final ActivityDraftData roundTripped = ActivityDraftMapper.fromJson(
      json,
      defaults: defaults,
    );

    expect(roundTripped.revision, 3);
    expect(roundTripped.location.latitude, 56.951);
    expect(roundTripped.location.accessCaution?.isInformal, isTrue);
    expect(roundTripped.location.accessCaution?.note, isNotNull);
    expect(roundTripped.location.linkedPlaceId, 'place-123');
    expect(roundTripped.typicalDurationMinutes.min, 45);
    expect(roundTripped.suggestedGroupSize?.max, 4);
    expect(roundTripped.optionalContribution?.kind, ActivityContributionKind.donation);
    expect(roundTripped.optionalContribution?.amountHint?.amountMinor, 300);
    expect(roundTripped.bestTime?.timeOfDay, ActivityTimeOfDay.evening);
    expect(roundTripped.bestTime?.season, ActivitySeason.autumn);
  });

  test('preserves unknown fields for forward-compat and re-emits them', () {
    final Map<String, Object?> json = <String, Object?>{
      ...ActivityDraftMapper.toJson(defaults),
      'future_field_from_a_newer_client': 'keep-me',
    };
    final ActivityDraftData parsed = ActivityDraftMapper.fromJson(
      json,
      defaults: defaults,
    );
    expect(parsed.unknownFields['future_field_from_a_newer_client'], 'keep-me');
    final Map<String, Object?> reserialized = ActivityDraftMapper.toJson(parsed);
    expect(reserialized['future_field_from_a_newer_client'], 'keep-me');
  });

  test('throws on an unsupported future schema version', () {
    final Map<String, Object?> json = <String, Object?>{
      ...ActivityDraftMapper.toJson(defaults),
      'schema_version': ActivityDraftData.currentSchemaVersion + 1,
    };
    expect(
      () => ActivityDraftMapper.fromJson(json, defaults: defaults),
      throwsFormatException,
    );
  });

  test('missing optional_contribution/best_time in JSON parse to null', () {
    final Map<String, Object?> json = ActivityDraftMapper.toJson(defaults)
      ..remove('optional_contribution')
      ..remove('best_time');
    final ActivityDraftData parsed = ActivityDraftMapper.fromJson(
      json,
      defaults: defaults,
    );
    expect(parsed.optionalContribution, isNull);
    expect(parsed.bestTime, isNull);
  });
}
