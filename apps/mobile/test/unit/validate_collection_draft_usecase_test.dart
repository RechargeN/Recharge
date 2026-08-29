import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_validation_issue.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/validate_collection_draft_usecase.dart';

const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');
const _validate = ValidateCollectionDraftUseCase();

CollectionItemDraft _item(
  String objectId, {
  CollectionSourceStatus status = CollectionSourceStatus.ready,
  String? sectionId,
  String curatorNote = '',
}) {
  return CollectionItemDraft(
    id: 'item_$objectId',
    ref: CollectionObjectRef(
      objectId: objectId,
      objectType: CollectionCatalogObjectType.place,
    ),
    snapshot: const CollectionItemSnapshotDraft(title: 'Title'),
    sourceStatus: status,
    order: 0,
    sectionId: sectionId,
    curatorNote: curatorNote,
  );
}

CreateDraftEntity _draft({
  required CollectionDraftData? collectionData,
  String title = 'A guide',
}) {
  return CreateDraftEntity.defaults(
    organizerId: 'u1',
    organizerEmail: 'e@example.com',
    organizerName: 'n',
  ).copyWith(
    objectType: CreateObjectType.collection,
    title: title,
    collectionData: collectionData,
  );
}

List<CollectionItemDraft> _threeReadyItems() =>
    <CollectionItemDraft>[_item('p1'), _item('p2'), _item('p3')];

void main() {
  test('non-collection drafts are ignored', () {
    final draft = CreateDraftEntity.defaults(
      organizerId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(_validate(draft), isEmpty);
  });

  test('missing collectionData reports details_missing and stops early', () {
    final issues = _validate(_draft(collectionData: null));
    expect(issues, hasLength(1));
    expect(issues.single.code, 'details_missing');
  });

  test('empty title and areaLabel are both reported', () {
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      items: _threeReadyItems(),
      compositionReview: CollectionCompositionReview(
        draftRevision: 1,
        reviewedAtUtc: DateTime.utc(2026),
        acknowledgedUnavailableStableKeys: const <String>{},
      ),
    );
    final issues = _validate(_draft(collectionData: data, title: '  '));
    expect(issues.map((i) => i.code), containsAll(<String>['title_required', 'area_required']));
  });

  test('fewer than minPublishableItemCount items blocks with min_items', () {
    final data = CollectionDraftData.defaults(
      publisherRef: _publisher,
    ).copyWith(areaLabel: 'Riga', items: <CollectionItemDraft>[_item('p1')]);
    final issues = _validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('min_items'));
  });

  test('duplicate stableKey among items is reported', () {
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[_item('p1'), _item('p1'), _item('p2')],
    );
    final issues = _validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('duplicate_item'));
  });

  test('item pointing at a non-existent section is reported', () {
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        _item('p1', sectionId: 'missing'),
        _item('p2'),
        _item('p3'),
      ],
    );
    final issues = _validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('orphan_section'));
  });

  test('curatorNote over the configured limit is reported', () {
    final validate = const ValidateCollectionDraftUseCase(curatorNoteMaxLength: 5);
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        _item('p1', curatorNote: 'too long for the limit'),
        _item('p2'),
        _item('p3'),
      ],
    );
    final issues = validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('curator_note_length'));
  });

  test('curatorNote counts Unicode grapheme clusters, not UTF-16 code units', () {
    // A family emoji is one grapheme cluster but several UTF-16 code units.
    final validate = const ValidateCollectionDraftUseCase(curatorNoteMaxLength: 1);
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        _item('p1', curatorNote: '👨‍👩‍👧‍👦'),
        _item('p2'),
        _item('p3'),
      ],
    );
    final issues = validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), isNot(contains('curator_note_length')));
  });

  test('missing composition review blocks publish', () {
    final data = CollectionDraftData.defaults(
      publisherRef: _publisher,
    ).copyWith(areaLabel: 'Riga', items: _threeReadyItems());
    final issues = _validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('composition_review_missing'));
  });

  test('review that does not acknowledge a current unavailable item is stale', () {
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        _item('p1', status: CollectionSourceStatus.unavailable),
        _item('p2'),
        _item('p3'),
      ],
      compositionReview: CollectionCompositionReview(
        draftRevision: 1,
        reviewedAtUtc: DateTime.utc(2026),
        acknowledgedUnavailableStableKeys: const <String>{},
      ),
    );
    final issues = _validate(_draft(collectionData: data));
    expect(issues.map((i) => i.code), contains('composition_review_stale'));
  });

  test('a clean, reviewed, three-item draft has no issues', () {
    // Real curator notes, not the shared _threeReadyItems() fixture —
    // "clean" here also needs to clear the curator_note_empty soft
    // warning added for §11 (Вопрос 6/curator-note nudge).
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        _item('p1', curatorNote: 'Great coffee'),
        _item('p2', curatorNote: 'Lovely garden'),
        _item('p3', curatorNote: 'Historic route'),
      ],
      compositionReview: CollectionCompositionReview(
        draftRevision: 1,
        reviewedAtUtc: DateTime.utc(2026),
        acknowledgedUnavailableStableKeys: const <String>{},
      ),
    );
    expect(_validate(_draft(collectionData: data)), isEmpty);
  });

  test('warnings never block: high self-publisher share is reported but not blocking', () {
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: <CollectionItemDraft>[
        CollectionItemDraft(
          id: 'item_p1',
          ref: const CollectionObjectRef(
            objectId: 'p1',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'Mine',
            publisherRef: _publisher,
          ),
          sourceStatus: CollectionSourceStatus.ready,
          order: 0,
          curatorNote: 'Great coffee',
        ),
        _item('p2', curatorNote: 'Lovely garden'),
        _item('p3', curatorNote: 'Historic route'),
      ],
      compositionReview: CollectionCompositionReview(
        draftRevision: 1,
        reviewedAtUtc: DateTime.utc(2026),
        acknowledgedUnavailableStableKeys: const <String>{},
      ),
    );
    final validate = const ValidateCollectionDraftUseCase(
      selfPublisherShareWarningThreshold: 0.3,
    );
    final issues = validate(_draft(collectionData: data));
    expect(
      issues.where((i) => i.code == 'self_publisher_share_high').single.severity,
      CollectionValidationSeverity.warning,
    );
  });

  test('warnings never block: item count above the soft threshold is reported but not blocking', () {
    final items = List<CollectionItemDraft>.generate(
      5,
      (i) => _item('p$i', curatorNote: 'Note $i'),
    );
    final data = CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
      areaLabel: 'Riga',
      items: items,
      compositionReview: CollectionCompositionReview(
        draftRevision: 1,
        reviewedAtUtc: DateTime.utc(2026),
        acknowledgedUnavailableStableKeys: const <String>{},
      ),
    );
    final validate = const ValidateCollectionDraftUseCase(
      itemCountSoftWarningThreshold: 4,
    );
    final issues = validate(_draft(collectionData: data));
    expect(
      issues.where((i) => i.code == 'item_count_high').single.severity,
      CollectionValidationSeverity.warning,
    );
  });
}
