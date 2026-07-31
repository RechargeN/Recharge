import '../entities/visited_place_entity.dart';
import '../repositories/visited_places_repository.dart';

class GetVisitedPlacesUseCase {
  const GetVisitedPlacesUseCase(this._repository);

  final VisitedPlacesRepository _repository;

  Future<List<VisitedPlaceEntity>> call({required String userId}) {
    return _repository.getVisitedPlaces(userId: userId);
  }
}
