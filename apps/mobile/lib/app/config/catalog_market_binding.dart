import '../../shared/primitives/market/market_ref.dart';

/// Explicit bridge to the existing Catalog v1 country-market namespace.
/// UI market ids and country display metadata do not grant server access.
String catalogMarketIdFor(MarketRef market) => switch (market.value) {
  'riga' || 'rezekne' => 'LV',
  _ => throw FormatException('catalog_market_binding_unknown', market.value),
};
