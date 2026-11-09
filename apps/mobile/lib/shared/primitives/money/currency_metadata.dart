import 'currency_code.dart';

class CurrencyMetadata {
  CurrencyMetadata({required this.code, required this.exponent}) {
    if (exponent < 0 || exponent > 6) {
      throw RangeError.range(exponent, 0, 6, 'exponent');
    }
  }
  final CurrencyCode code;
  final int exponent;
  @override
  bool operator ==(Object other) =>
      other is CurrencyMetadata &&
      code == other.code &&
      exponent == other.exponent;
  @override
  int get hashCode => Object.hash(code, exponent);
}

/// Explicitly supplied metadata; a currency code alone does not imply exponent 2.
class CurrencyMetadataRegistry {
  CurrencyMetadataRegistry(Iterable<CurrencyMetadata> entries)
    : _entries = Map.unmodifiable(_index(entries));
  static final eurOnly = CurrencyMetadataRegistry([
    CurrencyMetadata(code: CurrencyCode.eur, exponent: 2),
  ]);
  final Map<CurrencyCode, CurrencyMetadata> _entries;
  CurrencyMetadata? lookup(CurrencyCode code) => _entries[code];
  static Map<CurrencyCode, CurrencyMetadata> _index(
    Iterable<CurrencyMetadata> entries,
  ) {
    final result = <CurrencyCode, CurrencyMetadata>{};
    for (final entry in entries) {
      if (result.containsKey(entry.code)) {
        throw ArgumentError('Duplicate currency metadata');
      }
      result[entry.code] = entry;
    }
    return result;
  }
}
