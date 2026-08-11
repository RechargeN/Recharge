import '../entities/create_draft_entity.dart';
import '../entities/route_draft_save_result.dart';

abstract interface class RouteDraftPersistenceRepository {
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  });
}
