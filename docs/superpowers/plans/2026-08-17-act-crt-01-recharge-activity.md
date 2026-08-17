# ACT-CRT-01 (Recharge Activity Create Block) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `CreateObjectType.activity` ("Recharge Activity") its own typed domain model, validation, mapper, controller wiring and dedicated 4-step Create UI, replacing the current generic Event-shaped config that contradicts the Approved spec (`requiresStartDateTime = true`, `priceLabel` present).

**Architecture:** Mirror the existing `Place` vertical slice exactly (`PlaceDraftData` → `ActivityDraftData`, `PlaceDraftMapper` → `ActivityDraftMapper`, `ValidatePlaceDraftUseCase` → `ValidateActivityDraftUseCase`, `PlaceCreateBlock` → `ActivityCreateBlock`), wired into the same `CreateDraftEntity`/`CreateController`/`CreateState`/`CreateRepositoryImpl` extension points that already carry `placeData`/`findPeopleData`. Step 1 (title/category/subcategory/description/media) reuses existing generic `CreateController` setters unchanged — only Steps 2–3 (location/access, when-for-whom) need new typed state.

**Tech Stack:** Flutter/Dart, no new packages. Plain Dart value classes (no `freezed`/`equatable`, per repo convention), static mapper classes, callable usecases.

**Spec:** `docs/product/RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.3 (Approved). AC list is spec §18, numbered 1–10 — every task below is traceable to one of those 10 items. §12 is the validation matrix; §15 is the domain model; §11 is the step-by-step field spec.

## Global Constraints

- Money is minor units + ISO currency code (`amountMinor: int`, `currencyCode: String`), matching `EventMoneyDraft` — not `double`, despite `PlacePricingDraft` using `double` (Place predates this convention; Event is the current one and the spec §11 explicitly says "minor units").
- IDs: ULID/UUID generated client-side; `loc_*` only for unsaved local drafts, replaced with a permanent id at publish (`AGENTS.md` rule 2). The actual generator in this repo is `IdGenerator` → UUID v4 (`apps/mobile/lib/core/id/id_generator.dart`), not literally ULID — follow existing code, not the spec's ULID label.
- No Firebase, no network, no paid service, no new backend — local/mock only, consistent with the stabilization slice exception (`AGENTS.md` rule 4).
- Every new/changed file must keep `flutter analyze` at 0 issues and must not regress the full `flutter test` suite (spec AC #8) or the boundary/diff gates (AC #9).
- Follow existing immutability pattern exactly: plain `const`-constructible classes, hand-written `copyWith` with `bool clearX = false` sentinel flags for every nullable field (never rely on `null` alone to mean "clear").
- Out of scope for this plan (explicitly, so no task tries to build it): the §16.1 "Recharge now" Search quick-scenario and the §17 Discover feed card badge are described in the spec body but are **not** among the 10 AC items in §18 — they are fast-follow UX, not required for `ACT-CRT-01`. The §12 "4th+ informal card" soft-moderation-threshold row *is* covered (via AC #5, which requires all of §12), scoped as a local/mock counter mirroring the existing `CheckPlaceDuplicatesUseCase` pattern — no real backend moderation queue exists yet for any type.

---

## Task 1: `ActivityDraftData` domain entity

**Files:**
- Create: `apps/mobile/lib/features/create/domain/entities/activity_draft_data.dart`
- Test: `apps/mobile/test/unit/activity_draft_data_test.dart`

**Interfaces:**
- Consumes: `PublisherRef`/`PublisherType` from `apps/mobile/lib/features/create/domain/entities/publisher_ref.dart`.
- Produces: `ActivityDraftData`, `ActivityLocationDraft`, `ActivityAccessCautionDraft`, `ActivityIntRangeDraft`, `ActivityOptionalContributionDraft`, `ActivityContributionAmountDraft`, `ActivityBestTimeDraft`, `ActivityContributionKind`, `ActivityTimeOfDay`, `ActivitySeason` — all consumed by Tasks 2–17.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/activity_draft_data_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_data_test.dart`
Expected: FAIL — `activity_draft_data.dart` does not exist (import error).

- [ ] **Step 3: Write the implementation**

```dart
// apps/mobile/lib/features/create/domain/entities/activity_draft_data.dart
import 'publisher_ref.dart';

enum ActivityContributionKind { purchase, donation, other }

enum ActivityTimeOfDay { morning, afternoon, evening, night, any }

enum ActivitySeason { winter, spring, summer, autumn, any }

class ActivityIntRangeDraft {
  const ActivityIntRangeDraft({required this.min, required this.max});

  final int min;
  final int max;

  ActivityIntRangeDraft copyWith({int? min, int? max}) => ActivityIntRangeDraft(
    min: min ?? this.min,
    max: max ?? this.max,
  );
}

class ActivityAccessCautionDraft {
  const ActivityAccessCautionDraft({this.isInformal = false, this.note});

  final bool isInformal;
  final String? note;

  ActivityAccessCautionDraft copyWith({
    bool? isInformal,
    String? note,
    bool clearNote = false,
  }) => ActivityAccessCautionDraft(
    isInformal: isInformal ?? this.isInformal,
    note: clearNote ? null : (note ?? this.note),
  );
}

class ActivityLocationDraft {
  const ActivityLocationDraft({
    this.latitude,
    this.longitude,
    this.pinConfirmed = false,
    this.addressLine,
    this.accessNotes = '',
    this.accessCaution,
    this.linkedPlaceId,
  });

  final double? latitude;
  final double? longitude;
  final bool pinConfirmed;
  final String? addressLine;
  final String accessNotes;
  final ActivityAccessCautionDraft? accessCaution;
  final String? linkedPlaceId;

  ActivityLocationDraft copyWith({
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    bool? pinConfirmed,
    String? addressLine,
    bool clearAddressLine = false,
    String? accessNotes,
    ActivityAccessCautionDraft? accessCaution,
    bool clearAccessCaution = false,
    String? linkedPlaceId,
    bool clearLinkedPlaceId = false,
  }) => ActivityLocationDraft(
    latitude: clearLatitude ? null : (latitude ?? this.latitude),
    longitude: clearLongitude ? null : (longitude ?? this.longitude),
    pinConfirmed: pinConfirmed ?? this.pinConfirmed,
    addressLine: clearAddressLine ? null : (addressLine ?? this.addressLine),
    accessNotes: accessNotes ?? this.accessNotes,
    accessCaution: clearAccessCaution
        ? null
        : (accessCaution ?? this.accessCaution),
    linkedPlaceId: clearLinkedPlaceId
        ? null
        : (linkedPlaceId ?? this.linkedPlaceId),
  );
}

class ActivityContributionAmountDraft {
  const ActivityContributionAmountDraft({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  ActivityContributionAmountDraft copyWith({
    int? amountMinor,
    String? currencyCode,
  }) => ActivityContributionAmountDraft(
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
  );
}

class ActivityOptionalContributionDraft {
  const ActivityOptionalContributionDraft({
    this.kind,
    this.note,
    this.amountHint,
  });

  final ActivityContributionKind? kind;
  final String? note;
  final ActivityContributionAmountDraft? amountHint;

  ActivityOptionalContributionDraft copyWith({
    ActivityContributionKind? kind,
    bool clearKind = false,
    String? note,
    bool clearNote = false,
    ActivityContributionAmountDraft? amountHint,
    bool clearAmountHint = false,
  }) => ActivityOptionalContributionDraft(
    kind: clearKind ? null : (kind ?? this.kind),
    note: clearNote ? null : (note ?? this.note),
    amountHint: clearAmountHint ? null : (amountHint ?? this.amountHint),
  );
}

class ActivityBestTimeDraft {
  const ActivityBestTimeDraft({this.timeOfDay, this.season});

  final ActivityTimeOfDay? timeOfDay;
  final ActivitySeason? season;

  ActivityBestTimeDraft copyWith({
    ActivityTimeOfDay? timeOfDay,
    bool clearTimeOfDay = false,
    ActivitySeason? season,
    bool clearSeason = false,
  }) => ActivityBestTimeDraft(
    timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
    season: clearSeason ? null : (season ?? this.season),
  );
}

class ActivityDraftData {
  const ActivityDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.publisherRef,
    required this.location,
    required this.typicalDurationMinutes,
    this.suggestedGroupSize,
    this.optionalContribution,
    this.bestTime,
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final PublisherRef publisherRef;
  final ActivityLocationDraft location;
  final ActivityIntRangeDraft typicalDurationMinutes;
  final ActivityIntRangeDraft? suggestedGroupSize;
  final ActivityOptionalContributionDraft? optionalContribution;
  final ActivityBestTimeDraft? bestTime;
  final Map<String, Object?> unknownFields;

  factory ActivityDraftData.defaults({
    required String userId,
    required String currencyCode,
  }) {
    return ActivityDraftData(
      schemaVersion: currentSchemaVersion,
      revision: 0,
      publisherRef: PublisherRef(type: PublisherType.user, id: userId),
      location: const ActivityLocationDraft(),
      typicalDurationMinutes: const ActivityIntRangeDraft(min: 30, max: 240),
    );
  }

  ActivityDraftData nextRevision() => copyWith(revision: revision + 1);

  /// Activity has no nested entities with their own client-generated
  /// (`loc_`-prefixed) ids — location/duration/group-size/contribution/
  /// bestTime are plain value objects, not addressable sub-records. Kept
  /// for interface parity with `PlaceDraftData.replaceLocalIds`/
  /// `FindPeopleDraftData.replaceLocalIds` so `CreateRepositoryImpl`
  /// can call it unconditionally alongside the other typed payloads.
  ActivityDraftData replaceLocalIds(String Function() generateId) => this;

  ActivityDraftData copyWith({
    int? schemaVersion,
    int? revision,
    PublisherRef? publisherRef,
    ActivityLocationDraft? location,
    ActivityIntRangeDraft? typicalDurationMinutes,
    ActivityIntRangeDraft? suggestedGroupSize,
    bool clearSuggestedGroupSize = false,
    ActivityOptionalContributionDraft? optionalContribution,
    bool clearOptionalContribution = false,
    ActivityBestTimeDraft? bestTime,
    bool clearBestTime = false,
    Map<String, Object?>? unknownFields,
  }) {
    return ActivityDraftData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      publisherRef: publisherRef ?? this.publisherRef,
      location: location ?? this.location,
      typicalDurationMinutes:
          typicalDurationMinutes ?? this.typicalDurationMinutes,
      suggestedGroupSize: clearSuggestedGroupSize
          ? null
          : (suggestedGroupSize ?? this.suggestedGroupSize),
      optionalContribution: clearOptionalContribution
          ? null
          : (optionalContribution ?? this.optionalContribution),
      bestTime: clearBestTime ? null : (bestTime ?? this.bestTime),
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_data_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/domain/entities/activity_draft_data.dart apps/mobile/test/unit/activity_draft_data_test.dart
git commit -m "feat(create): add ActivityDraftData domain entity for ACT-CRT-01"
```

---

## Task 2: `ActivityValidationIssue` + `ValidateActivityDraftUseCase`

