import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/visited_place_entity.dart';
import '../repositories/visited_places_repository.dart';

class VisitHistoryValidationException implements Exception {
  const VisitHistoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecordPlaceVisitUseCase {
  const RecordPlaceVisitUseCase({
    required VisitedPlacesRepository repository,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final VisitedPlacesRepository _repository;
  final IdGenerator _idGenerator;

  Future<VisitedPlaceEntity> call({
    required String userId,
    required String placeId,
    required String title,
    required String subtitle,
    required String city,
    required String category,
    required DateTime visitedOn,
    required DateTime today,
    required String timezoneId,
    String coverImageUrl = '',
  }) {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) {
      throw const VisitHistoryValidationException(
        'Visit owner and place are required',
      );
    }
    final DateTime normalizedDay = DateTime(
      visitedOn.year,
      visitedOn.month,
      visitedOn.day,
    );
    final DateTime normalizedToday = DateTime(
      today.year,
      today.month,
      today.day,
    );
    if (normalizedDay.isAfter(normalizedToday)) {
      throw const VisitHistoryValidationException(
        'A visit date cannot be in the future',
      );
    }
    final String normalizedTimezone = timezoneId.trim();
    if (normalizedTimezone.isEmpty) {
      throw const VisitHistoryValidationException('Visit timezone is required');
    }

    return _repository.recordVisit(
      VisitedPlaceEntity(
        id: _idGenerator.generate(),
        userId: userId,
        placeId: placeId,
        title: title.trim(),
        subtitle: subtitle.trim(),
        city: city.trim(),
        category: category,
        visitedOn: normalizedDay,
        timezoneId: normalizedTimezone,
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: DateTime.now().toUtc(),
        coverImageUrl: coverImageUrl,
      ),
    );
  }
}
