/// Structural currency identity. Availability/exponent belong to metadata.
class CurrencyCode {
  const CurrencyCode._(this.value);
  factory CurrencyCode.parse(String source) {
    final normalized = source.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw FormatException('Expected an alpha-3 currency code', source);
    }
    return CurrencyCode._(normalized);
  }
  static const eur = CurrencyCode._('EUR');
  final String value;
  @override
  bool operator ==(Object other) =>
      other is CurrencyCode && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
