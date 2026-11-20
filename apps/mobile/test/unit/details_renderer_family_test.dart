import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/presentation/pages/discover_details_page.dart';
import 'package:recharge/features/discover/presentation/shell/details_renderer.dart';
import 'package:recharge/shared/primitives/money/money.dart';

/// Debug assertion at route_details_renderer.dart (seen on A34): a
/// Route-typed item without Route data must not get the Route renderer,
/// which needs a published Route or Catalog Route facts.
void main() {
  DiscoverItemEntity item(DiscoverObjectKind kind) => DiscoverItemEntity(
    id: 'itm_1',
    title: 'River walk',
    subtitle: 'Old town',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
    latitude: 56.95,
    longitude: 24.1,
    priceAmount: Money(minorUnits: 0, currency: CurrencyCode.parse('EUR')),
    distanceKm: 1.2,
    isFree: true,
    relevanceScore: 0.7,
    objectKind: kind,
  );

  test('a Route-typed item without Route data uses the shared renderer', () {
    final DiscoverItemEntity route = item(DiscoverObjectKind.route);
    expect(route.isRoute, isFalse);
    expect(detailsRendererFamilyFor(route), DetailsRendererFamily.objectOffer);
  });

  test('other objects keep the shared renderer', () {
    expect(
      detailsRendererFamilyFor(item(DiscoverObjectKind.place)),
      DetailsRendererFamily.objectOffer,
    );
  });
}
