import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/collection_draft_data.dart';
import '../entities/collection_item_draft.dart';
import '../entities/create_draft_entity.dart';
import '../entities/publisher_ref.dart';

/// Stable ids and keys of one Collection publication (D3.4 §5.5): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, another publisher or another
/// draft can never reuse them, and every save of the same draft repeats them.
final class CollectionPublicationScope {
  CollectionPublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.4 §5.5; fixed here and in the tests.
  static const String namespace = 'cc088011-4f89-400c-b2cd-ebbf22fbcdc8';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:collection-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

  /// Stable for the local item, not its position: reordering keeps every id.
  String itemId(String localItemId) => _id('item:$localItemId');

  String sectionId(String localSectionId) => _id('section:$localSectionId');

  String get coverAttachmentId => _id('attachment:cover');

  String galleryAttachmentId(String localMediaRef) =>
      _id('attachment:gallery:$localMediaRef');

  /// The Media intent of one exact upload: same attachment and bytes, same id.
  String uploadIntentId(String attachmentId, String sha256Hex) =>
      _id('upload:$attachmentId:$sha256Hex');

  /// Prefix of every Content idempotency key of this publication.
  String get keyBase =>
      'clp1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One medium of the Collection: the cover or a gallery photo of the draft.
final class CollectionMediaAttachment {
  const CollectionMediaAttachment({
    required this.attachmentId,
    required this.role,
    required this.localRef,
  });

  final String attachmentId;

  /// `cover` or `gallery`.
  final String role;

  /// The reference in the Create draft (a local file).
  final String localRef;
}

final class CollectionContentBody {
  const CollectionContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the Content Collection body cannot carry, or a review the
  /// server would never accept; a draft that has any is not sent at all.
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<CollectionMediaAttachment> attachments;
}

/// Maps a Create Collection draft to the Content Collection body (D3.4 §5.2,
/// §5.3). Items keep their exact `{objectId, objectType}` reference: whether
/// the object is an allowed published object is decided by the server
/// (Catalog-owned membership), never here. Nothing is invented: a value the
/// draft does not hold is not sent, and the server's own rules decide the rest.
final class CollectionContentBodyMapper {
  const CollectionContentBodyMapper();

