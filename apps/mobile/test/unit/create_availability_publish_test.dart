import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';

void main() {
  test(
    'shared Create slot keeps exact UTC bounds and rejects non-UTC construction',
    () {
      final start = DateTime.utc(2026, 8, 3, 12, 0, 0, 123, 456);
      final end = start.add(const Duration(minutes: 30));
      final slot = CreateTimeSlotDraft(
        localId: 'slot',
        startAtUtc: start,
        endAtUtc: end,
      );
      final restored = CreateTimeSlotDraft.fromMap(slot.toMap());
      expect(restored.startAtUtc, start);
      expect(restored.endAtUtc, end);
      expect(restored.localId, 'slot');
      expect(
        () => CreateTimeSlotDraft(
          localId: 'slot',
          startAtUtc: DateTime(2026, 8, 3, 12),
          endAtUtc: end,
        ),
        throwsArgumentError,
      );
      expect(
        () => CreateTimeSlotDraft(
          localId: 'slot',
          startAtUtc: start,
          endAtUtc: DateTime(2026, 8, 3, 13),
        ),
        throwsArgumentError,
      );
      expect(
        () => CreateTimeSlotDraft(
          localId: 'slot',
          startAtUtc: start,
          endAtUtc: start,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'stored generic slot UTC failures never normalize into different slots',
    () {
      final valid = <String, Object?>{
        'local_id': 'slot',
        'start_at_utc': '2026-08-03T12:00:00Z',
        'end_at_utc': '2026-08-03T13:00:00Z',
      };
      for (final field in ['start_at_utc', 'end_at_utc']) {
        for (final bad in <Object?>[
          null,
          123,
          '',
          '2026-02-30T12:00:00Z',
          '2026-08-03T12:00:00',
          '2026-08-03T12:00:00+03:00',
        ]) {
          expect(
            () => CreateTimeSlotDraft.fromMap({...valid, field: bad}),
            throwsFormatException,
          );
        }
      }
      expect(
        () => CreateTimeSlotDraft.fromMap({
          ...valid,
          'end_at_utc': valid['start_at_utc'],
        }),
        throwsFormatException,
      );
    },
  );
  test('publish replaces local slot ids with permanent ids', () async {
    final _MemoryCreateLocalDataSource dataSource =
        _MemoryCreateLocalDataSource();
    final CreateRepositoryImpl repository = CreateRepositoryImpl(
      localDataSource: dataSource,
      idGenerator: const _FixedIdGenerator(),
    );
    final CreateDraftEntity draft =
        CreateDraftEntity.defaults(
          organizerId: 'u1',
          organizerEmail: 'user@example.com',
          organizerName: 'user',
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ).copyWith(
          scheduleSlots: <CreateTimeSlotDraft>[
            CreateTimeSlotDraft(
              localId: 'loc_123',
              startAtUtc: DateTime.utc(2026, 7, 20, 10),
              endAtUtc: DateTime.utc(2026, 7, 20, 11),
            ),
          ],
        );

    final CreateDraftEntity published = await repository.publishDraft(
      'u1',
      draft,
    );

    expect(published.scheduleSlots.single.localId, 'uuid-fixed');
    expect(
      dataSource.saved!.toEntity().scheduleSlots.single.localId,
      'uuid-fixed',
    );
  });

  test(
    'Event publish atomically replaces occurrence and override ids',
    () async {
      final _MemoryCreateLocalDataSource dataSource =
          _MemoryCreateLocalDataSource();
      final _CountingIdGenerator idGenerator = _CountingIdGenerator();
      final CreateRepositoryImpl repository = CreateRepositoryImpl(
        localDataSource: dataSource,
        idGenerator: idGenerator,
      );
      final EventOccurrenceDraft occurrence = EventOccurrenceDraft(
        id: 'loc_occurrence',
        localDate: '2026-08-03',
        startAtUtc: DateTime.utc(2026, 8, 3, 16),
        endAtUtc: DateTime.utc(2026, 8, 3, 18),
      );
      final CreateDraftEntity base = CreateDraftEntity.defaults(
        organizerId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      );
      final CreateDraftEntity draft = base.copyWith(
        scheduleSlots: <CreateTimeSlotDraft>[
          CreateTimeSlotDraft(
            localId: occurrence.id,
            startAtUtc: occurrence.startAtUtc,
            endAtUtc: occurrence.endAtUtc,
          ),
        ],
        eventData: base.eventData!.copyWith(
          occurrences: <EventOccurrenceDraft>[occurrence],
          occurrenceOverrides: <String, EventOccurrenceOverrideDraft>{
            occurrence.id: EventOccurrenceOverrideDraft(
              occurrenceId: occurrence.id,
              capacity: 20,
            ),
          },
        ),
      );

      final CreateDraftEntity published = await repository.publishDraft(
        'u1',
        draft,
      );
      final CreateDraftEntity repeated = await repository.publishDraft(
        'u1',
        draft,
      );

      expect(published.id, 'uuid-1');
      expect(published.eventData!.occurrences.single.id, 'uuid-2');
      expect(published.scheduleSlots.single.localId, 'uuid-2');
      expect(published.eventData!.occurrenceOverrides.keys.single, 'uuid-2');
      expect(
        published.eventData!.occurrenceOverrides.values.single.occurrenceId,
        'uuid-2',
      );
      expect(repeated.id, published.id);
      expect(idGenerator.calls, 2);
    },
  );

  test(
    'Event publish replaces admission rule and inventory pool local ids',
    () async {
      final _MemoryCreateLocalDataSource dataSource =
          _MemoryCreateLocalDataSource();
      final _CountingIdGenerator idGenerator = _CountingIdGenerator();
      final CreateRepositoryImpl repository = CreateRepositoryImpl(
        localDataSource: dataSource,
        idGenerator: idGenerator,
      );
      final CreateDraftEntity base = CreateDraftEntity.defaults(
        organizerId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      );
      final CreateDraftEntity draft = base.copyWith(
        eventData: base.eventData!.copyWith(
          schemaVersion: 3,
          admission: const EventAdmissionDraft(
            admissionMode: AdmissionMode.openEntry,
            registrationMode: EventRegistrationMode.none,
            confirmationMode: ConfirmationMode.none,
            eligibilityRules: <EligibilityRule>[
              EligibilityRule(
                id: 'loc_rule',
                kind: EligibilityRuleKind.invitation,
              ),
            ],
          ),
          inventory: const EventInventoryConfiguration(
            authority: InventoryAuthority.none,
            pools: <EventInventoryPoolDraft>[
              EventInventoryPoolDraft(
                id: 'loc_pool',
                label: 'Onsite',
                shape: InventoryShape.generalCapacity,
                channel: InventoryChannel.onsite,
                capacityMode: EventCapacityMode.known,
                capacity: 10,
              ),
            ],
          ),
        ),
      );

      final CreateDraftEntity published = await repository.publishDraft(
        'u1',
        draft,
      );

      expect(published.id, 'uuid-1');
      expect(
        published.eventData!.admission!.eligibilityRules.single.id,
        'uuid-2',
      );
      expect(published.eventData!.inventory!.pools.single.id, 'uuid-3');
      expect(idGenerator.calls, 3);
    },
  );

  test(
    'Place publish replaces draft, period, and exception local ids',
    () async {
      final _MemoryCreateLocalDataSource dataSource =
          _MemoryCreateLocalDataSource();
      final _CountingIdGenerator idGenerator = _CountingIdGenerator();
      final CreateRepositoryImpl repository = CreateRepositoryImpl(
        localDataSource: dataSource,
        idGenerator: idGenerator,
      );
      final CreateDraftEntity base = CreateDraftEntity.defaults(
        organizerId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      );
      final PlaceDraftData place =
          PlaceDraftData.defaults(
            userId: 'u1',
            marketCityId: 'riga',
            countryCode: 'LV',
            city: 'Riga',
            timezoneId: 'Europe/Riga',
            currencyCode: 'EUR',
          ).copyWith(
            hours: const PlaceHoursDraft(
              mode: PlaceHoursMode.regular,
              weeklyPeriods: <LocalOpeningPeriod>[
                LocalOpeningPeriod(
                  id: 'loc_period',
                  dayOfWeek: 1,
                  openMinute: 540,
                  closeMinute: 1080,
                  closesNextDay: false,
                ),
              ],
              exceptions: <OpeningException>[
                OpeningException(
                  id: 'loc_exception',
                  localDate: '2026-12-25',
                  kind: OpeningExceptionKind.closedAllDay,
                ),
              ],
            ),
          );

      final CreateDraftEntity draft = base.copyWith(
        objectType: CreateObjectType.place,
        placeData: place,
      );
      final CreateDraftEntity published = await repository.publishDraft(
        'u1',
        draft,
      );
      final CreateDraftEntity repeated = await repository.publishDraft(
        'u1',
        draft,
      );

      expect(published.id, 'uuid-1');
      expect(published.placeData!.hours.weeklyPeriods.single.id, 'uuid-2');
      expect(published.placeData!.hours.exceptions.single.id, 'uuid-3');
      expect(repeated.id, published.id);
      expect(idGenerator.calls, 3);
      expect(dataSource.saved!.toEntity().placeData, isNotNull);
    },
  );
}

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();

  @override
  String generate() => 'uuid-fixed';
}

class _CountingIdGenerator implements IdGenerator {
  int calls = 0;

  @override
  String generate() => 'uuid-${++calls}';
}

class _MemoryCreateLocalDataSource extends CreateLocalDataSource {
  _MemoryCreateLocalDataSource() : super(const FlutterSecureStorage());

  CreateDraftModel? saved;

  @override
  Future<CreateDraftModel?> loadDraft(String userId) async => saved;

  @override
  Future<void> saveDraft(String userId, CreateDraftModel model) async {
    saved = model;
  }
}
