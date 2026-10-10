import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/explore/application/profile_role_summary.dart';

import 'package:recharge/shared/primitives/id/id_generator.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/professional_page_creation_input.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/usecases/create_professional_page_usecase.dart';

void main() {
  test('maps default user role to User tier', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'user',
      capabilities: const <String>['discover.read', 'favorites.write'],
    );

    expect(summary.tier, ProfileRoleTier.user);
    expect(summary.canCreate, isFalse);
    expect(summary.canGenerate, isFalse);
    expect(summary.primaryActionLabel, 'Open Saved');
  });

  test('does not promote a user from create capabilities alone', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'user',
      capabilities: const <String>['create.event', 'create.place'],
    );

    expect(summary.tier, ProfileRoleTier.user);
    expect(summary.canCreate, isFalse);
    expect(summary.canGenerate, isFalse);
    expect(summary.primaryActionLabel, 'Open Saved');
  });

  test('maps generator capabilities to Pro generator tier', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'creator',
      capabilities: const <String>['create.event', 'scenario.generate'],
    );

    expect(summary.tier, ProfileRoleTier.proGenerator);
    expect(summary.canCreate, isTrue);
    expect(summary.canGenerate, isTrue);
    expect(summary.primaryActionLabel, 'Open Builder');
  });

  test('one personal title/layout with distinct actual tool hints', () {
    final summaries = <ProfileRoleSummary?>[
      null,
      profileRoleSummaryFor(role: 'user', capabilities: const []),
      profileRoleSummaryFor(role: 'creator', capabilities: const []),
      profileRoleSummaryFor(
        role: 'creator',
        capabilities: const ['scenario.generate'],
      ),
    ];
    for (final summary in summaries) {
      final presentation = ProfilePersonalPresentation(accessSummary: summary);
      expect(presentation.title, 'Creator');
      expect(presentation.layout, ProfilePersonalLayout.personal);
      expect(presentation.accessSummary, same(summary));
      expect(presentation.canShowCreatorTools, summary?.canCreate ?? false);
      expect(presentation.canShowGeneratorTools, summary?.canGenerate ?? false);
    }
  });

  test('unknown role or unavailable capabilities stays fail closed', () {
    for (final summary in <ProfileRoleSummary>[
      profileRoleSummaryFor(role: null, capabilities: const ['create.event']),
      profileRoleSummaryFor(role: 'creator', capabilities: null),
      profileRoleSummaryFor(
        role: 'unknown',
        capabilities: const ['create.event'],
      ),
    ]) {
      final presentation = ProfilePersonalPresentation(accessSummary: summary);
      expect(presentation.title, 'Creator');
      expect(presentation.canShowCreatorTools, isFalse);
      expect(presentation.canShowGeneratorTools, isFalse);
      for (final tier in ProfileRoleTier.values) {
        final preview = profileRoleSummaryForPresentation(
          tier: tier,
          accessSummary: summary,
        );
        expect(preview.canCreate, isFalse);
        expect(preview.canGenerate, isFalse);
        expect(
          profileRoleTierUnlocked(
            tier: ProfileRoleTier.creator,
            accessSummary: preview,
          ),
          isFalse,
        );
      }
    }
  });

  test(
    'all preview tiers preserve actual hints and descriptive capabilities',
    () {
      for (final role in ['user', 'creator', 'pro_generator']) {
        final actual = profileRoleSummaryFor(
          role: role,
          capabilities: const ['create.event'],
        );
        for (final tier in ProfileRoleTier.values) {
          final preview = profileRoleSummaryForPresentation(
            tier: tier,
            accessSummary: actual,
          );
          expect(preview.tier, tier);
          expect(preview.canCreate, actual.canCreate);
          expect(preview.canGenerate, actual.canGenerate);
          expect(preview.capabilities, same(actual.capabilities));
        }
      }
    },
  );

  for (final verification in CreatorVerificationStatus.values) {
    test(
      'Creator presentation cannot authorize page create: $verification',
      () async {
        final snapshot = _snapshot(verification, const {'page.create'});
        final repository = _AccessRepository(snapshot);
        final actual = profileRoleSummaryFor(
          role: snapshot.globalRole,
          capabilities: snapshot.globalCapabilities.toList(),
        );
        final preview = profileRoleSummaryForPresentation(
          tier: ProfileRoleTier.creator,
          accessSummary: actual,
        );
        expect(
          ProfilePersonalPresentation(accessSummary: preview).title,
          'Creator',
        );
        final createPage = CreateProfessionalPageUseCase(
          repository: repository,
          idGenerator: _TestIdGenerator(),
        );
        if (verification == CreatorVerificationStatus.verified) {
          final page = await createPage(userId: 'u1', input: _pageInput);
          expect(page.ownerUserId, 'u1');
          expect(repository.savedPages, 1);
        } else {
          await expectLater(
            createPage(userId: 'u1', input: _pageInput),
            throwsA(
              isA<CreateProfessionalPageException>().having(
                (error) => error.code,
                'code',
                'page_creation_not_authorized',
              ),
            ),
          );
          expect(repository.savedPages, 0);
        }
        expect(repository.snapshot, same(snapshot));
        expect(snapshot.creatorVerificationStatus, verification);
        expect(snapshot.globalCapabilities, const {'page.create'});
      },
    );
  }

  test(
    'verified identity and preview do not invent missing page grant',
    () async {
      final repository = _AccessRepository(
        _snapshot(CreatorVerificationStatus.verified, const {}),
      );
      final summary = profileRoleSummaryFor(
        role: 'creator',
        capabilities: const [],
      );
      final preview = profileRoleSummaryForPresentation(
        tier: ProfileRoleTier.proGenerator,
        accessSummary: summary,
      );
      expect(preview.canGenerate, isFalse);
      await expectLater(
        CreateProfessionalPageUseCase(
          repository: repository,
          idGenerator: _TestIdGenerator(),
        )(userId: 'u1', input: _pageInput),
        throwsA(
          isA<CreateProfessionalPageException>().having(
            (error) => error.code,
            'code',
            'page_creation_not_authorized',
          ),
        ),
      );
      expect(repository.savedPages, 0);
      expect(repository.snapshot.globalCapabilities, isEmpty);
    },
  );
}

IdentityAccessSnapshot _snapshot(
  CreatorVerificationStatus verification,
  Set<String> capabilities,
) => IdentityAccessSnapshot(
  userId: 'u1',
  globalRole: 'creator',
  creatorVerificationStatus: verification,
  globalCapabilities: capabilities,
  pages: const [],
  memberships: const [],
  revision: 7,
);

const _pageInput = ProfessionalPageCreationInput(
  kind: ManagedPageKind.company,
  displayName: 'Test page',
  marketId: 'riga',
  countryCode: 'LV',
  defaultLocale: 'en',
  timezone: 'Europe/Riga',
  defaultCurrency: 'EUR',
  supportedLocales: ['en'],
);

class _TestIdGenerator implements IdGenerator {
  @override
  String generate() => '01ARZ3NDEKTSV4RRFFQ69G5FAV';
}

class _AccessRepository implements IdentityWorkspaceRepository {
  _AccessRepository(this.snapshot);
  final IdentityAccessSnapshot snapshot;
  int savedPages = 0;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async =>
      snapshot;

  @override
  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  }) async {
    savedPages++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
