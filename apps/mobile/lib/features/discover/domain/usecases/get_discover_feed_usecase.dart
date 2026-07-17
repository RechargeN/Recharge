import '../entities/discover_query.dart';
import '../entities/discover_item_entity.dart';
import '../repositories/discover_repository.dart';
import '../repositories/time_fit_evaluation_store.dart';
import 'apply_time_window_usecase.dart';

class GetDiscoverFeedUseCase {
  GetDiscoverFeedUseCase(
    this._repository, {
    ApplyTimeWindowUseCase? applyTimeWindow,
    TimeFitEvaluationStore? evaluationStore,
  }) : _applyTimeWindow = applyTimeWindow,
       _evaluationStore = evaluationStore;

  final DiscoverRepository _repository;
  final ApplyTimeWindowUseCase? _applyTimeWindow;
  final TimeFitEvaluationStore? _evaluationStore;

  Future<List<DiscoverItemEntity>> call(DiscoverQuery query) async {
    final List<DiscoverItemEntity> items = await _repository.getFeed(query);
    if (query.timeWindow == null || _applyTimeWindow == null) {
      _evaluationStore?.clear();
      return items;
    }
    final List<DiscoverItemEntity> evaluated = await _applyTimeWindow(
      items,
      query,
    );
    _evaluationStore?.replaceAll(
      evaluated
          .map((DiscoverItemEntity item) => item.timeFitEvaluation)
          .whereType(),
    );
    return evaluated;
  }
}
