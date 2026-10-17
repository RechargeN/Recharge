import '../entities/scenario_draft_entity.dart';

abstract interface class QuickPlanRepository {
  Future<void> restore();
  Future<void> refresh(String id);
  Future<void> save(ScenarioDraftEntity plan, {required int expectedRevision});
  Future<void> delete(String id, {required int expectedRevision});
  Future<void> importJson(String source);
  ScenarioDraftEntity? cached(String id);
  int? serverRevision(String id);
  bool hasPending(String id);
  List<Map<String, Object?>> get conflicts;
  void clearVisible();
}
