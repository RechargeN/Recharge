import '../entities/visited_place_entity.dart';

abstract class VisitedPlacesRepository {
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({required String userId});

  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit);

  Future<void> removeVisit({required String userId, required String visitId});
}
