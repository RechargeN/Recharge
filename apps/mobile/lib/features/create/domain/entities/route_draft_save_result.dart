enum RouteDraftSaveStatus { saved, conflict, invalidDraft, superseded }

class RouteDraftSaveResult {
  const RouteDraftSaveResult({
    required this.status,
    required this.requestedRevision,
    this.persistedRevision,
  });

  final RouteDraftSaveStatus status;
  final int requestedRevision;
  final int? persistedRevision;

  bool get isSaved => status == RouteDraftSaveStatus.saved;
}
