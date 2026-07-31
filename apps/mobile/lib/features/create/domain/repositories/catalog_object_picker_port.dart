import '../entities/scenario_item_draft.dart';

class ScenarioCatalogObjectCandidate {
  const ScenarioCatalogObjectCandidate({
    required this.id,
    required this.objectType,
    required this.title,
    required this.subtitle,
    required this.durationMinutes,
    this.coverMediaId,
    this.publisherId,
  });

  final String id;
  final ScenarioCatalogObjectType objectType;
  final String title;
  final String subtitle;
  final int durationMinutes;
  final String? coverMediaId;
  final String? publisherId;
}

abstract class CatalogObjectPickerPort {
  Future<List<ScenarioCatalogObjectCandidate>> search(String query);
}
