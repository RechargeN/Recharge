import '../entities/scenario_transit_schedule.dart';
import '../repositories/scenario_transit_schedule_repository.dart';

class SearchScenarioTransitOptionsUseCase {
  const SearchScenarioTransitOptionsUseCase(this._repository);

  final ScenarioTransitScheduleRepository _repository;

  Future<ScenarioTransitSearchResult> call(ScenarioTransitSearchQuery query) {
    if (!query.serviceDate.isValid) {
      throw ArgumentError.value(
        query.serviceDate.iso8601,
        'serviceDate',
        'Must be a valid local date.',
      );
    }
    if (query.originStopId.trim().isEmpty ||
        query.destinationStopId.trim().isEmpty ||
        query.originStopId == query.destinationStopId) {
      throw ArgumentError('Origin and destination must be different stops.');
    }
    if (query.departAfter.secondsFromServiceDay < 0 ||
        query.limit < 1 ||
        query.limit > 100) {
      throw ArgumentError('Invalid departure time or result limit.');
    }
    return _repository.searchServices(query);
  }
}