  /// [reviewedRevision] is the server draft revision this save will produce
  /// (`expectedRevision + 1`): the composition review belongs to exactly it.
  CollectionContentBody map(
    CreateDraftEntity draft, {
    required CollectionPublicationScope scope,
    required int reviewedRevision,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final CollectionDraftData? data = draft.collectionData;
    if (draft.objectType != CreateObjectType.collection || data == null) {
      throw ArgumentError('Not a Collection draft');
    }
    final CollectionCompositionReview? review = data.compositionReview;
    final Set<String> itemKeys = data.items
        .map((CollectionItemDraft item) => item.ref.stableKey)
        .toSet();
    final Set<String> unavailableKeys = data.items
        .where(
          (CollectionItemDraft item) =>
              item.sourceStatus == CollectionSourceStatus.unavailable,
        )
        .map((CollectionItemDraft item) => item.ref.stableKey)
        .toSet();
    final List<String> unsupported = <String>[
      if (data.unknownFields.isNotEmpty) 'unknown_fields',
      if (draft.visibility == VisibilityType.private) 'visibility.private',
      if (review == null) 'composition_review',
      if (review != null &&
          (!itemKeys.containsAll(review.acknowledgedUnavailableStableKeys) ||
              !review.acknowledgedUnavailableStableKeys.containsAll(
                unavailableKeys,
              )))
        'composition_review_stale',
    ];
    final List<CollectionMediaAttachment> attachments = attachmentsOf(
      draft,
      scope,
    );
    String mediaId(CollectionMediaAttachment item) =>
        assetIds[item.attachmentId] ?? 'loc_${item.attachmentId}';
    String? text(String value) => value.trim().isEmpty ? null : value.trim();

    final Map<String, Object?> body = <String, Object?>{
      'title': draft.title.trim(),
      if (text(draft.shortDescription) case final String value)
        'shortDescription': value,
      if (text(draft.fullDescription) case final String value)
        'fullDescription': value,
      if (text(draft.mainCategory) case final String value) 'categoryId': value,
      if (text(draft.subcategory) case final String value)
        'subcategoryId': value,
      'media': <String, Object?>{
        for (final CollectionMediaAttachment item in attachments)
          if (item.role == 'cover')
            'coverImage': <String, Object?>{'mediaId': mediaId(item)},
        'gallery': <Map<String, Object?>>[
          for (final CollectionMediaAttachment item in attachments)
            if (item.role == 'gallery')
              <String, Object?>{'mediaId': mediaId(item)},
        ],
      },
      if (text(data.areaLabel) case final String value) 'areaLabel': value,
      if (data.areaId case final String value when value.trim().isNotEmpty)
        'areaId': value.trim(),
      if (data.anchorLatitude != null && data.anchorLongitude != null)
        'anchor': <String, Object?>{
          'latitude': data.anchorLatitude,
          'longitude': data.anchorLongitude,
        },
      if (data.budgetTier != null) 'budgetTier': data.budgetTier!.name,
      'visibility': draft.visibility.name,
      'sections': <Map<String, Object?>>[
        for (final CollectionSectionDraft section in data.sections)
          <String, Object?>{
            'id': scope.sectionId(section.id),
            'title': section.title.trim(),
            'order': section.order,
          },
      ],
      'items': <Map<String, Object?>>[
        for (final CollectionItemDraft item in data.items) _item(item, scope),
      ],
      if (review != null)
        'compositionReview': <String, Object?>{
          'draftRevision': reviewedRevision,
          'reviewedAtUtc': review.reviewedAtUtc.toUtc().toIso8601String(),
          'acknowledgedUnavailableStableKeys':
              review.acknowledgedUnavailableStableKeys.toList()..sort(),
        },
    };
    return CollectionContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  /// The draft's media in body order: the cover, then the gallery as ordered
  /// in the draft, each with its stable attachment id (§5.5).
  List<CollectionMediaAttachment> attachmentsOf(
    CreateDraftEntity draft,
    CollectionPublicationScope scope,
  ) => <CollectionMediaAttachment>[
    if (draft.media.coverImage.trim().isNotEmpty)
      CollectionMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: draft.media.coverImage,
      ),
    for (final String ref in draft.media.gallery)
      CollectionMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];

  /// One item: its own stable id, the exact reference, the geo-free fallback
  /// snapshot (never the source's cover media id: another publisher's Media is
  /// not attachable to this revision), order, section and curation.
  static Map<String, Object?> _item(
    CollectionItemDraft item,
    CollectionPublicationScope scope,
  ) {
    final CollectionItemSnapshotDraft snapshot = item.snapshot;
    final PublisherRef? publisher = snapshot.publisherRef;
    final String note = item.curatorNote.trim();
    return <String, Object?>{
      'id': scope.itemId(item.id),
      'ref': <String, Object?>{
        'objectId': item.ref.objectId,
        'objectType': item.ref.objectType.name,
      },
      'snapshot': <String, Object?>{
        'title': snapshot.title,
        if (snapshot.categoryLabel case final String value
            when value.trim().isNotEmpty)
          'categoryLabel': value,
        if (publisher != null)
          'publisherRef': <String, Object?>{
            'type': publisher.type.wireName,
            'id': publisher.id,
          },
        if (snapshot.priceFromMinorUnits != null)
          'priceFromMinorUnits': snapshot.priceFromMinorUnits,
        if (snapshot.currency case final String value
            when value.trim().isNotEmpty)
          'currency': value,
        if (snapshot.checkedAtUtc != null)
          'checkedAtUtc': snapshot.checkedAtUtc!.toUtc().toIso8601String(),
      },
      'sourceStatus': item.sourceStatus.name,
      'order': item.order,
      if (item.sectionId != null) 'sectionId': scope.sectionId(item.sectionId!),
      if (note.isNotEmpty) 'curatorNote': note,
      if (item.highlight) 'highlight': true,
    };
  }
}
