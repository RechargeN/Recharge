import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/entities/rental_direct_publish_decision.dart';
import 'package:recharge/features/create/domain/usecases/resolve_rental_direct_publish_usecase.dart';

void main() {
  const resolve = ResolveRentalDirectPublishUseCase();

  RentalDirectPublishContext authorizedContext({
    bool isVerifiedCreator = true,
    Set<String> capabilities = const <String>{'publish.rental.direct'},
    PublisherRef draftPublisherRef = const PublisherRef(
      type: PublisherType.user,
      id: 'user-1',
    ),
    bool isPolicyTrusted = true,
    String actorUserId = 'user-1',
  }) {
    return RentalDirectPublishContext(
      actorUserId: actorUserId,
      isVerifiedCreator: isVerifiedCreator,
      capabilities: capabilities,
      draftPublisherRef: draftPublisherRef,
      isPolicyTrusted: isPolicyTrusted,
    );
  }

  test('every condition satisfied resolves authorized', () {
    final decision = resolve(authorizedContext());

    expect(decision.authorized, isTrue);
    expect(decision.reasonCode, RentalDirectPublishReasonCode.authorized);
  });

  test('unverified Creator resolves creatorUnverified first', () {
    final decision = resolve(
      authorizedContext(
        isVerifiedCreator: false,
        capabilities: const <String>{},
        isPolicyTrusted: false,
      ),
    );

    expect(decision.authorized, isFalse);
    expect(
      decision.reasonCode,
      RentalDirectPublishReasonCode.creatorUnverified,
    );
  });

  test('missing capability resolves capabilityMissing', () {
    final decision = resolve(
      authorizedContext(capabilities: const <String>{}),
    );

    expect(
      decision.reasonCode,
      RentalDirectPublishReasonCode.capabilityMissing,
    );
  });

  test('untrusted policy resolves policyUntrusted', () {
    final decision = resolve(authorizedContext(isPolicyTrusted: false));

    expect(decision.reasonCode, RentalDirectPublishReasonCode.policyUntrusted);
  });

  test('page publisher is always pageMembershipUnsupported', () {
    final decision = resolve(
      authorizedContext(
        draftPublisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-1',
        ),
      ),
    );

    expect(
      decision.reasonCode,
      RentalDirectPublishReasonCode.pageMembershipUnsupported,
    );
  });

  test('personal publisher mismatch resolves notOwner', () {
    final decision = resolve(
      authorizedContext(
        draftPublisherRef: const PublisherRef(
          type: PublisherType.user,
          id: 'someone-else',
        ),
        actorUserId: 'user-1',
      ),
    );

    expect(decision.reasonCode, RentalDirectPublishReasonCode.notOwner);
  });

  test(
    'multiple simultaneous violations report the first checked reason',
    () {
      final decision = resolve(
        authorizedContext(
          isVerifiedCreator: false,
          capabilities: const <String>{},
          isPolicyTrusted: false,
          draftPublisherRef: const PublisherRef(
            type: PublisherType.page,
            id: 'page-1',
          ),
        ),
      );

      expect(
        decision.reasonCode,
        RentalDirectPublishReasonCode.creatorUnverified,
      );
    },
  );
}
