import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/features/create/application/collection_budget_suggestion_policy.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';

void main() {
  const policy = CollectionBudgetSuggestionPolicy();
  MarketBudgetTierConfig config(int low, int medium) => MarketBudgetTierConfig(
    marketCityId: 'test',
    currency: 'EUR',
    lowMaxMinorUnits: low,
    mediumMaxMinorUnits: medium,
  );
  CollectionBudgetTier? suggest(List<int> amounts, int low, int medium) =>
      policy.suggest(
        items: amounts.map((amount) => item(amount)).toList(),
        marketConfig: config(low, medium),
      );

  test('median does not round a half minor unit at tier boundaries', () {
    expect(suggest([1000, 1000], 1000, 2000), CollectionBudgetTier.low);
    expect(suggest([1000, 1001], 1000, 2000), CollectionBudgetTier.medium);
    expect(suggest([2000, 2001], 1000, 2000), CollectionBudgetTier.high);
    expect(suggest([0, 1000, 3000], 1000, 2000), CollectionBudgetTier.low);
  });
  test('maximum safe amounts retain exact median classification', () {
    const max = Money.maxSafeMinorUnits;
    expect(suggest([max - 1, max], max - 1, max), CollectionBudgetTier.medium);
    expect(suggest([max, max], max - 1, max), CollectionBudgetTier.medium);
  });
  test('feature free policy, coverage and currency rules remain explicit', () {
    expect(suggest([0, 0], 1000, 2000), CollectionBudgetTier.free);
    expect(suggest([100], 1000, 2000), isNull);
    expect(
      policy.suggest(
        items: [
          item(100),
          item(100, currency: 'USD'),
        ],
        marketConfig: config(1000, 2000),
      ),
      isNull,
    );
  });
}

CollectionItemDraft item(int amount, {String currency = 'EUR'}) =>
    CollectionItemDraft(
      id: 'item-$amount-$currency',
      ref: CollectionObjectRef(
        objectId: 'object-$amount-$currency',
        objectType: CollectionCatalogObjectType.place,
      ),
      snapshot: CollectionItemSnapshotDraft(
        title: 'Test',
        priceFromMinorUnits: amount,
        currency: currency,
      ),
      sourceStatus: CollectionSourceStatus.ready,
      order: 0,
    );
