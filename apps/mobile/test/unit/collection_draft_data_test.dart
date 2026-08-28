import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');

CollectionItemDraft _item(
  String objectId, {
  CollectionCatalogObjectType type = CollectionCatalogObjectType.place,
  String? sectionId,
  CollectionSourceStatus status = CollectionSourceStatus.ready,
}) {
  return CollectionItemDraft(
    id: 'item_$objectId',
    ref: CollectionObjectRef(objectId: objectId, objectType: type),
    snapshot: const CollectionItemSnapshotDraft(title: 'Title'),
    sourceStatus: status,
    order: 0,
    sectionId: sectionId,
  );
}

void main() {
  group('CollectionObjectRef', () {
    test('stableKey combines type and id', () {
      const ref = CollectionObjectRef(
        objectId: 'p1',
        objectType: CollectionCatalogObjectType.place,
      );
      expect(ref.stableKey, 'place:p1');
    });

    test('only excludes collection/scenario/event/activity/findPeople by construction', () {
      // The enum itself is the invariant: it has exactly the five values
      // approved for CLG-CRT-01 (§3.12, §9). If this list ever grows beyond
      // five, that is itself the decision this test guards.
      expect(CollectionCatalogObjectType.values, hasLength(5));
      expect(
        CollectionCatalogObjectType.values.map((t) => t.name).toSet(),
        <String>{'place', 'route', 'bookableSession', 'classWorkshop', 'rental'},
      );
    });

    test('equality and hashCode are structural', () {
      const a = CollectionObjectRef(
        objectId: 'p1',
        objectType: CollectionCatalogObjectType.place,
      );
      const b = CollectionObjectRef(
        objectId: 'p1',
        objectType: CollectionCatalogObjectType.place,
      );
      const c = CollectionObjectRef(
        objectId: 'p1',
        objectType: CollectionCatalogObjectType.route,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('CollectionItemDraft.copyWith', () {
    test('clearSectionId nulls the section back out', () {
      final item = _item('p1', sectionId: 's1');
      final cleared = item.copyWith(clearSectionId: true);
      expect(cleared.sectionId, isNull);
      expect(item.sectionId, 's1', reason: 'original must stay unchanged');
    });

    test('updates curatorNote and highlight independently', () {
      final item = _item('p1');
      final updated = item.copyWith(curatorNote: 'Why visit', highlight: true);
      expect(updated.curatorNote, 'Why visit');
      expect(updated.highlight, isTrue);
      expect(updated.ref, item.ref);
    });
  });

  group('CollectionDraftData', () {
    test('defaults() starts with an empty, unreviewed draft', () {
      final draft = CollectionDraftData.defaults(publisherRef: _publisher);
      expect(draft.schemaVersion, CollectionDraftData.currentSchemaVersion);
      expect(draft.items, isEmpty);
      expect(draft.sections, isEmpty);
      expect(draft.budgetTier, isNull);
      expect(draft.compositionReview, isNull);
    });

    test('copyWith replaces items without mutating the original', () {
      final draft = CollectionDraftData.defaults(publisherRef: _publisher);
      final withItems = draft.copyWith(items: <CollectionItemDraft>[_item('p1')]);
      expect(draft.items, isEmpty);
      expect(withItems.items, hasLength(1));
    });

    test('clearAreaId/clearBudgetTier/clearCompositionReview null the field back out', () {
      final draft = CollectionDraftData.defaults(
        publisherRef: _publisher,
      ).copyWith(
        areaId: 'riga_old_town',
        budgetTier: CollectionBudgetTier.medium,
        compositionReview: CollectionCompositionReview(
          draftRevision: 1,
          reviewedAtUtc: DateTime.utc(2026),
          acknowledgedUnavailableStableKeys: const <String>{},
        ),
      );
      expect(draft.areaId, 'riga_old_town');
      expect(draft.budgetTier, CollectionBudgetTier.medium);
      expect(draft.compositionReview, isNotNull);

      final cleared = draft.copyWith(
        clearAreaId: true,
        clearBudgetTier: true,
        clearCompositionReview: true,
      );
      expect(cleared.areaId, isNull);
      expect(cleared.budgetTier, isNull);
      expect(cleared.compositionReview, isNull);
    });
  });
}
