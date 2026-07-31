import '../repositories/visited_places_repository.dart';

class RemoveVisitUseCase {
  const RemoveVisitUseCase(this._repository);

  final VisitedPlacesRepository _repository;

  Future<void> call({required String userId, required String visitId}) {
    if (userId.trim().isEmpty || visitId.trim().isEmpty) {
      throw ArgumentError('Visit owner and id are required');
    }
    return _repository.removeVisit(userId: userId, visitId: visitId);
  }
}
