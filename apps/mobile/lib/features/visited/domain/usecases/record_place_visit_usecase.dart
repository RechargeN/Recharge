import '../../../../shared/primitives/time/local_date.dart';
import '../../../../shared/primitives/time/iana_time_zone.dart';
import '../../../../shared/primitives/time/utc_instant.dart';
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
    required LocalDate Function(DateTime instantUtc, String timezoneId)
    localDateAt,
    DateTime Function()? nowUtc,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _localDateAt = localDateAt,
       _nowUtc = nowUtc;

  final VisitedPlacesRepository _repository;
  final IdGenerator _idGenerator;
  final LocalDate Function(DateTime, String) _localDateAt;
  final DateTime Function()? _nowUtc;

  LocalDate todayInZone(String timezoneId) => _dayAt(_instant(), timezoneId);
  DateTime _instant() =>
      UtcInstant(_nowUtc?.call() ?? DateTime.now().toUtc()).value;
  LocalDate _dayAt(DateTime instant, String timezoneId) {
    try {
      return _localDateAt(instant, IanaTimeZone.parse(timezoneId).value);
    } on Object {
      throw const VisitHistoryValidationException('place_timezone_required');
    }
  }

  Future<VisitedPlaceEntity> call({
    required String userId,
    required String placeId,
    required String title,
    required String subtitle,
    required String city,
    required String category,
    required DateTime visitedOn,
    DateTime?
    today, // Retained read-compatibility argument; never used as the Place clock.
    required String timezoneId,
    String coverImageUrl = '',
  }) {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) {
      throw const VisitHistoryValidationException(
        'Visit owner and place are required', // l10n-ignore: developer error
      );
    }
    final instant = _instant();
    final day = LocalDate(visitedOn.year, visitedOn.month, visitedOn.day);
    final placeToday = _dayAt(instant, timezoneId);
    if (day.compareTo(placeToday) > 0) {
      throw const VisitHistoryValidationException(
        'A visit date cannot be in the future', // l10n-ignore: developer error
      );
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
        visitedOn: DateTime(day.year, day.month, day.day),
        timezoneId: IanaTimeZone.parse(timezoneId).value,
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: instant,
        coverImageUrl: coverImageUrl,
      ),
    );
  }
}
