import '../entities/discover_item_entity.dart';
import '../repositories/discover_repository.dart';
import '../repositories/time_fit_evaluation_store.dart';

class GetDiscoverDetailsUseCase {
  GetDiscoverDetailsUseCase(
    this._repository, {
    TimeFitEvaluationStore? evaluationStore,
  }) : _evaluationStore = evaluationStore;

  final DiscoverRepository _repository;
  final TimeFitEvaluationStore? _evaluationStore;

  Future<DiscoverItemEntity> call(String itemId) async {
    final DiscoverItemEntity item = await _repository.getDetails(itemId);
    final evaluation = _evaluationStore?.get(itemId);
    return evaluation == null
        ? item
        : item.copyWith(timeFitEvaluation: evaluation);
  }
}
