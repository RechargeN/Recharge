import 'currency_code.dart';

enum MoneyArithmeticError { outOfRange, currencyMismatch }

class MoneyArithmeticException implements Exception {
  const MoneyArithmeticException(this.code);
  final MoneyArithmeticError code;
  @override
  String toString() => 'MoneyArithmeticException(${code.name})';
}

/// Integer monetary value. Sign/free/price policies belong to each feature.
class Money implements Comparable<Money> {
  factory Money({required int minorUnits, required CurrencyCode currency}) {
    if (minorUnits < -maxSafeMinorUnits || minorUnits > maxSafeMinorUnits) {
      throw const MoneyArithmeticException(MoneyArithmeticError.outOfRange);
    }
    return Money._(minorUnits, currency);
  }
  const Money._(this.minorUnits, this.currency);
  static const maxSafeMinorUnits = 9007199254740991;
  static final _max = BigInt.from(maxSafeMinorUnits);
  final int minorUnits;
  final CurrencyCode currency;
  Money operator +(Money other) {
    _sameCurrency(other);
    return _fromBigInt(BigInt.from(minorUnits) + BigInt.from(other.minorUnits));
  }

  Money operator -(Money other) {
    _sameCurrency(other);
    return _fromBigInt(BigInt.from(minorUnits) - BigInt.from(other.minorUnits));
  }

  Money scaledBy(int integerFactor) =>
      _fromBigInt(BigInt.from(minorUnits) * BigInt.from(integerFactor));
  Money _fromBigInt(BigInt value) {
    if (value < -_max || value > _max) {
      throw const MoneyArithmeticException(MoneyArithmeticError.outOfRange);
    }
    return Money(minorUnits: value.toInt(), currency: currency);
  }

  void _sameCurrency(Money other) {
    if (currency != other.currency) {
      throw const MoneyArithmeticException(
        MoneyArithmeticError.currencyMismatch,
      );
    }
  }

  @override
  int compareTo(Money other) {
    _sameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      minorUnits == other.minorUnits &&
      currency == other.currency;
  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
