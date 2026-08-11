import 'currency_code.dart';

/// Exact monetary amount stored in integer minor units.
final class Money implements Comparable<Money> {
  const Money({required int minorUnits, required this.currency})
    : _minorUnits = minorUnits;

  const Money.zero(this.currency) : _minorUnits = 0;

  static const int maxSafeMinorUnits = 9007199254740991;

  final int _minorUnits;
  final CurrencyCode currency;

  int get minorUnits {
    if (_minorUnits < -maxSafeMinorUnits || _minorUnits > maxSafeMinorUnits) {
      throw MoneyRangeException(_minorUnits);
    }
    return _minorUnits;
  }

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  Money operator -() => Money(minorUnits: -minorUnits, currency: currency);

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw MoneyCurrencyMismatchException(currency, other.currency);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits ${currency.value})';
}

final class MoneyCurrencyMismatchException implements Exception {
  const MoneyCurrencyMismatchException(this.left, this.right);

  final CurrencyCode left;
  final CurrencyCode right;

  @override
  String toString() =>
      'MoneyCurrencyMismatchException(${left.value}, ${right.value})';
}

final class MoneyRangeException implements Exception {
  const MoneyRangeException(this.minorUnits);

  final int minorUnits;

  @override
  String toString() =>
      'MoneyRangeException($minorUnits outside JSON-safe integer range)';
}
