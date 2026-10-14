import '../../../core/config/recharge_taxonomy.dart';
import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/usecases/build_collection_content_body.dart';
import '../domain/usecases/build_place_content_body.dart';
import '../domain/usecases/build_rental_content_body.dart';
import '../domain/usecases/content_server_readiness.dart';
import 'create_taxonomy.dart';
import 'place_create_config.dart';

/// Server publication requirements of the user's Create draft (M1 stage 3,
/// owner decisions Р-09 and 3-Б): the draft goes through the same mapper the
/// publication path sends, and the readiness ports answer with the server's
/// public code and field. Used by the publication controllers before submit
/// and by the Create form while the type's server path is enabled; the local
/// Create rules stay as they are. A draft that cannot be mapped (no publisher,
/// unsupported content) has no requirements here: the publication path
/// refuses it with its own code.
List<ContentValidationViolation> placeServerRequirements(
  CreateDraftEntity draft, {
  required String accountId,
  required String marketCurrencyCode,
  String? serverOwnerUserId,
  Map<String, String> assetIds = const <String, String>{},
  PlaceContentBodyMapper mapper = const PlaceContentBodyMapper(),
}) {
  final PublisherRef? ref = draft.placeData?.publisherRef;
  if (draft.objectType != CreateObjectType.place ||
      ref == null ||
      !ref.isValid) {
    return const <ContentValidationViolation>[];
  }
  final PlaceContentBody mapped = mapper.map(
    draft,
    scope: PlacePublicationScope(
      accountId: accountId,
      publisherRef: ref,
      localDraftId: draft.id,
    ),
    policy: placeCreationPolicyFor(draft.subcategory),
    serverOwnerUserId: serverOwnerUserId ?? accountId,
    assetIds: assetIds,
  );
  return placeServerReadiness(
    mapped.body,
    marketCurrencyCode: marketCurrencyCode,
  );
}

List<ContentValidationViolation> rentalServerRequirements(
  CreateDraftEntity draft, {
  required String accountId,
  required DateTime nowUtc,
  String? serverActorUserId,
  Map<String, String> assetIds = const <String, String>{},
  RentalContentBodyMapper mapper = const RentalContentBodyMapper(),
}) {
  final PublisherRef? ref = draft.rentalData?.publisherRef;
  if (draft.objectType != CreateObjectType.rental ||
      ref == null ||
      !ref.isValid) {
    return const <ContentValidationViolation>[];
  }
  final RentalContentBody mapped = mapper.map(
    draft,
    scope: RentalPublicationScope(
      accountId: accountId,
      publisherRef: ref,
      localDraftId: draft.id,
    ),
    localAccountId: accountId,
    serverActorUserId: serverActorUserId ?? accountId,
    assetIds: assetIds,
  );
  return rentalServerReadiness(mapped.body, nowUtc: nowUtc);
}

List<ContentValidationViolation> collectionServerRequirements(
  CreateDraftEntity draft, {
  required String accountId,
  int reviewedRevision = 0,
  Map<String, String> assetIds = const <String, String>{},
  CollectionContentBodyMapper mapper = const CollectionContentBodyMapper(),
}) {
  final PublisherRef? ref = draft.collectionData?.publisherRef;
  if (draft.objectType != CreateObjectType.collection ||
      ref == null ||
      !ref.isValid) {
    return const <ContentValidationViolation>[];
  }
  final CollectionContentBody mapped = mapper.map(
    draft,
    scope: CollectionPublicationScope(
      accountId: accountId,
      publisherRef: ref,
      localDraftId: draft.id,
    ),
    reviewedRevision: reviewedRevision,
    assetIds: assetIds,
  );
  return collectionServerReadiness(
    mapped.body,
    subcategoryApplies: (String category, String subcategory) =>
        canonicalSubcategoryApplies(
          RechargeContentType.collection,
          category,
          subcategory,
        ),
  );
}
