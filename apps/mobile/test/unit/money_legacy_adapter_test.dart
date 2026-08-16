import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/shared/primitives/money/money_parser.dart';

void main() {
  test('legacy integer and decimal numbers convert losslessly', () {
    final MoneyParseSuccess integer =
        MoneyParser.parseLegacyNumber(4, currency: CurrencyCode.eur)
            as MoneyParseSuccess;
    final MoneyParseSuccess decimal =
        MoneyParser.parseLegacyNumber(12.34, currency: CurrencyCode.eur)
            as MoneyParseSuccess;

    expect(integer.money.minorUnits, 400);
    expect(decimal.money.minorUnits, 1234);
  });

  test('ambiguous legacy precision returns a typed failure', () {
    final MoneyParseResult result = MoneyParser.parseLegacyNumber(
      12.345,
      currency: CurrencyCode.eur,
    );

    expect(result, isA<MoneyParseFailure>());
    expect(
      (result as MoneyParseFailure).code,
      MoneyParseFailureCode.excessFractionDigits,
    );
  });
}
