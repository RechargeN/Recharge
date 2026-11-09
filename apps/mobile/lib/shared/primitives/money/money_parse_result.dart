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
  const MoneyParseResult.failure(MoneyParseError this.error)
    : value = null;
  final Money? value;
  final MoneyParseError? error;
  bool get isSuccess => value != null;
}
