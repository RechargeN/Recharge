import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_availability_exception.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  late CreateLocalDataSource source;
  late CreateRepositoryImpl repository;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    source = CreateLocalDataSource(storage);
    repository = CreateRepositoryImpl(
      localDataSource: source,
      idGenerator: const _FixedIdGenerator(),
    );
  });

  CreateDraftEntity draft(CreateObjectType type, {String owner = 'u1'}) {
    final start = DateTime.utc(2026, 8, 3, 12, 0, 0, 123, 456);
    final event =
        EventDraftData.defaults(
          marketCityId: 'riga',
          countryCode: 'LV',
          city: 'Riga',
          timezoneId: 'Pacific/Honolulu',
          currencyCode: 'EUR',
        ).copyWith(
          occurrences: [
            EventOccurrenceDraft(
              id: 'o1',
              localDate: '2026-08-03',
              startAtUtc: start,
              endAtUtc: start.add(const Duration(hours: 1)),
            ),
          ],
        );
    final session =
        SessionDraftData.defaults(
          resourceName: 'Sauna',
          timezoneId: 'Pacific/Honolulu',
        ).copyWith(
          exceptions: [
            SessionAvailabilityException(
              id: 'x',
              startDateLocal: '2026-08-03',
              endDateLocal: '2026-08-03',
              allDay: true,
              createdByUserId: owner,
              createdAtUtc: start,
            ),
          ],
        );
    return CreateDraftEntity.defaults(
      organizerId: owner,
      organizerEmail: '',
      organizerName: '',
      timezone: 'Pacific/Honolulu',
      currency: 'EUR',
    ).copyWith(
      objectType: type,
      eventData: type == CreateObjectType.event ? event : null,
      clearEventData: type != CreateObjectType.event,
      sessionData: type == CreateObjectType.session ? session : null,
    );
  }

  Map<String, dynamic> corrupt(CreateDraftEntity value) {
    final wire = CreateDraftModel.fromEntity(value).toJson();
    final sections = wire['sectionData'] as Map;
    if (value.objectType == CreateObjectType.event) {
      (((sections['event_details'] as Map)['occurrences'] as List).single
              as Map)['startAtUtc'] =
          '2026-02-30T12:00:00Z';
    } else {
      (((sections['session_details'] as Map)['exceptions'] as List).single
              as Map)['created_at_utc'] =
          '2026-08-03T12:00:00';
    }
    return wire;
  }

  for (final type in [CreateObjectType.event, CreateObjectType.session]) {
    test(
      '${type.name}: corrupt restore and direct replacement preserve raw owner bytes',
      () async {
        final original = draft(type);
        final raw = jsonEncode(corrupt(original));
        await storage.write(key: 'create_draft_u1', value: raw);
        await expectLater(repository.loadDraft('u1'), throwsFormatException);
        await expectLater(
          repository.saveDraft('u1', original.copyWith(title: 'replace')),
          throwsFormatException,
        );
        await expectLater(
          source.saveDraft('u1', CreateDraftModel.fromEntity(original)),
          throwsFormatException,
        );
        expect(await storage.read(key: 'create_draft_u1'), raw);
        // Another owner remains writable; no shared failure flag or storage key.
        await repository.saveDraft('u2', draft(type, owner: 'u2'));
        expect((await repository.loadDraft('u2'))!.organizerId, 'u2');
        expect(await storage.read(key: 'create_draft_u1'), raw);
        // Explicit fixture repair allows the same queue to recover after errors.
        await storage.write(
          key: 'create_draft_u1',
          value: jsonEncode(CreateDraftModel.fromEntity(original).toJson()),
        );
        await repository.saveDraft('u1', original.copyWith(title: 'recovered'));
        expect((await repository.loadDraft('u1'))!.title, 'recovered');
      },
    );

    test(
      '${type.name}: valid legacy UTC read keeps precision zone and exact bytes',
      () async {
        final original = draft(type);
        final raw = jsonEncode(CreateDraftModel.fromEntity(original).toJson());
        await storage.write(key: 'create_draft_u1', value: raw);
        final loaded = (await repository.loadDraft('u1'))!;
        final instant = type == CreateObjectType.event
            ? loaded.eventData!.occurrences.single.startAtUtc
            : loaded.sessionData!.exceptions.single.createdAtUtc;
        expect(instant, DateTime.utc(2026, 8, 3, 12, 0, 0, 123, 456));
        expect(
          type == CreateObjectType.event
              ? loaded.eventData!.timezoneId
              : loaded.sessionData!.timezoneId,
          'Pacific/Honolulu',
        );
        expect(await storage.read(key: 'create_draft_u1'), raw);
      },
    );

    test(
      '${type.name}: direct incoming malformed model cannot overwrite valid storage',
      () async {
        final original = draft(type);
        await repository.saveDraft('u1', original);
        final before = await storage.read(key: 'create_draft_u1');
        final invalid = CreateDraftModel.fromJson(corrupt(original));
        await expectLater(
          source.saveDraft('u1', invalid),
          throwsFormatException,
        );
        expect(await storage.read(key: 'create_draft_u1'), before);
      },
    );
  }

  test(
    'unreadable slot blocks replacement before any Scenario collection side effect',
    () async {
      final raw = jsonEncode(corrupt(draft(CreateObjectType.event)));
      await storage.write(key: 'create_draft_u1', value: raw);
      final scenario = draft(CreateObjectType.event).copyWith(
        objectType: CreateObjectType.scenario,
        clearEventData: true,
        scenarioData: ScenarioDraftData.defaults(),
      );
      await expectLater(
        repository.saveDraft('u1', scenario),
        throwsFormatException,
      );
      expect(await storage.readAll(), {'create_draft_u1': raw});
    },
  );

  test(
    'Rental missing money currency preserves raw bytes and blocks replacement',
    () async {
      final original = draft(CreateObjectType.event).copyWith(
        objectType: CreateObjectType.rental,
        clearEventData: true,
        rentalData: RentalDraftData.defaults(
          userId: 'u1',
          currencyCode: 'EUR',
          timeZoneId: 'Europe/Riga',
        ),
      );
      final wire = CreateDraftModel.fromEntity(original).toJson();
      wire['currency'] = '';
      final rental = (wire['sectionData'] as Map)['rental_details'] as Map;
      (rental['pricing'] as Map).remove('currencyCode');
      final raw = jsonEncode(wire);
      await storage.write(key: 'create_draft_u1', value: raw);
      await expectLater(
        repository.loadDraft('u1'),
        throwsA(isA<MoneyReadException>()),
      );
      await expectLater(
        repository.saveDraft('u1', original),
        throwsA(isA<MoneyReadException>()),
      );
      expect(await storage.read(key: 'create_draft_u1'), raw);
    },
  );
  test(
    'malformed Scenario calendar preserves owner bytes and blocks replacement',
    () async {
      final original = draft(CreateObjectType.event).copyWith(
        objectType: CreateObjectType.scenario,
        clearEventData: true,
        scenarioData: ScenarioDraftData.defaults(),
      );
      final wire = CreateDraftModel.fromEntity(original).toJson();
      final scenario = (wire['sectionData'] as Map)['scenario'] as Map;
      scenario['days'] = [
        {
          'id': 'd',
          'dayIndex': 0,
          'localDate': {'year': 2026, 'month': 2, 'day': 30},
        },
      ];
      final raw = jsonEncode(wire);
      await storage.write(key: 'create_draft_u1', value: raw);
      await expectLater(repository.loadDraft('u1'), throwsFormatException);
      await expectLater(
        repository.saveDraft('u1', original),
        throwsFormatException,
      );
      expect(await storage.read(key: 'create_draft_u1'), raw);
    },
  );
  test('malformed JSON does not masquerade as a fresh draft', () async {
    await storage.write(key: 'create_draft_u1', value: '{broken');
    await expectLater(repository.loadDraft('u1'), throwsFormatException);
    await expectLater(
      repository.saveDraft('u1', draft(CreateObjectType.event)),
      throwsFormatException,
    );
    expect(await storage.read(key: 'create_draft_u1'), '{broken');
  });

  test(
    'corrupt envelope UTC and generic slots preserve raw bytes on read and replacement',
    () async {
      final original = draft(CreateObjectType.session);
      for (final problem in [
        'createdAtUtcIso',
        'updatedAtUtcIso',
        'startDateTimeUtcIso',
        'endDateTimeUtcIso',
        'registrationDeadlineUtcIso',
        'publishedAtUtcIso',
        'missingAudit',
        'slot',
        'slotShape',
      ]) {
        final wire = CreateDraftModel.fromEntity(original).toJson();
        if (problem == 'missingAudit') {
          wire.remove('createdAtUtcIso');
        } else if (problem == 'slot' || problem == 'slotShape') {
          wire['scheduleSlots'] = problem == 'slotShape'
              ? [null]
              : [
                  {
                    'local_id': 'old',
                    'start_at_utc': '2026-02-30T12:00:00Z',
                    'end_at_utc': '2026-03-01T13:00:00Z',
                  },
                ];
        } else {
          wire[problem] = '2026-08-03T12:00:00';
        }
        final raw = jsonEncode(wire);
        await storage.write(key: 'create_draft_u1', value: raw);
        await expectLater(
          repository.loadDraft('u1'),
          throwsFormatException,
          reason: problem,
        );
        await expectLater(
          repository.saveDraft('u1', original),
          throwsFormatException,
          reason: problem,
        );
        expect(await storage.read(key: 'create_draft_u1'), raw);
      }
    },
  );

  test(
    'valid old envelope text and generic slot payload survive read byte-for-byte',
    () async {
      final wire =
          CreateDraftModel.fromEntity(draft(CreateObjectType.session)).toJson()
            ..['schemaVersion'] = 1
            ..['createdAtUtcIso'] = '2026-08-03T12:00:00Z'
            ..['updatedAtUtcIso'] = '2026-08-03T12:00:00.1Z'
            ..['scheduleSlots'] = [
              {
                'local_id': 'old',
                'start_at_utc': '2026-08-03T12:00:00.123456Z',
                'end_at_utc': '2026-08-03T13:00:00.123456Z',
              },
            ];
      final raw = jsonEncode(wire);
      await storage.write(key: 'create_draft_u1', value: raw);
      final loaded = (await repository.loadDraft('u1'))!;
      expect(loaded.updatedAtUtc, DateTime.utc(2026, 8, 3, 12, 0, 0, 100));
      expect(loaded.scheduleSlots.single.localId, 'old');
      expect(loaded.scheduleSlots.single.startAtUtc.microsecond, 456);
      expect(await storage.read(key: 'create_draft_u1'), raw);
    },
  );
}

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();
  @override
  String generate() => 'fixed-id';
}
