import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

/// Published member ids of the compatibility fixture (D3.4 §5.7). Fixed UUIDs:
/// the bodies are compared byte for byte with the shared JSON fixture.
const List<String> collectionCompatMemberIds = <String>[
  'b7a9c1d2-0000-4000-8000-00000000d341',
  'b7a9c1d2-0000-4000-8000-00000000d342',
  'b7a9c1d2-0000-4000-8000-00000000d343',
];

/// One member of a fixture draft: the referenced object, the local status the
/// Create preview recorded and the curation the author wrote.
final class CollectionFixtureMember {
  const CollectionFixtureMember({
    required this.objectId,
    this.objectType = CollectionCatalogObjectType.place,
    this.title,
    this.sourceStatus = CollectionSourceStatus.ready,
    this.curatorNote = '',
    this.highlight = false,
    this.inSection = false,
  });

  final String objectId;
  final CollectionCatalogObjectType objectType;
  final String? title;
  final CollectionSourceStatus sourceStatus;
  final String curatorNote;
  final bool highlight;
  final bool inSection;
}

/// A user's Collection draft as the Create flow stores it (D3.4 §5): Create
/// defaults plus what a user fills in, under the canonical taxonomy pair
/// `travel_tours/hidden_gems_tour`. Local item and section ids are `loc_*`;
/// it is not a backend body. [acknowledged] is the review the author recorded
/// in the Create preview (null: no review).
CreateDraftEntity userCollectionDraft({
  required String pageId,
  required List<CollectionFixtureMember> members,
  String coverPath = 'C:/photos/collection-cover.png',
  List<String> galleryPaths = const <String>[],
  String localId = 'local-collection-1',
  String title = 'Quiet corners of central Riga',
  String shortDescription = 'Three calm stops a short walk apart',
  String subcategory = 'hidden_gems_tour',
  String areaLabel = 'Riga centre',
  Set<String>? acknowledged = const <String>{},
  VisibilityType visibility = VisibilityType.public,
  Map<String, Object?> unknownFields = const <String, Object?>{},
}) {
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Stand Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  const String sectionId = 'loc_section_parks';
  int sectionOrder = 0;
  int looseOrder = 0;
  final List<CollectionItemDraft> items = <CollectionItemDraft>[
    for (final (int index, CollectionFixtureMember member) in members.indexed)
      CollectionItemDraft(
        id: 'loc_item_${index + 1}',
        ref: CollectionObjectRef(
          objectId: member.objectId,
          objectType: member.objectType,
        ),
        snapshot: CollectionItemSnapshotDraft(
          title: member.title ?? 'Stop ${index + 1}',
          checkedAtUtc: DateTime.utc(2026, 10, 12, 8),
        ),
        sourceStatus: member.sourceStatus,
        order: member.inSection ? sectionOrder++ : looseOrder++,
        sectionId: member.inSection ? sectionId : null,
        curatorNote: member.curatorNote,
        highlight: member.highlight,
      ),
  ];
  final bool anySection = members.any((member) => member.inSection);
  return base.copyWith(
    id: localId,
    objectType: CreateObjectType.collection,
    title: title,
    mainCategory: 'travel_tours',
    subcategory: subcategory,
    shortDescription: shortDescription,
    visibility: visibility,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
    collectionData: CollectionDraftData(
      schemaVersion: CollectionDraftData.currentSchemaVersion,
      publisherRef: PublisherRef(type: PublisherType.page, id: pageId),
      areaLabel: areaLabel,
      anchorLatitude: 56.9545,
      anchorLongitude: 24.1155,
      budgetTier: CollectionBudgetTier.free,
      sections: <CollectionSectionDraft>[
        if (anySection)
          const CollectionSectionDraft(id: sectionId, title: 'Parks', order: 0),
      ],
      items: items,
      compositionReview: acknowledged == null
          ? null
          : CollectionCompositionReview(
              draftRevision: 7,
              reviewedAtUtc: DateTime.utc(2026, 10, 12, 8, 30),
              acknowledgedUnavailableStableKeys: acknowledged,
            ),
      unknownFields: unknownFields,
    ),
  );
}

