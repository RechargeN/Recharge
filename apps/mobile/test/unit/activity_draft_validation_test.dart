import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/activity_validation_issue.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/validate_activity_draft_usecase.dart';

/// Builds an otherwise fully v1.4-conformant Activity draft: valid title,
/// category, description and cover — so each test below can override just
/// the one field it means to test, without tripping unrelated new checks.
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
    title: 'Coffee walk by the canal',
    mainCategory: 'wellness_recharge',
    subcategory: 'recharge_walk',
    shortDescription: 'A calm walk along the canal with coffee to go.',
    activityData:
        activityData ??
        ActivityDraftData.defaults(userId: 'user-1', currencyCode: 'EUR'),
    media:
        media ??
        const MediaEntity(
          coverImage: 'https://example.com/cover.jpg',
          gallery: <String>[],
        ),
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
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: '  ',
              ),
            ),
      ),
    );
    expect(
      issues.any(
        (i) =>
            i.code == 'access_notes_required' &&
            i.severity == ActivityValidationSeverity.error,
      ),
      isTrue,
    );
  });

  test('blocks isInformal=true without a note', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Path from the gate.',
                accessCaution: const ActivityAccessCautionDraft(
                  isInformal: true,
                ),
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'access_caution_note_required'), isTrue);
  });

  test('allows isInformal=true with a note', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Path from the gate.',
                accessCaution: const ActivityAccessCautionDraft(
                  isInformal: true,
                  note:
                      'Part of the slope is fenced private land, do not cross.',
                ),
              ),
            ),
      ),
    );
    expect(
      issues.any((i) => i.code == 'access_caution_note_required'),
      isFalse,
    );
  });

  test('blocks optionalContribution.kind set without note', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              optionalContribution: const ActivityOptionalContributionDraft(
                kind: ActivityContributionKind.donation,
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'contribution_note_required'), isTrue);
  });

  test('blocks amountHint set without kind/note', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              optionalContribution: const ActivityOptionalContributionDraft(
                amountHint: ActivityContributionAmountDraft(
                  amountMinor: 300,
                  currencyCode: 'EUR',
                ),
              ),
            ),
      ),
    );
    expect(
      issues.any((i) => i.code == 'contribution_amount_needs_kind'),
      isTrue,
    );
  });

  test('does not block when optionalContribution is entirely unset', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                accessNotes: 'Ok.',
              ),
            ),
      ),
    );
    expect(
      issues.any(
        (i) => i.sectionId == 'location' && i.code.startsWith('contribution'),
      ),
      isFalse,
    );
  });

  test('blocks typicalDurationMinutes.min > max', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              typicalDurationMinutes: const ActivityIntRangeDraft(
                min: 200,
                max: 100,
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'duration_range_invalid'), isTrue);
  });

  test('blocks suggestedGroupSize.min > max when both set', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              suggestedGroupSize: const ActivityIntRangeDraft(min: 10, max: 2),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'group_size_range_invalid'), isTrue);
  });

  test('blocks missing coverImage', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                accessNotes: 'Ok.',
              ),
            ),
        media: const MediaEntity(coverImage: '', gallery: <String>[]),
      ),
    );
    expect(issues.any((i) => i.code == 'cover_image_required'), isTrue);
  });

  test('blocks an unconfirmed pin even with valid coordinates', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: false,
                accessNotes: 'Gravel path, well signed.',
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'pin_confirmation_required'), isTrue);
  });

  test('blocks missing/out-of-range coordinates', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
            ),
      ),
    );
    expect(
      issues.any((i) => i.code == 'location_coordinates_required'),
      isTrue,
    );
  });

  test('blocks accessNotes shorter than 10 characters', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Short',
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'access_notes_length'), isTrue);
  });

  test('blocks an accessCaution note longer than 200 characters', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
                accessCaution: ActivityAccessCautionDraft(
                  isInformal: true,
                  note: 'x' * 201,
                ),
              ),
            ),
      ),
    );
    expect(issues.any((i) => i.code == 'access_caution_note_length'), isTrue);
  });

  test('raises a non-blocking notice when isInformal=true', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
                accessCaution: const ActivityAccessCautionDraft(
                  isInformal: true,
                  note:
                      'Part of the slope is fenced private land, do not cross.',
                ),
              ),
            ),
      ),
    );
    expect(
      issues.any(
        (i) =>
            i.code == 'informal_access_notice' &&
            i.severity == ActivityValidationSeverity.warning,
      ),
      isTrue,
    );
  });

  test(
    'blocks a contribution note shorter than 10 or longer than 140 characters',
    () {
      final tooShort = validate(
        _draft(
          activityData:
              ActivityDraftData.defaults(
                userId: 'u',
                currencyCode: 'EUR',
              ).copyWith(
                location: const ActivityLocationDraft(
                  latitude: 56.9,
                  longitude: 24.1,
                  pinConfirmed: true,
                  accessNotes: 'Gravel path, well signed.',
                ),
                optionalContribution: const ActivityOptionalContributionDraft(
                  kind: ActivityContributionKind.donation,
                  note: 'short',
                ),
              ),
        ),
      );
      expect(tooShort.any((i) => i.code == 'contribution_note_length'), isTrue);

      final tooLong = validate(
        _draft(
          activityData:
              ActivityDraftData.defaults(
                userId: 'u',
                currencyCode: 'EUR',
              ).copyWith(
                location: const ActivityLocationDraft(
                  latitude: 56.9,
                  longitude: 24.1,
                  pinConfirmed: true,
                  accessNotes: 'Gravel path, well signed.',
                ),
                optionalContribution: ActivityOptionalContributionDraft(
                  kind: ActivityContributionKind.donation,
                  note: 'x' * 141,
                ),
              ),
        ),
      );
      expect(tooLong.any((i) => i.code == 'contribution_note_length'), isTrue);
    },
  );

  test('blocks a non-positive contribution amount', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              optionalContribution: const ActivityOptionalContributionDraft(
                kind: ActivityContributionKind.purchase,
                note: 'Coffee at the kiosk, not required.',
                amountHint: ActivityContributionAmountDraft(
                  amountMinor: 0,
                  currencyCode: 'EUR',
                ),
              ),
            ),
      ),
    );
    expect(
      issues.any((i) => i.code == 'contribution_amount_not_positive'),
      isTrue,
    );
  });

  test('blocks a contribution amount in an unsupported currency', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              optionalContribution: const ActivityOptionalContributionDraft(
                kind: ActivityContributionKind.purchase,
                note: 'Coffee at the kiosk, not required.',
                amountHint: ActivityContributionAmountDraft(
                  amountMinor: 300,
                  currencyCode: 'USD',
                ),
              ),
            ),
      ),
    );
    expect(
      issues.any((i) => i.code == 'contribution_currency_unsupported'),
      isTrue,
    );
  });

  test('blocks a title shorter than 5 or longer than 80 characters', () {
    final tooShort = validate(_draft().copyWith(title: 'Hi'));
    expect(tooShort.any((i) => i.code == 'title_length'), isTrue);

    final tooLong = validate(_draft().copyWith(title: 'x' * 81));
    expect(tooLong.any((i) => i.code == 'title_length'), isTrue);
  });

  test('blocks a missing category or subcategory', () {
    final issues = validate(
      _draft().copyWith(mainCategory: '', subcategory: ''),
    );
    expect(issues.any((i) => i.code == 'category_required'), isTrue);
  });

  test('blocks a non-positive duration or group-size minimum', () {
    final durationIssues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              typicalDurationMinutes: const ActivityIntRangeDraft(
                min: 0,
                max: 60,
              ),
            ),
      ),
    );
    expect(
      durationIssues.any((i) => i.code == 'duration_not_positive'),
      isTrue,
    );

    final groupIssues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
              ),
              suggestedGroupSize: const ActivityIntRangeDraft(min: 0, max: 4),
            ),
      ),
    );
    expect(groupIssues.any((i) => i.code == 'group_size_not_positive'), isTrue);
  });

  test(
    'warns (non-blocking) when duration or group size is outside the recommended range',
    () {
      final issues = validate(
        _draft(
          activityData:
              ActivityDraftData.defaults(
                userId: 'u',
                currencyCode: 'EUR',
              ).copyWith(
                location: const ActivityLocationDraft(
                  latitude: 56.9,
                  longitude: 24.1,
                  pinConfirmed: true,
                  accessNotes: 'Gravel path, well signed.',
                ),
                typicalDurationMinutes: const ActivityIntRangeDraft(
                  min: 10,
                  max: 480,
                ),
                suggestedGroupSize: const ActivityIntRangeDraft(
                  min: 1,
                  max: 25,
                ),
              ),
        ),
      );
      expect(
        issues.any(
          (i) =>
              i.code == 'duration_out_of_recommended_range' &&
              i.severity == ActivityValidationSeverity.warning,
        ),
        isTrue,
      );
      expect(
        issues.any(
          (i) =>
              i.code == 'group_size_out_of_recommended_range' &&
              i.severity == ActivityValidationSeverity.warning,
        ),
        isTrue,
      );
      expect(
        issues.where((i) => i.severity == ActivityValidationSeverity.error),
        isEmpty,
      );
    },
  );

  test('a fully valid draft has no error-severity issues', () {
    final issues = validate(
      _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: const ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, 5 min from parking.',
              ),
            ),
        media: const MediaEntity(
          coverImage: 'https://example.com/cover.jpg',
          gallery: <String>[],
        ),
      ),
    );
    expect(
      issues.where((i) => i.severity == ActivityValidationSeverity.error),
      isEmpty,
    );
  });
  test(
    'a filled non-informal caution still follows the 200 character bound',
    () {
      final draft = _draft(
        activityData:
            ActivityDraftData.defaults(
              userId: 'u',
              currencyCode: 'EUR',
            ).copyWith(
              location: ActivityLocationDraft(
                latitude: 56.9,
                longitude: 24.1,
                pinConfirmed: true,
                accessNotes: 'Gravel path, well signed.',
                accessCaution: ActivityAccessCautionDraft(
                  isInformal: false,
                  note: List.filled(201, 'N').join(),
                ),
              ),
            ),
      );
      expect(
        validate(draft).any((i) => i.code == 'access_caution_note_length'),
        isTrue,
      );
    },
  );
}