**Files:**
- Create: `apps/mobile/lib/features/create/domain/entities/activity_validation_issue.dart`
- Create: `apps/mobile/lib/features/create/domain/usecases/validate_activity_draft_usecase.dart`
- Test: `apps/mobile/test/unit/activity_draft_validation_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftData` (Task 1), `CreateDraftEntity`/`CreateObjectType` (existing, extended by Task 4).
- Produces: `ActivityValidationSeverity`, `ActivityValidationIssue`, `ValidateActivityDraftUseCase` (callable: `List<ActivityValidationIssue> call(CreateDraftEntity draft)`) — consumed by Task 10 (`CreateController`).

This usecase implements only the pure draft-shape rows of spec §12 (rows that need nothing but the draft itself). The category-applicability row and the required-criteria-field row need the taxonomy catalogue and are added as an extra check in `CreateController._activityIssues()` in Task 10, exactly mirroring how `ValidatePlaceDraftUseCase` does **not** own the `subcategory_not_applicable` check either (that lives in `_placeIssues()`). The soft "4th informal card" threshold needs cross-draft publisher data and is implemented in Task 6/11 (publish-time), not here.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/activity_draft_validation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/activity_validation_issue.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/media_entity.dart';
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
      media: const MediaEntity(coverImage: null, gallery: <String>[]),
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
```

> Adjust `MediaEntity`'s constructor call to whatever its real field names are — read `apps/mobile/lib/features/create/domain/entities/media_entity.dart` (or the equivalent file backing `CreateDraftEntity.media`) before writing this test; it is referenced generically as "`media` (`MediaEntity`)" in the codebase survey and its exact shape was not dumped. If `coverImage`/`gallery` differ, use the real field names — do not invent an API.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_validation_test.dart`
Expected: FAIL — missing files.

- [ ] **Step 3: Write the implementation**

```dart
// apps/mobile/lib/features/create/domain/entities/activity_validation_issue.dart
enum ActivityValidationSeverity { error, warning }

class ActivityValidationIssue {
  const ActivityValidationIssue({
    required this.code,
    required this.severity,
    required this.sectionId,
    required this.messageKey,
    this.fieldId,
    this.messageParams = const <String, Object?>{},
  });

  final String code;
  final ActivityValidationSeverity severity;
  final String sectionId; // 'basics' | 'location' | 'whenFor' | 'publish'
  final String? fieldId;
  final String messageKey;
  final Map<String, Object?> messageParams;
}
```

```dart
// apps/mobile/lib/features/create/domain/usecases/validate_activity_draft_usecase.dart
import '../entities/activity_draft_data.dart';
import '../entities/activity_validation_issue.dart';
import '../entities/create_draft_entity.dart';

class ValidateActivityDraftUseCase {
  const ValidateActivityDraftUseCase();

  List<ActivityValidationIssue> call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.activity) {
      return const <ActivityValidationIssue>[];
    }
    final ActivityDraftData? activity = draft.activityData;
    if (activity == null) {
      return const <ActivityValidationIssue>[
        ActivityValidationIssue(
          code: 'details_missing',
          severity: ActivityValidationSeverity.error,
          sectionId: 'basics',
          messageKey: 'activity.validation.details_missing',
        ),
      ];
    }

    final List<ActivityValidationIssue> issues = <ActivityValidationIssue>[];
    void error(String code, String sectionId, [String? fieldId]) {
      issues.add(
        ActivityValidationIssue(
          code: code,
          severity: ActivityValidationSeverity.error,
          sectionId: sectionId,
          fieldId: fieldId,
          messageKey: 'activity.validation.$code',
        ),
      );
    }

    final ActivityLocationDraft location = activity.location;
    if (location.accessNotes.trim().isEmpty) {
      error('access_notes_required', 'location', 'accessNotes');
    }
    final ActivityAccessCautionDraft? caution = location.accessCaution;
    if (caution != null &&
        caution.isInformal &&
        (caution.note == null || caution.note!.trim().isEmpty)) {
      error('access_caution_note_required', 'location', 'accessCautionNote');
    }

    final ActivityOptionalContributionDraft? contribution =
        activity.optionalContribution;
    if (contribution != null) {
      final bool hasKind = contribution.kind != null;
      final bool hasNote =
          contribution.note != null && contribution.note!.trim().isNotEmpty;
      final bool hasAmount = contribution.amountHint != null;
      if (hasKind && !hasNote) {
        error('contribution_note_required', 'location', 'contributionNote');
      }
      if (hasAmount && !(hasKind && hasNote)) {
        error(
          'contribution_amount_needs_kind',
          'location',
          'contributionAmountHint',
        );
      }
    }

    if (activity.typicalDurationMinutes.min >
        activity.typicalDurationMinutes.max) {
      error('duration_range_invalid', 'whenFor', 'typicalDurationMinutes');
    }
    final ActivityIntRangeDraft? groupSize = activity.suggestedGroupSize;
    if (groupSize != null && groupSize.min > groupSize.max) {
      error('group_size_range_invalid', 'whenFor', 'suggestedGroupSize');
    }

    if (draft.media.coverImage == null || draft.media.coverImage!.isEmpty) {
      error('cover_image_required', 'basics', 'coverImage');
    }

    return issues;
  }
}
```

> If `MediaEntity.coverImage` is actually non-nullable-but-empty-string-means-absent (check the real file), adjust the `cover_image_required` condition to match — do not assume nullability without reading the file first.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_validation_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/domain/entities/activity_validation_issue.dart apps/mobile/lib/features/create/domain/usecases/validate_activity_draft_usecase.dart apps/mobile/test/unit/activity_draft_validation_test.dart
git commit -m "feat(create): add ValidateActivityDraftUseCase for §12 draft-shape rules"
```

---

## Task 3: `ActivityDraftMapper` (JSON round-trip)

**Files:**
- Create: `apps/mobile/lib/features/create/data/models/activity_draft_mapper.dart`
- Test: `apps/mobile/test/unit/activity_draft_mapper_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftData` and value objects (Task 1).
- Produces: `ActivityDraftMapper.toJson(ActivityDraftData) -> Map<String, Object?>`, `ActivityDraftMapper.fromJson(Object? raw, {required ActivityDraftData defaults}) -> ActivityDraftData` — consumed by Task 5 (`CreateDraftModel`).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/activity_draft_mapper_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_mapper_test.dart`
Expected: FAIL — mapper file missing.

- [ ] **Step 3: Write the implementation**

```dart
// apps/mobile/lib/features/create/data/models/activity_draft_mapper.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/activity_draft_mapper_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/data/models/activity_draft_mapper.dart apps/mobile/test/unit/activity_draft_mapper_test.dart
git commit -m "feat(create): add ActivityDraftMapper JSON round-trip"
```

---

## Task 4: Wire `activityData` into `CreateDraftEntity` + add `ModerationStatus.flaggedForReview`

**Files:**
- Modify: `apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart`
- Test: `apps/mobile/test/unit/create_draft_entity_activity_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftData` (Task 1).
- Produces: `CreateDraftEntity.activityData` (nullable field), `CreateDraftEntity.copyWith(..., activityData:, clearActivityData:)`, `ModerationStatus.flaggedForReview` — consumed by every remaining task.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/create_draft_entity_activity_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/create_draft_entity_activity_test.dart`
Expected: FAIL — no `activityData` getter, no `flaggedForReview` enum value.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart`:

1. Add the import: `import 'activity_draft_data.dart';` next to the existing `import 'place_draft_data.dart';`.
2. Change the enum:

```dart
enum ModerationStatus { none, pending, approved, rejected, flaggedForReview }
```

3. Add the field next to `placeData` in the constructor parameter list (mirror line-for-line):

```dart
    this.activityData,
```

right after `this.placeData,`, and the field declaration:

```dart
  final ActivityDraftData? activityData;
```

right after `final PlaceDraftData? placeData;`.

4. In `copyWith`, add the parameters right after `PlaceDraftData? placeData,` / `bool clearPlaceData = false,`:

```dart
    ActivityDraftData? activityData,
    bool clearActivityData = false,
```

and in the constructed return value, right after the `placeData:` line:

```dart
      activityData: clearActivityData ? null : (activityData ?? this.activityData),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/create_draft_entity_activity_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Run the full existing suite to confirm no regression from the enum addition**

Run: `cd apps/mobile && flutter test`
Expected: PASS, same count as before + 3 (enum values are read by `.name`, not index, everywhere per the codebase survey, so appending a new value is safe — but this step proves it).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart apps/mobile/test/unit/create_draft_entity_activity_test.dart
git commit -m "feat(create): wire activityData into CreateDraftEntity, add flaggedForReview"
```

---

## Task 5: Wire `activityData` into `CreateDraftModel` (persistence JSON)

**Files:**
- Modify: `apps/mobile/lib/features/create/data/models/create_draft_model.dart`
- Test: `apps/mobile/test/unit/create_draft_model_activity_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftMapper` (Task 3), `ActivityDraftData` (Task 1), `CreateDraftEntity.activityData` (Task 4).
- Produces: draft persistence now round-trips `activity_details` the same way it already round-trips `place_details`/`find_people_details` — consumed by Task 10's autosave/load path (already generic, no controller change needed for load).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/create_draft_model_activity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity draft round-trips through CreateDraftModel toJson/fromJson', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ).copyWith(
        location: const ActivityLocationDraft(
          latitude: 56.95,
          longitude: 24.11,
          accessNotes: 'Gravel path from parking.',
        ),
      ),
    );

    final Map<String, Object?> json = CreateDraftModel.fromEntity(draft).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(json).toEntity();

    expect(restored.objectType, CreateObjectType.activity);
    expect(restored.activityData, isNotNull);
    expect(restored.activityData!.location.accessNotes, 'Gravel path from parking.');
  });

  test('non-activity draft has null activityData after round-trip', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    );
    final Map<String, Object?> json = CreateDraftModel.fromEntity(draft).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(json).toEntity();
    expect(restored.activityData, isNull);
  });
}
```

> `CreateDraftModel.fromEntity(...).toJson()` / `CreateDraftModel.fromJson(...).toEntity()` are illustrative — read the real `CreateDraftModel` header (constructor/`toJson`/`fromJson`/entity-conversion method names) at the top of the file before writing this test, and use the actual API surface. The critical behavior under test is unchanged: an `activity` draft survives a full serialize→deserialize cycle with `activityData` intact.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/create_draft_model_activity_test.dart`
Expected: FAIL — `activityData` always null after round-trip (nothing reads/writes `activity_details` yet).

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/data/models/create_draft_model.dart`:

1. Add imports next to the existing ones:

```dart
import '../../domain/entities/activity_draft_data.dart';
import 'activity_draft_mapper.dart';
```

2. In the serialize path (mirror the `place_details` block at the existing `if (entity.placeData != null) { serializedSections['place_details'] = ...}` site), add:

```dart
    if (entity.activityData != null) {
      serializedSections['activity_details'] = ActivityDraftMapper.toJson(
        entity.activityData!,
      );
    }
```

3. In the deserialize path, right after the existing `legacyPlaceDefaults`/`placeData` block, add:

```dart
    final ActivityDraftData legacyActivityDefaults = ActivityDraftData.defaults(
      userId: organizerId,
      currencyCode: currency,
    );
    final ActivityDraftData? activityData =
        parsedObjectType == CreateObjectType.activity
        ? ActivityDraftMapper.fromJson(
            migratedSectionData['activity_details'],
            defaults: legacyActivityDefaults,
          )
        : null;
