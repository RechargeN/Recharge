import '../domain/entities/collection_draft_data.dart';
import '../domain/entities/collection_item_draft.dart';

/// Market/currency-scoped tier thresholds (§15 "Конфигурационные
/// константы"). Concrete EUR values for the Riga demo live in runtime
/// defaults, not here or in any widget.
class MarketBudgetTierConfig {
  const MarketBudgetTierConfig({
    required this.marketCityId,
    required this.currency,
    required this.lowMaxMinorUnits,
    required this.mediumMaxMinorUnits,
  });

  final String marketCityId;
  final String currency;

  /// Median price ≤ this ⇒ `low`. A median of exactly 0 ⇒ `free`.
  final int lowMaxMinorUnits;

  /// Median price ≤ this ⇒ `medium`; above it ⇒ `high`.
  final int mediumMaxMinorUnits;
}

/// Deterministic, non-destructive budget-tier suggestion (§7 Шаг 4, Вопрос
/// 18). Never writes a field on its own — the coordinator only applies the
/// result through an explicit author action — and never guesses across
/// mixed or unknown currencies.
class CollectionBudgetSuggestionPolicy {
  const CollectionBudgetSuggestionPolicy({
    this.minPriceCoverage = 0.5,
    this.minPriceCount = 2,
  });

  final double minPriceCoverage;
  final int minPriceCount;

  CollectionBudgetTier? suggest({
    required List<CollectionItemDraft> items,
    required MarketBudgetTierConfig marketConfig,
  }) {
    final List<CollectionItemDraft> readyItems = items
        .where(
          (CollectionItemDraft item) =>
              item.sourceStatus == CollectionSourceStatus.ready,
        )
        .toList(growable: false);
    if (readyItems.isEmpty) return null;

    final List<int> pricesInMarketCurrency = <int>[];
    for (final CollectionItemDraft item in readyItems) {
      final int? price = item.snapshot.priceFromMinorUnits;
      final String? currency = item.snapshot.currency;
      if (price == null || currency == null) continue;
      if (currency != marketConfig.currency) {
        // A single foreign/unknown currency invalidates the whole
        // suggestion rather than silently excluding that item.
        return null;
      }
      pricesInMarketCurrency.add(price);
    }
    if (pricesInMarketCurrency.length < minPriceCount) return null;
    final double coverage = pricesInMarketCurrency.length / readyItems.length;
    if (coverage < minPriceCoverage) return null;

    final BigInt twiceMedian = _twiceMedian(pricesInMarketCurrency);
    if (twiceMedian <= BigInt.zero) return CollectionBudgetTier.free;
    if (twiceMedian <=
        BigInt.from(marketConfig.lowMaxMinorUnits) * BigInt.two) {
      return CollectionBudgetTier.low;
    }
    if (twiceMedian <=
        BigInt.from(marketConfig.mediumMaxMinorUnits) * BigInt.two) {
      return CollectionBudgetTier.medium;
    }
    return CollectionBudgetTier.high;
  }

  // Compare the exact rational median without rounding half a minor unit.
  static BigInt _twiceMedian(List<int> values) {
    final List<int> sorted = List<int>.of(values)..sort();
    final int mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return BigInt.from(sorted[mid]) * BigInt.two;
    return BigInt.from(sorted[mid - 1]) + BigInt.from(sorted[mid]);
  }
}
