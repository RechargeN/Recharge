import '../entities/place_enrichment_proposal.dart';
import '../repositories/place_enrichment_port.dart';

enum PlaceEnrichmentFailureCode { invalidProposal }

class PlaceEnrichmentFailure implements Exception {
  const PlaceEnrichmentFailure(this.code, this.message);

  final PlaceEnrichmentFailureCode code;
  final String message;

  @override
  String toString() => 'PlaceEnrichmentFailure($code, $message)';
}

class GeneratePlaceEnrichmentProposalUseCase {
  const GeneratePlaceEnrichmentProposalUseCase(this._port);

  final PlaceEnrichmentPort _port;

  Future<PlaceEnrichmentProposal> call(PlaceEnrichmentRequest request) async {
    final PlaceEnrichmentProposal proposal = await _port.generate(request);
    final Set<String> allowedPaths = request.allowedTaxonomy
        .map(
          (PlaceTaxonomyOption option) =>
              '${option.categoryId}/${option.subcategoryId}',
        )
        .toSet();
    final String? categoryId = proposal.suggestedCategoryId;
    final String? subcategoryId = proposal.suggestedSubcategoryId;
    final bool taxonomyPairIsValid =
        categoryId == null && subcategoryId == null ||
        categoryId != null &&
            subcategoryId != null &&
            allowedPaths.contains('$categoryId/$subcategoryId');
    final bool invalid =
        proposal.id.trim().isEmpty ||
        proposal.mode != PlaceEnrichmentMode.localDemo ||
        proposal.sourceRevision != request.sourceRevision ||
        !taxonomyPairIsValid ||
        (proposal.suggestedShortDescription?.length ?? 0) > 180 ||
        (proposal.suggestedVisitMinutes ?? 1) <= 0;
    if (invalid) {
      throw const PlaceEnrichmentFailure(
        PlaceEnrichmentFailureCode.invalidProposal,
        'The local Place helper returned an invalid proposal.',
      );
    }
    return proposal;
  }
}