```

4. In the `CreateDraftEntity(...)` constructor call at the bottom of `fromJson`, add `activityData: activityData,` right after the existing `placeData: placeData,` line.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/create_draft_model_activity_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/data/models/create_draft_model.dart apps/mobile/test/unit/create_draft_model_activity_test.dart
git commit -m "feat(create): persist activityData through CreateDraftModel"
```

---

## Task 6: `CountActivityInformalAccessUseCase` (§12 soft moderation threshold)

**Files:**
- Create: `apps/mobile/lib/features/create/domain/usecases/count_activity_informal_access_usecase.dart`
- Create: `apps/mobile/lib/features/create/data/datasources/activity_informal_access_mock_datasource.dart`
- Test: `apps/mobile/test/unit/count_activity_informal_access_usecase_test.dart`

**Interfaces:**
- Consumes: `CreateDraftEntity` (Task 4).
- Produces: `CountActivityInformalAccessUseCase` (callable: `int call(CreateDraftEntity draft)`), `mockActivityInformalAccessCounts` (`Map<String, int>`, publisher id → count) — consumed by Task 11 (`CreateController.publishDraft`/`CreateRepositoryImpl`).

This mirrors `CheckPlaceDuplicatesUseCase`/`mockPlaceDuplicateCandidates` exactly: a pure sync usecase over an injected/mock data source, no repository, no network. The mock seed starts **empty** (fresh feature, no invented history — same principle as `VIS-HIST-01`'s "v2 begins empty").

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/count_activity_informal_access_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/count_activity_informal_access_usecase.dart';

void main() {
  test('returns 0 for an unknown publisher', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase();
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'new-user',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'new-user',
        currencyCode: 'EUR',
      ),
    );
    expect(usecase(draft), 0);
  });

  test('returns the injected count for a known publisher', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase(
      publishedInformalActivityCounts: <String, int>{'user-3': 3},
    );
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-3',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-3',
        currencyCode: 'EUR',
      ),
    );
    expect(usecase(draft), 3);
  });

  test('returns 0 when activityData is missing', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase(
      publishedInformalActivityCounts: <String, int>{'user-1': 5},
    );
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(usecase(draft), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/count_activity_informal_access_usecase_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement**

```dart
// apps/mobile/lib/features/create/domain/usecases/count_activity_informal_access_usecase.dart
import '../entities/create_draft_entity.dart';

class CountActivityInformalAccessUseCase {
  const CountActivityInformalAccessUseCase({
    this.publishedInformalActivityCounts = const <String, int>{},
  });

  /// publisher id -> number of already-published Recharge Activity items
  /// from that publisher with `accessCaution.isInformal == true`. Local/
  /// mock only, mirroring `CheckPlaceDuplicatesUseCase`'s injected-candidate
  /// pattern — no backend moderation queue exists yet for any Create type.
  final Map<String, int> publishedInformalActivityCounts;

  int call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.activity ||
        draft.activityData == null) {
      return 0;
    }
    final String publisherId = draft.activityData!.publisherRef.id;
    return publishedInformalActivityCounts[publisherId] ?? 0;
  }
}
```

```dart
// apps/mobile/lib/features/create/data/datasources/activity_informal_access_mock_datasource.dart
/// Publisher id -> count of already-published Recharge Activity items with
/// `accessCaution.isInformal == true`. Starts empty — same "fresh feature,
/// no invented history" convention as Visit History v2 and Place duplicate
/// candidates being explicit demo data rather than silently pre-seeded.
const Map<String, int> mockActivityInformalAccessCounts = <String, int>{};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/count_activity_informal_access_usecase_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/domain/usecases/count_activity_informal_access_usecase.dart apps/mobile/lib/features/create/data/datasources/activity_informal_access_mock_datasource.dart apps/mobile/test/unit/count_activity_informal_access_usecase_test.dart
git commit -m "feat(create): add soft informal-access moderation threshold usecase"
```

---

## Task 7: Fix `CreateBlockConfig` for `activity` + `_availabilityKindFor` routing (spec AC #2)

**Files:**
- Modify: `apps/mobile/lib/features/create/application/create_taxonomy.dart`
- Modify: `apps/mobile/lib/features/create/application/controllers/create_controller.dart` (`_availabilityKindFor` only)
- Test: `apps/mobile/test/unit/create_taxonomy_activity_config_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: corrected `createBlockConfigFor(CreateObjectType.activity)` and `_availabilityKindFor(CreateObjectType.activity) == CreateAvailabilityKind.none` — consumed by Task 10/17 (`CreatePage`, `CreateController.setObjectType`).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/create_taxonomy_activity_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity CreateBlockConfig matches the Approved spec (§2, §11)', () {
    final CreateBlockConfig config = createBlockConfigFor(CreateObjectType.activity);
    expect(config.requiresStartDateTime, isFalse);
    expect(config.locationLabel, 'Where to go');
    expect(config.priceLabel, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/create_taxonomy_activity_config_test.dart`
Expected: FAIL — current config has `requiresStartDateTime: true`, `locationLabel: 'Meeting place'`, `priceLabel: 'Expected spend'`.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/application/create_taxonomy.dart`, replace the `activity` entry (currently lines 85–94):

```dart
CreateBlockConfig(
  objectType: CreateObjectType.activity,
  title: 'Recharge activity',
  description: 'Lightweight activity such as a walk or reset',
  defaultCategoryId: 'wellness_recharge',
  defaultSubcategoryId: 'recharge_walk',
  requiresStartDateTime: false,
  locationLabel: 'Where to go',
  priceLabel: '',
),
```

In `apps/mobile/lib/features/create/application/controllers/create_controller.dart`, in `_availabilityKindFor` (around line 3489), remove `CreateObjectType.activity ||` from the `eventSlots` case so it falls through to the `none` default (mirroring `place`/`rental`):

```dart
  CreateAvailabilityKind _availabilityKindFor(CreateObjectType type) {
    return switch (type) {
      CreateObjectType.event ||
      CreateObjectType.session ||
      CreateObjectType.classWorkshop ||
      CreateObjectType.findPeople => CreateAvailabilityKind.eventSlots,
      // ...existing remaining cases unchanged...
    };
  }
```

> Read the full existing `switch` body before editing — only remove the `CreateObjectType.activity ||` line; leave every other case exactly as-is. If there's an explicit `CreateObjectType.place || CreateObjectType.rental => CreateAvailabilityKind.openingHours,` case, `activity` should fall to the final `_ => CreateAvailabilityKind.none` default, not join that case (Activity is evergreen, not opening-hours-gated).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/create_taxonomy_activity_config_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run the full suite to confirm no regression on other types' availability routing**

Run: `cd apps/mobile && flutter test`
Expected: PASS, same failures as baseline (none introduced).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/create/application/create_taxonomy.dart apps/mobile/lib/features/create/application/controllers/create_controller.dart apps/mobile/test/unit/create_taxonomy_activity_config_test.dart
git commit -m "fix(create): correct activity CreateBlockConfig per spec §2/§11 (AC #2)"
```

---

## Task 8: `activity_create_config.dart` (4-step wizard config)

**Files:**
- Create: `apps/mobile/lib/features/create/application/activity_create_config.dart`

**Interfaces:**
- Produces: `ActivityCreateStepConfig`, `const List<ActivityCreateStepConfig> activityCreateSteps` (4 entries: `basics`, `location`, `whenFor`, `publish`) — consumed by Task 9 (state), Task 10 (controller nav), Tasks 13–16 (widget).

No test needed — this is a pure declarative const list, the same shape as `placeCreateSteps`/`findPeopleCreateSteps`, exercised indirectly by the widget/controller tests in later tasks.

- [ ] **Step 1: Write the implementation**

```dart
// apps/mobile/lib/features/create/application/activity_create_config.dart
class ActivityCreateStepConfig {
  const ActivityCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// Matches spec §11: Step 1 (basics + media), Step 2 (location & access),
/// Step 3 (when & for whom), Step 4 (preview & publish). The spec's entry
/// "Step 0 guard" is routing/auth logic in CreateController, not a stepper
/// index — same convention as Place, whose 3-step `placeCreateSteps` also
/// excludes its entry guard.
const List<ActivityCreateStepConfig> activityCreateSteps =
    <ActivityCreateStepConfig>[
      ActivityCreateStepConfig(
        id: 'basics',
        title: 'About',
        description: 'Title, category and media',
      ),
      ActivityCreateStepConfig(
        id: 'location',
        title: 'Location',
        description: 'Where to go and how to get there',
      ),
      ActivityCreateStepConfig(
        id: 'whenFor',
        title: 'When & for whom',
        description: 'Best time, duration and group size',
      ),
      ActivityCreateStepConfig(
        id: 'publish',
        title: 'Publish',
        description: 'Preview and send',
      ),
    ];
```

- [ ] **Step 2: Verify it compiles**

Run: `cd apps/mobile && flutter analyze lib/features/create/application/activity_create_config.dart`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/lib/features/create/application/activity_create_config.dart
git commit -m "feat(create): add 4-step activity create wizard config"
```

---

## Task 9: `CreateState` — `activityStep` + `activityValidationIssues`

**Files:**
- Modify: `apps/mobile/lib/features/create/application/state/create_state.dart`
- Test: `apps/mobile/test/unit/create_state_activity_test.dart`

**Interfaces:**
- Consumes: `ActivityValidationIssue` (Task 2).
- Produces: `CreateState.activityStep` (`int`), `CreateState.activityValidationIssues` (`List<ActivityValidationIssue>`), corresponding `copyWith`/`clearActivityValidationIssues` — consumed by Task 10 (controller) and Tasks 13–16 (widget).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/create_state_activity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/activity_validation_issue.dart';

void main() {
  test('CreateState.initial starts at activityStep 0 with no issues', () {
    final CreateState state = CreateState.initial();
    expect(state.activityStep, 0);
    expect(state.activityValidationIssues, isEmpty);
  });

  test('copyWith sets and clears activityValidationIssues independently', () {
    final CreateState state = CreateState.initial();
    const List<ActivityValidationIssue> issues = <ActivityValidationIssue>[
      ActivityValidationIssue(
        code: 'access_notes_required',
        severity: ActivityValidationSeverity.error,
        sectionId: 'location',
        messageKey: 'activity.validation.access_notes_required',
      ),
    ];
    final CreateState withIssues = state.copyWith(
      activityStep: 2,
      activityValidationIssues: issues,
    );
    expect(withIssues.activityStep, 2);
    expect(withIssues.activityValidationIssues, issues);
    final CreateState cleared = withIssues.copyWith(
      clearActivityValidationIssues: true,
    );
    expect(cleared.activityValidationIssues, isEmpty);
    expect(cleared.activityStep, 2, reason: 'unrelated field must survive');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/create_state_activity_test.dart`
Expected: FAIL — no `activityStep`/`activityValidationIssues` members.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/application/state/create_state.dart`:

1. Add import: `import '../../domain/entities/activity_validation_issue.dart';`
2. Constructor: add `required this.activityStep,` and `required this.activityValidationIssues,` (place next to `placeStep`/`placeValidationIssues`).
3. `CreateState.initial()`: add `activityStep: 0,` and `activityValidationIssues: const <ActivityValidationIssue>[],`.
4. Fields: add `final int activityStep;` and `final List<ActivityValidationIssue> activityValidationIssues;`.
5. `copyWith` params: add `int? activityStep,`, `List<ActivityValidationIssue>? activityValidationIssues,`, `bool clearActivityValidationIssues = false,`.
6. `copyWith` body: add `activityStep: activityStep ?? this.activityStep,` and:

```dart
      activityValidationIssues: clearActivityValidationIssues
          ? const <ActivityValidationIssue>[]
          : (activityValidationIssues ?? this.activityValidationIssues),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/create_state_activity_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/application/state/create_state.dart apps/mobile/test/unit/create_state_activity_test.dart
git commit -m "feat(create): add activityStep/activityValidationIssues to CreateState"
```

---

## Task 10: `CreateController` wiring — defaults, type-switch, validation dispatch, autosave, mutators, step nav

**Files:**
- Modify: `apps/mobile/lib/features/create/application/controllers/create_controller.dart`
- Test: `apps/mobile/test/unit/activity_controller_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftData`, `ValidateActivityDraftUseCase` (Task 2), `activityCreateSteps` (Task 8), `CreateState.activityStep`/`activityValidationIssues` (Task 9).
- Produces (all on `CreateController`): `setObjectType(CreateObjectType.activity)` now seeds `activityData`; `updateActivityCoordinates({lat, lng})`, `confirmActivityPin()`, `updateActivityAddressLine(String)`, `updateActivityAccessNotes(String)`, `updateActivityAccessCaution({bool isInformal, String? note})`, `updateActivityLinkedPlaceId(String?)`, `updateActivityOptionalContribution({kind, note, amountMinor, currencyCode})`, `clearActivityOptionalContribution()`, `updateActivityBestTime({timeOfDay, season})`, `updateActivityTypicalDuration({min, max})`, `updateActivitySuggestedGroupSize({min, max})`, `clearActivitySuggestedGroupSize()`, `goToActivityStep(int)` — all consumed by Tasks 13–16 (widget).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/activity_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

// Build `controller` via the same test factory/mocks used by
// test/unit/place_controller_test.dart (or whatever the existing Place
// controller test's setup helper is called) — read that file first and
// reuse its fixture/mock-repository wiring rather than duplicating it.

void main() {
  group('CreateController activity wiring', () {
    late CreateController controller;

    setUp(() {
      // controller = buildTestCreateController(userId: 'user-1');
      // See existing place_controller_test.dart for the real setup call.
    });

    test('setObjectType(activity) seeds activityData with market defaults', () {
      controller.setObjectType(CreateObjectType.activity);
      expect(controller.state.draft.objectType, CreateObjectType.activity);
      expect(controller.state.draft.activityData, isNotNull);
      expect(controller.state.draft.activityData!.location.accessNotes, '');
    });

    test('updateActivityAccessNotes updates the draft and bumps revision', () {
      controller.setObjectType(CreateObjectType.activity);
      final int before = controller.state.draft.activityData!.revision;
      controller.updateActivityAccessNotes('Gravel path from parking.');
      expect(
        controller.state.draft.activityData!.location.accessNotes,
        'Gravel path from parking.',
      );
      expect(controller.state.draft.activityData!.revision, greaterThan(before));
    });

    test('confirmActivityPin sets pinConfirmed', () {
      controller.setObjectType(CreateObjectType.activity);
      controller.updateActivityCoordinates(latitude: '56.95', longitude: '24.11');
      controller.confirmActivityPin();
      expect(controller.state.draft.activityData!.location.pinConfirmed, isTrue);
    });

    test('goToActivityStep blocks forward navigation on a blocking error', () async {
      controller.setObjectType(CreateObjectType.activity);
      // location.accessNotes is empty by default -> blocking error on step 1.
      final bool advanced = await controller.goToActivityStep(2);
      expect(advanced, isFalse);
      expect(controller.state.activityStep, 0);
      expect(controller.state.activityValidationIssues, isNotEmpty);
    });

    test('goToActivityStep allows forward navigation once the current step is valid', () async {
      controller.setObjectType(CreateObjectType.activity);
      controller.updateActivityCoordinates(latitude: '56.95', longitude: '24.11');
      controller.confirmActivityPin();
      controller.updateActivityAccessNotes('Gravel path from parking.');
      final bool advanced = await controller.goToActivityStep(1);
      expect(advanced, isTrue);
      expect(controller.state.activityStep, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/activity_controller_test.dart`
Expected: FAIL — none of the new methods exist. Before running, replace the setup comment with the real fixture call from `test/unit/place_controller_test.dart` (read that file first to get the exact constructor/mocks — do not invent one).

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/application/controllers/create_controller.dart`:

**3a. Constructor + field** (mirror `validatePlaceDraft`, near line 120/143):

```dart
    ValidateActivityDraftUseCase validateActivityDraft =
        const ValidateActivityDraftUseCase(),
    CountActivityInformalAccessUseCase countActivityInformalAccess =
        const CountActivityInformalAccessUseCase(),
```
in the constructor parameter list, with initializer-list assignments:
```dart
       _validateActivityDraft = validateActivityDraft,
       _countActivityInformalAccess = countActivityInformalAccess,
```
and fields:
```dart
  final ValidateActivityDraftUseCase _validateActivityDraft;
  final CountActivityInformalAccessUseCase _countActivityInformalAccess;
```

Add imports:
```dart
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/activity_validation_issue.dart';
import '../../domain/usecases/count_activity_informal_access_usecase.dart';
import '../../domain/usecases/validate_activity_draft_usecase.dart';
import '../activity_create_config.dart';
```

**3b. `_activityDefaults` helper** (mirror `_placeDefaults`, near line 3561):

```dart
  ActivityDraftData _activityDefaults(String userId) {
    return ActivityDraftData.defaults(
      userId: userId,
      currencyCode: _runtimeDefaults.currency,
    );
  }
```

**3c. `setObjectType` wiring** (in the `copyWith(...)` block around line 507–539, add alongside the `placeData`/`clearPlaceData` pair):

```dart
        activityData: type == CreateObjectType.activity
            ? (_state.draft.activityData ?? _activityDefaults(_state.userId))
            : null,
        clearActivityData: type != CreateObjectType.activity,
```

**3d. `_activityIssues` wrapper** (mirror `_placeIssues`, near line 3801 — adds the taxonomy-applicability and required-criteria checks that the pure usecase doesn't own, exactly like Place's wrapper):

```dart
  List<ActivityValidationIssue> _activityIssues([CreateDraftEntity? draft]) {
    final CreateDraftEntity target = draft ?? _state.draft;
    final List<ActivityValidationIssue> issues = List<ActivityValidationIssue>.of(
      _validateActivityDraft(target),
    );
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      target.mainCategory,
    );
    final bool subcategoryAllowed =
        category?.subcategories.any(
          (CreateTaxonomySubcategory sub) => sub.id == target.subcategory,
        ) ??
        false;
    if (category == null || !subcategoryAllowed) {
      issues.add(
        const ActivityValidationIssue(
          code: 'subcategory_not_applicable',
          severity: ActivityValidationSeverity.error,
          sectionId: 'basics',
          fieldId: 'subcategory',
          messageKey: 'activity.validation.subcategory_not_applicable',
        ),
      );
    }
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      target.subcategory,
    );
    if (criteria != null) {
      final Map<String, Object?> criteriaValues =
          (target.sectionData['criteria'] as Map<String, Object?>?) ??
          const <String, Object?>{};
      for (final RechargeCriteriaFieldDefinition field in criteria.fields) {
        if (criteria.profile.requiredFieldIds.contains(field.id) &&
            (criteriaValues[field.id] == null ||
                (criteriaValues[field.id] is String &&
                    (criteriaValues[field.id] as String).trim().isEmpty))) {
          issues.add(
            ActivityValidationIssue(
              code: 'criteria_field_required',
              severity: ActivityValidationSeverity.error,
              sectionId: 'whenFor',
              fieldId: field.id,
              messageKey: 'activity.validation.criteria_field_required',
              messageParams: <String, Object?>{'field': field.id},
            ),
          );
        }
      }
    }
    return issues;
  }
