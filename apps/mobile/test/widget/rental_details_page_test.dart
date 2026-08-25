import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/published_rental_discovery_entity.dart';
import 'package:recharge/features/discover/presentation/pages/rental_details_page.dart';

import 'widget_test_viewport.dart';

void main() {
  PublishedRentalDiscoveryEntity entity({
    bool hasInventory = true,
    String? externalBookingUrl = 'https://example.com/book',
  }) {
    return PublishedRentalDiscoveryEntity(
      rentalId: 'rental-1',
      publisherId: 'user-1',
      title: 'Mountain bikes for rent',
      shortDescription: 'Trail bikes',
      fullDescription: 'Trail bikes for the whole family.',
      categoryId: 'sport',
      subcategoryId: 'cycling',
      inventoryGroups: <PublishedRentalInventoryGroupRef>[
        PublishedRentalInventoryGroupRef(
          id: 'g1',
          label: 'Adult M',
          quantity: 3,
          condition: 'good',
          status: hasInventory ? 'available' : 'retired',
        ),
      ],
      totalUnitsAggregate: 3,
      publicAreaLabel: 'Old Town, Riga',
      publicGeoPrecisionMeters: 500,
      deliveryAvailable: false,
      offeredMinMinutes: 1440,
      offeredMaxMinutes: 4320,
      idRequiredAtHandover: true,
      minRenterAge: 18,
      currencyCode: 'EUR',
      billingUnit: 'day',
      rateSteps: const <PublishedRentalRateStepRef>[
        PublishedRentalRateStepRef(minUnits: 1, unitPriceMinor: 2500),
      ],
      hasDeposit: false,
      damagePolicy: 'Repair cost billed to renter.',
      cancellationPolicyId: 'standard',
      externalBookingUrl: externalBookingUrl,
      publishedAtUtc: DateTime.utc(2026, 8, 24),
    );
  }

  fullPageTestWidgets('renders title, inventory and rate plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RentalDetailsPage(projection: entity())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mountain bikes for rent'), findsOneWidget);
    expect(find.textContaining('Adult M'), findsOneWidget);
    expect(
      find.text('Check availability on provider site'),
      findsOneWidget,
    );
  });

  fullPageTestWidgets(
    'the CTA is enabled purely from listing data, independent of any '
    'viewer capability check (OBJ-AC-07 — no capability is even read here)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RentalDetailsPage(projection: entity())),
      );
      await tester.pumpAndSettle();

      final Finder ctaButton = find.widgetWithText(
        FilledButton,
        'Check availability on provider site',
      );
      expect(ctaButton, findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(ctaButton);
      expect(button.onPressed, isNotNull);
    },
  );

  fullPageTestWidgets(
    'no active inventory collapses the CTA to Currently unavailable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RentalDetailsPage(projection: entity(hasInventory: false)),
        ),
      );
      await tester.pumpAndSettle();

      final Finder ctaButton = find.widgetWithText(
        FilledButton,
        'Currently unavailable',
      );
      expect(ctaButton, findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(ctaButton);
      expect(button.onPressed, isNull);
    },
  );
}
