import 'currency_code.dart';

/// Display and decimal-scale metadata for a supported currency.
final class CurrencyMetadata {
  const CurrencyMetadata({
    required this.code,
    required this.minorUnitExponent,
    required this.symbol,
  }) : assert(minorUnitExponent >= 0 && minorUnitExponent <= 6);

  final CurrencyCode code;
  final int minorUnitExponent;
  final String symbol;

  static const List<CurrencyMetadata> supported = <CurrencyMetadata>[
    CurrencyMetadata(code: CurrencyCode.eur, minorUnitExponent: 2, symbol: '€'),
    CurrencyMetadata(
      code: CurrencyCode.usd,
      minorUnitExponent: 2,
      symbol: r'$',
    ),
    CurrencyMetadata(code: CurrencyCode.gbp, minorUnitExponent: 2, symbol: '£'),
    CurrencyMetadata(
      code: CurrencyCode.sek,
      minorUnitExponent: 2,
      symbol: 'kr',
    ),
    CurrencyMetadata(
      code: CurrencyCode.nok,
      minorUnitExponent: 2,
      symbol: 'kr',
    ),
    CurrencyMetadata(
      code: CurrencyCode.dkk,
      minorUnitExponent: 2,
      symbol: 'kr',
    ),
    CurrencyMetadata(
      code: CurrencyCode.pln,
      minorUnitExponent: 2,
      symbol: 'zł',
    ),
    CurrencyMetadata(
      code: CurrencyCode.chf,
      minorUnitExponent: 2,
      symbol: 'CHF',
    ),
    CurrencyMetadata(code: CurrencyCode.jpy, minorUnitExponent: 0, symbol: '¥'),
    CurrencyMetadata(
      code: CurrencyCode.bhd,
      minorUnitExponent: 3,
      symbol: 'BHD',
    ),
  ];

  static CurrencyMetadata? tryFor(CurrencyCode code) {
    for (final CurrencyMetadata metadata in supported) {
      if (metadata.code == code) {
        return metadata;
      }
    }
    return null;
  }
}
