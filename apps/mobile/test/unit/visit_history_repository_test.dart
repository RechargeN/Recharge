import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/id/id_generator.dart';
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

  test(
    'concurrent duplicate visits and colliding legacy owner ids stay isolated',
    () async {
      final repository = VisitedPlacesRepositoryImpl(
        localDataSource: VisitedPlacesLocalDataSource(
          const FlutterSecureStorage(),
        ),
      );
      final useCase = RecordPlaceVisitUseCase(
        repository: repository,
        idGenerator: _SequenceIdGenerator(),
        nowUtc: () => DateTime.utc(2026, 7, 31, 12),
        localDateAt: (instant, zone) =>
            TimezoneRepositoryImpl().toLocal(instant, zone).date,
      );
      final results = await Future.wait([
        _record(useCase, visitedOn: DateTime(2026, 7, 21)),
        _record(useCase, visitedOn: DateTime(2026, 7, 21)),
      ]);
      expect(results[0].id, results[1].id);
      await _record(
        useCase,
        visitedOn: DateTime(2026, 7, 22),
        userId: 'user_1',
      );
      expect(
        (await repository.getVisitedPlaces(
          userId: 'user:1',
        )).single.localDayKey,
        '2026-07-21',
      );
      expect(
        (await repository.getVisitedPlaces(
          userId: 'user_1',
        )).single.localDayKey,
        '2026-07-22',
      );
      await repository.removeVisit(userId: 'user:1', visitId: results[0].id);
      await repository.removeVisit(userId: 'user:1', visitId: results[0].id);
      expect(await repository.getVisitedPlaces(userId: 'user:1'), isEmpty);
      expect(await repository.getVisitedPlaces(userId: 'user_1'), hasLength(1));
    },
  );

  test(
    'Visit today uses Place zone and ignores caller device calendar',
    () async {
      final repository = VisitedPlacesRepositoryImpl(
        localDataSource: VisitedPlacesLocalDataSource(
          const FlutterSecureStorage(),
        ),
      );
      final instant = DateTime.utc(2026, 3, 28, 23, 30, 0, 123, 456);
      final useCase = RecordPlaceVisitUseCase(
        repository: repository,
        idGenerator: _SequenceIdGenerator(),
        nowUtc: () => instant,
        localDateAt: (utc, zone) =>
            TimezoneRepositoryImpl().toLocal(utc, zone).date,
      );
      expect(useCase.todayInZone('Europe/Riga').toString(), '2026-03-29');
      expect(useCase.todayInZone('Pacific/Honolulu').toString(), '2026-03-28');
      Future<VisitedPlaceEntity> record(
        String zone,
        String owner,
        DateTime date,
      ) => useCase(
        userId: owner,
        placeId: 'place',
        title: 'Place',
        subtitle: '',
        city: '',
        category: 'other',
        visitedOn: date,
        today: DateTime(2099),
        timezoneId: zone,
      );
      final first = await record(
        'Europe/Riga',
        'owner-a',
        DateTime(2026, 3, 29),
      );
      expect(first.recordedAtUtc, instant);
      expect(
        (await record('Europe/Riga', 'owner-a', DateTime(2026, 3, 29))).id,
        first.id,
      );
      final other = await record(
        'Europe/Riga',
        'owner-b',
        DateTime(2026, 3, 29),
      );
      expect(other.id, isNot(first.id));
      expect(
        () => record('Pacific/Honolulu', 'owner-a', DateTime(2026, 3, 29)),
        throwsA(isA<VisitHistoryValidationException>()),
      );
      for (final zone in ['', 'Europe/Unknown', ' Europe/Riga ']) {
        expect(
          () => useCase.todayInZone(zone),
          throwsA(isA<VisitHistoryValidationException>()),
        );
      }
    },
  );
  test(
    'Visit model rejects invalid calendar and implicit UTC without normalizing',
    () {
      final entity = VisitedPlaceEntity(
        id: 'v',
        userId: 'u',
        placeId: 'p',
        title: '',
        subtitle: '',
        city: '',
        category: '',
        visitedOn: DateTime(2026, 3, 29),
        timezoneId: 'Europe/Riga',
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: DateTime.utc(2026, 3, 29, 0, 0, 0, 123, 456),
      );
      final wire = VisitedPlaceModel.fromEntity(entity).toJson();
      expect(
        VisitedPlaceModel.fromJson(wire).toEntity().recordedAtUtc,
        entity.recordedAtUtc,
      );
      expect(
        () => VisitedPlaceModel.fromJson({
          ...wire,
          'visitedOn': '2026-02-30',
        }).toEntity(),
        throwsFormatException,
      );
      expect(
        () => VisitedPlaceModel.fromJson({
          ...wire,
          'recordedAtUtcIso': '2026-03-29T00:00:00',
        }).toEntity(),
        throwsFormatException,
      );
    },
  );
  test(
    'unreadable Visit siblings survive attempted record and deletion unchanged',
    () async {
      const storage = FlutterSecureStorage();
      const key = 'visit_history_v2_user_1';
      const raw = '[{"schemaVersion":99,"id":"future"}]';
      await storage.write(key: key, value: raw);
      final repository = VisitedPlacesRepositoryImpl(
        localDataSource: VisitedPlacesLocalDataSource(storage),
      );
      expect(await repository.getVisitedPlaces(userId: 'user:1'), isEmpty);
      final useCase = RecordPlaceVisitUseCase(
        repository: repository,
        idGenerator: _SequenceIdGenerator(),
        nowUtc: () => DateTime.utc(2026, 7, 31, 12),
        localDateAt: (utc, zone) =>
            TimezoneRepositoryImpl().toLocal(utc, zone).date,
      );
      await expectLater(
        _record(useCase, visitedOn: DateTime(2026, 7, 20)),
        throwsFormatException,
      );
      await expectLater(
        repository.removeVisit(userId: 'user:1', visitId: 'future'),
        throwsFormatException,
      );
      expect(await storage.read(key: key), raw);
    },
  );
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
      localDateAt: (instant, zone) =>
          TimezoneRepositoryImpl().toLocal(instant, zone).date,
      nowUtc: () => DateTime.utc(2026, 7, 31, 12),
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
      localDateAt: (instant, zone) =>
          TimezoneRepositoryImpl().toLocal(instant, zone).date,
      nowUtc: () => DateTime.utc(2026, 7, 31, 12),
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
  String userId = 'user:1',
}) {
  return useCase(
    userId: userId,
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
