import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/place_enrichment_coordinator.dart';
import 'package:recharge/features/create/data/datasources/place_enrichment_mock_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/place_creation_policy.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_enrichment_proposal.dart';
import 'package:recharge/features/create/domain/repositories/place_enrichment_port.dart';
import 'package:recharge/features/create/domain/usecases/generate_place_enrichment_proposal_usecase.dart';

void main() {
  test(
    'local helper proposes approved monument taxonomy without invented facts',
    () async {
      final PlaceEnrichmentCoordinator coordinator = PlaceEnrichmentCoordinator(
        generateProposal: GeneratePlaceEnrichmentProposalUseCase(
          MockPlaceEnrichmentDataSource(),
        ),
      );
      final CreateDraftEntity draft = _placeDraft(title: 'Памятник Свободы');

      final PlaceEnrichmentProposal proposal = await coordinator.generate(
        draft,
      );

      expect(proposal.mode, PlaceEnrichmentMode.localDemo);
      expect(proposal.suggestedCategoryId, 'art_culture_museums');
      expect(proposal.suggestedSubcategoryId, 'monument');
      expect(proposal.suggestedKind, PlaceKind.pointOfInterest);
      expect(proposal.suggestedShortDescription, isNotEmpty);
      expect(
        proposal.disclosures,
        contains(
          'Hours, prices, accessibility and amenities were not inferred.',
        ),
      );
      expect(draft.mainCategory, isEmpty);
      expect(draft.shortDescription, isEmpty);
      expect(draft.placeData!.revision, 0);
    },
  );

  test(
    'apply is revision-safe and does not overwrite creator description',
    () async {
      final PlaceEnrichmentCoordinator coordinator = PlaceEnrichmentCoordinator(
        generateProposal: GeneratePlaceEnrichmentProposalUseCase(
          MockPlaceEnrichmentDataSource(),
        ),
      );
      final CreateDraftEntity draft = _placeDraft(
        title: 'Freedom Monument',
        shortDescription: 'Creator supplied description',
      );
      final PlaceEnrichmentProposal proposal = await coordinator.generate(
        draft,
      );

      final CreateDraftEntity applied = coordinator.apply(draft, proposal);

      expect(applied.subcategory, 'monument');
      expect(applied.placeData!.placeKind, PlaceKind.pointOfInterest);
      expect(applied.shortDescription, 'Creator supplied description');
      expect(applied.placeData!.revision, 1);
      expect(
        () => coordinator.apply(
          draft.copyWith(placeData: draft.placeData!.nextRevision()),
          proposal,
        ),
        throwsA(isA<PlaceEnrichmentStaleFailure>()),
      );
    },
  );

  test(
    'use case rejects taxonomy outside the approved request options',
    () async {
      const GeneratePlaceEnrichmentProposalUseCase generate =
          GeneratePlaceEnrichmentProposalUseCase(_InvalidTaxonomyPort());
      const PlaceEnrichmentRequest request = PlaceEnrichmentRequest(
        title: 'A place',
        shortDescription: '',
        locationLabel: 'Riga',
        city: 'Riga',
        currentCategoryId: '',
        currentSubcategoryId: '',
        currentProfileId: PlaceCreationProfileId.balanced,
        sourceRevision: 4,
        allowedTaxonomy: <PlaceTaxonomyOption>[
          PlaceTaxonomyOption(
            categoryId: 'art_culture_museums',
            subcategoryId: 'monument',
            label: 'Monument',
          ),
        ],
      );

      await expectLater(
        generate(request),
        throwsA(
          isA<PlaceEnrichmentFailure>().having(
            (PlaceEnrichmentFailure failure) => failure.code,
            'code',
            PlaceEnrichmentFailureCode.invalidProposal,
          ),
        ),
      );
    },
  );
}

CreateDraftEntity _placeDraft({
  required String title,
  String shortDescription = '',
}) {
  final CreateDraftEntity common = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'creator@example.test',
    organizerName: 'Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final PlaceDraftData place =
      PlaceDraftData.defaults(
        userId: 'user-1',
        marketCityId: 'riga',
        countryCode: 'LV',
        city: 'Riga',
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      ).copyWith(
        location: const PlaceLocationDraft(
          marketCityId: 'riga',
          countryCode: 'LV',
          city: 'Riga',
          timezoneId: 'Europe/Riga',
          formattedAddress: 'Brivibas bulvaris',
          latitude: 56.9515,
          longitude: 24.1133,
          accuracy: PlaceLocationAccuracy.rooftop,
          pinConfirmed: true,
        ),
      );
  return common.copyWith(
    objectType: CreateObjectType.place,
    title: title,
    shortDescription: shortDescription,
    mainCategory: '',
    subcategory: '',
    placeData: place,
  );
}

class _InvalidTaxonomyPort implements PlaceEnrichmentPort {
  const _InvalidTaxonomyPort();

  @override
  Future<PlaceEnrichmentProposal> generate(
    PlaceEnrichmentRequest request,
  ) async {
    return PlaceEnrichmentProposal(
      id: 'invalid-taxonomy',
      mode: PlaceEnrichmentMode.localDemo,
      sourceRevision: request.sourceRevision,
      generatedAtUtc: DateTime.utc(2026, 7, 31),
      confidence: PlaceEnrichmentConfidence.estimated,
      evidence: const <PlaceEnrichmentEvidence>[],
      disclosures: const <String>[],
      missingRecommendedFieldIds: const <String>[],
      suggestedCategoryId: 'unknown',
      suggestedSubcategoryId: 'invented',
    );
  }
}
