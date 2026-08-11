import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  late CreateLocalDataSource dataSource;
  late CreateRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    dataSource = CreateLocalDataSource(const FlutterSecureStorage());
    repository = CreateRepositoryImpl(
      localDataSource: dataSource,
      idGenerator: const _FixedIdGenerator(),
    );
  });

  CreateDraftEntity draftAt(int revision) =>
      CreateDraftEntity.defaults(
        organizerId: 'user-1',
        organizerEmail: 'owner@example.test',
        organizerName: 'Owner',
      ).copyWith(
        id: '01ROUTEDRAFT000000000000001',
        objectType: CreateObjectType.route,
        clearEventData: true,
        routeData: routeFixture(revision: revision),
      );

  test('conditionally saves first and newer Route revisions', () async {
    final first = await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(0),
      expectedRevision: null,
    );
    final newer = await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(2),
      expectedRevision: 0,
    );
    final restored = await repository.loadDraft('user-1');

    expect(first.status, RouteDraftSaveStatus.saved);
    expect(newer.status, RouteDraftSaveStatus.saved);
    expect(restored?.routeData?.revision, 2);
    expect(restored?.sectionData.containsKey('route_details'), isFalse);
  });

  test('an older write cannot overwrite a newer persisted revision', () async {
    await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(0),
      expectedRevision: null,
    );
    await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(3),
      expectedRevision: 0,
    );

    final stale = await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(1),
      expectedRevision: 0,
    );
    final restored = await repository.loadDraft('user-1');

    expect(stale.status, RouteDraftSaveStatus.conflict);
    expect(stale.persistedRevision, 3);
    expect(restored?.routeData?.revision, 3);
  });

  test('concurrent compare-and-set writes serialize per user', () async {
    await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(0),
      expectedRevision: null,
    );

    final results = await Future.wait(<Future<RouteDraftSaveResult>>[
      repository.saveRouteDraft(
        userId: 'user-1',
        draft: draftAt(1),
        expectedRevision: 0,
      ),
      repository.saveRouteDraft(
        userId: 'user-1',
        draft: draftAt(2),
        expectedRevision: 1,
      ),
    ]);
    final restored = await repository.loadDraft('user-1');

    expect(
      results.every((RouteDraftSaveResult value) => value.isSaved),
      isTrue,
    );
    expect(restored?.routeData?.revision, 2);
  });

  test('corrupt existing storage is not silently overwritten', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'create_draft_user-1': jsonEncode(<String, Object?>{
        'id': 42,
        'objectType': 'route',
      }),
    });
    dataSource = CreateLocalDataSource(const FlutterSecureStorage());
    repository = CreateRepositoryImpl(
      localDataSource: dataSource,
      idGenerator: const _FixedIdGenerator(),
    );

    final result = await repository.saveRouteDraft(
      userId: 'user-1',
      draft: draftAt(0),
      expectedRevision: null,
    );

    expect(result.status, RouteDraftSaveStatus.conflict);
    expect(await repository.loadDraft('user-1'), isNull);
  });
}

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();

  @override
  String generate() => '01FIXED000000000000000000';
}
