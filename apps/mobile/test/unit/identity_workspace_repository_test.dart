import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/data/datasources/identity_workspace_local_datasource.dart';
import 'package:recharge/features/identity/data/datasources/mock_identity_fixture.dart';
import 'package:recharge/features/identity/data/datasources/public_professional_page_local_datasource.dart';
import 'package:recharge/features/identity/data/repositories/identity_workspace_repository_impl.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';

void main() {
  const String userId = 'workspace-storage-user';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('persists workspace per user and restores exact page id', () async {
    const storage = FlutterSecureStorage();
    final repository = IdentityWorkspaceRepositoryImpl(
      localDataSource: const IdentityWorkspaceLocalDataSource(storage),
      mockFixture: const MockIdentityFixture(),
    );
    final page = WorkspaceRef.page('created-page-id');

    await repository.saveActiveWorkspace(userId, page);

    expect(await repository.loadActiveWorkspace(userId), page);
    expect(await repository.loadActiveWorkspace('another-user'), isNull);
  });

  test('persists only pages explicitly created by the user', () async {
    const storage = FlutterSecureStorage();
    const publicDataSource = PublicProfessionalPageLocalDataSource(storage);
    final repository = IdentityWorkspaceRepositoryImpl(
      localDataSource: const IdentityWorkspaceLocalDataSource(storage),
      mockFixture: const MockIdentityFixture(),
      publicPageLocalDataSource: publicDataSource,
    );
    final page = ManagedPageEntity(
      id: 'created-page-id',
      ownerUserId: userId,
      kind: ManagedPageKind.company,
      displayName: 'Created Page',
      avatar: '',
      verificationStatus: ManagedPageVerificationStatus.pending,
      lifecycle: ManagedPageLifecycle.active,
      marketId: 'riga',
      countryCode: 'LV',
      defaultLocale: 'en',
      timezone: 'Europe/Riga',
      defaultCurrency: 'EUR',
      supportedLocales: const <String>['en', 'lv', 'ru'],
      createdAtUtc: DateTime.utc(2026, 7, 31),
      revision: 1,
    );
    const membership = ManagedPageMembershipEntity(
      pageId: 'created-page-id',
      userId: userId,
      relationship: ManagedPageRelationship.owner,
      status: ManagedPageMembershipStatus.active,
      capabilities: <String>{'page.manage'},
      revision: 1,
    );

    expect((await repository.loadAccessSnapshot(userId)).pages, isEmpty);
    await repository.saveCreatedPage(
      userId: userId,
      page: page,
      membership: membership,
    );

    final restored = await repository.loadAccessSnapshot(userId);
    expect(restored.pages.single.displayName, 'Created Page');
    expect(restored.memberships.single.isOwner, isTrue);
    expect((await publicDataSource.loadPages()).single.id, page.id);
  });

  test('persists one pending page-limit request idempotently', () async {
    final repository = IdentityWorkspaceRepositoryImpl(
      localDataSource: const IdentityWorkspaceLocalDataSource(
        FlutterSecureStorage(),
      ),
      mockFixture: const MockIdentityFixture(),
    );
    final request = PageLimitIncreaseRequestEntity(
      id: 'request-id',
      userId: userId,
      currentOwnedPageCount: 3,
      requestedOwnedPageLimit: 4,
      status: PageLimitIncreaseRequestStatus.pending,
      createdAtUtc: DateTime.utc(2026, 7, 31),
      revision: 1,
    );

    await repository.savePageLimitRequest(request);
    await repository.savePageLimitRequest(request);

    expect(await repository.loadPendingPageLimitRequest(userId), request);
  });

  test('corrupt workspace and managed-page records fail closed', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'identity_active_workspace_$userId': '{"schemaVersion":1,"type":"page"}',
      'identity_managed_pages_$userId': '{"schemaVersion":1,"pages":"bad"}',
    });
    const dataSource = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());

    expect(await dataSource.loadActiveWorkspace(userId), isNull);
    final record = await dataSource.loadManagedPageRecord(userId);
    expect(record.pages, isEmpty);
    expect(record.memberships, isEmpty);
  });

  test('schema v1 page record migrates with deterministic slug', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'identity_managed_pages_$userId': jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'pages': <Map<String, Object>>[
          <String, Object>{
            'id': 'legacy-page-12345678',
            'ownerUserId': userId,
            'kind': 'company',
            'displayName': 'Legacy Riga Page',
            'avatar': '',
            'verificationStatus': 'pending',
            'lifecycle': 'active',
            'marketId': 'riga',
            'countryCode': 'LV',
            'defaultLocale': 'en',
            'timezone': 'Europe/Riga',
            'defaultCurrency': 'EUR',
            'supportedLocales': <String>['en'],
            'createdAtUtc': '2026-07-31T00:00:00.000Z',
            'revision': 1,
          },
        ],
        'memberships': <Object>[],
        'limitRequests': <Object>[],
      }),
    });
    const dataSource = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());

    final record = await dataSource.loadManagedPageRecord(userId);

    expect(record.pages.single.displayName, 'Legacy Riga Page');
    expect(record.pages.single.slug, 'legacy-riga-page-12345678');
  });
}