```

> Read `_placeIssues()`'s exact taxonomy lookup lines (around 3812–3830, already dumped in the codebase survey) and the exact `CategoryCriteriaResult`/`RechargeCriteriaFieldDefinition`/`RechargeCriteriaProfile` field names (`requiredFieldIds`, `fields`, `profile`) from `get_category_criteria_usecase.dart` before finalizing this method — reuse the identical pattern Place already uses, don't invent field names.

**3e. `_validate` dispatcher** (add a branch in the existing `if/else if` chain around line 3432–3454, after the `place` branch):

```dart
    if (draft.objectType == CreateObjectType.activity) {
      final List<ActivityValidationIssue> issues = _activityIssues(draft);
      return <String, String>{
        for (final ActivityValidationIssue issue in issues)
          if (issue.severity == ActivityValidationSeverity.error)
            issue.fieldId ?? issue.code: issue.messageKey,
      };
    }
```

**3f. Autosave inclusion** (in `_updateDraft`, the type list around line 3536–3543, add `resolved.objectType == CreateObjectType.activity ||` to the existing `||`-chain).

**3g. `_updateActivity` helper** (mirror `_updatePlace`, near line 3771):

```dart
  void _updateActivity(
    ActivityDraftData Function(ActivityDraftData activity) transform,
  ) {
    final ActivityDraftData? current = _state.draft.activityData;
    if (_state.draft.objectType != CreateObjectType.activity ||
        current == null) {
      return;
    }
    final ActivityDraftData next = transform(current).nextRevision();
    _updateDraft(
      _state.draft.copyWith(
        activityData: next,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }
```

**3h. Field mutators** (place near the Place mutators, e.g. after `confirmPlacePin`):

```dart
  void updateActivityCoordinates({
    required String latitude,
    required String longitude,
  }) {
    final double? lat = _parseDouble(latitude);
    final double? lng = _parseDouble(longitude);
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          latitude: lat,
          clearLatitude: lat == null,
          longitude: lng,
          clearLongitude: lng == null,
          pinConfirmed: false,
        ),
      ),
    );
  }

  void confirmActivityPin() {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(pinConfirmed: true),
      ),
    );
  }

  void updateActivityAddressLine(String value) {
    final String trimmed = value.trim();
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          addressLine: trimmed,
          clearAddressLine: trimmed.isEmpty,
        ),
      ),
    );
  }

  void updateActivityAccessNotes(String value) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(accessNotes: value.trim()),
      ),
    );
  }

  void updateActivityAccessCaution({
    required bool isInformal,
    String? note,
  }) {
    _updateActivity((ActivityDraftData activity) {
      final String trimmedNote = (note ?? '').trim();
      return activity.copyWith(
        location: activity.location.copyWith(
          accessCaution: isInformal
              ? ActivityAccessCautionDraft(
                  isInformal: true,
                  note: trimmedNote.isEmpty ? null : trimmedNote,
                )
              : null,
          clearAccessCaution: !isInformal,
        ),
      );
    });
  }

  void updateActivityLinkedPlaceId(String? placeId) {
    final String trimmed = (placeId ?? '').trim();
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          linkedPlaceId: trimmed.isEmpty ? null : trimmed,
          clearLinkedPlaceId: trimmed.isEmpty,
        ),
      ),
    );
  }

  void updateActivityOptionalContribution({
    ActivityContributionKind? kind,
    String? note,
    int? amountMinor,
  }) {
    _updateActivity((ActivityDraftData activity) {
      final String trimmedNote = (note ?? '').trim();
      return activity.copyWith(
        optionalContribution: ActivityOptionalContributionDraft(
          kind: kind,
          note: trimmedNote.isEmpty ? null : trimmedNote,
          amountHint: amountMinor == null
              ? null
              : ActivityContributionAmountDraft(
                  amountMinor: amountMinor,
                  currencyCode: _runtimeDefaults.currency,
                ),
        ),
      );
    });
  }

  void clearActivityOptionalContribution() {
    _updateActivity(
      (ActivityDraftData activity) =>
          activity.copyWith(clearOptionalContribution: true),
    );
  }

  void updateActivityBestTime({
    ActivityTimeOfDay? timeOfDay,
    ActivitySeason? season,
  }) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        bestTime: ActivityBestTimeDraft(timeOfDay: timeOfDay, season: season),
      ),
    );
  }

  void updateActivityTypicalDuration({required int min, required int max}) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        typicalDurationMinutes: ActivityIntRangeDraft(min: min, max: max),
      ),
    );
  }

  void updateActivitySuggestedGroupSize({required int min, required int max}) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        suggestedGroupSize: ActivityIntRangeDraft(min: min, max: max),
      ),
    );
  }

  void clearActivitySuggestedGroupSize() {
    _updateActivity(
      (ActivityDraftData activity) =>
          activity.copyWith(clearSuggestedGroupSize: true),
    );
  }
