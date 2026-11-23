import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';

// Owner 2026-11-23, variant A (ADR 0023 amendment): a User creates a Page and
// publishes free content from it without identity or Page verification. Paid,
// booking and the "verified" badge still need verification (server-checked).

ManagedPageEntity _page(ManagedPageVerificationStatus status) =>
    ManagedPageEntity(
      id: 'page-1',
      ownerUserId: 'alice',
      kind: ManagedPageKind.company,
      displayName: 'Cafe',
      avatar: '',
      verificationStatus: status,
      lifecycle: ManagedPageLifecycle.active,
      marketId: 'LV',
      countryCode: 'LV',
      defaultLocale: 'lv',
      timezone: 'Europe/Riga',
      defaultCurrency: 'EUR',
      supportedLocales: const <String>['lv'],
      createdAtUtc: DateTime.utc(2026, 11, 23),
      revision: 1,
    );

IdentityAccessSnapshot _snapshot(ManagedPageVerificationStatus status) =>
    IdentityAccessSnapshot(
      userId: 'alice',
      globalRole: 'user',
      creatorVerificationStatus: CreatorVerificationStatus.notStarted,
      globalCapabilities: const <String>{'page.create'},
      pages: <ManagedPageEntity>[_page(status)],
      memberships: const <ManagedPageMembershipEntity>[
        ManagedPageMembershipEntity(
          pageId: 'page-1',
          userId: 'alice',
          relationship: ManagedPageRelationship.owner,
          status: ManagedPageMembershipStatus.active,
          capabilities: <String>{'page.manage', 'page.content.create'},
          revision: 1,
        ),
      ],
      revision: 1,
    );

void main() {
  final unverified = _snapshot(ManagedPageVerificationStatus.unverified);

  test('an unverified User may create a Page', () {
    expect(unverified.canCreatePage, isTrue);
  });

  test('an unverified User works in an active unverified Page', () {
    expect(unverified.canActivatePage('page-1'), isTrue);
    expect(
      unverified.canUsePage('alice', 'page-1', 'page.content.create'),
      isTrue,
    );
  });

  test('an active unverified Page is public; a rejected one is not', () {
    expect(
      _page(ManagedPageVerificationStatus.unverified).isPubliclyVisible,
      isTrue,
    );
    expect(
      _page(ManagedPageVerificationStatus.rejected).isPubliclyVisible,
      isFalse,
    );
    expect(
      _page(ManagedPageVerificationStatus.revoked).isPubliclyVisible,
      isFalse,
    );
  });

  test('without page.create nobody creates a Page', () {
    final none = IdentityAccessSnapshot(
      userId: 'alice',
      globalRole: 'user',
      creatorVerificationStatus: CreatorVerificationStatus.verified,
      globalCapabilities: const <String>{},
      pages: const <ManagedPageEntity>[],
      memberships: const <ManagedPageMembershipEntity>[],
      revision: 1,
    );
    expect(none.canCreatePage, isFalse);
  });
}
