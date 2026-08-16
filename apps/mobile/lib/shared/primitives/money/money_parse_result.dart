import 'money.dart';

sealed class MoneyParseResult {
  const MoneyParseResult();

  bool get isSuccess => this is MoneyParseSuccess;
}

final class MoneyParseSuccess extends MoneyParseResult {
  const MoneyParseSuccess(this.money);

  final Money money;
}

enum MoneyParseFailureCode {
  empty,
  invalidFormat,
  unknownCurrency,
  excessFractionDigits,
  overflow,
}

final class MoneyParseFailure extends MoneyParseResult {
  const MoneyParseFailure({required this.code, required this.message});

  final MoneyParseFailureCode code;
  final String message;
}
