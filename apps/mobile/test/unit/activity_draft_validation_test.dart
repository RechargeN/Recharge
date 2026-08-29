import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/activity_validation_issue.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/validate_activity_draft_usecase.dart';

CreateDraftEntity _draft({
  ActivityDraftData? activityData,
  MediaEntity? media,
}) {
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'User',
  );
  return base.copyWith(
    objectType: CreateObjectType.activity,
    activityData:
        activityData ??
        ActivityDraftData.defaults(userId: 'user-1', currencyCode: 'EUR'),
    media: media ?? base.media,
  );
}

void main() {
  const ValidateActivityDraftUseCase validate = ValidateActivityDraftUseCase();

  test('returns empty for non-activity draft', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'u',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(validate(draft), isEmpty);
  });

  test('returns details_missing when activityData is null', () {
    final CreateDraftEntity draft = _draft().copyWith(clearActivityData: true);
    final issues = validate(draft);
    expect(issues, hasLength(1));
    expect(issues.single.code, 'details_missing');
  });

  test('blocks empty accessNotes', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: const ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: '  ',
          )),
    ));
    expect(
      issues.any((i) => i.code == 'access_notes_required' && i.severity == ActivityValidationSeverity.error),
      isTrue,
    );
  });

  test('blocks isInformal=true without a note', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: 'Path from the gate.',
            accessCaution: const ActivityAccessCautionDraft(isInformal: true),
          )),
    ));
    expect(issues.any((i) => i.code == 'access_caution_note_required'), isTrue);
  });

  test('allows isInformal=true with a note', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: 'Path from the gate.',
            accessCaution: const ActivityAccessCautionDraft(
              isInformal: true,
              note: 'Part of the slope is fenced private land, do not cross.',
            ),
          )),
    ));
    expect(issues.any((i) => i.code == 'access_caution_note_required'), isFalse);
  });

  test('blocks optionalContribution.kind set without note', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(
            location: const ActivityLocationDraft(
              latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
            ),
            optionalContribution: const ActivityOptionalContributionDraft(
              kind: ActivityContributionKind.donation,
            ),
          ),
    ));
    expect(issues.any((i) => i.code == 'contribution_note_required'), isTrue);
  });

  test('blocks amountHint set without kind/note', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(
            location: const ActivityLocationDraft(
              latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
            ),
            optionalContribution: const ActivityOptionalContributionDraft(
              amountHint: ActivityContributionAmountDraft(
                amountMinor: 300, currencyCode: 'EUR',
              ),
            ),
          ),
    ));
    expect(issues.any((i) => i.code == 'contribution_amount_needs_kind'), isTrue);
  });

  test('does not block when optionalContribution is entirely unset', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: const ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
          )),
    ));
    expect(issues.any((i) => i.sectionId == 'location' && i.code.startsWith('contribution')), isFalse);
  });

  test('blocks typicalDurationMinutes.min > max', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(
            location: const ActivityLocationDraft(
              latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
            ),
            typicalDurationMinutes: const ActivityIntRangeDraft(min: 200, max: 100),
          ),
    ));
    expect(issues.any((i) => i.code == 'duration_range_invalid'), isTrue);
  });

  test('blocks suggestedGroupSize.min > max when both set', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(
            location: const ActivityLocationDraft(
              latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
            ),
            suggestedGroupSize: const ActivityIntRangeDraft(min: 10, max: 2),
          ),
    ));
    expect(issues.any((i) => i.code == 'group_size_range_invalid'), isTrue);
  });

  test('blocks missing coverImage', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: const ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: 'Ok.',
          )),
      media: const MediaEntity(coverImage: '', gallery: <String>[]),
    ));
    expect(issues.any((i) => i.code == 'cover_image_required'), isTrue);
  });

  test('a fully valid draft has no error-severity issues', () {
    final issues = validate(_draft(
      activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR')
          .copyWith(location: const ActivityLocationDraft(
            latitude: 56.9, longitude: 24.1, accessNotes: 'Gravel path, 5 min from parking.',
          )),
      media: const MediaEntity(coverImage: 'https://example.com/cover.jpg', gallery: <String>[]),
    ));
    expect(issues.where((i) => i.severity == ActivityValidationSeverity.error), isEmpty);
  });
}
