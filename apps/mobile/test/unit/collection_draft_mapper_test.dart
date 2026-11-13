import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/collection_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');

CollectionDraftData _defaults() =>
    CollectionDraftData.defaults(publisherRef: _publisher);

void main() {
  test('fromJson on a non-map value returns the given defaults untouched', () {
    final defaults = _defaults();
    expect(CollectionDraftMapper.fromJson(null, defaults: defaults), same(defaults));
    expect(CollectionDraftMapper.fromJson('nope', defaults: defaults), same(defaults));
  });

  test('round-trips a fully populated draft', () {
    final original = _defaults().copyWith(
      areaLabel: 'Old Riga',
      areaId: 'riga_old_town',
      budgetTier: CollectionBudgetTier.medium,
      sections: const <CollectionSectionDraft>[
        CollectionSectionDraft(id: 's1', title: 'Top sights', order: 0),
      ],
      items: <CollectionItemDraft>[
        CollectionItemDraft(
          id: 'item1',
          ref: const CollectionObjectRef(
            objectId: 'place1',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'A nice place',
            coverMediaId: 'media1',
            categoryLabel: 'cafe',
            publisherRef: const PublisherRef(type: PublisherType.page, id: 'p1'),
            priceFromMinorUnits: 1500,
            currency: 'EUR',
            checkedAtUtc: DateTime.utc(2026, 1, 2, 3),
          ),
          sourceStatus: CollectionSourceStatus.ready,
          order: 0,
          sectionId: 's1',
          curatorNote: 'Great coffee',
          highlight: true,
        ),
      ],
      compositionReview: CollectionCompositionReview(
        draftRevision: 4,
        reviewedAtUtc: DateTime.utc(2026, 2, 1),
        acknowledgedUnavailableStableKeys: const <String>{'route:r1'},
      ),
    );

    final json = CollectionDraftMapper.toJson(original);
    final restored = CollectionDraftMapper.fromJson(json, defaults: _defaults());

    expect(restored.areaLabel, original.areaLabel);
    expect(restored.areaId, original.areaId);
    expect(restored.budgetTier, original.budgetTier);
    expect(restored.publisherRef, original.publisherRef);
    expect(restored.sections, hasLength(1));
    expect(restored.sections.single.id, 's1');
    expect(restored.items, hasLength(1));
    final CollectionItemDraft item = restored.items.single;
    expect(item.ref.stableKey, 'place:place1');
    expect(item.curatorNote, 'Great coffee');
    expect(item.highlight, isTrue);
    expect(item.sectionId, 's1');
    expect(item.snapshot.title, 'A nice place');
    expect(item.snapshot.priceFromMinorUnits, 1500);
    expect(item.snapshot.publisherRef, const PublisherRef(type: PublisherType.page, id: 'p1'));
    expect(item.snapshot.checkedAtUtc, DateTime.utc(2026, 1, 2, 3));
    expect(restored.compositionReview?.draftRevision, 4);
    expect(
      restored.compositionReview?.acknowledgedUnavailableStableKeys,
      <String>{'route:r1'},
    );
  });

  test('unknown top-level fields round-trip instead of being dropped', () {
    final json = CollectionDraftMapper.toJson(_defaults());
    json['future_field'] = 'from a newer minor version';

    final restored = CollectionDraftMapper.fromJson(json, defaults: _defaults());

    expect(restored.unknownFields['future_field'], 'from a newer minor version');
    expect(
      CollectionDraftMapper.toJson(restored)['future_field'],
      'from a newer minor version',
    );
  });

  test('an unsupported future major schema version is rejected, not guessed at', () {
    final json = CollectionDraftMapper.toJson(_defaults());
    json['schema_version'] = CollectionDraftData.currentSchemaVersion + 1;

    expect(
      () => CollectionDraftMapper.fromJson(json, defaults: _defaults()),
      throwsFormatException,
    );
  });

  test('an item missing a required field is dropped rather than crashing', () {
    final json = CollectionDraftMapper.toJson(_defaults());
    json['items'] = <Map<String, Object?>>[
      <String, Object?>{'id': 'broken'}, // no object_id/object_type/order
    ];

    final restored = CollectionDraftMapper.fromJson(json, defaults: _defaults());

    expect(restored.items, isEmpty);
  });
}
