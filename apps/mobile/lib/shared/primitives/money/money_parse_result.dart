import 'money.dart';

enum MoneyParseError {
  empty,
  invalidSyntax,
  unsupportedLocale,
  unknownCurrency,
  excessiveFractionDigits,
  outOfRange,
  invalidCanonicalValue,
  missingCurrency,
  nonFiniteLegacy,
}

class MoneyParseResult {
  const MoneyParseResult.success(Money this.value) : error = null;
  const MoneyParseResult.failure(MoneyParseError this.error) : value = null;
  final Money? value;
  final MoneyParseError? error;
  bool get isSuccess => value != null;
}

/// A mapper could not safely restore a monetary value. Callers must not treat
/// this as an absent record or replace the stored value with a fresh default.
class MoneyReadException implements Exception {
  const MoneyReadException(this.code);
  final MoneyParseError code;
  @override
  String toString() => 'MoneyReadException(${code.name})';
}
