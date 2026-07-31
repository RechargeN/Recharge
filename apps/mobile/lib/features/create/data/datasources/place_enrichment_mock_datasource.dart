import '../../domain/entities/place_creation_policy.dart';
import '../../domain/entities/place_enrichment_proposal.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/repositories/place_enrichment_port.dart';

class MockPlaceEnrichmentDataSource implements PlaceEnrichmentPort {
  int _sequence = 0;

  @override
  Future<PlaceEnrichmentProposal> generate(
    PlaceEnrichmentRequest request,
  ) async {
    final String haystack = '${request.title} ${request.locationLabel}'
        .toLowerCase();
    final _PlaceClassification? classification = _classify(
      haystack,
      request.allowedTaxonomy,
    );
    final String effectiveSubcategory =
        classification?.subcategoryId ?? request.currentSubcategoryId;
    final PlaceCreationProfileId profileId =
        classification?.profileId ?? request.currentProfileId;
    final List<String> missing = <String>[
      if (request.title.trim().isEmpty) 'title',
      if (request.currentSubcategoryId.isEmpty && classification == null)
        'subcategory',
      if (request.locationLabel.trim().isEmpty) 'locationLabel',
      if (request.shortDescription.trim().isEmpty) 'shortDescription',
    ];
    final String? description =
        request.shortDescription.trim().isEmpty &&
            request.title.trim().isNotEmpty &&
            effectiveSubcategory.isNotEmpty
        ? _description(
            title: request.title.trim(),
            city: request.city.trim(),
            subcategoryId: effectiveSubcategory,
          )
        : null;
    final bool simpleDestination =
        profileId == PlaceCreationProfileId.simplePoi ||
        profileId == PlaceCreationProfileId.naturalDestination ||
        profileId == PlaceCreationProfileId.publicSpace;

    return PlaceEnrichmentProposal(
      id: 'place-local-demo-${request.sourceRevision}-${++_sequence}',
      mode: PlaceEnrichmentMode.localDemo,
      sourceRevision: request.sourceRevision,
      generatedAtUtc: DateTime.now().toUtc(),
      confidence: classification == null
          ? PlaceEnrichmentConfidence.unresolved
          : PlaceEnrichmentConfidence.taxonomyRule,
      evidence: <PlaceEnrichmentEvidence>[
        if (classification != null)
          const PlaceEnrichmentEvidence(
            label: 'Matched title/location words to approved taxonomy',
            confidence: PlaceEnrichmentConfidence.taxonomyRule,
          ),
        if (description != null)
          const PlaceEnrichmentEvidence(
            label: 'Description is an editable draft based on submitted data',
            confidence: PlaceEnrichmentConfidence.estimated,
          ),
      ],
      disclosures: const <String>[
        'Local demo: no web or live place data were checked.',
        'Hours, prices, accessibility and amenities were not inferred.',
      ],
      missingRecommendedFieldIds: missing,
      suggestedKind: classification?.kind,
      suggestedCategoryId: classification?.categoryId,
      suggestedSubcategoryId: classification?.subcategoryId,
      suggestedShortDescription: description,
      suggestedVisitMinutes: simpleDestination ? 30 : null,
      clarifyingQuestion: classification == null
          ? 'What kind of place is this? Choose a category so the form can adapt.'
          : null,
    );
  }

  _PlaceClassification? _classify(
    String text,
    List<PlaceTaxonomyOption> options,
  ) {
    final List<_ClassificationRule> rules = <_ClassificationRule>[
      const _ClassificationRule(
        tokens: <String>['monument', 'памят', 'pieminekl'],
        subcategoryId: 'monument',
        kind: PlaceKind.pointOfInterest,
        profileId: PlaceCreationProfileId.simplePoi,
      ),
      const _ClassificationRule(
        tokens: <String>['memorial', 'мемориал', 'memoriāl'],
        subcategoryId: 'memorial',
        kind: PlaceKind.pointOfInterest,
        profileId: PlaceCreationProfileId.simplePoi,
      ),
      const _ClassificationRule(
        tokens: <String>['viewpoint', 'смотров', 'skatu'],
        subcategoryId: 'viewpoint',
        kind: PlaceKind.pointOfInterest,
        profileId: PlaceCreationProfileId.simplePoi,
      ),
      const _ClassificationRule(
        tokens: <String>['museum', 'музе', 'muzej'],
        subcategoryId: 'museum',
        kind: PlaceKind.managedVenue,
        profileId: PlaceCreationProfileId.culturalVenue,
      ),
      const _ClassificationRule(
        tokens: <String>['cafe', 'coffee', 'кафе', 'кофе', 'kafejn'],
        subcategoryId: 'cafe_visit',
        kind: PlaceKind.managedVenue,
        profileId: PlaceCreationProfileId.hospitality,
      ),
      const _ClassificationRule(
        tokens: <String>['park', 'парк', 'parks'],
        subcategoryId: 'park',
        kind: PlaceKind.publicSpace,
        profileId: PlaceCreationProfileId.publicSpace,
      ),
    ];
    for (final _ClassificationRule rule in rules) {
      if (!rule.tokens.any(text.contains)) continue;
      final PlaceTaxonomyOption? option = options
          .where(
            (PlaceTaxonomyOption item) =>
                item.subcategoryId == rule.subcategoryId,
          )
          .firstOrNull;
      if (option != null) {
        return _PlaceClassification(
          categoryId: option.categoryId,
          subcategoryId: option.subcategoryId,
          kind: rule.kind,
          profileId: rule.profileId,
        );
      }
    }
    return null;
  }

  String _description({
    required String title,
    required String city,
    required String subcategoryId,
  }) {
    final String kind = subcategoryId.replaceAll('_', ' ');
    return city.isEmpty
        ? '$title is a $kind. Review and add any useful local context.'
        : '$title is a $kind in $city. Review and add any useful local context.';
  }
}

class _ClassificationRule {
  const _ClassificationRule({
    required this.tokens,
    required this.subcategoryId,
    required this.kind,
    required this.profileId,
  });

  final List<String> tokens;
  final String subcategoryId;
  final PlaceKind kind;
  final PlaceCreationProfileId profileId;
}

class _PlaceClassification {
  const _PlaceClassification({
    required this.categoryId,
    required this.subcategoryId,
    required this.kind,
    required this.profileId,
  });

  final String categoryId;
  final String subcategoryId;
  final PlaceKind kind;
  final PlaceCreationProfileId profileId;
}
