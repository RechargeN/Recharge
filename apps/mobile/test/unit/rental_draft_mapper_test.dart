import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/rental_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';

void main() {
  test(
    'round-trips typed Rental data and preserves unknown top-level fields',
    () {
      final RentalDraftData defaults = _defaults();
      final RentalDraftData decoded = RentalDraftMapper.fromJson(
        <String, Object?>{
          'schemaVersion': 1,
          'revision': 3,
          'publisherRef': <String, Object?>{'type': 'user', 'id': 'user-1'},
          'title': 'Mountain bikes',
          'shortDescription': 'Trail bikes for rent, all sizes available.',
          'fullDescription':
              'Full description with enough characters to pass validation for '
              'this rental listing about mountain bikes for rent near Riga.',
          'categoryId': 'sport',
          'subcategoryId': 'cycling',
          'inventoryGroups': <Object?>[
            <String, Object?>{
              'id': 'group-1',
              'label': 'Adult M',
              'quantity': 5,
              'condition': 'good',
              'status': 'available',
            },
          ],
          'availability': <String, Object?>{
            'timeZoneId': 'Europe/Riga',
            'coverage': <String, Object?>{
              'startsAtUtc': '2026-08-01T00:00:00.000Z',
              'endsAtUtc': '2026-11-01T00:00:00.000Z',
              'confirmedAtUtc': '2026-08-20T00:00:00.000Z',
            },
            'blocks': <Object?>[],
          },
          'handover': <String, Object?>{
            'pickupPlaceName': 'Riga bike shop',
            'publicAreaLabel': 'Old Town',
            'disclosure': 'approximateArea',
          },
          'terms': <String, Object?>{
            'offeredMinMinutes': 60,
            'offeredMaxMinutes': 4320,
          },
          'pricing': <String, Object?>{
            'currencyCode': 'EUR',
            'billingUnit': 'day',
            'rateSteps': <Object?>[
              <String, Object?>{
                'minUnits': 1,
                'unitPrice': <String, Object?>{
                  'amountMinor': 2800,
                  'currencyCode': 'EUR',
                },
              },
            ],
            'deposit': <String, Object?>{
              'amount': <String, Object?>{
                'amountMinor': 15000,
                'currencyCode': 'EUR',
              },
              'collectionMethod': 'externalProvider',
              'terms': 'Held by provider until return.',
            },
            'damagePolicy': 'Repair cost up to deposit amount.',
            'cancellationPolicyId': 'standard',
          },
          'fulfillment': <String, Object?>{
            'externalBookingUrl': 'https://example.com/book',
          },
          'attestation': <String, Object?>{'policyVersion': '1.0'},
          'futureField': <String, Object?>{'enabled': true},
        },
        defaults: defaults,
      );

      expect(decoded.revision, 3);
      expect(decoded.title, 'Mountain bikes');
      expect(decoded.inventoryGroups, hasLength(1));
      expect(decoded.inventoryGroups.first.quantity, 5);
      expect(decoded.availability.coverage, isNotNull);
      expect(decoded.pricing.rateSteps.first.unitPrice.amountMinor, 2800);
      expect(decoded.pricing.deposit.amount.amountMinor, 15000);
      expect(
        decoded.fulfillment.externalBookingUrl,
        'https://example.com/book',
      );
      expect(decoded.unknownFields, contains('futureField'));

      final Map<String, Object?> encoded = RentalDraftMapper.toJson(decoded);
      expect(encoded['futureField'], <String, Object?>{'enabled': true});
      expect(encoded['schemaVersion'], RentalDraftData.currentSchemaVersion);
      expect(encoded['title'], 'Mountain bikes');
    },
  );

  test('rejects unsupported future schema instead of silently downgrading', () {
    expect(
      () => RentalDraftMapper.fromJson(<String, Object?>{
        'schemaVersion': 999,
      }, defaults: _defaults()),
      throwsFormatException,
    );
  });
}

RentalDraftData _defaults() => RentalDraftData.defaults(
  userId: 'user-1',
  currencyCode: 'EUR',
  timeZoneId: 'Europe/Riga',
);
