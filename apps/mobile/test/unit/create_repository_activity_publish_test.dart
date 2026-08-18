import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('publishing an activity draft replaces the loc_ id and keeps activityData', () async {
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
      id: 'loc_abc',
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ),
    );

    final CreateDraftEntity published = await repository.publishDraft(
      'user-1',
      draft,
    );

    expect(published.id, isNot(startsWith('loc_')));
    expect(published.activityData, isNotNull);
  });

  test('publishing a flaggedForReview activity draft preserves the moderation status', () async {
    final _MemoryDataSource dataSource = _MemoryDataSource();
    final CreateRepositoryImpl repository = CreateRepositoryImpl(
      localDataSource: dataSource,
      idGenerator: _CountingIdGenerator(),
    );
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-3',
      organizerEmail: 'user3@example.com',
      organizerName: 'Host',
      currency: 'EUR',
    );
    final CreateDraftEntity draft = base.copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-3',
        currencyCode: 'EUR',
      ),
      moderationStatus: ModerationStatus.flaggedForReview,
    );

    final CreateDraftEntity published = await repository.publishDraft(
      'user-3',
      draft,
    );

    expect(published.moderationStatus, ModerationStatus.flaggedForReview);
  });
}

class _CountingIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => '01JTEST${++_value}PERMANENT';
}

class _MemoryDataSource extends CreateLocalDataSource {
  _MemoryDataSource() : super(const FlutterSecureStorage());

  CreateDraftModel? saved;

  @override
  Future<CreateDraftModel?> loadDraft(String userId) async => saved;

  @override
  Future<void> saveDraft(String userId, CreateDraftModel model) async {
    saved = model;
  }
}
