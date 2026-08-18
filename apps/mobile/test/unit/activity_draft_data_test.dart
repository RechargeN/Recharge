import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

void main() {
  group('ActivityDraftData.defaults', () {
    test('seeds required fields with no location/optional data', () {
      final ActivityDraftData draft = ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      );
      expect(draft.schemaVersion, ActivityDraftData.currentSchemaVersion);
      expect(draft.revision, 0);
      expect(draft.publisherRef, const PublisherRef(type: PublisherType.user, id: 'user-1'));
      expect(draft.location.accessNotes, '');
      expect(draft.location.pinConfirmed, isFalse);
      expect(draft.typicalDurationMinutes.min, 30);
      expect(draft.typicalDurationMinutes.max, 240);
      expect(draft.suggestedGroupSize, isNull);
      expect(draft.optionalContribution, isNull);
      expect(draft.bestTime, isNull);
    });
  });

  group('ActivityDraftData.copyWith', () {
    test('clearX flags null out optional fields independently of the value arg', () {
      final ActivityDraftData draft = ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ).copyWith(
        bestTime: const ActivityBestTimeDraft(timeOfDay: ActivityTimeOfDay.evening),
        suggestedGroupSize: const ActivityIntRangeDraft(min: 2, max: 6),
      );
      expect(draft.bestTime?.timeOfDay, ActivityTimeOfDay.evening);
      final ActivityDraftData cleared = draft.copyWith(clearBestTime: true);
      expect(cleared.bestTime, isNull);
      expect(cleared.suggestedGroupSize?.min, 2, reason: 'unrelated field must survive');
    });

    test('nextRevision increments revision only', () {
      final ActivityDraftData draft = ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      );
      expect(draft.nextRevision().revision, 1);
    });

    test('replaceLocalIds is a no-op (no nested client-generated ids exist)', () {
      final ActivityDraftData draft = ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      );
      expect(identical(draft.replaceLocalIds(() => 'x'), draft), isTrue);
    });
  });

  group('ActivityLocationDraft.copyWith', () {
    test('clearLatitude/clearLongitude null the pin independently', () {
      const ActivityLocationDraft location = ActivityLocationDraft(
        latitude: 56.95,
        longitude: 24.10,
        accessNotes: 'Gravel path from the main gate.',
      );
      final ActivityLocationDraft cleared = location.copyWith(clearLatitude: true);
      expect(cleared.latitude, isNull);
      expect(cleared.longitude, 24.10);
    });
  });

  group('ActivityAccessCautionDraft', () {
    test('isInformal true requires no structural note enforcement here (validated elsewhere)', () {
      const ActivityAccessCautionDraft caution = ActivityAccessCautionDraft(isInformal: true);
      expect(caution.note, isNull);
    });
  });
}
