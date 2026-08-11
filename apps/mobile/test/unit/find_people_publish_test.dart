import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';

void main() {
  test(
    'mock publish replaces relation ids and exposes only safe snapshot',
    () async {
      final _MemoryDataSource dataSource = _MemoryDataSource();
      final CreateRepositoryImpl repository = CreateRepositoryImpl(
        localDataSource: dataSource,
        idGenerator: _CountingIdGenerator(),
      );
      final CreateDraftEntity base = CreateDraftEntity.defaults(
        organizerId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Host',
        currency: 'EUR',
      );
      final CreateDraftEntity draft = base.copyWith(
        objectType: CreateObjectType.findPeople,
        scheduleSlots: <CreateTimeSlotDraft>[
          CreateTimeSlotDraft(
            localId: 'loc_slot',
            startAtUtc: DateTime.utc(2026, 8, 20, 16),
            endAtUtc: DateTime.utc(2026, 8, 20, 18),
          ),
        ],
        findPeopleData:
            FindPeopleDraftData.defaults(
              userId: 'user-1',
              currencyCode: 'EUR',
            ).copyWith(
              exactAddressLine: 'Private exact address',
              exactGeo: const FindPeopleGeoPointDraft(
                latitude: 56.9501,
                longitude: 24.1051,
              ),
              applicationQuestions: const <FindPeopleApplicationQuestionDraft>[
                FindPeopleApplicationQuestionDraft(
                  id: 'loc_question',
                  prompt: 'What level do you play?',
                  type: FindPeopleQuestionType.text,
                ),
              ],
            ),
      );

      final CreateDraftEntity published = await repository.publishDraft(
        'user-1',
        draft,
      );
      final Map<String, Object?> snapshot =
          published.sectionData['find_people_publish_snapshot']!
              as Map<String, Object?>;

      expect(published.id, isNot(startsWith('loc_')));
      expect(published.scheduleSlots.single.localId, isNot(startsWith('loc_')));
      expect(
        published.findPeopleData!.applicationQuestions.single.id,
        isNot(startsWith('loc_')),
      );
      expect(snapshot['candidate_slot_ids'], <String>[
        published.scheduleSlots.single.localId,
      ]);
      expect(snapshot, isNot(contains('exact_address_line')));
      expect(snapshot, isNot(contains('exact_geo')));
      expect(snapshot['private_meeting_ref'], startsWith('local-secure:'));
    },
  );
}

class _CountingIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => '01JTEST${++_value}PERMANENT';
}

class _MemoryDataSource extends CreateLocalDataSource {
  _MemoryDataSource()
    : super(const FlutterSecureStorage(), activeCurrency: 'EUR');

  CreateDraftModel? saved;

  @override
  Future<CreateDraftModel?> loadDraft(String userId) async => saved;

  @override
  Future<void> saveDraft(String userId, CreateDraftModel model) async {
    saved = model;
  }
}
