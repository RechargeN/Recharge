import '../repositories/travel_time_repository.dart';

class CalculateTravelTimesUseCase {
  const CalculateTravelTimesUseCase(this._repository);

  final TravelTimeRepository _repository;

  Future<Map<String, TravelTimeEstimate>> call(
    TravelTimeBatchRequest request,
  ) async {
    final List<TravelTimeEstimate> estimates = await _repository.estimateBatch(
      request,
    );
    return <String, TravelTimeEstimate>{
      for (final TravelTimeEstimate estimate in estimates)
        estimate.candidateId: estimate,
    };
  }
}