```

**3i. `_setActivityIssues` + `goToActivityStep`** (mirror `_setPlaceIssues`/`goToPlaceStep`):

```dart
  void _setActivityIssues(
    List<ActivityValidationIssue> issues, {
    required String message,
  }) {
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        activityValidationIssues: issues,
        validationErrors: <String, String>{
          for (final ActivityValidationIssue issue in issues)
            if (issue.severity == ActivityValidationSeverity.error)
              issue.fieldId ?? issue.code: issue.messageKey,
        },
        message: message,
      ),
    );
  }

  Future<bool> goToActivityStep(int step) async {
    final int nextStep = step.clamp(0, activityCreateSteps.length - 1);
    if (nextStep > _state.activityStep) {
      final List<ActivityValidationIssue> issues = _activityIssues();
      final String currentSectionId = activityCreateSteps[_state.activityStep].id;
      final List<ActivityValidationIssue> blocking = issues
          .where(
            (ActivityValidationIssue issue) =>
                issue.severity == ActivityValidationSeverity.error &&
                issue.sectionId == currentSectionId,
          )
          .toList(growable: false);
      if (blocking.isNotEmpty) {
        _setActivityIssues(issues, message: 'Проверьте обязательные поля шага');
        return false;
      }
    }
    _setState(_state.copyWith(activityStep: nextStep, clearMessage: true));
    await saveDraft();
    return true;
  }
