import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
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
}

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();

  @override
  String generate() => 'uuid-fixed';
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