List<CollectionFixtureMember> collectionCompatMembers({
  CollectionSourceStatus second = CollectionSourceStatus.ready,
}) => <CollectionFixtureMember>[
  CollectionFixtureMember(
    objectId: collectionCompatMemberIds[0],
    title: 'Kronvalda park pond',
    curatorNote: 'Benches by the water',
    highlight: true,
    inSection: true,
  ),
  CollectionFixtureMember(
    objectId: collectionCompatMemberIds[1],
    title: 'Vērmanes garden fountain',
    sourceStatus: second,
    inSection: true,
  ),
  CollectionFixtureMember(
    objectId: collectionCompatMemberIds[2],
    title: 'Esplanāde chess corner',
  ),
];

/// One Create case of the shared compatibility fixture (§5.7): the draft and
/// the live status the server's Catalog would answer for each member.
final class CollectionCompatCase {
  const CollectionCompatCase({
    required this.name,
    required this.createCase,
    required this.draft,
    this.unavailable = const <String>{},
  });

  final String name;
  final String createCase;
  final CreateDraftEntity draft;

  /// Stable keys the Catalog reports as not ready (withheld) for this case.
  final Set<String> unavailable;
}

const String collectionCompatPageId = 'page-compat-1';
const String collectionCompatAccountId = 'account-compat-1';
const int collectionCompatReviewedRevision = 2;

String _key(int index) => 'place:${collectionCompatMemberIds[index]}';

List<CollectionCompatCase> collectionCompatCases() => <CollectionCompatCase>[
  CollectionCompatCase(
    name: 'valid',
    createCase: 'the accepted draft: three ready Places, canonical taxonomy',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
    ),
  ),
  CollectionCompatCase(
    name: 'withheld_acknowledged',
    createCase: 'a member hidden by its owner, acknowledged in the preview',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(
        second: CollectionSourceStatus.unavailable,
      ),
      acknowledged: <String>{_key(1)},
    ),
    unavailable: <String>{_key(1)},
  ),
  CollectionCompatCase(
    name: 'withheld_not_reviewed',
    createCase: 'a member hidden after the preview, which saw it ready',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
    ),
    unavailable: <String>{_key(1)},
  ),
  CollectionCompatCase(
    name: 'too_few_items',
    createCase: 'Create lets a draft hold two items',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers().take(2).toList(),
    ),
  ),
  CollectionCompatCase(
    name: 'area_missing',
    createCase: 'no area label',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
      areaLabel: '  ',
    ),
  ),
  CollectionCompatCase(
    name: 'short_description_missing',
    createCase: 'no short description',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
      shortDescription: '',
    ),
  ),
  CollectionCompatCase(
    name: 'cover_missing',
    createCase: 'no cover photo',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
      coverPath: '',
    ),
  ),
  CollectionCompatCase(
    name: 'subcategory_unknown',
    createCase: 'a subcategory absent from the canonical taxonomy',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: collectionCompatMembers(),
      subcategory: 'no_such_subcategory',
    ),
  ),
  CollectionCompatCase(
    name: 'curator_note_too_long',
    createCase: 'a legacy curator note over 300 graphemes',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: <CollectionFixtureMember>[
        CollectionFixtureMember(
          objectId: collectionCompatMemberIds[0],
          curatorNote: 'x' * 301,
        ),
        ...collectionCompatMembers().skip(1),
      ],
    ),
  ),
  CollectionCompatCase(
    name: 'local_object',
    createCase: 'an item that references an unsaved local object',
    draft: userCollectionDraft(
      pageId: collectionCompatPageId,
      members: <CollectionFixtureMember>[
        ...collectionCompatMembers().take(2),
        const CollectionFixtureMember(objectId: 'loc_place_draft_1'),
      ],
    ),
  ),
];
