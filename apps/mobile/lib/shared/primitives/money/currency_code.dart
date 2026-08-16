/// Structurally valid ISO 4217-style alphabetic currency code.
final class CurrencyCode implements Comparable<CurrencyCode> {
  const CurrencyCode._(this.value);

  factory CurrencyCode.parse(String raw) {
    final String normalized = raw.trim().toUpperCase();
    if (!_pattern.hasMatch(normalized)) {
      throw FormatException('Invalid alphabetic currency code: $raw');
    }
    return CurrencyCode._(normalized);
  }

  static CurrencyCode? tryParse(Object? raw) {
    if (raw is! String) {
      return null;
    }
    try {
      return CurrencyCode.parse(raw);
    } on FormatException {
      return null;
    }
  }

  static const CurrencyCode eur = CurrencyCode._('EUR');
  static const CurrencyCode usd = CurrencyCode._('USD');
  static const CurrencyCode gbp = CurrencyCode._('GBP');
  static const CurrencyCode sek = CurrencyCode._('SEK');
  static const CurrencyCode nok = CurrencyCode._('NOK');
  static const CurrencyCode dkk = CurrencyCode._('DKK');
  static const CurrencyCode pln = CurrencyCode._('PLN');
  static const CurrencyCode chf = CurrencyCode._('CHF');
  static const CurrencyCode jpy = CurrencyCode._('JPY');
  static const CurrencyCode bhd = CurrencyCode._('BHD');

  static final RegExp _pattern = RegExp(r'^[A-Z]{3}$');

  final String value;

  @override
  int compareTo(CurrencyCode other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CurrencyCode && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
