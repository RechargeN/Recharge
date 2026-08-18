import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('defaults() has no activityData', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'u',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(draft.activityData, isNull);
  });

  test('copyWith sets activityData; clearActivityData nulls it back out', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'u',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    final ActivityDraftData activity = ActivityDraftData.defaults(
      userId: 'u',
      currencyCode: 'EUR',
    );
    final CreateDraftEntity withActivity = draft.copyWith(
      objectType: CreateObjectType.activity,
      activityData: activity,
    );
    expect(withActivity.activityData, same(activity));
    final CreateDraftEntity cleared = withActivity.copyWith(
      clearActivityData: true,
    );
    expect(cleared.activityData, isNull);
  });

  test('ModerationStatus has a flaggedForReview value', () {
    expect(ModerationStatus.values, contains(ModerationStatus.flaggedForReview));
  });
}
