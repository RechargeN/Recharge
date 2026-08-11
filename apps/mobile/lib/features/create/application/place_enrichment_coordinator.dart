import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/place_enrichment_proposal.dart';
import '../domain/entities/place_creation_policy.dart';
import '../domain/entities/place_draft_data.dart';
import '../domain/usecases/generate_place_enrichment_proposal_usecase.dart';
import 'create_taxonomy.dart';
import 'place_create_config.dart';

class PlaceEnrichmentStaleFailure implements Exception {
  const PlaceEnrichmentStaleFailure();

  @override
  String toString() => 'PlaceEnrichmentStaleFailure(source revision changed)';
}

class PlaceEnrichmentCoordinator {
  const PlaceEnrichmentCoordinator({
    required GeneratePlaceEnrichmentProposalUseCase generateProposal,
  }) : _generateProposal = generateProposal;

  final GeneratePlaceEnrichmentProposalUseCase _generateProposal;

  Future<PlaceEnrichmentProposal> generate(CreateDraftEntity draft) {
    final PlaceDraftData place = draft.placeData!;
    return _generateProposal(
      PlaceEnrichmentRequest(
        title: draft.title,
        shortDescription: draft.shortDescription,
        locationLabel: place.location.locationLabel ?? '',
        city: place.location.city,
        currentCategoryId: draft.mainCategory,
        currentSubcategoryId: draft.subcategory,
        currentProfileId: placeCreationPolicyFor(draft.subcategory).id,
        sourceRevision: place.revision,
        allowedTaxonomy: <PlaceTaxonomyOption>[
          for (final CreateTaxonomyCategory category
              in createTaxonomyForObjectType(CreateObjectType.place))
            for (final CreateTaxonomySubcategory subcategory
                in category.subcategories)
              PlaceTaxonomyOption(
                categoryId: category.id,
                subcategoryId: subcategory.id,
                label: '${category.title} / ${subcategory.title}',
              ),
        ],
      ),
    );
  }

  CreateDraftEntity apply(
    CreateDraftEntity draft,
    PlaceEnrichmentProposal proposal,
  ) {
    final PlaceDraftData place = draft.placeData!;
    if (place.revision != proposal.sourceRevision) {
      throw const PlaceEnrichmentStaleFailure();
    }
    final String nextCategory =
        proposal.suggestedCategoryId ?? draft.mainCategory;
    final String nextSubcategory =
        proposal.suggestedSubcategoryId ?? draft.subcategory;
    final PlaceCreationPolicy nextPolicy = placeCreationPolicyFor(
      nextSubcategory,
    );
    final PlaceKind nextKind =
        proposal.suggestedKind ?? place.placeKind ?? nextPolicy.suggestedKind;
    final PlaceRelationship nextRelationship =
        place.relationshipToPlace ?? PlaceRelationship.visitor;
    final PlaceDraftData nextPlace = place
        .copyWith(
          placeKind: nextKind,
          relationshipToPlace: nextRelationship,
          categoryConfirmed: nextSubcategory.isNotEmpty,
          visitPlanning:
              place.visitPlanning.recommendedVisitMinutes == null &&
                  proposal.suggestedVisitMinutes != null
              ? place.visitPlanning.copyWith(
                  recommendedVisitMinutes: proposal.suggestedVisitMinutes,
                )
              : place.visitPlanning,
        )
        .nextRevision();
    return draft.copyWith(
      mainCategory: nextCategory,
      subcategory: nextSubcategory,
      shortDescription: draft.shortDescription.trim().isEmpty
          ? (proposal.suggestedShortDescription ?? '')
          : draft.shortDescription,
      placeData: nextPlace,
      availabilityKind: nextPolicy.hours == PlaceFieldRequirement.hidden
          ? CreateAvailabilityKind.none
          : draft.availabilityKind,
      updatedAtUtc: DateTime.now().toUtc(),
    );
  }
}
