import '../entities/place_enrichment_proposal.dart';

abstract class PlaceEnrichmentPort {
  Future<PlaceEnrichmentProposal> generate(PlaceEnrichmentRequest request);
}