```

**3j. `publishDraft()` — validation-failure branch** (add an `else if` in the existing chain around line 3110–3121, after the `place` branch):

```dart
      } else if (_state.draft.objectType == CreateObjectType.activity) {
        _setActivityIssues(
          _activityIssues(),
          message: 'Проверьте обязательные поля Recharge Activity',
        );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/activity_controller_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full suite**

Run: `cd apps/mobile && flutter test`
Expected: PASS, no regressions.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/create/application/controllers/create_controller.dart apps/mobile/test/unit/activity_controller_test.dart
git commit -m "feat(create): wire ActivityDraftData into CreateController"
```

---

## Task 11: `publishDraft()` — soft informal-access threshold (§12 4th-card row)

**Files:**
- Modify: `apps/mobile/lib/features/create/application/controllers/create_controller.dart` (`publishDraft()` only)
- Test: `apps/mobile/test/unit/activity_publish_moderation_test.dart`

**Interfaces:**
- Consumes: `CountActivityInformalAccessUseCase` (Task 6), `ModerationStatus.flaggedForReview` (Task 4).
- Produces: publishing a 4th-or-later informal-access Activity from the same publisher no longer blocks, but the published draft carries `moderationStatus: flaggedForReview` instead of `pending`.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/activity_publish_moderation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/count_activity_informal_access_usecase.dart';

// Reuse the same test controller factory as activity_controller_test.dart,
// but override countActivityInformalAccess with a known count.

void main() {
  test('4th+ informal-access card publishes flagged, not blocked', () async {
    // final controller = buildTestCreateController(
    //   userId: 'user-3',
    //   countActivityInformalAccess: const CountActivityInformalAccessUseCase(
    //     publishedInformalActivityCounts: {'user-3': 3},
    //   ),
    // );
    // controller.setObjectType(CreateObjectType.activity);
    // controller.updateActivityCoordinates(latitude: '56.95', longitude: '24.11');
    // controller.confirmActivityPin();
    // controller.updateActivityAccessNotes('Trail off the marked path.');
    // controller.updateActivityAccessCaution(isInformal: true, note: 'Watch for dogs.');
    // final bool published = await controller.publishDraft();
    // expect(published, isTrue);
    // expect(
    //   controller.state.publishedDraft!.moderationStatus,
    //   ModerationStatus.flaggedForReview,
    // );
  });

  test('1st-3rd informal-access card publishes as normal pending', () async {
    // Same as above but with count 0 -> expect ModerationStatus.pending.
  });
}
```

> Fill in the commented-out setup using the real test controller factory (same one Task 10 uses) plus whatever full-draft fields (title, category, cover image, criteria) are required to pass validation end-to-end — copy the minimal valid-draft setup from `activity_draft_validation_test.dart`'s "fully valid draft" case in Task 2 and adapt it through the controller's mutator methods from Task 10, rather than constructing `ActivityDraftData` directly.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/activity_publish_moderation_test.dart`
Expected: FAIL — `moderationStatus` is always `pending` today; the constructor param doesn't exist yet.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/application/controllers/create_controller.dart`, `publishDraft()`, right before the final `_setState(status: CreateStatus.publishing, ...)` block (i.e. after the existing Place duplicate/warning gate, before the `_publishCreateDraftUseCase` call), add:

```dart
    CreateDraftEntity draftToPublish = _state.draft;
    if (draftToPublish.objectType == CreateObjectType.activity) {
      final ActivityAccessCautionDraft? caution =
          draftToPublish.activityData?.location.accessCaution;
      final bool isInformal = caution?.isInformal ?? false;
      if (isInformal) {
        final int priorInformalCount = _countActivityInformalAccess(
          draftToPublish,
        );
        if (priorInformalCount >= 3) {
          draftToPublish = draftToPublish.copyWith(
            moderationStatus: ModerationStatus.flaggedForReview,
          );
        }
      }
    }
```

Then change the `_publishCreateDraftUseCase` call to use `draftToPublish` instead of `_state.draft`:

```dart
    final CreateDraftEntity published = await _publishCreateDraftUseCase(
      userId: _state.userId,
      draft: draftToPublish,
    );
```

> Verify `CreateDraftEntity.copyWith` already accepts a `moderationStatus` parameter (it should, as a generic field per the codebase survey) — if the parameter name differs, use the real one.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/activity_publish_moderation_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/application/controllers/create_controller.dart apps/mobile/test/unit/activity_publish_moderation_test.dart
git commit -m "feat(create): soft-flag 4th+ informal-access activity for review (§12)"
```

---

## Task 12: `CreateRepositoryImpl.publishDraft()` — `activityData.replaceLocalIds` wiring

**Files:**
- Modify: `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart`
- Test: `apps/mobile/test/unit/create_repository_activity_publish_test.dart`

**Interfaces:**
- Consumes: `ActivityDraftData.replaceLocalIds` (Task 1, no-op but must be called for interface parity and future-proofing).
- Produces: published Activity drafts go through the same id-replacement pipeline as Place/FindPeople (AC #1 "по образцу PlaceDraftData" extends to the full publish flow, not just the entity shape).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/create_repository_activity_publish_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

// Reuse the same fake local datasource/id-generator setup as the existing
// Place publish test in create_repository_impl_test.dart (or equivalent) —
// read that file first for the real constructor signature.

void main() {
  test('publishing an activity draft replaces a loc_ id and keeps activityData', () async {
    // final repository = buildTestCreateRepository();
    // final draft = CreateDraftEntity.defaults(...).copyWith(
    //   id: 'loc_abc',
    //   objectType: CreateObjectType.activity,
    //   activityData: ActivityDraftData.defaults(userId: 'u', currencyCode: 'EUR'),
    // );
    // final published = await repository.publishDraft('user-1', draft);
    // expect(published.id.startsWith('loc_'), isFalse);
    // expect(published.activityData, isNotNull);
  });
}
```

> Read the existing Place-equivalent repository test to find its real fixture-building helper and reuse it — do not hand-roll a new fake datasource.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/create_repository_activity_publish_test.dart`
Expected: FAIL only if `activityData` is silently dropped somewhere in the copy chain — otherwise this may already pass once Task 4/5 land, since `replaceLocalIds` is a no-op. Confirm which by running before Step 3; if it already passes, Step 3 is only about explicitly wiring the call for consistency/future-proofing (still commit it — interface parity is the point, not just current behavior).

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart`, in the `copyWith(...)` block that builds `published` (around line 281–288), add right after the existing `placeData:`/`findPeopleData:` lines:

```dart
      activityData: draft.activityData?.replaceLocalIds(_idGenerator.generate),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/create_repository_activity_publish_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart apps/mobile/test/unit/create_repository_activity_publish_test.dart
git commit -m "feat(create): wire activityData through publish id-replacement pipeline"
```

---

## Task 13: `ActivityCreateBlock` widget — skeleton + Step 1 (Basics)

**Files:**
- Create: `apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart`
- Test: `apps/mobile/test/widget/activity_create_block_test.dart`

**Interfaces:**
- Consumes: `CreateController`, `CreateState` (Tasks 9–10), `activityCreateSteps` (Task 8), `createTaxonomyForObjectType` (existing, from `create_taxonomy.dart`).
- Produces: `ActivityCreateBlock` StatefulWidget (`controller`, `state`, `onPublished` params, matching `PlaceCreateBlock`'s exact constructor shape) — consumed by Task 17 (`create_page.dart`).

Follow `PlaceCreateBlock`'s structural pattern exactly: a `StatefulWidget` with a `Map<String, TextEditingController> _fields` helper, a `switch (widget.state.activityStep)` between step methods, and a shared `_StepCard`-style wrapper. Step 1 fields are all **generic** `CreateController` methods that already exist (`updateTitle`, `updateMainCategory`, `updateSubcategory`, `updateShortDescription`, `updateFullDescription`, `updateCoverImage`, `addGalleryImage`, `removeGalleryImageAt`) — no new controller methods needed for this step.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/widget/activity_create_block_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

// Reuse the same MaterialApp + test CreateController wrapping helper as
// test/widget/place_create_block_test.dart (or equivalent) — read that
// file first for the exact pump/controller-provider boilerplate.

void main() {
  testWidgets('renders the Basics step title field for a fresh activity draft', (
    WidgetTester tester,
  ) async {
    // final controller = buildTestCreateController(userId: 'user-1')
    //   ..setObjectType(CreateObjectType.activity);
    // await tester.pumpWidget(
    //   MaterialApp(
    //     home: Scaffold(
    //       body: ActivityCreateBlock(
    //         controller: controller,
    //         state: controller.state,
    //         onPublished: () {},
    //       ),
    //     ),
    //   ),
    // );
    // expect(find.text('Title'), findsOneWidget);
    // expect(find.byType(TextFormField), findsWidgets);
  });
}
```

> Read `test/widget/place_create_block_test.dart` first for the exact pump helper / test controller wiring (mock repository, `ChangeNotifierProvider` vs a plain rebuild-on-state-copy pattern — whichever this codebase uses) and mirror it precisely. Do not invent a different test harness.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_test.dart`
Expected: FAIL — widget file doesn't exist.

- [ ] **Step 3: Implement**

```dart
// apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart
import 'package:flutter/material.dart';

import '../../application/activity_create_config.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_taxonomy.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/activity_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';

class ActivityCreateBlock extends StatefulWidget {
  const ActivityCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<ActivityCreateBlock> createState() => _ActivityCreateBlockState();
}

class _ActivityCreateBlockState extends State<ActivityCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  TextEditingController _field(String id, String value) {
    final TextEditingController? existing = _fields[id];
    if (existing != null) {
      if (existing.text != value && !existing.selection.isValid) {
        existing.text = value;
      }
      return existing;
    }
    final TextEditingController created = TextEditingController(text: value);
    _fields[id] = created;
    return created;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ActivityValidationIssue> _issuesFor(String sectionId) => widget
      .state
      .activityValidationIssues
      .where((ActivityValidationIssue issue) => issue.sectionId == sectionId)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final ActivityDraftData? activity = draft.activityData;
    if (activity == null) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Loading Recharge Activity draft…'),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ActivityProgressHeader(
          steps: activityCreateSteps,
          currentIndex: widget.state.activityStep,
          onStepTapped: (int index) => widget.controller.goToActivityStep(index),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey<int>(widget.state.activityStep),
            child: switch (widget.state.activityStep) {
              0 => _basicsStep(draft),
              1 => _locationStep(activity),
              2 => _whenForStep(activity, draft),
              _ => _publishStep(draft, activity),
            },
          ),
        ),
        _navigation(),
        if (widget.state.message != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.state.message!),
          ),
      ],
    );
  }

  Widget _basicsStep(CreateDraftEntity draft) {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final CreateTaxonomyCategory? selectedCategory = categories
        .where((CreateTaxonomyCategory c) => c.contentGroup.id == draft.mainCategory)
        .cast<CreateTaxonomyCategory?>()
        .firstWhere((_) => true, orElse: () => null);
    return _StepCard(
      title: 'About this activity',
      children: <Widget>[
        TextFormField(
          controller: _field('title', draft.title),
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: widget.controller.updateTitle,
        ),
        DropdownButtonFormField<String>(
          initialValue: draft.mainCategory.isEmpty ? null : draft.mainCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: <DropdownMenuItem<String>>[
            for (final CreateTaxonomyCategory category in categories)
              DropdownMenuItem<String>(
                value: category.contentGroup.id,
                child: Text(category.contentGroup.id),
              ),
          ],
          onChanged: (String? value) {
            if (value != null) widget.controller.updateMainCategory(value);
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: draft.subcategory.isEmpty ? null : draft.subcategory,
          decoration: const InputDecoration(labelText: 'Subcategory'),
          items: <DropdownMenuItem<String>>[
            for (final sub in selectedCategory?.subcategories ?? const [])
              DropdownMenuItem<String>(value: sub.id, child: Text(sub.id)),
          ],
          onChanged: (String? value) {
            if (value != null) widget.controller.updateSubcategory(value);
          },
        ),
        TextFormField(
          controller: _field('shortDescription', draft.shortDescription),
          decoration: const InputDecoration(labelText: 'Short description'),
          onChanged: widget.controller.updateShortDescription,
        ),
        TextFormField(
          controller: _field('fullDescription', draft.fullDescription),
          decoration: const InputDecoration(labelText: 'Full description (optional)'),
          maxLines: 4,
          onChanged: widget.controller.updateFullDescription,
        ),
        TextFormField(
          controller: _field('coverImage', draft.media.coverImage ?? ''),
          decoration: const InputDecoration(labelText: 'Cover image URL'),
          onChanged: widget.controller.updateCoverImage,
        ),
        for (final ActivityValidationIssue issue in _issuesFor('basics'))
          Text(issue.messageKey, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }

  // _locationStep, _whenForStep, _publishStep, _navigation added in Tasks 14-16.
  Widget _locationStep(ActivityDraftData activity) => const SizedBox.shrink();
  Widget _whenForStep(ActivityDraftData activity, CreateDraftEntity draft) =>
      const SizedBox.shrink();
  Widget _publishStep(CreateDraftEntity draft, ActivityDraftData activity) =>
      const SizedBox.shrink();
  Widget _navigation() => const SizedBox.shrink();
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActivityProgressHeader extends StatelessWidget {
  const _ActivityProgressHeader({
    required this.steps,
    required this.currentIndex,
    required this.onStepTapped,
  });

  final List<ActivityCreateStepConfig> steps;
  final int currentIndex;
  final ValueChanged<int> onStepTapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onStepTapped(i),
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: i <= currentIndex
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

> `createTaxonomyForObjectType`'s return type field names (`contentGroup.id`, `subcategories`, `sub.id`) must be checked against the real `CreateTaxonomyCategory`/`CreateTaxonomySubcategory` classes (already partly surfaced in the codebase survey as `contentGroup`/`subcategories`/`.allows()`) before finalizing — if display labels differ from raw ids, use whatever `PlaceCreateBlock`'s own category dropdown already uses for consistency.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart apps/mobile/test/widget/activity_create_block_test.dart
git commit -m "feat(create): add ActivityCreateBlock skeleton + Basics step"
```

---

## Task 14: `ActivityCreateBlock` — Step 2 (Location & Access)

**Files:**
- Modify: `apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart` (`_locationStep` only)
- Test: `apps/mobile/test/widget/activity_create_block_location_test.dart`

**Interfaces:**
- Consumes: `updateActivityCoordinates`, `confirmActivityPin`, `updateActivityAddressLine`, `updateActivityAccessNotes`, `updateActivityAccessCaution`, `updateActivityLinkedPlaceId`, `updateActivityOptionalContribution`, `clearActivityOptionalContribution` (Task 10).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/widget/activity_create_block_location_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

// Same harness as Task 13's test, but drive to activityStep 1 first
// (controller.goToActivityStep requires a valid step-0 draft first, or
// directly seed state.activityStep via the test controller helper — check
// how place_create_block_test.dart jumps straight to a later step).

void main() {
  testWidgets('shows the informal-access note field only when the caution switch is on', (
    WidgetTester tester,
  ) async {
    // Pump ActivityCreateBlock at activityStep 1.
    // expect(find.text('Access notes'), findsOneWidget);
    // expect(find.text('This is not an official spot'), findsOneWidget);
    // Initially the note field is hidden.
    // expect(find.text('What to know before you go'), findsNothing);
    // Toggle the switch and expect the note field to appear.
    // await tester.tap(find.byType(Switch));
    // await tester.pump();
    // expect(find.text('What to know before you go'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_location_test.dart`
Expected: FAIL — `_locationStep` currently returns `SizedBox.shrink()`.

- [ ] **Step 3: Implement**

Replace the `_locationStep` stub in `activity_create_block.dart`:

```dart
  Widget _locationStep(ActivityDraftData activity) {
    final ActivityAccessCautionDraft? caution = activity.location.accessCaution;
    final bool isInformal = caution?.isInformal ?? false;
    final ActivityOptionalContributionDraft? contribution =
        activity.optionalContribution;
    return _StepCard(
      title: 'Where is it, and how do I get there?',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _field(
                  'latitude',
                  activity.location.latitude?.toString() ?? '',
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (String value) => widget.controller
                    .updateActivityCoordinates(
                      latitude: value,
                      longitude: _fields['longitude']?.text ?? '',
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _field(
                  'longitude',
                  activity.location.longitude?.toString() ?? '',
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (String value) => widget.controller
                    .updateActivityCoordinates(
                      latitude: _fields['latitude']?.text ?? '',
                      longitude: value,
                    ),
              ),
            ),
          ],
        ),
        FilledButton(
          onPressed: widget.controller.confirmActivityPin,
          child: Text(
            activity.location.pinConfirmed
                ? 'Pin confirmed'
                : 'Confirm this pin',
          ),
        ),
        TextFormField(
          controller: _field('addressLine', activity.location.addressLine ?? ''),
          decoration: const InputDecoration(labelText: 'Address line (optional)'),
          onChanged: widget.controller.updateActivityAddressLine,
        ),
        TextFormField(
          controller: _field('accessNotes', activity.location.accessNotes),
          decoration: const InputDecoration(labelText: 'Access notes'),
          maxLines: 2,
          onChanged: widget.controller.updateActivityAccessNotes,
        ),
        SwitchListTile(
          title: const Text('This is not an official spot'),
          value: isInformal,
          onChanged: (bool value) => widget.controller.updateActivityAccessCaution(
            isInformal: value,
            note: caution?.note,
          ),
        ),
        if (isInformal)
          TextFormField(
            controller: _field('accessCautionNote', caution?.note ?? ''),
            decoration: const InputDecoration(
              labelText: 'What to know before you go',
            ),
            maxLines: 2,
            onChanged: (String value) => widget.controller
                .updateActivityAccessCaution(isInformal: true, note: value),
          ),
        TextFormField(
          controller: _field('linkedPlaceId', activity.location.linkedPlaceId ?? ''),
          decoration: const InputDecoration(
            labelText: 'Linked Place id (optional)',
          ),
          onChanged: widget.controller.updateActivityLinkedPlaceId,
        ),
        SwitchListTile(
          title: const Text('It is customary to leave something here'),
          value: contribution != null,
          onChanged: (bool value) {
            if (value) {
              widget.controller.updateActivityOptionalContribution(
                kind: ActivityContributionKind.donation,
              );
            } else {
              widget.controller.clearActivityOptionalContribution();
            }
          },
        ),
        if (contribution != null) ...<Widget>[
          DropdownButtonFormField<ActivityContributionKind>(
            initialValue: contribution.kind,
            decoration: const InputDecoration(labelText: 'Contribution kind'),
            items: const <DropdownMenuItem<ActivityContributionKind>>[
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.purchase,
                child: Text('Purchase (e.g. coffee at the counter)'),
              ),
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.donation,
                child: Text('Donation'),
              ),
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.other,
                child: Text('Other'),
              ),
            ],
            onChanged: (ActivityContributionKind? kind) {
              if (kind != null) {
                widget.controller.updateActivityOptionalContribution(
                  kind: kind,
                  note: contribution.note,
                  amountMinor: contribution.amountHint?.amountMinor,
                );
              }
            },
          ),
          TextFormField(
            controller: _field('contributionNote', contribution.note ?? ''),
            decoration: const InputDecoration(
              labelText: 'e.g. "Coffee on the counter, optional"',
            ),
            onChanged: (String value) => widget.controller
                .updateActivityOptionalContribution(
                  kind: contribution.kind,
                  note: value,
                  amountMinor: contribution.amountHint?.amountMinor,
                ),
          ),
          TextFormField(
            controller: _field(
              'contributionAmountHint',
              contribution.amountHint == null
                  ? ''
                  : (contribution.amountHint!.amountMinor / 100).toStringAsFixed(2),
            ),
            decoration: const InputDecoration(labelText: 'Approximate amount (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) {
              final double? parsed = double.tryParse(value.replaceAll(',', '.'));
              widget.controller.updateActivityOptionalContribution(
                kind: contribution.kind,
                note: contribution.note,
                amountMinor: parsed == null ? null : (parsed * 100).round(),
              );
            },
          ),
        ],
        for (final ActivityValidationIssue issue in _issuesFor('location'))
          Text(issue.messageKey, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_location_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart apps/mobile/test/widget/activity_create_block_location_test.dart
git commit -m "feat(create): add ActivityCreateBlock Location & Access step"
```

---

## Task 15: `ActivityCreateBlock` — Step 3 (When & For Whom) + Step 4 (Preview & Publish) + navigation

**Files:**
- Modify: `apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart` (`_whenForStep`, `_publishStep`, `_navigation`)
- Test: `apps/mobile/test/widget/activity_create_block_publish_test.dart`

**Interfaces:**
- Consumes: `updateActivityBestTime`, `updateActivityTypicalDuration`, `updateActivitySuggestedGroupSize`, `clearActivitySuggestedGroupSize`, `goToActivityStep`, `publishDraft` (Task 10), `GetCategoryCriteriaUseCase` (existing).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/widget/activity_create_block_publish_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

// Same harness as Task 13/14; drive to activityStep 3 with a fully valid
// draft (mirror the "fully valid draft" fixture from Task 2's usecase test,
// applied through controller mutators).

void main() {
  testWidgets('publish button is present on the final step and does not show a price field', (
    WidgetTester tester,
  ) async {
    // Pump ActivityCreateBlock at activityStep 3 with a valid draft.
    // expect(find.text('Send for review'), findsOneWidget);
    // expect(find.textContaining('Price'), findsNothing);
    // expect(find.textContaining('Expected spend'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_publish_test.dart`
Expected: FAIL — `_publishStep`/`_navigation` currently return empty widgets.

- [ ] **Step 3: Implement**

Replace the three stubs:

```dart
  Widget _whenForStep(ActivityDraftData activity, CreateDraftEntity draft) {
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      draft.subcategory,
    );
    final ActivityIntRangeDraft? groupSize = activity.suggestedGroupSize;
    return _StepCard(
      title: 'When is it best, and how long does it take?',
      children: <Widget>[
        DropdownButtonFormField<ActivityTimeOfDay>(
          initialValue: activity.bestTime?.timeOfDay,
          decoration: const InputDecoration(labelText: 'Best time of day (optional)'),
          items: <DropdownMenuItem<ActivityTimeOfDay>>[
            for (final ActivityTimeOfDay value in ActivityTimeOfDay.values)
              DropdownMenuItem<ActivityTimeOfDay>(value: value, child: Text(value.name)),
          ],
          onChanged: (ActivityTimeOfDay? value) => widget.controller.updateActivityBestTime(
            timeOfDay: value,
            season: activity.bestTime?.season,
          ),
        ),
        DropdownButtonFormField<ActivitySeason>(
          initialValue: activity.bestTime?.season,
          decoration: const InputDecoration(labelText: 'Best season (optional)'),
          items: <DropdownMenuItem<ActivitySeason>>[
            for (final ActivitySeason value in ActivitySeason.values)
              DropdownMenuItem<ActivitySeason>(value: value, child: Text(value.name)),
          ],
          onChanged: (ActivitySeason? value) => widget.controller.updateActivityBestTime(
            timeOfDay: activity.bestTime?.timeOfDay,
            season: value,
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _field(
                  'durationMin',
                  activity.typicalDurationMinutes.min.toString(),
                ),
                decoration: const InputDecoration(labelText: 'Typical duration, min (minutes)'),
                keyboardType: TextInputType.number,
                onChanged: (String value) {
                  final int? min = int.tryParse(value);
                  if (min != null) {
                    widget.controller.updateActivityTypicalDuration(
                      min: min,
                      max: activity.typicalDurationMinutes.max,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _field(
                  'durationMax',
                  activity.typicalDurationMinutes.max.toString(),
                ),
                decoration: const InputDecoration(labelText: 'Typical duration, max (minutes)'),
                keyboardType: TextInputType.number,
                onChanged: (String value) {
                  final int? max = int.tryParse(value);
                  if (max != null) {
                    widget.controller.updateActivityTypicalDuration(
                      min: activity.typicalDurationMinutes.min,
                      max: max,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('Suggest a group size'),
          value: groupSize != null,
          onChanged: (bool value) {
            if (value) {
              widget.controller.updateActivitySuggestedGroupSize(min: 1, max: 10);
            } else {
              widget.controller.clearActivitySuggestedGroupSize();
            }
          },
        ),
        if (groupSize != null)
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _field('groupMin', groupSize.min.toString()),
                  decoration: const InputDecoration(labelText: 'Group, min people'),
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? min = int.tryParse(value);
                    if (min != null) {
                      widget.controller.updateActivitySuggestedGroupSize(
                        min: min,
                        max: groupSize.max,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _field('groupMax', groupSize.max.toString()),
                  decoration: const InputDecoration(labelText: 'Group, max people'),
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? max = int.tryParse(value);
                    if (max != null) {
                      widget.controller.updateActivitySuggestedGroupSize(
                        min: groupSize.min,
                        max: max,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        if (criteria != null)
          for (final RechargeCriteriaFieldDefinition field in criteria.fields)
            TextFormField(
              controller: _field('criteria.${field.id}', ''),
              decoration: InputDecoration(labelText: field.id),
              onChanged: (String value) => widget.controller.updateCriteriaField(
                field.id,
                value,
              ),
            ),
        for (final ActivityValidationIssue issue in _issuesFor('whenFor'))
          Text(issue.messageKey, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }

  Widget _publishStep(CreateDraftEntity draft, ActivityDraftData activity) {
    return _StepCard(
      title: 'Preview and publish',
      children: <Widget>[
        Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
        Text(draft.shortDescription),
        Text('${activity.typicalDurationMinutes.min}–${activity.typicalDurationMinutes.max} min'),
        if (activity.location.accessCaution?.isInformal ?? false)
          Text(
            activity.location.accessCaution!.note ?? '',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final ActivityValidationIssue issue in widget.state.activityValidationIssues)
          Text(issue.messageKey, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }

  Widget _navigation() {
    final int step = widget.state.activityStep;
    final bool isLast = step == activityCreateSteps.length - 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (step > 0)
            TextButton(
              onPressed: () => widget.controller.goToActivityStep(step - 1),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          FilledButton(
            onPressed: isLast
                ? () async {
                    final bool published = await widget.controller.publishDraft();
                    if (published) widget.onPublished();
                  }
                : () => widget.controller.goToActivityStep(step + 1),
            child: Text(isLast ? 'Send for review' : 'Save & continue'),
          ),
        ],
      ),
    );
  }
```

> `widget.controller.updateCriteriaField(String, String)` — verify the real generic criteria-write method name on `CreateController` (used by `_DynamicCriteriaSection` in `create_page.dart` and `place_create_block.dart`'s `_criteriaFields`) before using it here; it must already exist since Place/Event both drive criteria through it.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_publish_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run all activity widget tests together**

Run: `cd apps/mobile && flutter test test/widget/activity_create_block_test.dart test/widget/activity_create_block_location_test.dart test/widget/activity_create_block_publish_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart apps/mobile/test/widget/activity_create_block_publish_test.dart
git commit -m "feat(create): add ActivityCreateBlock When/For-Whom + Publish steps"
```

---

## Task 16: Wire `ActivityCreateBlock` into `CreatePage` (spec AC #5)

**Files:**
- Modify: `apps/mobile/lib/features/create/presentation/pages/create_page.dart`
- Test: `apps/mobile/test/widget/create_page_activity_routing_test.dart`

**Interfaces:**
- Consumes: `ActivityCreateBlock` (Tasks 13–15).
- Produces: selecting `Recharge activity` in Create Hub now renders the dedicated 4-step block instead of the generic form.

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/widget/create_page_activity_routing_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

// Same harness as create_page_test.dart's existing place-routing case.

void main() {
  testWidgets('CreatePage renders ActivityCreateBlock for CreateObjectType.activity', (
    WidgetTester tester,
  ) async {
    // Pump CreatePage with a test controller whose draft.objectType is
    // CreateObjectType.activity (via controller.setObjectType(...)).
    // expect(find.byType(ActivityCreateBlock), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/widget/create_page_activity_routing_test.dart`
Expected: FAIL — `activity` currently falls into the generic `else` branch, not a dedicated widget.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/create/presentation/pages/create_page.dart`:

1. Add import: `import '../widgets/activity_create_block.dart';`
2. In the `switch (state.draft.objectType)` chain (the sequence of `if (... == CreateObjectType.place) ... else if (... == CreateObjectType.findPeople) ...` etc., around lines 184–252), add a new branch **before** the generic `else` fallback, following the exact same shape as the `place`/`findPeople` branches:

```dart
    } else if (state.draft.objectType == CreateObjectType.activity) {
      return ActivityCreateBlock(
        controller: controller,
        state: state,
        onPublished: onPublished,
      );
```

> Read the exact surrounding `if`/`else if` chain first — match its real variable names (`controller`, `state`, `onPublished` or whatever the enclosing method's parameters are actually called) rather than assuming. Insert the new branch in the same position/shape as the `findPeople` branch (right after it, before `route`), since Activity, like FindPeople, needs no map/routing dependencies from that point in the chain.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/widget/create_page_activity_routing_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Run the full suite**

Run: `cd apps/mobile && flutter test`
Expected: PASS, no regressions on other object types' routing.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/create/presentation/pages/create_page.dart apps/mobile/test/widget/create_page_activity_routing_test.dart
git commit -m "feat(create): route CreateObjectType.activity to ActivityCreateBlock (AC #5)"
```

---

## Task 17: Category picker regression test (spec AC #6)

**Files:**
- Test: `apps/mobile/test/unit/activity_category_filter_test.dart`

**Interfaces:**
- Consumes: `createTaxonomyForObjectType` (existing, `create_taxonomy.dart`).

AC #6 is already satisfied by the existing generic taxonomy filter (`createTaxonomyForObjectType(CreateObjectType.activity)` already filters by the real `applicableTypes`/flag-`A` data, per the codebase survey — `activity` is one of the six types genuinely filtered, unlike `findPeople`/`quickPlan`/`collection`). This task only needs a regression test locking that behavior against spec §8's table, so a future taxonomy change can't silently break it.

- [ ] **Step 1: Write the test**

```dart
// apps/mobile/test/unit/activity_category_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity taxonomy includes wellness_recharge and outdoor_nature_walking (flag A, §8)', () {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final Set<String> categoryIds = categories
        .map((CreateTaxonomyCategory c) => c.contentGroup.id)
        .toSet();
    expect(categoryIds, contains('wellness_recharge'));
    expect(categoryIds, contains('outdoor_nature_walking'));
    expect(categoryIds, contains('sport'));
  });

  test('activity taxonomy excludes a category with no flag A (music_nightlife, per §7.1 of CATEGORY_SYSTEM.md)', () {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final Set<String> categoryIds = categories
        .map((CreateTaxonomyCategory c) => c.contentGroup.id)
        .toSet();
    expect(categoryIds, isNot(contains('music_nightlife')));
  });
}
```

> Verify the real category ids for `wellness_recharge`/`outdoor_nature_walking`/`sport`/`music_nightlife` against `apps/mobile/lib/core/config/recharge_taxonomy_seed.dart` before finalizing — use whatever the actual seed ids are if they differ from the spec's §8 shorthand.

- [ ] **Step 2: Run test**

Run: `cd apps/mobile && flutter test test/unit/activity_category_filter_test.dart`
Expected: PASS immediately (no production code change needed — this locks existing correct behavior). If it fails, that is itself a real finding: stop and report it rather than "fixing" the test to match broken behavior.

- [ ] **Step 3: Commit**

```bash
git add apps/mobile/test/unit/activity_category_filter_test.dart
git commit -m "test(create): lock activity category-picker flag-A filtering (AC #6)"
```

---

## Task 18: Discover mapping for `activity` (spec AC #7)

**Files:**
- Modify: `apps/mobile/lib/features/discover/data/datasources/discover_remote_datasource.dart` (mock feed only — add one `activity` fixture entry)
- Test: `apps/mobile/test/unit/discover_activity_item_test.dart`

**Interfaces:**
- Consumes: `DiscoverItemModel`, `DiscoverItemEntity`, `DiscoverObjectKind.activity` (existing — already the enum default), `DiscoverRepositoryImpl` filters (existing).

Discover is still fully mock/local for every Create type except Route (per `LAUNCH_STATUS.md`, "Discover — mock-данные"); there is no live publish→feed bridge for Place/Event/FindPeople either. AC #7 is scoped here to the mapping contract an Activity item must satisfy once it does enter Discover data — proven with one mock fixture + filter tests, matching the precedent set by `DiscoverRepositoryImpl._routeItem` (`priceAmount: 0, isFree: true` for objects with no formal price).

- [ ] **Step 1: Write the failing test**

```dart
// apps/mobile/test/unit/discover_activity_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';

// Reuse the existing DiscoverRepositoryImpl test fixture/mock datasource
// setup from discover_repository_impl_test.dart (read it first).

void main() {
  test('an activity mock item is free, evergreen and duration-filterable', () {
    // final repository = buildTestDiscoverRepository(); // existing test helper
    // final results = await repository.search(DiscoverQuery.empty().copyWith(
    //   availableDurationMinutes: 60,
    //   freeOnly: true,
    // ));
    // final activityItem = results.firstWhere(
    //   (DiscoverItemEntity item) => item.objectKind == DiscoverObjectKind.activity,
    // );
    // expect(activityItem.isFree, isTrue);
    // expect(activityItem.priceAmount, 0);
    // expect(activityItem.availabilityKind, AvailabilityKind.none);
    // expect(activityItem.durationMinutes, isNotNull);
  });

  test('a long activity is excluded when availableDurationMinutes is too short', () {
    // Seed a mock activity item with durationMinutes: 180, query availableDurationMinutes: 60,
    // expect it to be filtered out (same code path event/place already use).
  });
}
```

> Read `discover_repository_impl_test.dart`'s existing fixture-building helper first (it already seeds event/place/route mock items — reuse that pattern rather than inventing new plumbing) and adapt the commented setup to its real API.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/unit/discover_activity_item_test.dart`
Expected: FAIL — no `activity`-kind mock item exists in the feed yet.

- [ ] **Step 3: Implement**

In `apps/mobile/lib/features/discover/data/datasources/discover_remote_datasource.dart`, inside `_buildMockFeed()`, add one fixture entry alongside the existing `event`/`route`/`place` templates, with the object-kind-specific fields set per the mapping rule this AC requires:

```dart
    <String, Object?>{
      'id': 'mock-activity-coffee-walk',
      'object_kind': 'activity',
      'title': 'Coffee walk by the canal',
      // ...copy the remaining required generic fields (category, geo,
      // description, cover image, etc.) from the shape of an existing
      // 'event' or 'place' fixture entry in this same file...
      'duration_minutes': 45,
      'duration_confidence': 'estimated',
      'availability_kind': 'none',
      'price_amount': 0,
      'is_free': true,
      'starts_at_utc': null, // or the fixture's published/creation timestamp,
                              // matching how `_routeItem` substitutes
                              // `route.publishedAtUtc` for a technical date —
                              // read that call site's exact handling of a
                              // non-nullable `startsAtUtc` field before
                              // deciding null vs a stamped fallback here.
    },
```

> `DiscoverItemModel.fromMap`'s exact required-vs-nullable field list must be checked (already partly surfaced: `priceAmount`/`isFree` are `required`; `startsAtUtc` was flagged as non-nullable in the survey) — if `starts_at_utc` truly cannot be null, use a fixed fixture timestamp instead, exactly mirroring how `_routeItem` handles the same non-nullable field for a date-less object.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/unit/discover_activity_item_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/discover/data/datasources/discover_remote_datasource.dart apps/mobile/test/unit/discover_activity_item_test.dart
git commit -m "feat(discover): add activity mock item satisfying time/free filters (AC #7)"
```

---

## Task 19: Status docs — `LAUNCH_STATUS.md` + `AGENTS.md` (spec AC #10)

**Files:**
- Modify: `docs/architecture/LAUNCH_STATUS.md`
- Modify: `AGENTS.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update `LAUNCH_STATUS.md`**

Add a new row to the Slice Tracker table (after the `ACT-CRT-SPEC-01` row), following the exact column format of neighboring rows:

```
| ACT-CRT-01 | Recharge Activity Create implementation | Done | 2026-08-17 | Implemented the Approved `RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.3 local/mock vertical: typed `ActivityDraftData` (own domain entity, mapper, validation usecase, mirroring `PlaceDraftData`); corrected `CreateBlockConfig` (`requiresStartDateTime = false`, no price label, `locationLabel = 'Where to go'`); lightweight `Location` variant with mandatory `accessNotes` and conditional `accessCaution` (no mandatory Place link); optional non-Pricing `optionalContribution`; `bestTime`/`typicalDurationMinutes`/`suggestedGroupSize`; a dedicated 4-step Create UI (`ActivityCreateBlock`); full §12 validation matrix including a local/mock soft threshold for the 4th+ informal-access card (`moderationStatus = flaggedForReview`, publish not blocked); category picker reuses the existing flag-`A` taxonomy filter unchanged; Discover mock feed gained one `activity` item satisfying the Time-available/Free-only filter contract. No Firebase, network, paid service, Search quick-scenario or Home rail was added (§16.1 is explicitly out of scope for this slice, not one of the 10 AC). Verification: `flutter analyze --no-pub` 0 issues; full `flutter test --no-pub` <N> passed; boundary gate passed with 59 existing allowlist suppressions and no new violation; scoped `git diff --check` passed. |
```

Replace `<N>` with the actual full-suite pass count from Task 21's verification run — do not guess it.

- [ ] **Step 2: Update `AGENTS.md`**

In the "Статусы фич" table, `Create Hub: 10 типов` row, replace the clause:

```
Recharge Activity получил Approved slice spec `ACT-CRT-01` (`RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.3, 2026-08-17) — evergreen без даты/Pricing, облегчённая Location с `accessCaution`/`optionalContribution`, целевая `bestTime`; код ещё не написан, текущий generic `CreateBlockConfig` (`requiresStartDateTime = true`, `priceLabel`) ему пока противоречит и подлежит правке в рамках `ACT-CRT-01`
```

with:

```
Recharge Activity реализован по `RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.3 (`ACT-CRT-01` Done) — собственный typed `ActivityDraftData`, облегчённая Location с `accessCaution`/`optionalContribution`, `bestTime`, 4-шаговый Create UI; `CreateBlockConfig` приведён в соответствие целевой модели (`requiresStartDateTime = false`, без price label)
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/LAUNCH_STATUS.md AGENTS.md
git commit -m "docs: mark ACT-CRT-01 Done in LAUNCH_STATUS and AGENTS status table"
```

---

## Task 20: Final verification gate (spec AC #8, #9)

**Files:** none (verification only).

- [ ] **Step 1: Full analyzer**

Run: `cd apps/mobile && flutter analyze --no-pub`
Expected: 0 issues.

- [ ] **Step 2: Full test suite**

Run: `cd apps/mobile && flutter test --no-pub`
Expected: all tests pass; record the exact pass count for Task 19's `LAUNCH_STATUS.md` entry.

- [ ] **Step 3: Boundary gate**

Run from repo root: `dart tools/scripts/check_boundaries.dart --repo-root . --format text` (or the Windows wrapper `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\scripts\check-boundaries.ps1`).
Expected: passes with the existing 59 allowlisted suppressions and no new violation.

- [ ] **Step 4: Diff/whitespace check**

Run: `git diff --check`
Expected: clean (aside from pre-existing line-ending warnings, if any were already present on the branch).

- [ ] **Step 5: If Task 19 recorded a placeholder `<N>` pass count, fix it now with the real number from Step 2, and commit the correction.**

```bash
git add docs/architecture/LAUNCH_STATUS.md
git commit -m "docs: record actual ACT-CRT-01 verification test count"
```

- [ ] **Step 6: Report** — state plainly which gates are green, and if any is not, say so with the actual output rather than proceeding to declare the slice Done.

---

## Self-Review Notes (already applied above, kept for the executor's awareness)

- **§16.1 "Recharge now" quick-scenario and §17 Discover card badge are intentionally excluded** — not among spec §18's 10 numbered AC items, called out explicitly in Global Constraints and again in Task 18. If the product owner disagrees with this scoping, that's a one-line addendum to this plan (a new Task 21), not a reason to block Tasks 1–20.
- **Task 2/10/11's exact test harness calls are placeholders for "the real existing test fixture"** — every `place_*_test.dart` referenced must be read before writing the corresponding activity test, because this codebase's test-controller/repository construction helpers were not fully dumped by the exploration pass. This is intentional: copying an unread, guessed-at fixture signature would violate "No Placeholders" harder than flagging the exact file to read first.
- **Money convention**: confirmed `EventMoneyDraft{amountMinor:int, currencyCode:String}` is the live convention (not `PlacePricingDraft`'s older `double`); `ActivityContributionAmountDraft` in Task 1 follows it.
- **`replaceLocalIds` on `ActivityDraftData` is a real, intentional no-op**, not a stub — documented inline in Task 1 and exercised by Task 12's test for interface parity with the publish pipeline.
