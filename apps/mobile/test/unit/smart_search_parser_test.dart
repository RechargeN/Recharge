import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/application/smart_search_parser.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('parses free yoga tonight near radius', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'free yoga tonight near 5 km',
      currency: CurrencyCode.eur,
    );

    expect(result.queryText, 'yoga');
    expect(result.selectedCategoryIds, contains('wellness_recharge'));
    expect(result.freeOnly, isTrue);
    expect(result.datePreset, SmartSearchDatePreset.tonight);
    expect(result.radiusMeters, 5000);
    expect(result.unlimitedRadius, isFalse);
    expect(result.explanationChips, contains('free only'));
  });

  test('parses museum today budget', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'museum today under 10',
      currency: CurrencyCode.eur,
    );

    expect(result.queryText, 'museum');
    expect(result.selectedCategoryIds, contains('art_culture_museums'));
    expect(
      result.budgetMax,
      const Money(minorUnits: 1000, currency: CurrencyCode.eur),
    );
    expect(result.datePreset, SmartSearchDatePreset.today);
  });

  test('does not relabel an explicitly different currency', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'museum up to 10 usd',
      currency: CurrencyCode.eur,
    );

    expect(result.budgetMax, isNull);
  });

  test('parses any area and preserves text query', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'live music anywhere',
      currency: CurrencyCode.eur,
    );

    expect(result.queryText, 'live music');
    expect(result.selectedCategoryIds, contains('music_nightlife'));
    expect(result.unlimitedRadius, isTrue);
  });

  test('parses smart route intent with duration and steps', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'build a free calm walking route for 2 hours with coffee and park near 5 km',
      currency: CurrencyCode.eur,
    );

    expect(result.routeIntent, isNotNull);
    expect(result.routeIntent!.mood, 'calm');
    expect(result.routeIntent!.durationMinutes, 120);
    expect(result.routeIntent!.freeOnly, isTrue);
    expect(result.routeIntent!.walkingOnly, isTrue);
    expect(
      result.routeIntent!.stepCategories,
      containsAll(<String>[
        'food_drinks.coffee',
        'wellness_recharge.calm_walk',
      ]),
    );
    expect(result.explanationChips, contains('route'));
    expect(result.explanationChips, contains('120 min'));
  });

  test('parses active smart route fallback steps', () {
    final SmartSearchParseResult result = parseSmartSearch(
      'active route for 90 min',
      currency: CurrencyCode.eur,
    );

    expect(result.routeIntent, isNotNull);
    expect(result.routeIntent!.mood, 'active');
    expect(result.routeIntent!.durationMinutes, 90);
    expect(result.routeIntent!.stepCategories, <String>[
      'sport.tennis',
      'outdoor_nature_walking.city_walk',
    ]);
  });
}
