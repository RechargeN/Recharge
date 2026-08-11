import '../../domain/entities/visited_place_entity.dart';
import '../../domain/repositories/visited_places_repository.dart';
import '../datasources/visited_places_local_datasource.dart';
import '../models/visited_place_model.dart';

class VisitedPlacesRepositoryImpl implements VisitedPlacesRepository {
  VisitedPlacesRepositoryImpl({
    required VisitedPlacesLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final VisitedPlacesLocalDataSource _localDataSource;

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    final List<VisitedPlaceModel> models = await _localDataSource
        .readVisitedPlaces(userId);
    final List<VisitedPlaceEntity> visits = models
        .map((VisitedPlaceModel model) => model.toEntity())
        .where((VisitedPlaceEntity visit) => visit.userId == userId)
        .toList(growable: false);
    visits.sort(_compareVisits);
    return visits;
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    final List<VisitedPlaceModel> current = await _localDataSource
        .readVisitedPlaces(visit.userId);
    final List<VisitedPlaceEntity> entities = current
        .map((VisitedPlaceModel model) => model.toEntity())
        .where(
          (VisitedPlaceEntity existing) => existing.userId == visit.userId,
        )
        .toList(growable: true);
    for (final VisitedPlaceEntity existing in entities) {
      if (existing.placeId == visit.placeId &&
          existing.localDayKey == visit.localDayKey) {
        return existing;
      }
    }
    entities.add(visit);
    entities.sort(_compareVisits);
    await _localDataSource.writeVisitedPlaces(
      visit.userId,
      entities.map(VisitedPlaceModel.fromEntity).toList(growable: false),
    );
    return visit;
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {
    final List<VisitedPlaceModel> current = await _localDataSource
        .readVisitedPlaces(userId);
    final List<VisitedPlaceModel> remaining = current
        .where(
          (VisitedPlaceModel model) =>
              model.userId != userId || model.id != visitId,
        )
        .toList(growable: false);
    await _localDataSource.writeVisitedPlaces(userId, remaining);
  }
}

int _compareVisits(VisitedPlaceEntity left, VisitedPlaceEntity right) {
  final int byDay = right.localDayKey.compareTo(left.localDayKey);
  if (byDay != 0) return byDay;
  return right.recordedAtUtc.compareTo(left.recordedAtUtc);
}
