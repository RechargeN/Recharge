import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/collection_draft_data.dart';
import '../entities/collection_publication_data.dart';
import '../entities/create_draft_entity.dart';

/// Assembles the single canonical publish bundle (§12) from an already
/// validated, composition-reviewed draft. Never called directly by UI —
/// the coordinator runs `ValidateCollectionDraftUseCase` first and only
/// calls this on a clean result.
class BuildCollectionPublicationBundleUseCase {
  const BuildCollectionPublicationBundleUseCase({required this.idGenerator});

  final IdGenerator idGenerator;

  CollectionPublishBundle call({
    required CreateDraftEntity draft,
    required String publishAttemptId,
    // §12 idempotency: a replay must rebuild the exact same payload the
    // datasource hashed the first time, not just reuse `publishAttemptId`
    // — otherwise a fresh `collectionVersionId` here would change the
    // payload hash on every call and turn every retry into a spurious
    // `idempotencyConflict` instead of a `replayedIdempotentSuccess`. The
    // coordinator passes the version id it minted for this same attempt
    // when retrying; a first attempt leaves this null and gets a fresh one.
    String? collectionVersionId,
  }) {
    if (draft.objectType != CreateObjectType.collection) {
      throw ArgumentError('Draft is not a Collection draft.');
    }
    final CollectionDraftData? data = draft.collectionData;
    if (data == null) {
      throw ArgumentError('Collection draft is missing collectionData.');
    }
    final CollectionCompositionReview? review = data.compositionReview;
    if (review == null) {
      throw StateError(
        'Cannot publish without a fresh CollectionCompositionReview (§9).',
      );
    }
    // Temporary `loc_*` drafts get a permanent id at first publish (ADR
    // id-only invariant); an existing Collection keeps its id across
    // versions.
    final String collectionId = draft.id.startsWith('loc_')
        ? idGenerator.generate()
        : draft.id;
    return CollectionPublishBundle(
      collectionId: collectionId,
      collectionVersionId: collectionVersionId ?? idGenerator.generate(),
      publisherRef: data.publisherRef,
      title: draft.title,
      shortDescription: draft.shortDescription,
      fullDescription: draft.fullDescription,
      coverMediaId: draft.media.coverImage.isEmpty
          ? null
          : draft.media.coverImage,
      marketCityId: draft.marketCityId,
      areaLabel: data.areaLabel,
      areaId: data.areaId,
      budgetTier: data.budgetTier,
      visibility: draft.visibility.name,
      sections: List<CollectionSectionDraft>.unmodifiable(data.sections),
      items: List.unmodifiable(data.items),
      compositionReview: review,
      publishAttemptId: publishAttemptId,
    );
  }
}
