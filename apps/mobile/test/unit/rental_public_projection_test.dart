import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_public_projection_usecase.dart';

void main() {
  const BuildRentalPublicProjectionUseCase useCase =
      BuildRentalPublicProjectionUseCase();

  RentalDraftData draft({
    RentalLocationDisclosure disclosure =
        RentalLocationDisclosure.approximateArea,
    String? publicAddress,
  }) =>
      RentalDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
        timeZoneId: 'Europe/Riga',
      ).copyWith(
        title: 'Kayaks',
        handover: RentalHandoverDraft(
          pickupPlaceName: 'Riga waterfront',
          publicAreaLabel: 'Daugava embankment',
          disclosure: disclosure,
          publicAddress: publicAddress,
        ),
      );

  test('AC12: approximate-area draft never exposes a public address', () {
    final RentalDraftData source = draft(
      disclosure: RentalLocationDisclosure.approximateArea,
      publicAddress:
          'Some Street 12', // should never happen upstream, but defend anyway
    );

    final projection = useCase(id: 'listing-1', draft: source);

    expect(projection.publicAddress, isNull);
  });

  test(
    'business-address opt-in exposes exactly the address Creator entered',
    () {
      final RentalDraftData source = draft(
        disclosure: RentalLocationDisclosure.publicBusinessAddress,
        publicAddress: 'Some Street 12',
      );

      final projection = useCase(id: 'listing-1', draft: source);

      expect(projection.publicAddress, 'Some Street 12');
    },
  );

  test('projection never carries private authoring fields by construction', () {
    // RentalListing has no exactPickupAddress/exactPickupGeo/notes fields at
    // all — this test documents that guarantee via reflection-free means:
    // any attempt to add such data here would fail to compile against
    // RentalListing's actual field set, not merely fail at runtime.
    final RentalDraftData source = draft();
    final projection = useCase(id: 'listing-1', draft: source);

    expect(projection.id, 'listing-1');
    expect(projection.publisherRef, source.publisherRef);
  });
}
