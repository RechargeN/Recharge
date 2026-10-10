import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/visited/data/datasources/visited_places_local_datasource.dart';
import 'package:recharge/features/visited/data/models/visited_place_model.dart';
import 'package:recharge/features/visited/data/repositories/visited_places_repository_impl.dart';
import 'package:recharge/features/visited/domain/entities/visited_place_entity.dart';
import 'package:recharge/features/visited/domain/usecases/record_place_visit_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('fresh v2 is empty and legacy seeded v1 is ignored', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'visited_places_v1_user_1': jsonEncode(<Map<String, Object?>>[
        <String, Object?>{'id': 'seeded-demo'},
      ]),
    });
    final repository = VisitedPlacesRepositoryImpl(
      localDataSource: VisitedPlacesLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );

    expect(await repository.getVisitedPlaces(userId: 'user:1'), isEmpty);
  });

  test('same place and day is idempotent, another day is retained', () async {
    final repository = VisitedPlacesRepositoryImpl(
      localDataSource: VisitedPlacesLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );
    final useCase = RecordPlaceVisitUseCase(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
    );

    final first = await _record(useCase, visitedOn: DateTime(2026, 7, 20));
    final duplicate = await _record(useCase, visitedOn: DateTime(2026, 7, 20));
    await _record(useCase, visitedOn: DateTime(2026, 7, 19));

    final visits = await repository.getVisitedPlaces(userId: 'user:1');
    expect(duplicate.id, first.id);
    expect(visits, hasLength(2));
    expect(visits.map((VisitedPlaceEntity item) => item.localDayKey), <String>[
      '2026-07-20',
      '2026-07-19',
    ]);

    await repository.removeVisit(userId: 'user:1', visitId: first.id);
    expect(await repository.getVisitedPlaces(userId: 'user:1'), hasLength(1));
  });

  test('future self-reported date is rejected', () {
    final repository = VisitedPlacesRepositoryImpl(
      localDataSource: VisitedPlacesLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );
    final useCase = RecordPlaceVisitUseCase(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
    );

    expect(
      () => _record(useCase, visitedOn: DateTime(2026, 8, 1)),
      throwsA(isA<VisitHistoryValidationException>()),
    );
  });

  test('v2 keeps valid records when another record is corrupt', () async {
    final valid = VisitedPlaceModel.fromEntity(
      VisitedPlaceEntity(
        id: 'visit-1',
        userId: 'user:1',
        placeId: 'place-1',
        title: 'Library',
        subtitle: 'Quiet reading room',
        city: 'Riga',
        category: 'art_culture_museums',
        visitedOn: DateTime(2026, 7, 20),
        timezoneId: 'Europe/Riga',
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: DateTime.utc(2026, 7, 20, 10),
      ),
    ).toJson();
    final foreign = VisitedPlaceModel.fromEntity(
      VisitedPlaceEntity(
        id: 'foreign-visit',
        userId: 'another-user',
        placeId: 'place-2',
        title: 'Foreign record',
        subtitle: '',
        city: 'Riga',
        category: 'other',
        visitedOn: DateTime(2026, 7, 21),
        timezoneId: 'Europe/Riga',
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: DateTime.utc(2026, 7, 21, 10),
      ),
    ).toJson();
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      '${VisitedPlacesLocalDataSource.keyPrefix}user_1': jsonEncode(<Object?>[
          valid,
          foreign,
          <String, Object?>{'schemaVersion': 99, 'id': 'future'},
      ]),
    });
    final repository = VisitedPlacesRepositoryImpl(
      localDataSource: VisitedPlacesLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );

    final visits = await repository.getVisitedPlaces(userId: 'user:1');
    expect(visits.single.id, 'visit-1');
  });
}

Future<VisitedPlaceEntity> _record(
  RecordPlaceVisitUseCase useCase, {
  required DateTime visitedOn,
}) {
  return useCase(
    userId: 'user:1',
    placeId: 'place-1',
    title: 'Library',
    subtitle: 'Quiet reading room',
    city: 'Riga',
    category: 'art_culture_museums',
    visitedOn: visitedOn,
    today: DateTime(2026, 7, 31),
    timezoneId: 'Europe/Riga',
  );
}

class _SequenceIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() {
    _value += 1;
    return 'visit-$_value';
  }
}
