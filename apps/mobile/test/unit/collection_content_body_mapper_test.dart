import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_collection_content_body.dart';

import '../fixtures/create/user_collection_draft.dart';

/// D3.4 §5.2, §5.3, §5.5: the Create Collection draft -> Content Collection
/// body. Every Create case produces exactly the body of the shared fixture
/// (whose validator codes the backend test proves); references are sent as
/// they are; nothing is invented; and a draft the server could never accept
/// as reviewed is refused locally.
void main() {
  const CollectionContentBodyMapper mapper = CollectionContentBodyMapper();

  CollectionPublicationScope scope({
    String account = collectionCompatAccountId,
    String page = collectionCompatPageId,
    String localDraftId = 'local-collection-1',
  }) => CollectionPublicationScope(
    accountId: account,
    publisherRef: PublisherRef(type: PublisherType.page, id: page),
    localDraftId: localDraftId,
  );

  CreateDraftEntity draft({
    Set<String>? acknowledged = const <String>{},
    VisibilityType visibility = VisibilityType.public,
    Map<String, Object?> unknownFields = const <String, Object?>{},
    List<CollectionFixtureMember>? members,
  }) => userCollectionDraft(
    pageId: collectionCompatPageId,
    members: members ?? collectionCompatMembers(),
    acknowledged: acknowledged,
    visibility: visibility,
    unknownFields: unknownFields,
  );

  test('every Create case maps to exactly the body of the shared fixture', () {
    final Map<String, Object?> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'collection_create_compat.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final List<Object?> cases = fixture['cases']! as List<Object?>;
    final Map<String, CollectionCompatCase> byName =
        <String, CollectionCompatCase>{
          for (final CollectionCompatCase item in collectionCompatCases())
            item.name: item,
        };
    expect(cases, hasLength(byName.length));
    for (final Object? raw in cases) {
      final Map<String, Object?> item = raw! as Map<String, Object?>;
      final CollectionCompatCase compat = byName[item['name']]!;
      final CollectionPublicationScope current = scope(
        localDraftId: compat.draft.id,
      );
      final CollectionContentBody mapped = mapper.map(
        compat.draft,
        scope: current,
        reviewedRevision: fixture['reviewedRevision']! as int,
        assetIds: <String, String>{
          current.coverAttachmentId: fixture['coverAssetId']! as String,
        },
      );
      expect(mapped.unsupported, isEmpty, reason: compat.name);
      expect(
        jsonDecode(jsonEncode(mapped.body)),
        item['body'],
        reason: compat.name,
      );
      expect(
        (item['unavailableStableKeys']! as List<Object?>).toSet(),
        compat.unavailable,
        reason: compat.name,
      );
    }
  });

  test('ids are UUIDv5 of the scope: stable for an item, never shared', () {
    final CollectionPublicationScope current = scope();
    expect(
      CollectionPublicationScope.namespace,
      'cc088011-4f89-400c-b2cd-ebbf22fbcdc8',
    );
    // Cross-checked with Python `uuid.uuid5`.
    expect(
      current.sectionId('loc_section_parks'),
      'cee4983d-36fc-5438-b815-051304169bc8',
    );
    expect(
      current.itemId('loc_item_1'),
      '684271e5-d16e-5683-927e-af9b5086c72b',
    );
    expect(
      scope(account: 'account-b').itemId('loc_item_1'),
      isNot(current.itemId('loc_item_1')),
    );
    expect(
      scope(page: 'page-b').itemId('loc_item_1'),
      isNot(current.itemId('loc_item_1')),
    );
    expect(current.keyBase, startsWith('clp1-'));
    expect(current.keyBase, hasLength(5 + 24));

    // Reordering items keeps every id; the body follows the draft's order.
    final CreateDraftEntity ordered = draft();
    final CreateDraftEntity reversed = ordered.copyWith(
      collectionData: ordered.collectionData!.copyWith(
        items: ordered.collectionData!.items.reversed.toList(),
      ),
    );
    List<Object?> idsOf(CreateDraftEntity value) =>
        (mapper.map(value, scope: current, reviewedRevision: 2).body['items']!
                as List<Map<String, Object?>>)
            .map((Map<String, Object?> item) => item['id'])
            .toList();
    expect(idsOf(reversed), idsOf(ordered).reversed.toList());
  });

  test(
    'references, every allowed item type and the review are sent as they are',
    () {
      final CreateDraftEntity current = draft(
        members: <CollectionFixtureMember>[
          for (final (int index, CollectionCatalogObjectType type)
              in CollectionCatalogObjectType.values.indexed)
            CollectionFixtureMember(
              objectId: 'b7a9c1d2-0000-4000-8000-00000000e00$index',
              objectType: type,
            ),
        ],
      );
      final Map<String, Object?> body = mapper
          .map(current, scope: scope(), reviewedRevision: 5)
          .body;
      expect(
        (body['items']! as List<Map<String, Object?>>)
            .map((Map<String, Object?> item) => item['ref'])
            .toList(),
        <Object?>[
          for (final (int index, CollectionCatalogObjectType type)
              in CollectionCatalogObjectType.values.indexed)
            <String, Object?>{
              'objectId': 'b7a9c1d2-0000-4000-8000-00000000e00$index',
              'objectType': type.name,
            },
        ],
      );
      expect(
        (body['compositionReview']! as Map<String, Object?>)['draftRevision'],
        5,
      );
    },
  );

  test('before upload the cover is a local placeholder the server refuses', () {
    final CollectionPublicationScope current = scope();
    final Map<String, Object?> media =
        mapper.map(draft(), scope: current, reviewedRevision: 2).body['media']!
            as Map<String, Object?>;
    expect(media['coverImage'], <String, Object?>{
      'mediaId': 'loc_${current.coverAttachmentId}',
    });
  });

  test('snapshots carry no geo and never the source object media id', () {
    final CreateDraftEntity base = draft();
    final CollectionItemDraft first = base.collectionData!.items.first;
    final CreateDraftEntity withMedia = base.copyWith(
      collectionData: base.collectionData!.copyWith(
        items: <CollectionItemDraft>[
          first.copyWith(
            snapshot: CollectionItemSnapshotDraft(
              title: first.snapshot.title,
              coverMediaId: 'foreign-place-cover',
              categoryLabel: 'Parks',
              publisherRef: const PublisherRef(
                type: PublisherType.page,
                id: 'page-owner',
              ),
              priceFromMinorUnits: 0,
              currency: 'EUR',
            ),
          ),
          ...base.collectionData!.items.skip(1),
        ],
      ),
    );
    final Map<String, Object?> snapshot =
        (mapper
                        .map(withMedia, scope: scope(), reviewedRevision: 2)
                        .body['items']!
                    as List<Map<String, Object?>>)
                .first['snapshot']!
            as Map<String, Object?>;
    expect(snapshot, <String, Object?>{
      'title': first.snapshot.title,
      'categoryLabel': 'Parks',
      'publisherRef': <String, Object?>{'type': 'page', 'id': 'page-owner'},
      'priceFromMinorUnits': 0,
      'currency': 'EUR',
    });
  });

  test('what the server could never accept is refused locally', () {
    String unsupported(CreateDraftEntity value) => mapper
        .map(value, scope: scope(), reviewedRevision: 2)
        .unsupported
        .join(',');
    expect(unsupported(draft()), isEmpty);
    expect(unsupported(draft(acknowledged: null)), 'composition_review');
    // An unavailable item the review did not acknowledge.
    expect(
      unsupported(
        draft(
          members: collectionCompatMembers(
            second: CollectionSourceStatus.unavailable,
          ),
        ),
      ),
      'composition_review_stale',
    );
    // An acknowledgement of an item no longer in the draft.
    expect(
      unsupported(draft(acknowledged: <String>{'place:gone'})),
      'composition_review_stale',
    );
    expect(
      unsupported(draft(visibility: VisibilityType.private)),
      'visibility.private',
    );
    expect(
      unsupported(draft(unknownFields: <String, Object?>{'future': 1})),
      'unknown_fields',
    );
  });
}
