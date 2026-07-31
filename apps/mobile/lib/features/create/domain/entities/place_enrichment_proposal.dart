import 'place_creation_policy.dart';
import 'place_draft_data.dart';

enum PlaceEnrichmentMode { localDemo }

enum PlaceEnrichmentConfidence { taxonomyRule, estimated, unresolved }

class PlaceTaxonomyOption {
  const PlaceTaxonomyOption({
    required this.categoryId,
    required this.subcategoryId,
    required this.label,
  });

  final String categoryId;
  final String subcategoryId;
  final String label;
}

class PlaceEnrichmentRequest {
  const PlaceEnrichmentRequest({
    required this.title,
    required this.shortDescription,
    required this.locationLabel,
    required this.city,
    required this.currentCategoryId,
    required this.currentSubcategoryId,
    required this.currentProfileId,
    required this.sourceRevision,
    required this.allowedTaxonomy,
  });

  final String title;
  final String shortDescription;
  final String locationLabel;
  final String city;
  final String currentCategoryId;
  final String currentSubcategoryId;
  final PlaceCreationProfileId currentProfileId;
  final int sourceRevision;
  final List<PlaceTaxonomyOption> allowedTaxonomy;
}

class PlaceEnrichmentEvidence {
  const PlaceEnrichmentEvidence({
    required this.label,
    required this.confidence,
  });

  final String label;
  final PlaceEnrichmentConfidence confidence;
}

class PlaceEnrichmentProposal {
  const PlaceEnrichmentProposal({
    required this.id,
    required this.mode,
    required this.sourceRevision,
    required this.generatedAtUtc,
    required this.confidence,
    required this.evidence,
    required this.disclosures,
    required this.missingRecommendedFieldIds,
    this.suggestedKind,
    this.suggestedCategoryId,
    this.suggestedSubcategoryId,
    this.suggestedShortDescription,
    this.suggestedVisitMinutes,
    this.clarifyingQuestion,
  });

  final String id;
  final PlaceEnrichmentMode mode;
  final int sourceRevision;
  final DateTime generatedAtUtc;
  final PlaceEnrichmentConfidence confidence;
  final List<PlaceEnrichmentEvidence> evidence;
  final List<String> disclosures;
  final List<String> missingRecommendedFieldIds;
  final PlaceKind? suggestedKind;
  final String? suggestedCategoryId;
  final String? suggestedSubcategoryId;
  final String? suggestedShortDescription;
  final int? suggestedVisitMinutes;
  final String? clarifyingQuestion;

  bool get canApply =>
      suggestedKind != null ||
      suggestedCategoryId != null ||
      suggestedSubcategoryId != null ||
      suggestedShortDescription != null ||
      suggestedVisitMinutes != null;
}
